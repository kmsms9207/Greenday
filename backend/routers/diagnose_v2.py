# backend/routers/diagnose_v2.py
from __future__ import annotations

import io
import os
import asyncio
import logging
from dataclasses import dataclass
from typing import Dict, List, Tuple, Optional, Any

import numpy as np
from PIL import Image, ImageOps, UnidentifiedImageError

from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, Query
from sqlalchemy.orm import Session

import models
from database import get_db
from dependencies import get_current_user

from transformers import pipeline, AutoImageProcessor

# (한국어 매핑/폴백 번역) - Papago 키 없어도 동작, 있으면 폴백 번역
from services.i18n import to_korean

logger = logging.getLogger(__name__)

# ============================================================
# 환경 변수(기본값 포함)
# ============================================================
MODEL_IDS = [
    m.strip()
    for m in os.getenv("GREENDAY_V2_MODELS", "wambugu71/crop_leaf_diseases_vit").split(";")
    if m.strip()
]

USE_CLIP_DEFAULT = os.getenv("GREENDAY_V2_USE_CLIP", "true").lower() in {"1", "true", "yes"}
CLIP_MODEL_ID = os.getenv("GREENDAY_V2_CLIP_MODEL", "openai/clip-vit-base-patch32")

USE_TTA_DEFAULT = os.getenv("GREENDAY_V2_USE_TTA", "true").lower() in {"1", "true", "yes"}

THRESHOLD: float = float(os.getenv("GREENDAY_V2_THRESHOLD", "0.01"))  # 잡음 컷
IGNORE_LABELS = {x.strip().lower() for x in os.getenv("GREENDAY_V2_IGNORE", "invalid").split(",") if x.strip()}

# 결정 임계치 (Notion 요약과 동일)
LLM_LOW: float = float(os.getenv("GREENDAY_V2_LLM_LOW", "0.35"))          # v2에선 참고만(LLM은 v3에서)
LLM_HIGH: float = float(os.getenv("GREENDAY_V2_LLM_HIGH", "0.80"))
SPECIES_MIN_CONF: float = float(os.getenv("GREENDAY_V2_SPECIES_MIN_CONF", "0.60"))

def _resolve_device() -> int:
    return 0 if os.getenv("GREENDAY_AI_DEVICE", "").lower() == "cuda" else -1

_DEVICE = _resolve_device()

# ============================================================
# 지연 로딩 캐시
# ============================================================
_model_lock = asyncio.Lock()
_classifier_cache: Dict[str, Any] = {}
_clip_cache: Optional[Any] = None

async def _load_image_classifier(model_id: str):
    loop = asyncio.get_running_loop()

    def _load():
        try:
            proc = AutoImageProcessor.from_pretrained(model_id, use_fast=True)
        except Exception:
            proc = None
        return pipeline(
            task="image-classification",
            model=model_id,
            image_processor=proc,
            device=_DEVICE,
        )

    return await loop.run_in_executor(None, _load)

async def get_classifier(model_id: str):
    if model_id in _classifier_cache:
        return _classifier_cache[model_id]
    async with _model_lock:
        if model_id not in _classifier_cache:
            clf = await _load_image_classifier(model_id)
            _classifier_cache[model_id] = clf
            logger.info("[AI] Loaded classifier: %s (device=%s)", model_id, _DEVICE)
    return _classifier_cache[model_id]

async def get_clip():
    global _clip_cache
    if _clip_cache is not None:
        return _clip_cache
    async with _model_lock:
        if _clip_cache is None:
            loop = asyncio.get_running_loop()

            def _load():
                return pipeline("zero-shot-image-classification", model=CLIP_MODEL_ID, device=_DEVICE)

            _clip_cache = await loop.run_in_executor(None, _load)
            logger.info("[AI] Loaded CLIP: %s (device=%s)", CLIP_MODEL_ID, _DEVICE)
    return _clip_cache

# ============================================================
# 라벨 유틸
# ============================================================
def split_label(raw_label: str) -> Tuple[str, str]:
    if "___" in raw_label:
        p, d = raw_label.split("___", 1)
        return p.strip(), d.strip()
    parts = raw_label.replace("-", " ").split()
    if not parts:
        return "Unknown", raw_label
    return parts[0], "_".join(parts[1:]).strip()

# ============================================================
# 전처리: 간단 HSV/채도·명도 컷으로 잎 영역 크롭 (OpenCV 없이)
# ============================================================
def hsv_leaf_crop(pil: Image.Image) -> Image.Image:
    try:
        rgb = pil.convert("RGB")
        hsv = rgb.convert("HSV")
        arr = np.array(hsv)
        h, s, v = arr[..., 0], arr[..., 1], arr[..., 2]
        mask = (s > 40) & (v > 40)  # 채도/명도 기반 간단 마스크
        ys, xs = np.where(mask)
        if len(xs) < 200:
            return pil
        x1, x2, y1, y2 = xs.min(), xs.max(), ys.min(), ys.max()
        pad = 10
        x1 = max(0, x1 - pad)
        y1 = max(0, y1 - pad)
        x2 = min(arr.shape[1], x2 + pad)
        y2 = min(arr.shape[0], y2 + pad)
        return pil.crop((x1, y1, x2, y2))
    except Exception:
        return pil

