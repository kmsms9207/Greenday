# backend/routers/diagnose_v3.py
from __future__ import annotations

import io
import os
import asyncio
import logging
from dataclasses import dataclass
from typing import Dict, List, Tuple, Optional, Any
from datetime import datetime, timedelta, timezone

import numpy as np
from PIL import Image, ImageOps, UnidentifiedImageError

from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import and_

import models
from database import get_db
from dependencies import get_current_user

from transformers import pipeline, AutoImageProcessor

from services.i18n import to_korean, cache_set_label_ko  # Papago 없어도 동작
from utils.image_meta import compute_phash64, make_thumbnail_bytes

logger = logging.getLogger(__name__)

# ===== 환경 변수 =====
MODEL_IDS = [m.strip() for m in os.getenv("GREENDAY_V2_MODELS", "wambugu71/crop_leaf_diseases_vit").split(";") if m.strip()]
USE_CLIP_DEFAULT = os.getenv("GREENDAY_V2_USE_CLIP", "true").lower() in {"1", "true", "yes"}
USE_TTA_DEFAULT  = os.getenv("GREENDAY_V2_USE_TTA", "true").lower() in {"1", "true", "yes"}
CLIP_MODEL_ID = os.getenv("GREENDAY_V2_CLIP_MODEL", "openai/clip-vit-base-patch32")

THRESHOLD: float = float(os.getenv("GREENDAY_V2_THRESHOLD", "0.25"))
IGNORE_LABELS = {x.strip().lower() for x in os.getenv("GREENDAY_V2_IGNORE", "invalid").split(",") if x.strip()}

LLM_LOW: float = float(os.getenv("GREENDAY_V2_LLM_LOW", "0.35"))   # (참고값)
LLM_HIGH: float = float(os.getenv("GREENDAY_V2_LLM_HIGH", "0.80"))

# 종명 숨김 + 병/해충만 판단
HIDE_SPECIES: bool = os.getenv("GREENDAY_V3_HIDE_SPECIES", "true").lower() in {"1","true","yes"}
DISEASE_ONLY: bool = os.getenv("GREENDAY_V3_DISEASE_ONLY", "true").lower() in {"1","true","yes"}

_default_disease_list = (
    "powdery_mildew,downy_mildew,leaf_spot,anthracnose,"
    "bacterial_leaf_spot,rust,early_blight,late_blight,gray_mold,botrytis,sooty_mold,"
    "chlorosis,leaf_scorch,edema,root_rot,overwatering_damage,underwatering_damage,sunburn,"
    "spider_mites,mealybugs,scale_insects,aphids,thrips,whiteflies,leaf_miner,virus_mosaic"
)
DISEASE_LIST = [x.strip() for x in os.getenv("GREENDAY_V3_DISEASE_LIST", _default_disease_list).split(",") if x.strip()]

# DB 캐시 TTL(초) - 동일 이미지(pHash)면 TTL 내 과거 결과 즉시 반환
DIAG_CACHE_TTL_SECONDS: int = int(os.getenv("DIAG_CACHE_TTL_SECONDS", str(90 * 24 * 3600)))

def _resolve_device() -> int:
    return 0 if os.getenv("GREENDAY_AI_DEVICE", "").lower() == "cuda" else -1
_DEVICE = _resolve_device()

# ===== 지연 로딩 =====
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
        return pipeline("image-classification", model=model_id, image_processor=proc, device=_DEVICE)
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

# ===== 유틸 =====
def split_label(raw_label: str) -> Tuple[str, str]:
    if "___" in raw_label:
        p, d = raw_label.split("___", 1)
        return p.strip(), d.strip()
    parts = raw_label.replace("-", " ").split()
    if not parts:
        return "Unknown", raw_label
    return parts[0], "_".join(parts[1:]).strip()

def norm_key(s: str) -> str:
    return (s or "").strip().lower().replace("-", "_").replace(" ", "_").replace("__","_")

