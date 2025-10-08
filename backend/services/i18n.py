# backend/services/i18n.py
from __future__ import annotations
import os, json
from functools import lru_cache
from pathlib import Path
from typing import Tuple, Optional

# httpx는 없으면 안 씀( Papago 비활성 모드 )
try:
    import httpx  # type: ignore
except Exception:
    httpx = None  # noqa

DATA_PATH = Path(os.getenv("LABELS_KO_JSON", "data/labels_ko.json"))
PAPAGO_ID = os.getenv("NAVER_PAPAGO_CLIENT_ID", "")
PAPAGO_SECRET = os.getenv("NAVER_PAPAGO_CLIENT_SECRET", "")
PAPAGO_URL = "https://openapi.naver.com/v1/papago/n2mt"

DEFAULT_MAP = {
    "plants": {
        "potato": "감자", "tomato": "토마토", "corn": "옥수수", "wheat": "밀", "apple": "사과",
        "grape": "포도", "orange": "오렌지", "peach": "복숭아", "pepper": "고추",
        "strawberry": "딸기", "soybean": "대두", "squash": "호박", "raspberry": "라즈베리", "blueberry": "블루베리",
    },
    "diseases": {
        "healthy": "정상", "early_blight": "겹무늬병", "late_blight": "역병",
        "common_rust": "녹병", "brown_rust": "갈색녹병", "powdery_mildew": "흰가루병",
        "leaf_mold": "잎곰팡이병", "septoria_leaf_spot": "점무늬병",
        "bacterial_spot": "세균성 반점병", "leaf_scorch": "잎마름병",
        "target_spot": "표적무늬병",
        "tomato_yellow_leaf_curl_virus": "토마토황화잎말림바이러스",
        "tomato_mosaic_virus": "토마토모자이크바이러스",
        "spider_mites_two_spotted_spider_mite": "점박이응애 피해",
        "cercospora_leaf_spot_gray_leaf_spot": "회색잎반점병",
        "northern_leaf_blight": "북부잎마름병",
        "black_rot": "검은썩음병",
        "cedar_apple_rust": "삼나무녹병",
        "esca_black_measles": "에스카병(검은홍역병)",
        "leaf_blight_isariopsis_leaf_spot": "잎마름병(이사리옵시스 잎반점)",
        "haunglongbing_citrus_greening": "황룡병(감귤녹화병)",
    },
    "labels": {}
}

def _ensure_file() -> dict:
    if DATA_PATH.exists():
        try:
            return json.loads(DATA_PATH.read_text(encoding="utf-8"))
        except Exception:
            pass
    DATA_PATH.parent.mkdir(parents=True, exist_ok=True)
    DATA_PATH.write_text(json.dumps(DEFAULT_MAP, ensure_ascii=False, indent=2), encoding="utf-8")
    return DEFAULT_MAP

@lru_cache(maxsize=1)
def _maps() -> dict:
    return _ensure_file()

def _save_maps(m: dict):
    DATA_PATH.write_text(json.dumps(m, ensure_ascii=False, indent=2), encoding="utf-8")
    _maps.cache_clear()

def norm(s: str) -> str:
    return (s or "").strip().lower().replace("-", "_").replace(" ", "_")

async def _papago_en2ko(text: str) -> Optional[str]:
    # Papago 키가 없거나 httpx가 없으면 사용하지 않음
    if not (PAPAGO_ID and PAPAGO_SECRET and httpx):
        return None
    headers = {
        "X-Naver-Client-Id": PAPAGO_ID,
        "X-Naver-Client-Secret": PAPAGO_SECRET,
        "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
    }
    data = {"source": "en", "target": "ko", "text": text}
    async with httpx.AsyncClient(timeout=10) as client:  # type: ignore
        r = await client.post("https://openapi.naver.com/v1/papago/n2mt", headers=headers, data=data)
        if r.status_code == 200:
            return r.json().get("message", {}).get("result", {}).get("translatedText")
    return None

# === 공개 API ===
async def to_korean(plant_en: str, disease_en: str) -> Tuple[str, str, str]:
    """영문 plant/disease 입력 → (plant_ko, disease_ko, label_ko) 반환"""
    m = _maps()

    full = f"{plant_en}___{disease_en}" if disease_en else plant_en
    if full in m.get("labels", {}):
        label_ko = m["labels"][full]
        plant_ko = m["plants"].get(norm(plant_en), plant_en)
        disease_ko = m["diseases"].get(norm(disease_en), disease_en)
        return plant_ko or plant_en, disease_ko or disease_en, label_ko

    plant_ko = m["plants"].get(norm(plant_en))
    disease_ko = m["diseases"].get(norm(disease_en))

    if plant_ko is None and plant_en:
        plant_ko = await _papago_en2ko(plant_en) or plant_en
    if disease_ko is None and disease_en:
        disease_ko = await _papago_en2ko(disease_en.replace("_", " ")) or disease_en

    label_ko = f"{plant_ko} 정상" if (disease_ko or "").strip() in ("", "정상") else f"{plant_ko} {disease_ko}"
    return plant_ko or plant_en, disease_ko or disease_en, label_ko

def cache_set_label_ko(full_label_en: str, plant_ko: str, disease_ko: str, label_ko: str, source: str = "llm"):
    """확정된 한글 라벨을 로컬 캐시에 저장."""
    m = _maps()
    m.setdefault("labels", {})[full_label_en] = label_ko
    p, d = full_label_en.split("___", 1) if "___" in full_label_en else (full_label_en, "")
    if plant_ko:
        m.setdefault("plants", {})[norm(p)] = plant_ko
    if disease_ko and d:
        m.setdefault("diseases", {})[norm(d)] = disease_ko
    _save_maps(m)