# ============================================================
# TTA (좌우/상하 반전, 90/270 회전)
# ============================================================
def _tta_variants(pil: Image.Image):
    yield pil
    yield pil.transpose(Image.FLIP_LEFT_RIGHT)
    yield pil.transpose(Image.FLIP_TOP_BOTTOM)
    yield pil.rotate(90, expand=True)
    yield pil.rotate(270, expand=True)

async def tta_predict(clf, pil: Image.Image, top_k: int = 3):
    agg: Dict[str, float] = {}
    n = 0
    for v in _tta_variants(pil):
        out = clf(v, top_k=top_k)
        for p in out:
            lbl = str(p.get("label", ""))
            sc = float(p.get("score", 0.0))
            agg[lbl] = agg.get(lbl, 0.0) + sc
        n += 1
    items = [{"label": k, "score": v / max(n, 1)} for k, v in agg.items()]
    items.sort(key=lambda x: x["score"], reverse=True)
    return items[:top_k]

# ============================================================
# CLIP 보조: 후보 라벨 텍스트로 제로샷 점수
# ============================================================
@dataclass
class ModelPred:
    model_id: str
    label: str
    score: float

async def clip_scores(pil: Image.Image, raw_labels: List[str]) -> List[ModelPred]:
    try:
        clip_pipe = await get_clip()
        # 후보 텍스트: "Plant disease words"
        cand_texts = []
        for lab in raw_labels:
            plant, disease = split_label(lab)
            cand_texts.append(f"{plant} {disease.replace('_', ' ')}".strip())
        out = clip_pipe(pil, candidate_labels=cand_texts, hypothesis_template="a photo of {}")
        # out: [{"label": "tomato early blight", "score": 0.7}, ...] (정렬된 리스트)
        preds: List[ModelPred] = []
        for o in out:
            text = str(o["label"]).strip()
            parts = text.split()
            if len(parts) >= 2:
                plant = parts[0].capitalize()
                disease = "_".join(parts[1:]).title().replace(" ", "_")
                approx = f"{plant}___{disease}"
            else:
                approx = text
            preds.append(ModelPred(CLIP_MODEL_ID, approx, float(o["score"])))
        return preds
    except Exception as e:
        logger.exception("CLIP failed: %s", e)
        return []

# ============================================================
# 집계(분류기 가중 1.0, CLIP 0.5) → 정규화 확률로 최종 라벨
# ============================================================
def aggregate_predictions(
    model_preds: List[ModelPred], clip_votes: Optional[List[ModelPred]] = None
) -> Tuple[str, float]:
    weights: Dict[str, float] = {}

    def add(ps: List[ModelPred], w: float):
        for p in ps:
            key = p.label
            if key.lower() in IGNORE_LABELS:
                continue
            if p.score < THRESHOLD:
                continue
            weights[key] = weights.get(key, 0.0) + w * float(p.score)

    add(model_preds, w=1.0)
    if clip_votes:
        add(clip_votes, w=0.5)

    if not weights:
        return ("Unknown", 0.0)

    labels, vals = list(weights.keys()), np.array(list(weights.values()), dtype=np.float32)
    probs = vals / (vals.sum() + 1e-8)
    idx = int(probs.argmax())
    return (labels[idx], float(probs[idx]))

# ============================================================
# FastAPI Router
# ============================================================
router = APIRouter(
    prefix="/diagnose",
    tags=["AI Diagnosis v2"],
    dependencies=[Depends(get_current_user)],  # 공개 테스트 필요하면 제거
)