def normalize_disease_key(name: str) -> str:
    k = norm_key(name)
    synonyms = {
        "gray_mold": "botrytis",
        "botrytis_gray_mold": "botrytis",
        "sooty_mould": "sooty_mold",
        "powdery mildew": "powdery_mildew",
        "downy mildew": "downy_mildew",
        "leaf miner": "leaf_miner",
        "spider_mite": "spider_mites",
        "mealybug": "mealybugs",
        "scale": "scale_insects",
        "whitefly": "whiteflies",
        "thrip": "thrips",
        "mosaic_virus": "virus_mosaic",
        "mosaic": "virus_mosaic",
    }
    k = synonyms.get(k, k)
    return k

def hsv_leaf_crop(pil: Image.Image) -> Image.Image:
    try:
        hsv = pil.convert("RGB").convert("HSV")
        arr = np.array(hsv); s, v = arr[...,1], arr[...,2]
        mask = (s > 40) & (v > 40)
        ys, xs = np.where(mask)
        if len(xs) < 200:
            return pil
        x1, x2, y1, y2 = xs.min(), xs.max(), ys.min(), ys.max()
        pad = 10
        return pil.crop((max(0, x1 - pad), max(0, y1 - pad), min(arr.shape[1], x2 + pad), min(arr.shape[0], y2 + pad)))
    except Exception:
        return pil

def _tta_variants(pil: Image.Image):
    yield pil
    yield pil.transpose(Image.FLIP_LEFT_RIGHT)
    yield pil.transpose(Image.FLIP_TOP_BOTTOM)
    yield pil.rotate(90, expand=True)
    yield pil.rotate(270, expand=True)

async def tta_predict(clf, pil: Image.Image, top_k: int = 3):
    agg: Dict[str, float] = {}; n = 0
    for v in _tta_variants(pil):
        out = clf(v, top_k=top_k)
        for p in out:
            lbl, sc = str(p.get("label","")), float(p.get("score",0.0))
            agg[lbl] = agg.get(lbl, 0.0) + sc
        n += 1
    items = [{"label": k, "score": v / max(n, 1)} for k, v in agg.items()]
    items.sort(key=lambda x: x["score"], reverse=True)
    return items[:top_k]

@dataclass
class ModelPred:
    model_id: str
    label: str
    score: float

async def clip_scores_disease_only(pil: Image.Image, disease_list: List[str]) -> Dict[str, float]:
    try:
        clip_pipe = await get_clip()
        cand_texts = [d.replace("_"," ") for d in disease_list]
        out = clip_pipe(pil, candidate_labels=cand_texts, hypothesis_template="a close-up photo of a leaf with {}")
        scores: Dict[str, float] = {}
        for o in out:
            raw = str(o["label"])
            k = normalize_disease_key(raw)
            scores[k] = max(scores.get(k, 0.0), float(o["score"]))
        return scores
    except Exception as e:
        logger.exception("CLIP(disease) failed: %s", e)
        return {}

def build_response_from_row(row) -> Dict[str, Any]:
    resp = {
        "label": row.disease_key,
        "label_ko": row.disease_ko,
        "score": float(row.score),
        "disease": row.disease_key,
        "disease_ko": row.disease_ko,
        "reason_ko": row.reason_ko or "",
        "severity": row.severity,
        "preprocess_used": bool(row.preprocess_used),
        "tta_used": bool(row.tta_used),
        "clip_used": bool(row.clip_votes is not None),
        "mode": row.mode or "disease_only",
        "disease_candidates": [],
        "image_url": row.image_url,
        "thumb_url": row.thumb_url,
        "diagnosis_id": row.id,
        "cached": True,
    }
    if row.per_model is not None:
        resp["per_model"] = row.per_model
    if row.clip_votes is not None:
        resp["clip_votes"] = row.clip_votes
    return resp

# ===== Router =====
router = APIRouter(
    prefix="/diagnose",
    tags=["AI Diagnosis v3 (auto, disease-only)"],
    dependencies=[Depends(get_current_user)],
)

