# services/remedy.py

from __future__ import annotations
import json
import re
from typing import Any, Dict, List

# --- 키 정규화 ---
def _norm_key(s: str) -> str:
    return (s or "").strip().lower().replace("-", "_").replace(" ", "_").replace("__", "_")

def normalize_disease_key(name: str) -> str:
    k = _norm_key(name)
    synonyms = {
        "gray_mold": "botrytis",
        "botrytis_gray_mold": "botrytis",
        "sooty_mould": "sooty_mold",
        "leaf_spots": "leaf_spot",
        "leafminer": "leaf_miner",
        "spider_mite": "spider_mites",
        "mealybug": "mealybugs",
        "scale": "scale_insects",
        "whitefly": "whiteflies",
        "thrip": "thrips",
        "mosaic": "virus_mosaic",
    }
    return synonyms.get(k, k)


# --- 한국어 병명 매핑 ---
DISEASE_KO: Dict[str, str] = {
    "powdery_mildew": "흰가루병",
    "downy_mildew": "노균병",
    "leaf_spot": "잎마름병/반점병",
    "anthracnose": "탄저병",
    "bacterial_leaf_spot": "세균성 잎반점병",
    "rust": "녹병",
    "early_blight": "겹무늬병",
    "late_blight": "역병",
    "botrytis": "회색곰팡이병(보트리티스)",
    "sooty_mold": "그을음병",
    "chlorosis": "엽록소결핍(황화)",
    "leaf_scorch": "잎끝타들음/잎마름",
    "edema": "부종",
    "root_rot": "뿌리썩음",
    "overwatering_damage": "과습 피해",
    "underwatering_damage": "건조 피해",
    "sunburn": "일소 피해",
    "spider_mites": "응애",
    "mealybugs": "밀깍지벌레",
    "scale_insects": "깍지벌레",
    "aphids": "진딧물",
    "thrips": "총채벌레",
    "whiteflies": "가루이",
    "leaf_miner": "굴파리",
    "virus_mosaic": "바이러스 모자이크",
    "unknown": "불확실",
}

# --- 간단 가이드 DB (필요 최소 항목; 확장 가능) ---
REMEDY_DB: Dict[str, Dict[str, List[str]]] = {
    "leaf_spot": {
        "immediate": [
            "갈색/검은 반점 잎을 도구 소독 후 제거·폐기.",
            "상부 분무 중단, 물 튐 최소화.",
        ],
        "care": [
            "세균성 의심 시 위생/통풍 개선이 핵심.",
            "곰팡이성 의심 시 병명 표기 살균제 라벨대로 사용.",
        ],
        "prevent": ["잎 표면 장시간 습윤 회피, 과비/광부족 교정."],
        "caution": ["도구·손 소독, 재사용 토양 금지."],
        "pro": ["반점 급격 확대 시 전문 상담 고려."],
    },
    "powdery_mildew": {
        "immediate": ["감염 잎 제거·폐기, 잎 젖히지 않기.", "통풍 확보, 과습 피하기."],
        "care": [
            "흰가루병 표기 살균제 라벨대로 사용(실내용 등록 제품).",
            "가벼운 경우 베이킹소다 소량 시험 살포(민감종 주의).",
        ],
        "prevent": ["과습/통풍불량 교정, 과다 질소 시비 지양."],
        "caution": ["약제는 라벨 지침/보호장비 준수."],
        "pro": ["신초 왜화·급속 확산 시 전문가 상담."],
    },
    "botrytis": {
        "immediate": ["회색 곰팡이 보이면 즉시 제거·폐기.", "환기·건조 강화."],
        "care": ["보트리티스 표기 살균제, 5~7일 관찰."],
        "prevent": ["낙엽·꽃대 제거, 과습 회피."],
        "caution": ["연한 조직 약해 주의, 저농도 시험."],
        "pro": ["꽃/새순 전면 감염 시 신속 대응 필요."],
    },
    "root_rot": {
        "immediate": ["젖은 토양 제거, 배수 좋은 토양으로 분갈이.", "썩은 뿌리 정리 후 소독."],
        "care": ["새 뿌리 발생까지 급수 최소화, 받침물 물 비우기."],
        "prevent": ["배수층/통기성 토양 사용, 과습 주기 교정."],
        "caution": ["오염 토양 재사용 금지."],
        "pro": ["뿌리 대부분 괴사 시 회생 어려움—삽수 고려."],
    },
    "spider_mites": {
        "immediate": ["잎 뒷면 물샤워 세척, 격리.", "거미줄 제거."],
        "care": ["원예용 살충비누/식물성 오일 반복 처리.", "심하면 실내용 등록 살충제 라벨 준수."],
        "prevent": ["건조 환경 개선, 잎 뒷면 정기 점검."],
        "caution": ["민감종 약해 주의."],
        "pro": ["재발 잦으면 약제 교대살포/전문 상담."],
    },
    "unknown": {
        "immediate": ["선명한 잎 앞/뒷면 근접샷 추가 촬영.", "상부 분무 중단, 통풍 확보, 과습 중단."],
        "care": ["1~2일 관찰 후 진행 방향 평가."],
        "prevent": ["물주기/광량/통풍 기준 점검."],
        "caution": ["불필요 약제 사용 금지."],
        "pro": ["급속 진행/전염 의심 시 격리·폐기 고려."],
    },
}

