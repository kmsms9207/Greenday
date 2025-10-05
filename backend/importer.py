#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
importer.py
- 일회성 데이터 파이프라인: Wikidata -> (옵션)Perenual -> (옵션)CLOVA X -> DB(PlantMaster UPSERT)
- 견고화 패치:
  * Wikidata: 가벼운 SPARQL + EntityData(REST)로 ko 라벨/이미지 보강
  * HTTP: httpx 타임아웃/재시도/백오프
  * Perenual: 429 시 재시도/백오프
사용법:
  python importer.py --limit 10 --dry-run
  python importer.py --limit 40
"""

import os
import json
import time
import argparse
import logging
import urllib.parse
from typing import Dict, Any, List, Optional, Tuple

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
# mysqlconnector & charset 미지정 시 자동 추가
if DATABASE_URL and "mysql+mysqlconnector://" in DATABASE_URL and "charset=" not in DATABASE_URL:
    DATABASE_URL += ("&" if "?" in DATABASE_URL else "?") + "charset=utf8mb4"

USER_AGENT = "PlantMasterImporter/1.1 (contact: team@greenday.local)"

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

# ------------------------- HTTP 유틸 (httpx, 재시도/백오프) -------------------------
def http_get_json(
    url: str,
    params: Dict[str, Any] = None,
    headers: Dict[str, str] = None,
    timeout: float = 90.0,
    retries: int = 5
) -> Dict[str, Any]:
    """
    GET JSON with retry/backoff.
    - Wikidata 429/5xx/ReadTimeout 시 지수 백오프 재시도
    """
    hdrs = {**(headers or {}), "User-Agent": USER_AGENT, "Accept-Encoding": "gzip"}
    params = dict(params or {})
    if "query.wikidata.org/sparql" in url and "timeout" not in params:
        params["timeout"] = "60000"  # 60s 쿼리 타임리밋

    backoff = 1.2
    last = None
    for i in range(retries):
        try:
            with httpx.Client(timeout=httpx.Timeout(timeout, connect=10, read=timeout), headers=hdrs) as c:
                r = c.get(url, params=params)
                r.raise_for_status()
                return r.json()
        except httpx.HTTPStatusError as e:
            code = e.response.status_code
            if code in (429, 502, 503, 504) and i < retries - 1:
                time.sleep(backoff * (i + 1))
                continue
            raise
        except (httpx.ReadTimeout, httpx.ConnectTimeout) as e:
            last = e
            if i < retries - 1:
                time.sleep(backoff * (i + 1))
                continue
            raise last

def http_post_json(url: str, json_body: Dict[str, Any], headers: Dict[str, str]) -> Dict[str, Any]:
    headers = {**(headers or {}), "User-Agent": USER_AGENT, "Content-Type": "application/json; charset=utf-8"}
    with httpx.Client(timeout=60.0, headers=headers) as client:
        r = client.post(url, json=json_body)
        r.raise_for_status()
        return r.json()

# ------------------------- Wikidata: REST 보강 -------------------------
def wikidata_entity(qid: str) -> Optional[Dict[str, Any]]:
    """Wikidata REST(Special:EntityData)로 ko 라벨/P18/학명(P225) 가져오기"""
    try:
        data = http_get_json(f"https://www.wikidata.org/wiki/Special:EntityData/{qid}.json", timeout=30.0, retries=3)
        ent = next(iter(data.get("entities", {}).values()), None)
        if not ent:
            return None
        labels = ent.get("labels", {})
        name_ko = (labels.get("ko") or {}).get("value")
        claims = ent.get("claims", {})
        # P225: scientific name
        sci = None
        if "P225" in claims and claims["P225"]:
            sci = claims["P225"][0]["mainsnak"]["datavalue"]["value"]
        # P18: image filename -> commons URL
        img_url = None
        if "P18" in claims and claims["P18"]:
            filename = claims["P18"][0]["mainsnak"]["datavalue"]["value"]
            img_url = "https://commons.wikimedia.org/wiki/Special:FilePath/" + urllib.parse.quote(filename) + "?width=640"
        return {"name_ko": name_ko, "species": sci, "image_url": img_url}
    except Exception:
        return None
    
def _fallback_plants(limit: int) -> List[Dict[str, Any]]:
    """Wikidata/네트워크가 계속 실패할 때 최소 동작을 보장하는 로컬 시드"""
    seeds = [
        # (species, ko_hint)
        ("Monstera deliciosa", "몬스테라"),
        ("Ficus elastica", "떡갈고무나무"),
        ("Epipremnum aureum", "스킨답서스"),
        ("Dracaena trifasciata", "산세베리아"),
        ("Spathiphyllum wallisii", "스파티필름"),
        ("Zamioculcas zamiifolia", "금전수"),
        ("Pilea peperomioides", "중국돈나무"),
        ("Chlorophytum comosum", "접란"),
        ("Hedera helix", "아이비"),
        ("Calathea orbifolia", "칼라데아 오르비폴리아"),
    ]
    out = []
    for species, ko in seeds[: max(1, limit)]:
        out.append({"name_ko": ko, "species": species, "image_url": None})
    return out

# ------------------------- Wikidata: 경량 SPARQL + REST 보강 -------------------------
def fetch_plants_from_wikidata(limit: int = 40) -> List[Dict[str, Any]]:
    """
    1) 초경량 SPARQL: QID + 학명만 (라벨/이미지 조인 없음)
    2) 각 QID에 대해 REST(EntityData)로 ko 라벨/P18 보강
    3) SPARQL/REST가 전부 실패하면 로컬 시드(fallback) 반환
    """
    # 비용 높은 rdfs:label 조인을 제거한 초경량 쿼리
    query = f"""
    SELECT ?item ?taxonName WHERE {{
      ?item wdt:P31 wd:Q16521 .      # taxon
      ?item wdt:P105 wd:Q7432 .      # rank = species
      ?item wdt:P171* wd:Q756 .      # under Plantae
      ?item wdt:P225 ?taxonName .    # scientific name
    }}
    LIMIT {int(max(10, limit * 3))}
    """

    params = {"query": query, "format": "json"}
    headers = {"Accept": "application/sparql-results+json"}

    qid_sci: List[Tuple[str, str]] = []
    try:
        data = http_get_json(
            WIKIDATA_SPARQL_ENDPOINT,
            params=params,
            headers=headers,
            timeout=90.0,
            retries=5,
        )
        for b in data.get("results", {}).get("bindings", []):
            item_uri = b.get("item", {}).get("value")
            sci = b.get("taxonName", {}).get("value")
            if not item_uri or not sci:
                continue
            qid = item_uri.rsplit("/", 1)[-1]  # http://www.wikidata.org/entity/QXXXX
            qid_sci.append((qid, sci))
    except Exception as e:
        logger.warning("Wikidata SPARQL failed: %s", e)

    # 아무 것도 못 가져온 경우 → 로컬 시드로 즉시 반환
    if not qid_sci:
        logger.warning("Using local fallback plant list due to Wikidata failure.")
        return _fallback_plants(limit)

    # 중복 제거 + 상위 limit
    seen = set()
    picked: List[Tuple[str, str]] = []
    for qid, sci in qid_sci:
        if sci in seen:
            continue
        seen.add(sci)
        picked.append((qid, sci))
        if len(picked) >= limit:
            break

    # EntityData(REST)로 ko 라벨/이미지 보강
    results: List[Dict[str, Any]] = []
    for qid, sci in picked:
        meta = wikidata_entity(qid) or {}
        name_ko = meta.get("name_ko") or sci  # ko 라벨이 없으면 학명으로 대체
        image_url = meta.get("image_url")
        results.append({"name_ko": name_ko, "species": sci, "image_url": image_url})
        time.sleep(0.2)  # REST 호출 간격

    # 혹시 REST도 전부 실패해버렸다면 마지막 안전망
    if not results:
        logger.warning("Wikidata REST fallback also empty. Using local seeds.")
        return _fallback_plants(limit)

    return results


# ------------------------- Perenual -------------------------
def perenual_search_by_species(scientific_name: str) -> Optional[Dict[str, Any]]:
    if not PERENUAL_API_KEY:
        return None
    try:
        q_params = {"key": PERENUAL_API_KEY, "q": scientific_name}
        data = http_get_json(f"{PERENUAL_API_BASE}/species-list", params=q_params, timeout=30.0, retries=3)
        d = data.get("data") or data  # 플랜/엔드포인트에 따라 응답 포맷 상이
        if isinstance(d, list) and d:
            return d[0]
        return None
    except Exception as e:
        logger.warning("Perenual search error (%s): %s", scientific_name, e)
        return None

def perenual_detail(species_id: int, max_retries: int = 3) -> Optional[Dict[str, Any]]:
    if not PERENUAL_API_KEY:
        return None
    backoff = 1.2
    for attempt in range(max_retries):
        try:
            q_params = {"key": PERENUAL_API_KEY}
            return http_get_json(f"{PERENUAL_API_BASE}/species/details/{species_id}", params=q_params, timeout=30.0, retries=1)
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 429 and attempt < max_retries - 1:
                time.sleep(backoff * (attempt + 1))  # 1.2s, 2.4s, ...
                continue
            logger.warning("Perenual detail error (%s): %s", species_id, e)
            return None
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

# ------------------------- LLM(Clova) -------------------------
def generate_one_liner_ko(data: Dict[str, Any]) -> str:
    """
    한 줄 설명 생성:
      1) CLOVA v3(Bearer) 또는 v1(APIGW) 자동 지원
      2) 둘 다 없으면 템플릿 문구 반환
    """
    diff = data.get("difficulty") or "중"
    light = data.get("light_requirement") or "반음지"
    water_text = data.get("water_cycle_text") or "주 1회"
    tmpl = f"이 식물은 {diff} 난이도로, {light} 환경에서 잘 자랍니다. 물은 {water_text} 주기로 주세요."

    if not (CLOVA_API_URL and (CLOVA_BEARER or CLOVA_API_KEY or CLOVA_API_KEY_ID)):
        return tmpl

    try:
        # 인증 방식 결정 (Bearer 우선)
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

        # v3 여부 (URL에 /v3/chat-completions)
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

        body = {"messages": messages, "temperature": 0.3, "topP": 0.9, "maxTokens": 80}
        if not is_v3:  # v1(apigw)만 body에 모델 필요, v3는 URL에 모델 포함
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
    Base.metadata.create_all(engine)  # 테이블 없을 때만 생성

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

        # API rate-limit 보호 (Wikidata REST/Perenual/Clova 전체 고려)
        time.sleep(1.2)

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