@router.post("/auto")
async def diagnose_auto(
    image: UploadFile = File(..., description="식물 잎 사진 (jpg/png 등)"),
    top_k: int = Query(3, ge=1, le=5),
    use_preprocess: bool = Query(True, description="HSV 기반 잎/배경 크롭"),
    use_tta: bool = Query(USE_TTA_DEFAULT, description="반전/회전 TTA 평균"),
    include_per_model: bool = Query(True, description="모델별 원시 예측 포함"),
    include_clip: bool = Query(USE_CLIP_DEFAULT, description="CLIP 제로샷 보조 포함"),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    # 0) 파일 검증
    if not image.content_type or not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="이미지 파일만 업로드할 수 있습니다.")
    raw = await image.read()
    if len(raw) > 20 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="파일이 너무 큽니다(최대 20MB).")

    # 1) 이미지 로드/회전 보정
    try:
        with Image.open(io.BytesIO(raw)) as pil0:
            pil0 = ImageOps.exif_transpose(pil0).convert("RGB")
    except UnidentifiedImageError:
        raise HTTPException(status_code=400, detail="이미지 파일을 인식할 수 없습니다.")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"이미지 처리 오류: {e}")

    # 1-1) pHash 계산 + 동일 이미지 캐시 조회
    img_hash = compute_phash64(pil0)
    if DIAG_CACHE_TTL_SECONDS > 0:
        since = datetime.now(timezone.utc) - timedelta(seconds=DIAG_CACHE_TTL_SECONDS)
        cached = (
            db.query(models.Diagnosis)
            .filter(
                and_(
                    models.Diagnosis.user_id == current_user.id,
                    models.Diagnosis.image_hash == img_hash,
                    models.Diagnosis.created_at >= since.replace(tzinfo=None)  # DB가 naive일 수 있음
                )
            )
            .order_by(models.Diagnosis.created_at.desc())
            .first()
        )
        if cached:
            return build_response_from_row(cached)

    # 1-2) 🚩 이미지 먼저 DB 저장 (Unknown이어도 남기기 위함)
    thumb_bytes = make_thumbnail_bytes(pil0, 768, "JPEG", 85)
    img_row = models.ImageAsset(
        user_id=current_user.id,
        image_hash=img_hash,
        mime=image.content_type,
        width=pil0.width, height=pil0.height, bytes=len(raw),
        original=raw,
        thumb=thumb_bytes,
    )
    db.add(img_row); db.flush()  # id 확보

    image_url = f"/media/{img_row.id}/orig"
    thumb_url = f"/media/{img_row.id}/thumb"

    # 2) 전처리(모델 입력용)
    pil = pil0
    if use_preprocess:
        pil = hsv_leaf_crop(pil)

    # 3) HF 예측
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
            per_model_preds.append(ModelPred(mid, str(p.get("label","")), float(p.get("score",0.0))))
        if out:
            last_raw_labels = [o["label"] for o in out]

    # 4) Disease-only 매핑 + CLIP 보조
    disease_scores_model: Dict[str, float] = {}
    for p in per_model_preds:
        _, dis = split_label(p.label)
        k = normalize_disease_key(dis)
        if k and k not in IGNORE_LABELS and p.score >= THRESHOLD:
            disease_scores_model[k] = max(disease_scores_model.get(k, 0.0), float(p.score))

    disease_scores_clip: Dict[str, float] = {}
    if include_clip and DISEASE_ONLY:
        disease_scores_clip = await clip_scores_disease_only(pil, DISEASE_LIST)

    # 5) 집계(모델 1.0, CLIP 0.8)
    weights: Dict[str, float] = {}
    for k, v in disease_scores_model.items():
        weights[k] = weights.get(k, 0.0) + 1.0 * v
    for k, v in disease_scores_clip.items():
        weights[k] = weights.get(k, 0.0) + 0.8 * v

    # 6) 결과 결정
    if not weights:
        # 🚩 Unknown이라도 Diagnosis 저장
        diag = models.Diagnosis(
            user_id=current_user.id,
            image_hash=img_row.image_hash,
            image_url=image_url,
            thumb_url=thumb_url,
            width=img_row.width, height=img_row.height, bytes=img_row.bytes, mime=img_row.mime,
            disease_key="unknown",
            disease_ko="불확실",
            score=0.0,
            severity="LOW",
            mode="disease_only",
            reason_ko="잎이 더 크게 나오도록 촬영하거나, 앞/뒷면과 병반 근접사진을 제공해 주세요.",
            source="disease_only",
            tta_used=bool(use_tta), preprocess_used=bool(use_preprocess),
            models=MODEL_IDS, clip_model=CLIP_MODEL_ID,
            thresholds={"threshold": THRESHOLD, "llm_low": LLM_LOW, "llm_high": LLM_HIGH},
            per_model=None, clip_votes=None,
        )
        db.add(diag); db.commit(); db.refresh(diag)
        return {
            "label": "Unknown",
            "label_ko": "불확실",
            "score": 0.0,
            "reason_ko": diag.reason_ko,
            "preprocess_used": bool(use_preprocess),
            "tta_used": bool(use_tta),
            "clip_used": bool(include_clip),
            "mode": "disease_only",
            "image_url": image_url,
            "thumb_url": thumb_url,
            "diagnosis_id": diag.id,
            "cached": False,
        }

    labels, vals = list(weights.keys()), np.array(list(weights.values()), dtype=np.float32)
    probs = vals / (vals.sum() + 1e-8)
    idx = int(probs.argmax())
    final_disease_key = labels[idx]
    final_conf = float(probs[idx])

    # 7) 한국어 표기 (plant 숨김)
    _plant_ko, disease_ko, _label_ko = await to_korean("", final_disease_key)
    label_ko = disease_ko or final_disease_key.replace("_", " ")

    # 8) Diagnosis 저장
    diag = models.Diagnosis(
        user_id=current_user.id,
        image_hash=img_row.image_hash,
        image_url=image_url,
        thumb_url=thumb_url,
        width=img_row.width, height=img_row.height, bytes=img_row.bytes, mime=img_row.mime,

        disease_key=final_disease_key,
        disease_ko=label_ko,
        score=round(final_conf, 4),  # Numeric 컬럼에 숫자형
        severity="HIGH" if final_conf >= 0.8 else "MEDIUM" if final_conf >= 0.5 else "LOW",
        mode="disease_only",
        reason_ko="",

        source="disease_only",
        tta_used=bool(use_tta),
        preprocess_used=bool(use_preprocess),
        models=MODEL_IDS,
        clip_model=CLIP_MODEL_ID,
        thresholds={"threshold": THRESHOLD, "llm_low": LLM_LOW, "llm_high": LLM_HIGH},
        per_model=[
            {"model_id": p.model_id, "label_raw": p.label, "score": round(p.score, 4),
             "disease_mapped": normalize_disease_key(split_label(p.label)[1])}
            for p in per_model_preds
            if (p.score >= THRESHOLD and p.label.lower() not in IGNORE_LABELS)
        ] if include_per_model else None,
        clip_votes=[{"label": k, "score": float(v)} for k, v in sorted(disease_scores_clip.items(), key=lambda x: -x[1])] if disease_scores_clip else None,
    )
    db.add(diag); db.commit(); db.refresh(diag)

    # 9) 응답
    resp: Dict[str, Any] = {
        "label": final_disease_key,
        "label_ko": label_ko,
        "score": round(final_conf, 4),
        "disease": final_disease_key,
        "disease_ko": label_ko,
        "reason_ko": "",
        "severity": diag.severity,
        "preprocess_used": bool(use_preprocess),
        "tta_used": bool(use_tta),
        "clip_used": bool(include_clip),
        "mode": "disease_only",
        "disease_candidates": [
            {"disease": labels[i], "score": float(probs[i])}
            for i in np.argsort(-probs)[:min(5, len(labels))]
        ],
        "image_url": image_url,
        "thumb_url": thumb_url,
        "diagnosis_id": diag.id,
        "cached": False,
    }
    if include_per_model:
        resp["per_model"] = diag.per_model
    if diag.clip_votes is not None:
        resp["clip_votes"] = diag.clip_votes

    # (선택) 병명 한글 캐시 저장: plant 없이 disease만
    try:
        full_label_en = f"___{final_disease_key}"
        cache_set_label_ko(full_label_en, "", label_ko, label_ko, source="rule")
    except Exception:
        pass

    return resp