def pick_severity(user_given: str | None, score: float | None) -> str:
    if user_given in {"LOW", "MEDIUM", "HIGH"}:
        return user_given
    if score is None:
        return "MEDIUM"
    if score >= 0.8:
        return "HIGH"
    if score >= 0.5:
        return "MEDIUM"
    return "LOW"

def get_remedy(
    disease_key: str,
    disease_ko_hint: str | None,
    severity_hint: str | None,
    score: float | None,
    plant_name: str | None = None,
):
    key = normalize_disease_key(disease_key or "unknown")
    data = REMEDY_DB.get(key) or REMEDY_DB["unknown"]
    disease_ko = disease_ko_hint or DISEASE_KO.get(key, key)
    sev = pick_severity(severity_hint, score)

    immediate = list(data["immediate"])
    care = list(data["care"])
    if sev == "HIGH":
        immediate = ["[우선순위↑] " + s for s in immediate] + ["증상 급속 확산 시 감염부 과감히 제거·폐기."]
        care = ["[빈도↑] " + s for s in care]
    elif sev == "LOW":
        care = ["[관찰] " + s for s in care]

    title = f"{disease_ko} 해결 가이드"
    summary = f"{plant_name or '식물'}에서 의심되는 '{disease_ko}' 대응 요약입니다. 심각도: {sev}."

    return {
        "disease_key": key,
        "disease_ko": disease_ko,
        "title_ko": title,
        "severity": sev,
        "summary_ko": summary,
        "immediate_actions": immediate,
        "care_plan": care,
        "prevention": data["prevent"],
        "caution": data["caution"],
        "when_to_call_pro": data["pro"],
    }

# --- LLM 응답 파서 + 보정 규칙 ---

# 한글 근거 텍스트에서 라벨 추정(unknown 보정)
_GUESS_RULES = [
    (r"(검은\s*반점|갈색\s*반점|원형\s*반점|반점.*퍼짐|spot)", "leaf_spot"),
    (r"(흰가루|가루)\s*(병|피해)?", "powdery_mildew"),
    (r"(노균|잿빛곰팡이|회색\s*곰팡이|botrytis)", "botrytis"),
    (r"(녹병|녹\s*색\s*포자)", "rust"),
    (r"(뿌리\s*썩음|배수\s*불량|토양.*젖어)", "root_rot"),
    (r"(응애|mite)", "spider_mites"),
    (r"(총채벌레|thrip|thrips)", "thrips"),
    (r"(진딧물|aphid)", "aphids"),
    (r"(가루이|whitefly|whiteflies)", "whiteflies"),
    (r"(굴파리|leaf\s*miner)", "leaf_miner"),
    (r"(바이러스|모자이크)", "virus_mosaic"),
]

def _guess_key_from_text(text: str) -> str | None:
    t = (text or "").lower()
    for pat, key in _GUESS_RULES:
        if re.search(pat, t):
            return key
    return None

def parse_llm_diagnosis_result(openai_resp: Dict[str, Any]) -> Dict[str, Any]:
    """
    OpenAI Chat Completions '원본 응답 JSON'을 프로젝트 표준 스키마로 변환.
    - JSON이 아니어도 코드블록/자유서술에서 최대한 추출·보정
    """
    # 1) content 추출
    try:
        content = openai_resp["choices"][0]["message"]["content"] or ""
    except Exception:
        content = ""

    if not content:
        return {
            "disease_key": "unknown",
            "disease_ko": DISEASE_KO["unknown"],
            "reason_ko": "AI 응답이 비어 있습니다.",
            "score": 0.0,
            "severity": "LOW",
        }

    # 2) content → dict 파싱 시도
    parsed: Dict[str, Any] = {}
    s = content.strip()
    if s.startswith("{"):
        try:
            parsed = json.loads(s)
        except Exception:
            parsed = {}
    if not parsed:
        # ```json ... ``` 추출
        m = re.search(r"```(?:json)?\s*([\s\S]*?)```", content, re.IGNORECASE)
        if m:
            try:
                parsed = json.loads(m.group(1).strip())
            except Exception:
                parsed = {}

    # 3) 필드 보정
    disease_key = normalize_disease_key(parsed.get("disease_key") or "unknown")
    disease_ko = parsed.get("disease_ko") or DISEASE_KO.get(disease_key, "불확실")
    reason_ko = parsed.get("reason_ko") or parsed.get("reason") or content.strip()

    # score 캐스팅 방어
    raw_score = parsed.get("score", 0.0)
    try:
        score = float(raw_score)
    except (TypeError, ValueError):
        score = 0.0
    if not (0.0 <= score <= 1.0):
        score = 0.0

    severity = (parsed.get("severity") or "LOW").upper()
    if severity not in {"LOW", "MEDIUM", "HIGH"}:
        severity = "LOW"

    # 4) unknown 보정(키워드 추정)
    if disease_key == "unknown":
        guessed = _guess_key_from_text(reason_ko)
        if guessed:
            disease_key = guessed
            disease_ko = DISEASE_KO.get(disease_key, disease_key)
            if score == 0.0:
                score = 0.55
            if severity == "LOW":
                severity = "MEDIUM"

    return {
        "disease_key": disease_key,
        "disease_ko": disease_ko,
        "reason_ko": reason_ko[:2000],
        "score": float(score),
        "severity": severity,
    }
