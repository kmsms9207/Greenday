#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
importer.py (rev: perenual-normalize)
- Wikidata(옵션) -> Perenual -> Clova X -> DB(PlantMaster UPSERT)
- 개선점:
  * Perenual 응답 정규화: watering_general_benchmark / sunlight / pets / care_level robust 파싱
  * water_cycle_text 50자 컷 + 광고/URL 필터
  * 429 백오프 강화, SPARQL 우회 스위치 유지
  * LLM 한 줄/140자 제한
"""

import os, json, time, argparse, logging, urllib.parse, re
from typing import Dict, Any, List, Optional, Tuple

import httpx
from dotenv import load_dotenv
from sqlalchemy import create_engine, select, Enum as SAEnum, String, Integer, Boolean, JSON as SAJSON
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, Session

# ------------------------- ENV -------------------------
load_dotenv()

WIKIDATA_SPARQL_ENDPOINT = os.getenv("WIKIDATA_SPARQL_ENDPOINT", "https://query.wikidata.org/sparql")
WIKIDATA_DISABLE = os.getenv("WIKIDATA_DISABLE", "0").lower() in ("1", "true", "yes")

PERENUAL_API_BASE = os.getenv("PERENUAL_API_BASE", "https://perenual.com/api")
PERENUAL_API_KEY = os.getenv("PERENUAL_API_KEY", "")

CLOVA_API_URL = os.getenv("CLOVA_API_URL", "")
CLOVA_BEARER = os.getenv("CLOVA_BEARER", "")
CLOVA_API_KEY_ID = os.getenv("CLOVA_API_KEY_ID", "")
CLOVA_API_KEY = os.getenv("CLOVA_API_KEY", "")
CLOVA_REQUEST_ID = os.getenv("CLOVA_REQUEST_ID", "plantmaster-importer")
CLOVA_MODEL = os.getenv("CLOVA_MODEL", "HCX-005")  # 기본 005로 맞춤

DATABASE_URL = os.getenv("DB_URL") or os.getenv("DATABASE_URL", "")
if DATABASE_URL and "mysql+mysqlconnector://" in DATABASE_URL and "charset=" not in DATABASE_URL:
    DATABASE_URL += ("&" if "?" in DATABASE_URL else "?") + "charset=utf8mb4"

USER_AGENT = "PlantMasterImporter/1.3 (contact: team@greenday.local)"  # 실제 메일 권장
MAX_DESC_CHARS = 140

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
logger = logging.getLogger("importer")

# ------------------------- DB -------------------------
class Base(DeclarativeBase):
    pass

class PlantMaster(Base):
    __tablename__ = "plants_master"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name_ko: Mapped[str] = mapped_column(String(150), nullable=False)
    name_en: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    species: Mapped[str] = mapped_column(String(190), nullable=False, unique=True)
    family: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    image_url: Mapped[Optional[str]] = mapped_column(String(1024), nullable=True)
    description: Mapped[Optional[str]] = mapped_column(String(length=65535), nullable=True)
    difficulty: Mapped[str] = mapped_column(SAEnum('상', '중', '하', name='difficulty_enum'), nullable=False, default='중')
    light_requirement: Mapped[str] = mapped_column(SAEnum('음지', '반음지', '양지', name='lightreq_enum'), nullable=False, default='반음지')
    water_cycle_text: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    water_interval_days: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    pet_safe: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)
    tags: Mapped[Optional[dict]] = mapped_column(SAJSON, nullable=True)

# ------------------------- HTTP -------------------------
def http_get_json(url: str, params: Dict[str, Any] = None, headers: Dict[str, str] = None,
                  timeout: float = 90.0, retries: int = 5) -> Dict[str, Any]:
    hdrs = {**(headers or {}), "User-Agent": USER_AGENT, "Accept-Encoding": "gzip"}
    params = dict(params or {})
    if "query.wikidata.org/sparql" in url and "timeout" not in params:
        params["timeout"] = "60000"
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
                ra = e.response.headers.get("Retry-After")
                time.sleep(int(ra) if ra and ra.isdigit() else backoff * (i + 1))
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

# ------------------------- Wikidata REST -------------------------
def wikidata_entity(qid: str) -> Optional[Dict[str, Any]]:
    try:
        data = http_get_json(f"https://www.wikidata.org/wiki/Special:EntityData/{qid}.json", timeout=30.0, retries=3)
        ent = next(iter(data.get("entities", {}).values()), None)
        if not ent:
            return None
        labels = ent.get("labels", {})
        name_ko = (labels.get("ko") or {}).get("value")
        claims = ent.get("claims", {})
        sci = None
        if "P225" in claims and claims["P225"]:
            sci = claims["P225"][0]["mainsnak"]["datavalue"]["value"]
        img_url = None
        if "P18" in claims and claims["P18"]:
            filename = claims["P18"][0]["mainsnak"]["datavalue"]["value"]
            img_url = "https://commons.wikimedia.org/wiki/Special:FilePath/" + urllib.parse.quote(filename) + "?width=640"
        return {"name_ko": name_ko, "species": sci, "image_url": img_url}
    except Exception:
        return None

def wikidata_search_by_scientific_name(scientific: str) -> Optional[Dict[str, Any]]:
    try:
        params = {"action": "wbsearchentities", "format": "json", "language": "ko", "type": "item", "search": scientific, "limit": 1}
        data = http_get_json("https://www.wikidata.org/w/api.php", params=params, timeout=30.0, retries=3)
        hits = data.get("search") or []
        if not hits: return None
        qid = hits[0].get("id")
        return wikidata_entity(qid)
    except Exception:
        return None

def _fallback_plants(limit: int) -> List[Dict[str, Any]]:
    seeds = [
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
    return [{"name_ko": ko, "species": sp, "image_url": None} for sp, ko in seeds[:max(1, limit)]]

def fetch_plants_from_wikidata(limit: int = 40) -> List[Dict[str, Any]]:
    query = f"""
    SELECT ?item ?taxonName WHERE {{
      ?item wdt:P31 wd:Q16521 .
      ?item wdt:P105 wd:Q7432 .
      ?item wdt:P171* wd:Q756 .
      ?item wdt:P225 ?taxonName .
    }}
    LIMIT {int(max(10, limit * 3))}
    """
    params = {"query": query, "format": "json"}
    headers = {"Accept": "application/sparql-results+json"}
    qid_sci: List[Tuple[str, str]] = []
    try:
        data = http_get_json(WIKIDATA_SPARQL_ENDPOINT, params=params, headers=headers, timeout=90.0, retries=5)
        for b in data.get("results", {}).get("bindings", []):
            item_uri = b.get("item", {}).get("value")
            sci = b.get("taxonName", {}).get("value")
            if not item_uri or not sci: continue
            qid = item_uri.rsplit("/", 1)[-1]
            qid_sci.append((qid, sci))
    except Exception as e:
        logger.warning("Wikidata SPARQL failed: %s", e)
    if not qid_sci:
        logger.warning("Using local fallback plant list due to Wikidata failure.")
        return _fallback_plants(limit)
    seen, picked = set(), []
    for qid, sci in qid_sci:
        if sci in seen: continue
        seen.add(sci); picked.append((qid, sci))
        if len(picked) >= limit: break
    results = []
    for qid, sci in picked:
        meta = wikidata_entity(qid) or {}
        name_ko = meta.get("name_ko") or sci
        image_url = meta.get("image_url")
        results.append({"name_ko": name_ko, "species": sci, "image_url": image_url})
        time.sleep(0.2)
    return results or _fallback_plants(limit)

# ------------------------- Perenual 정규화 -------------------------
def _to_list(val) -> List[str]:
    if val is None: return []
    if isinstance(val, list): return [str(x) for x in val if x is not None]
    return [str(val)]

def _norm_text(s: Optional[str]) -> str:
    return re.sub(r"\s+", " ", (s or "").strip().lower())

def map_light_requirement_any(sunlight) -> str:
    """
    다양한 표현을 한국어 3단계로 매핑:
      - 양지: "full sun", "direct sun", "bright light"
      - 반음지: "partial shade", "part shade", "bright indirect", "indirect", "filtered"
      - 음지: "full shade", "low light"
      기본값: 반음지
    """
    tokens = [t.lower() for t in _to_list(sunlight)]
    if any(("full sun" in t) or ("direct sun" in t) or ("bright light" in t) for t in tokens):
        # 풀선 혹은 아주 밝음
        if any(("partial shade" in t) or ("part shade" in t) or ("indirect" in t) for t in tokens):
            return "반음지"
        return "양지"
    if any(("partial shade" in t) or ("part shade" in t) or ("indirect" in t) or ("filtered" in t) or ("bright indirect" in t) for t in tokens):
        return "반음지"
    if any(("full shade" in t) or ("low light" in t) for t in tokens):
        return "음지"
    return "반음지"

def map_difficulty_any(src: Optional[str], water_days: Optional[int]) -> str:
    """
    우선 텍스트 기반, 없으면 물주기 휴리스틱:
      <=3일: 상, 4~10일: 중, >=11일: 하
    """
    if src:
        s = _norm_text(src)
        if any(k in s for k in ["easy", "beginner", "low"]): return "하"
        if any(k in s for k in ["hard", "difficult", "advanced", "high"]): return "상"
        if any(k in s for k in ["medium", "moderate"]): return "중"
    if isinstance(water_days, int):
        if water_days <= 3: return "상"
        if water_days >= 11: return "하"
    return "중"

def map_pet_safe_any(val) -> Optional[bool]:
    """
    0/1, "yes"/"no", "toxic"/"non-toxic", True/False 모두 처리
    True = pet_safe(안전), False = 유해
    """
    if val is None: return None
    v = val
    if isinstance(v, str):
        s = _norm_text(v)
        if s.isdigit(): v = int(s)
        elif s in ("yes", "true", "toxic", "poisonous"): return False
        elif s in ("no", "false", "non-toxic", "safe"): return True
    if isinstance(v, bool): return True if v is False else False  # 보수적 처리(잘 안쓰임)
    if isinstance(v, int):
        if v == 0: return True
        if v == 1: return False
    return None

def _water_text_from_days(days: Optional[int]) -> Optional[str]:
    if days is None: return None
    if 6 <= days <= 8: return "주 1회"
    if 12 <= days <= 16: return "2주 1회"
    return f"{days}일"

def map_watering_text(watering: Optional[str]) -> Optional[str]:
    if not watering: return None
    w = _norm_text(watering)
    if "http" in w or "upgrade" in w or "sorry" in w: return None
    if "frequent" in w: return "자주"
    if "average" in w: return "보통"
    if "minimum" in w: return "적게"
    if "once per week" in w: return "주 1회"
    if "once every 2 weeks" in w or "once every two weeks" in w: return "2주 1회"
    return None

def map_watering_days(watering: Optional[str]) -> Optional[int]:
    if not watering: return None
    w = _norm_text(watering)
    table = {
        "frequent": 3,
        "average": 7,
        "minimum": 14,
        "once per week": 7,
        "once every 2 weeks": 14,
        "once every two weeks": 14,
    }
    for k, v in table.items():
        if k in w: return v
    return None

def normalize_perenual_fields(src: Dict[str, Any]) -> Dict[str, Any]:
    """
    Perenual details/search 응답을 표준화해서 반환
    반환: name_en, family, sunlight(list/str), watering_text, watering_days, pet_safe(bool), care_level(str)
    """
    name_en = None
    family = None
    sunlight = None
    watering_text = None
    watering_days = None
    pet_safe = None
    care_level = None

    def pick(d: Dict[str, Any], *keys):
        for k in keys:
            if k in d and d[k] is not None:
                return d[k]
        return None

    # 최상단에서 공통 필드
    name_en = pick(src, "common_name", "common_names")
    if isinstance(name_en, list): name_en = name_en[0] if name_en else None
    sci_name = pick(src, "scientific_name")
    if isinstance(sci_name, list): sci_name = sci_name[0] if sci_name else None  # 사용 안하지만 참고
    family = pick(src, "family")

    # 햇빛
    sunlight = pick(src, "sunlight", "light")
    # 물주기 (1) 문자열
    watering_field = pick(src, "watering")
    watering_text = map_watering_text(watering_field)
    watering_days = map_watering_days(watering_field)

    # 물주기 (2) general benchmark가 더 신뢰도 높음
    bench = pick(src, "watering_general_benchmark")
    # 예: {"value":"7-10 days","min":7,"max":10}
    if isinstance(bench, dict):
        mn, mx = bench.get("min"), bench.get("max")
        if isinstance(mn, int) and isinstance(mx, int) and mn > 0 and mx >= mn:
            days = int(round((mn + mx) / 2))
            watering_days = watering_days or days
            watering_text = watering_text or _water_text_from_days(days)
        else:
            val = bench.get("value")
            if isinstance(val, str):
                m = re.search(r"(\d+)\s*-\s*(\d+)\s*days", val)
                if m:
                    days = int(round((int(m.group(1)) + int(m.group(2))) / 2))
                    watering_days = watering_days or days
                    watering_text = watering_text or _water_text_from_days(days)

    # 반려동물 독성
    pet_raw = pick(src, "poisonous_to_pets", "poisonous_to_pets_cat", "toxic_to_pets")
    pet_safe = map_pet_safe_any(pet_raw)

    # 난이도
    care_level = pick(src, "care_level", "maintenance", "difficulty")

    # 길이 컷 / 정리
    if watering_text and len(watering_text) > 50:
        watering_text = watering_text[:50]

    return {
        "name_en": name_en,
        "family": family,
        "sunlight": sunlight,
        "watering_text": watering_text,
        "watering_days": watering_days,
        "pet_safe": pet_safe,
        "care_level": care_level,
    }

# ------------------------- Perenual API -------------------------
def perenual_search_by_species(scientific_name: str) -> Optional[Dict[str, Any]]:
    if not PERENUAL_API_KEY: return None
    try:
        data = http_get_json(f"{PERENUAL_API_BASE}/species-list", params={"key": PERENUAL_API_KEY, "q": scientific_name}, timeout=30.0, retries=3)
        arr = data.get("data") or data
        return arr[0] if isinstance(arr, list) and arr else None
    except Exception as e:
        logger.warning("Perenual search error (%s): %s", scientific_name, e)
        return None

def perenual_detail(species_id: int, max_retries: int = 5) -> Optional[Dict[str, Any]]:
    if not PERENUAL_API_KEY: return None
    for attempt in range(max_retries):
        try:
            return http_get_json(f"{PERENUAL_API_BASE}/species/details/{species_id}", params={"key": PERENUAL_API_KEY}, timeout=30.0, retries=1)
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 429 and attempt < max_retries - 1:
                ra = e.response.headers.get("Retry-After")
                time.sleep(int(ra) if ra and ra.isdigit() else 1.5 * (attempt + 1))
                continue
            logger.warning("Perenual detail error (%s): %s", species_id, e)
            return None
        except Exception as e:
            logger.warning("Perenual detail error (%s): %s", species_id, e)
            return None

# ------------------------- LLM -------------------------
def to_one_line(s: str, limit: int = MAX_DESC_CHARS) -> str:
    s = re.sub(r"\s+", " ", (s or "").strip())
    return s if len(s) <= limit else s[:limit].rstrip() + "…"

def generate_one_liner_ko(data: Dict[str, Any]) -> str:
    diff = data.get("difficulty") or "중"
    light = data.get("light_requirement") or "반음지"
    water_text = data.get("water_cycle_text") or "주 1회"
    tmpl = f"이 식물은 {diff} 난이도로, {light} 환경에서 잘 자랍니다. 물은 {water_text} 주기로 주세요."
    if not (CLOVA_API_URL and (CLOVA_BEARER or CLOVA_API_KEY or CLOVA_API_KEY_ID)):
        return to_one_line(tmpl)
    try:
        use_bearer = bool(CLOVA_BEARER) or (CLOVA_API_KEY and CLOVA_API_KEY.startswith("nv-") and not CLOVA_API_KEY_ID)
        bearer = CLOVA_BEARER or (CLOVA_API_KEY if use_bearer else "")
        if use_bearer:
            headers = {"Authorization": f"Bearer {bearer}", "X-NCP-CLOVASTUDIO-REQUEST-ID": CLOVA_REQUEST_ID, "Content-Type": "application/json; charset=utf-8"}
        else:
            headers = {"X-NCP-APIGW-API-KEY-ID": CLOVA_API_KEY_ID, "X-NCP-APIGW-API-KEY": CLOVA_API_KEY, "X-NCP-CLOVASTUDIO-REQUEST-ID": CLOVA_REQUEST_ID, "Content-Type": "application/json; charset=utf-8"}
        is_v3 = "/v3/chat-completions" in (CLOVA_API_URL or "")
        prompt = (
            "다음 식물 메타데이터를 바탕으로 한국어 한 줄 설명을 만들어 주세요. "
            "형식: '이 식물은 {난이도} 난이도로, {햇빛} 환경에서 잘 자랍니다. 물은 {물주기} 주기로 주세요.' "
            "불필요한 장문/목록/줄바꿈 없이 1문장만.\n"
            f"데이터: {json.dumps(data, ensure_ascii=False)}"
        )
        messages = [
            {"role": "system", "content": "You are a concise assistant that answers in one sentence."},
            {"role": "user", "content": prompt},
        ]
        body = {"messages": messages, "temperature": 0.3, "topP": 0.9, "maxTokens": 80}
        if not is_v3: body["model"] = CLOVA_MODEL
        res = http_post_json(CLOVA_API_URL, body, headers=headers)
        text = None
        if isinstance(res, dict):
            text = res.get("result", {}).get("message", {}).get("content") or (res.get("choices") or [{}])[0].get("message", {}).get("content")
        return to_one_line(text or tmpl)
    except Exception as e:
        logger.warning("Clova X error: %s", e)
        return to_one_line(tmpl)

# ------------------------- UPSERT -------------------------
def upsert_plant_master(session: Session, row: Dict[str, Any], dry_run: bool = False) -> None:
    existing = session.execute(select(PlantMaster).where(PlantMaster.species == row["species"])).scalar_one_or_none()
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
        for k, v in payload.items(): setattr(existing, k, v)
        if not dry_run: session.add(existing)
        logger.info("[UPDATE] %s (%s)", row["species"], row.get("name_ko"))
    else:
        rec = PlantMaster(species=row["species"], **payload)
        if not dry_run: session.add(rec)
        logger.info("[INSERT] %s (%s)", row["species"], row.get("name_ko"))

# ------------------------- MAIN -------------------------
def run(limit: int = 40, dry_run: bool = False) -> None:
    if not DATABASE_URL: raise RuntimeError("DB_URL 또는 DATABASE_URL을(.env) 설정해주세요.")
    engine = create_engine(DATABASE_URL, pool_pre_ping=True, pool_recycle=3600)
    Base.metadata.create_all(engine)

    # 1) 종 목록
    wiki_rows: List[Dict[str, Any]] = []
    if not WIKIDATA_DISABLE:
        try:
            wiki_rows = fetch_plants_from_wikidata(limit=limit)
        except Exception as e:
            logger.warning("Wikidata 경로 실패: %s", e)
    if not wiki_rows:
        logger.info("Using Perenual catalog path (SPARQL 우회).")
        wiki_rows = _fallback_plants(limit)  # 간단 경로(원하면 catalog 페이징 함수로 대체 가능)

    logger.info("Wikidata fetched: %d rows", len(wiki_rows))

    to_save: List[Dict[str, Any]] = []
    for w in wiki_rows:
        species = w["species"]
        src = perenual_search_by_species(species)
        detail = None
        if src and isinstance(src, dict) and src.get("id"):
            detail = perenual_detail(src["id"])

        source_obj = detail or src or {}
        norm = normalize_perenual_fields(source_obj)

        # 파생값 계산
        lightreq = map_light_requirement_any(norm["sunlight"])
        difficulty = map_difficulty_any(norm["care_level"], norm["watering_days"])

        # 최종 row
        row = {
            "name_ko": w["name_ko"],
            "name_en": norm["name_en"],
            "species": species,
            "family": norm["family"],
            "image_url": w.get("image_url"),
            "difficulty": difficulty,
            "light_requirement": lightreq,
            "water_cycle_text": norm["watering_text"],
            "water_interval_days": norm["watering_days"],
            "pet_safe": norm["pet_safe"],
            "tags": {
                "source": {"wikidata": bool(w), "perenual": bool(source_obj)},
                "perenual_raw": source_obj or None,
            },
        }
        row["description"] = generate_one_liner_ko(row)
        to_save.append(row)

        time.sleep(1.2)  # rate-limit 보호

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
    ap.add_argument("--limit", type=int, default=40)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    try:
        run(limit=args.limit, dry_run=args.dry_run)
    except Exception as e:
        logger.exception("Importer failed: %s", e)
        raise