@router.post("/v2")
async def diagnose_v2(
    image: UploadFile = File(..., description="식물 잎 사진 (jpg/png 등)"),
    top_k: int = Query(3, ge=1, le=5),
    use_preprocess: bool = Query(True, description="HSV 기반 잎/배경 크롭"),
    use_tta: bool = Query(USE_TTA_DEFAULT, description="반전/회전 TTA 평균"),
    include_per_model: bool = Query(True, description="모델별 원시 예측 포함"),
    include_clip: bool = Query(USE_CLIP_DEFAULT, description="CLIP 보조 점수 포함"),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    # 0) 파일 검증
    if not image.content_type or not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="이미지 파일만 업로드할 수 있습니다.")
    raw = await image.read()
    if len(raw) > 20 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="파일이 너무 큽니다(최대 20MB).")

    # 1) 이미지 로드 및 전처리
    try:
        with Image.open(io.BytesIO(raw)) as pil:
            pil = ImageOps.exif_transpose(pil).convert("RGB")
    except UnidentifiedImageError:
        raise HTTPException(status_code=400, detail="이미지 파일을 인식할 수 없습니다.")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"이미지 처리 오류: {e}")

    if use_preprocess:
        pil = hsv_leaf_crop(pil)

    # 2) 멀티 분류기 예측(TTA 옵션)
    per_model_preds: List[ModelPred] = []
    last_raw_labels: List[str] = []

    for mid in MODEL_IDS:
        clf = await get_classifier(mid)
        try:
            out = await tta_predict(clf, pil, top_k=top_k) if use_tta else clf(pil, top_k=top_k)
        except Exception as e:
            logger.exception("Classifier failed (%s): %s", mid, e)
            continue
        for p in out:
            lbl = str(p.get("label", ""))
            sc = float(p.get("score", 0.0))
            per_model_preds.append(ModelPred(model_id=mid, label=lbl, score=sc))
        if out:
            last_raw_labels = [o["label"] for o in out]

    # 3) CLIP 보조(옵션)
    clip_votes: Optional[List[ModelPred]] = None
    if include_clip and last_raw_labels:
        clip_votes = await clip_scores(pil, raw_labels=last_raw_labels)

    # 4) 집계 → 최종 라벨/점수
    final_label_en, final_conf = aggregate_predictions(per_model_preds, clip_votes)

    # 5) 한국어 매핑/폴백 (Papago 키 없어도 동작)
    plant_en, disease_en = split_label(final_label_en)
    plant_ko, disease_ko, label_ko = await to_korean(plant_en, disease_en)

    # 6) 종 노출 억제 정책
    show_species = final_conf >= SPECIES_MIN_CONF
    if clip_votes:
        clip_sorted = sorted(clip_votes, key=lambda v: v.score, reverse=True)
        if clip_sorted:
            clip_top_label = clip_sorted[0].label
            clip_top_plant = clip_top_label.split("___", 1)[0] if "___" in clip_top_label else clip_top_label
            if clip_top_plant != plant_en:
                show_species = False

    # 7) 응답 구성
    resp: Dict[str, Any] = {
        "label": final_label_en,
        "label_ko": label_ko,
        "score": round(final_conf, 4),
        "disease": disease_en,
        "disease_ko": disease_ko,
        "preprocess_used": bool(use_preprocess),
        "tta_used": bool(use_tta),
        "clip_used": bool(include_clip),
        "threshold_used": THRESHOLD,
        "ignored_labels": sorted(list(IGNORE_LABELS)),
        "models": MODEL_IDS,
    }
    if show_species:
        resp.update({"plant": plant_en, "plant_ko": plant_ko})

    if include_per_model:
        resp["per_model"] = [
            {
                "model_id": p.model_id,
                "label": p.label,
                "score": round(p.score, 4),
                # 각 원시 라벨도 한국어 동봉 (캐시/사전+폴백)
                **(lambda _pl, _dl: {"plant": _pl, "disease": _dl})(*split_label(p.label)),
                **(lambda _pko, _dko, _lko: {"plant_ko": _pko, "disease_ko": _dko, "label_ko": _lko})(
                    *(await to_korean(*split_label(p.label)))
                ),
            }
            for p in per_model_preds
            if (p.score >= THRESHOLD and p.label.lower() not in IGNORE_LABELS)
        ]

    if include_clip and clip_votes:
        resp["clip_votes"] = [
            {
                "model_id": v.model_id,
                "label": v.label,
                "score": round(v.score, 4),
                **(lambda _pl, _dl: {"plant": _pl, "disease": _dl})(*split_label(v.label)),
                **(lambda _pko, _dko, _lko: {"plant_ko": _pko, "disease_ko": _dko, "label_ko": _lko})(
                    *(await to_korean(*split_label(v.label)))
                ),
            }
            for v in clip_votes
            if (v.score >= THRESHOLD and v.label.lower() not in IGNORE_LABELS)
        ]

    return resp

# (옵션) 모델별 지원 라벨 확인
@router.get("/v2/labels")
async def diagnose_v2_labels():
    labels_map: Dict[str, List[str]] = {}
    for mid in MODEL_IDS:
        try:
            clf = await get_classifier(mid)
            id2label = getattr(clf.model.config, "id2label", {})
            labels = [id2label[i] for i in sorted(id2label.keys())] if id2label else []
            labels_map[mid] = labels
        except Exception as e:
            logger.exception("labels failed for %s: %s", mid, e)
            labels_map[mid] = []
    return {"models": MODEL_IDS, "labels": labels_map}
