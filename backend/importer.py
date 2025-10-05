#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
importer.py
- HTTP: httpx
- DB 드라이버: mysql-connector-python (SQLAlchemy URL: mysql+mysqlconnector://)
- JSON 컬럼: SQLAlchemy JSON
- 실행은 동기(일회성 스크립트)

사용법:
  python importer.py --limit 40 --dry-run
  python importer.py --limit 40

필수/선택 환경변수(.env):
  DB_URL=mysql+mysqlconnector://user:pass@host:3306/greenday_db
  # 없으면 DATABASE_URL 사용. mysqlconnector & charset 미지정 시 자동으로 ?charset=utf8mb4 부여

  WIKIDATA_SPARQL_ENDPOINT=https://query.wikidata.org/sparql (기본값)
  PERENUAL_API_BASE=https://perenual.com/api (기본값)
  PERENUAL_API_KEY=... (없으면 이 단계 스킵)

  # CLOVA v3(Bearer) 우선, 없으면 v1(API Gateway)
  CLOVA_API_URL=...  # 예) https://clovastudio.stream.ntruss.com/testapp/v3/chat-completions/HCX-005
  CLOVA_BEARER=nv-...  # 테스트앱이면 보통 이 값만 존재
  # (v1인 경우)
  CLOVA_API_KEY_ID=
  CLOVA_API_KEY=
  CLOVA_MODEL=HCX-003 or HCX-005
  CLOVA_REQUEST_ID=plantmaster-importer
"""
import os
import json
import time
import argparse
import logging
from typing import Dict, Any, List, Optional

import httpx
from dotenv import load_dotenv
from sqlalchemy import (
    create_engine, select, Enum as SAEnum, String, Integer, Boolean, JSON as SAJSON,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, Session

# ------------------------- 설정 -------------------------
load_dotenv()

WIKIDATA_SPARQL_ENDPOINT = os.getenv("WIKIDATA_SPARQL_ENDPOINT", "https://query.wikidata.org/sparql")
PERENUAL_API_BASE = os.getenv("PERENUAL_API_BASE", "https://perenual.com/api")
PERENUAL_API_KEY = os.getenv("PERENUAL_API_KEY", "")

# CLOVA: v3(Bearer) 우선, 없으면 v1(APIGW)
CLOVA_API_URL = os.getenv("CLOVA_API_URL", "")
CLOVA_BEARER = os.getenv("CLOVA_BEARER", "")
CLOVA_API_KEY_ID = os.getenv("CLOVA_API_KEY_ID", "")
CLOVA_API_KEY = os.getenv("CLOVA_API_KEY", "")
CLOVA_REQUEST_ID = os.getenv("CLOVA_REQUEST_ID", "plantmaster-importer")
CLOVA_MODEL = os.getenv("CLOVA_MODEL", "HCX-003")

# DB_URL 우선, 없으면 DATABASE_URL 사용
DATABASE_URL = os.getenv("DB_URL") or os.getenv("DATABASE_URL", "")
# mysqlconnector & charset 미지정 시 자동으로 추가
if DATABASE_URL and "mysql+mysqlconnector://" in DATABASE_URL and "charset=" not in DATABASE_URL:
    DATABASE_URL += ("&" if "?" in DATABASE_URL else "?") + "charset=utf8mb4"

USER_AGENT = "PlantMasterImporter/1.0 (contact: team@greenday.local)"

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
logger = logging.getLogger("importer")

# ------------------------- DB 모델 -------------------------
class Base(DeclarativeBase):
    pass

class PlantMaster(Base):
    __tablename__ = "plants_master"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name_ko: Mapped[str] = mapped_column(String(150), nullable=False)
    name_en: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    species: Mapped[str] = mapped_column(String(190), nullable=False, unique=True)  # 학명 기준 UPSERT
    family: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    image_url: Mapped[Optional[str]] = mapped_column(String(1024), nullable=True)
    description: Mapped[Optional[str]] = mapped_column(String(length=65535), nullable=True)  # TEXT

    difficulty: Mapped[str] = mapped_column(SAEnum('상', '중', '하', name='difficulty_enum'),
                                           nullable=False, default='중')
    light_requirement: Mapped[str] = mapped_column(SAEnum('음지', '반음지', '양지', name='lightreq_enum'),
                                                  nullable=False, default='반음지')
    water_cycle_text: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    water_interval_days: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    pet_safe: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)
    tags: Mapped[Optional[dict]] = mapped_column(SAJSON, nullable=True)  # MySQL JSON

# ------------------------- HTTP 유틸 (httpx) -------------------------
def http_get_json(url: str, params: Dict[str, Any] = None, headers: Dict[str, str] = None) -> Dict[str, Any]:
    headers = {**(headers or {}), "User-Agent": USER_AGENT}
    with httpx.Client(timeout=30.0, headers=headers) as client:
        r = client.get(url, params=params or {})
        r.raise_for_status()
        return r.json()

def http_post_json(url: str, json_body: Dict[str, Any], headers: Dict[str, str]) -> Dict[str, Any]:
    headers = {**(headers or {}), "User-Agent": USER_AGENT, "Content-Type": "application/json; charset=utf-8"}
    with httpx.Client(timeout=60.0, headers=headers) as client:
        r = client.post(url, json=json_body)
        r.raise_for_status()
        return r.json()

# ------------------------- Wikidata -------------------------
def fetch_plants_from_wikidata(limit: int = 40) -> List[Dict[str, Any]]:
    """
    학명(P225), 한국어 라벨(itemLabel), 이미지(P18)를 수집.
    한국어 라벨이 없는 경우 제외.
    """
    query = f"""
    SELECT ?item ?itemLabel ?taxonName ?image WHERE {{
      ?item wdt:P31 wd:Q16521 .           # taxon
      ?item wdt:P225 ?taxonName .         # scientific name
      ?item wdt:P18 ?image .              # image
      SERVICE wikibase:label {{ bd:serviceParam wikibase:language "ko,en". }}
      FILTER(LANG(?itemLabel) = "ko")
    }}
    LIMIT {int(limit * 2)}
    """
    params = {"query": query, "format": "json"}
    headers = {"Accept": "application/sparql-results+json"}
    data = http_get_json(WIKIDATA_SPARQL_ENDPOINT, params=params, headers=headers)

    results = []
    for b in data.get("results", {}).get("bindings", []):
        ko_label = b.get("itemLabel", {}).get("value")
        sci = b.get("taxonName", {}).get("value")
        img = b.get("image", {}).get("value")
        if not ko_label or not sci:
            continue
        results.append({
            "name_ko": ko_label,
            "species": sci,
            "image_url": img,
        })

    # 중복 제거 (species 기준), 상위 limit
    uniq = {}
    for r in results:
        uniq.setdefault(r["species"], r)
    return list(uniq.values())[:limit]

# ------------------------- Perenual -------------------------
def perenual_search_by_species(scientific_name: str) -> Optional[Dict[str, Any]]:
    if not PERENUAL_API_KEY:
        return None
    try:
        q_params = {"key": PERENUAL_API_KEY, "q": scientific_name}
        data = http_get_json(f"{PERENUAL_API_BASE}/species-list", params=q_params)
        d = data.get("data") or data  # 플랜/엔드포인트에 따라 다름
        if isinstance(d, list) and d:
            return d[0]
        return None
    except Exception as e:
        logger.warning("Perenual search error (%s): %s", scientific_name, e)
        return None

def perenual_detail(species_id: int) -> Optional[Dict[str, Any]]:
    if not PERENUAL_API_KEY:
        return None
    try:
        q_params = {"key": PERENUAL_API_KEY}
        return http_get_json(f"{PERENUAL_API_BASE}/species/details/{species_id}", params=q_params)
    except Exception as e:
        logger.warning("Perenual detail error (%s): %s", species_id, e)
        return None

# ------------------------- 매핑 -------------------------
def map_difficulty(src: Optional[str]) -> str:
    if not src:
        return "중"
    s = str(src).strip().lower()
    if any(k in s for k in ["easy", "beginner", "low"]):
        return "하"
    if any(k in s for k in ["hard", "difficult", "advanced", "high"]):
        return "상"
    return "중"

def map_light_requirement(sunlight) -> str:
    if not sunlight:
        return "반음지"
    if isinstance(sunlight, list):
        tokens = [str(x).lower() for x in sunlight]
    else:
        tokens = [t.strip().lower() for t in str(sunlight).split(";")]

    has_full_sun = any("full sun" in t for t in tokens)
    has_partial = any(("partial shade" in t) or ("part shade" in t) for t in tokens)
    has_full_shade = any("full shade" in t for t in tokens)

    if has_partial and has_full_sun:
        return "반음지"
    if has_full_sun:
        return "양지"
    if has_partial:
        return "반음지"
    if has_full_shade:
        return "음지"
    return "반음지"

def map_watering_to_days(watering: Optional[str]) -> Optional[int]:
    if not watering:
        return None
    w = watering.strip().lower()
    table = {
        "frequent": 3,
        "average": 7,
        "minimum": 14,
        "once per week": 7,
        "once every 2 weeks": 14,
        "once every two weeks": 14,
    }
    for k, v in table.items():
        if k in w:
            return v
    return None

def map_watering_text(watering: Optional[str]) -> Optional[str]:
    if not watering:
        return None
    w = watering.strip().lower()
    if "frequent" in w:
        return "자주"
    if "average" in w:
        return "보통"
    if "minimum" in w:
        return "적게"
    if "once per week" in w:
        return "주 1회"
    if "once every 2 weeks" in w or "once every two weeks" in w:
        return "2주 1회"
    return watering

def map_pet_safe(poisonous_to_pets) -> Optional[bool]:
    try:
        if poisonous_to_pets is None:
            return None
        if isinstance(poisonous_to_pets, str) and poisonous_to_pets.isdigit():
            poisonous_to_pets = int(poisonous_to_pets)
        if poisonous_to_pets == 0:
            return True
        if poisonous_to_pets == 1:
            return False
    except Exception:
        pass
    return None

# ------------------------- LLM(Clova/OpenAI) -------------------------
def generate_one_liner_ko(data: Dict[str, Any]) -> str:
    """
    한 줄 설명 생성:
      1) 우선 CLOVA v3(Bearer) 또는 v1(APIGW) 자동 지원
      2) 둘 다 없으면 템플릿 문구 반환
    """
    diff = data.get("difficulty") or "중"
    light = data.get("light_requirement") or "반음지"
    water_text = data.get("water_cycle_text") or "주 1회"
    tmpl = f"이 식물은 {diff} 난이도로, {light} 환경에서 잘 자랍니다. 물은 {water_text} 주기로 주세요."

    if not (CLOVA_API_URL and (CLOVA_BEARER or CLOVA_API_KEY or CLOVA_API_KEY_ID)):
        return tmpl

    try:
        # 1) 인증 방식 결정 (Bearer 우선)
        use_bearer = bool(CLOVA_BEARER) or (CLOVA_API_KEY and CLOVA_API_KEY.startswith("nv-") and not CLOVA_API_KEY_ID)
        bearer = CLOVA_BEARER or (CLOVA_API_KEY if use_bearer else "")

        if use_bearer:
            headers = {
                "Authorization": f"Bearer {bearer}",
                "X-NCP-CLOVASTUDIO-REQUEST-ID": CLOVA_REQUEST_ID,
                "Content-Type": "application/json; charset=utf-8",
            }
        else:
            headers = {
                "X-NCP-APIGW-API-KEY-ID": CLOVA_API_KEY_ID,
                "X-NCP-APIGW-API-KEY": CLOVA_API_KEY,
                "X-NCP-CLOVASTUDIO-REQUEST-ID": CLOVA_REQUEST_ID,
                "Content-Type": "application/json; charset=utf-8",
            }

        # 2) v3 여부 (URL에 /v3/chat-completions)
        is_v3 = "/v3/chat-completions" in (CLOVA_API_URL or "")

        prompt = (
            "다음 식물 메타데이터를 바탕으로 한국어 한 줄 설명을 만들어 주세요. "
            "형식: '이 식물은 {난이도} 난이도로, {햇빛} 환경에서 잘 자랍니다. 물은 {물주기} 주기로 주세요.'\n"
            f"데이터: {json.dumps(data, ensure_ascii=False)}"
        )
        messages = [
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": prompt},
        ]

        body = {
            "messages": messages,
            "temperature": 0.3,
            "topP": 0.9,
            "maxTokens": 80,
        }
        # v1(apigw)만 body에 모델 필요, v3는 URL 경로에 모델 포함
        if not is_v3:
            body["model"] = CLOVA_MODEL

        res = http_post_json(CLOVA_API_URL, body, headers=headers)
        text = None
        if isinstance(res, dict):
            text = (
                res.get("result", {}).get("message", {}).get("content")
                or (res.get("choices") or [{}])[0].get("message", {}).get("content")
            )
        return (text or tmpl).strip()
    except Exception as e:
        logger.warning("Clova X error: %s", e)
        return tmpl

# ------------------------- UPSERT -------------------------
def upsert_plant_master(session: Session, row: Dict[str, Any], dry_run: bool = False) -> None:
    """
    species(학명) 기준 UPSERT
    """
    existing = session.execute(
        select(PlantMaster).where(PlantMaster.species == row["species"])
    ).scalar_one_or_none()

    payload = {
        "name_ko": row.get("name_ko"),
        "name_en": row.get("name_en"),
        "family": row.get("family"),
        "image_url": row.get("image_url"),
        "description": row.get("description"),
        "difficulty": row.get("difficulty") or "중",
        "light_requirement": row.get("light_requirement") or "반음지",
        "water_cycle_text": row.get("water_cycle_text"),
        "water_interval_days": row.get("water_interval_days"),
        "pet_safe": row.get("pet_safe"),
        "tags": row.get("tags") or {},
    }

    if existing:
        for k, v in payload.items():
            setattr(existing, k, v)
        if not dry_run:
            session.add(existing)
        logger.info("[UPDATE] %s (%s)", row["species"], row.get("name_ko"))
    else:
        rec = PlantMaster(species=row["species"], **payload)
        if not dry_run:
            session.add(rec)
        logger.info("[INSERT] %s (%s)", row["species"], row.get("name_ko"))

# ------------------------- MAIN FLOW -------------------------
def run(limit: int = 40, dry_run: bool = False) -> None:
    if not DATABASE_URL:
        raise RuntimeError("DB_URL 또는 DATABASE_URL을(.env) 설정해주세요.")

    engine = create_engine(DATABASE_URL, pool_pre_ping=True, pool_recycle=3600)
    Base.metadata.create_all(engine)  # 테이블 없을 때만 생성(있으면 그대로)

    # 1) Wikidata
    wiki_rows = fetch_plants_from_wikidata(limit=limit)
    logger.info("Wikidata fetched: %d rows", len(wiki_rows))

    to_save: List[Dict[str, Any]] = []
    for w in wiki_rows:
        species = w["species"]

        # 2) Perenual (옵션)
        perenual = perenual_search_by_species(species)
        detail = None
        if perenual and isinstance(perenual, dict) and perenual.get("id"):
            detail = perenual_detail(perenual["id"])

        # 필드 추출(여러 후보 키 대비)
        name_en = None
        family = None
        sunlight = None
        watering = None
        poisonous_to_pets = None
        care_level = None

        def pick(d: Dict[str, Any], *keys):
            for k in keys:
                if k in d and d[k] is not None:
                    return d[k]
            return None

        source_obj = detail or perenual or {}

        if source_obj:
            name_en = pick(source_obj, "common_name", "scientific_name")
            family = pick(source_obj, "family")
            sunlight = pick(source_obj, "sunlight")
            watering = pick(source_obj, "watering")
            poisonous_to_pets = pick(source_obj, "poisonous_to_pets")
            care_level = pick(source_obj, "care_level", "maintenance", "difficulty")

        difficulty = map_difficulty(care_level)
        lightreq = map_light_requirement(sunlight)
        water_text = map_watering_text(watering)
        water_days = map_watering_to_days(watering)
        pet_safe = map_pet_safe(poisonous_to_pets)

        row = {
            "name_ko": w["name_ko"],
            "name_en": name_en,
            "species": species,
            "family": family,
            "image_url": w.get("image_url"),
            "difficulty": difficulty,
            "light_requirement": lightreq,
            "water_cycle_text": water_text,
            "water_interval_days": water_days,
            "pet_safe": pet_safe,
            "tags": {
                "source": {"wikidata": True, "perenual": bool(source_obj)},
                "perenual_raw": source_obj or None,
            },
        }
        # 3) 한 줄 설명 생성 → description
        row["description"] = generate_one_liner_ko(row)

        to_save.append(row)

        # API rate-limit 보호
        time.sleep(0.2)

    # 4) DB UPSERT
    with Session(engine) as ses:
        for r in to_save:
            upsert_plant_master(ses, r, dry_run=dry_run)
        if dry_run:
            ses.rollback()
            logger.info("Dry-run: 변경사항을 롤백했습니다.")
        else:
            ses.commit()
            logger.info("Commit 완료: %d rows upserted", len(to_save))

# ------------------------- CLI -------------------------
if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=40, help="Wikidata에서 수집할 대략 개수(30~50 권장)")
    ap.add_argument("--dry-run", action="store_true", help="DB에 반영하지 않고 시뮬레이션")
    args = ap.parse_args()

    try:
        run(limit=args.limit, dry_run=args.dry_run)
    except Exception as e:
        logger.exception("Importer failed: %s", e)
        raise
