# backend/services/llm.py
from __future__ import annotations
import os, uuid, base64, httpx
from typing import List, Dict, Any, Optional

# ===== 환경 변수 =====
CLOVA_BEARER = os.getenv("CLOVA_BEARER", "")

CLOVA_API_URL = os.getenv("CLOVA_API_URL", "")  # 예: https://clovastudio.apigw.ntruss.com/testapp/v1/chat-completions/HCX-003
CLOVA_API_KEY = os.getenv("CLOVA_API_KEY", "")  # X-NCP-CLOVASTUDIO-API-KEY
CLOVA_APIGW_KEY = os.getenv("CLOVA_APIGW_KEY", "")  # X-NCP-APIGW-API-KEY
CLOVA_STUDIO_API_KEY = os.getenv("CLOVA_STUDIO_API_KEY", os.getenv("CLOVA_API_KEY", ""))
NCP_APIGW_API_KEY     = os.getenv("NCP_APIGW_API_KEY",     os.getenv("CLOVA_API_KEY", ""))
NCP_APIGW_API_KEY_ID  = os.getenv("NCP_APIGW_API_KEY_ID",  os.getenv("CLOVA_API_KEY_ID", ""))
CLOVA_REQUEST_ID = os.getenv("CLOVA_REQUEST_ID", "")  # 없으면 UUID 자동
CLOVA_TEMPERATURE = float(os.getenv("CLOVA_TEMPERATURE", "0.2"))

def _headers() -> dict:
    # 1) Bearer 방식(권장)
    if CLOVA_BEARER:
        return {
            "Authorization": f"Bearer {CLOVA_BEARER}",
            "Content-Type": "application/json; charset=utf-8",
            "X-NCP-CLOVASTUDIO-REQUEST-ID": str(uuid.uuid4()),
        }
    # 2) 레거시/조합 방식
    if CLOVA_STUDIO_API_KEY and NCP_APIGW_API_KEY:
        h = {
            "X-NCP-CLOVASTUDIO-API-KEY": CLOVA_STUDIO_API_KEY,
            "X-NCP-APIGW-API-KEY": NCP_APIGW_API_KEY,
            "Content-Type": "application/json; charset=utf-8",
            "X-NCP-CLOVASTUDIO-REQUEST-ID": str(uuid.uuid4()),
        }
        if NCP_APIGW_API_KEY_ID:
            h["X-NCP-APIGW-API-KEY-ID"] = NCP_APIGW_API_KEY_ID
        return h
    raise RuntimeError("CLOVA auth missing: set CLOVA_BEARER or (CLOVA_STUDIO_API_KEY + NCP_APIGW_API_KEY).")

def _image_part(image_bytes: Optional[bytes] = None, image_url: Optional[str] = None) -> Dict[str, Any]:
    if image_url:
        return {"type": "image_url", "image_url": {"url": image_url}}
    if image_bytes:
        b64 = base64.b64encode(image_bytes).decode("ascii")
        return {"type": "image_base64", "image_base64": {"base64": b64}}
    return {"type": "text", "text": "NO_IMAGE"}

async def llm_rerank_and_koreanize(
    image_bytes: bytes,
    candidates: List[Dict[str, Any]],
    image_url: Optional[str] = None,
) -> Dict[str, Any]:
    """
    candidates: [{"label_en": "Potato___Early_Blight", "score": 0.77}, ...]
    반환: {"chosen_label_en","plant_ko","disease_ko","label_ko","confidence","reason_ko","show_species"}
    """
    if not (CLOVA_API_URL and CLOVA_API_KEY and CLOVA_APIGW_KEY):
        raise RuntimeError("CLOVA LLM env vars missing (CLOVA_API_URL, CLOVA_API_KEY, CLOVA_APIGW_KEY)")

    # 제어어휘(간단 예시, 필요에 따라 확장/환경변수화)
    plants_vocab = "토마토, 감자, 옥수수, 밀, 사과, 포도, 오렌지, 복숭아, 딸기, 고추"
    diseases_vocab = "겹무늬병, 역병, 녹병, 흰가루병, 점무늬병, 잎곰팡이병, 세균성 반점병, 잎마름병"

    sys_prompt = (
        "당신은 식물 병해 전문가입니다. 이미지를 보고 아래 후보 중 가장 그럴듯한 1개만 선택하세요. "
        "항상 한국어로, 아래 JSON 스키마로만 출력하세요.\n"
        "병명/작물명은 가능한 한 표준 용어를 사용하세요.\n"
        "스키마: {"
        "\"chosen_label_en\":\"Plant___Disease\","
        "\"plant_ko\":\"\","
        "\"disease_ko\":\"\","
        "\"label_ko\":\"\","
        "\"confidence\":0.0,"
        "\"reason_ko\":\"\","
        "\"show_species\":true}"
    )
    user_text = (
        f"후보:\n" +
        "\n".join([f"- {c['label_en']} ({c['score']:.2f})" for c in candidates]) +
        f"\n\n제어어휘(참고): 작물={plants_vocab} / 병명={diseases_vocab}\n"
        "규칙: 확신이 낮으면 show_species=false로 설정하세요."
    )

    messages = [
        {"role": "system", "content": [{"type": "text", "text": sys_prompt}]},
        {"role": "user", "content": [_image_part(image_bytes, image_url), {"type": "text", "text": user_text}]},
    ]

    payload = {
        "messages": messages,
        "topP": 0.8,
        "temperature": CLOVA_TEMPERATURE,
        "repeatPenalty": 1.1,
        "stopBefore": [],
        "includeAiFilters": True,
        "seed": 0,
    }

    async with httpx.AsyncClient(timeout=40) as client:
        r = await client.post(CLOVA_API_URL, headers=_headers(), json=payload)
        r.raise_for_status()
        data = r.json()

    # CLOVA 응답 포맷에 맞춰 추출(모델별 차이가 있을 수 있음)
    # 여기서는 content[0].text에 JSON 문자열이 들어온다고 가정
    try:
        content = data["result"]["message"]["content"][0]["text"]
    except Exception:
        # fallbacks
        content = data.get("result", {}).get("outputText") or ""

    import json as _json
    try:
        return _json.loads(content)
    except Exception:
        # 혹시 JSON이 아니면 간단 파싱 실패 -> Unknown 취급
        return {
            "chosen_label_en": candidates[0]["label_en"] if candidates else "Unknown",
            "plant_ko": "",
            "disease_ko": "",
            "label_ko": "",
            "confidence": 0.0,
            "reason_ko": "LLM JSON 파싱 실패",
            "show_species": False,
        }

async def llm_guidance(image_bytes: bytes, image_url: Optional[str] = None) -> str:
    """확신 낮을 때 추가 촬영/정보 가이던스를 한국어로 생성."""
    if not (CLOVA_API_URL and CLOVA_API_KEY and CLOVA_APIGW_KEY):
        return "추가 사진(잎 앞/뒤, 전체 수형, 꽃/열매 근접)을 제공해 주세요."

    sys_prompt = (
        "당신은 식물 진단 도우미입니다. 이미지를 보고 더 정확한 진단을 위해 "
        "사용자가 어떤 추가 사진(각도/거리/부위)이나 정보를 제공해야 하는지 한국어로 한 단락으로 알려주세요."
    )
    messages = [
        {"role": "system", "content": [{"type": "text", "text": sys_prompt}]},
        {"role": "user", "content": [_image_part(image_bytes, image_url), {"type": "text", "text": "안내만 작성"}]},
    ]
    payload = {
        "messages": messages,
        "topP": 0.8,
        "temperature": 0.4,
        "repeatPenalty": 1.1,
        "includeAiFilters": True,
        "seed": 0,
    }
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            r = await client.post(CLOVA_API_URL, headers=_headers(), json=payload)
            r.raise_for_status()
            data = r.json()
        try:
            return data["result"]["message"]["content"][0]["text"]
        except Exception:
            return data.get("result", {}).get("outputText") or "추가 사진(잎 앞/뒤, 전체 수형, 꽃/열매)을 제공해주세요."
    except Exception:
        return "추가 사진(잎 앞/뒤, 전체 수형, 꽃/열매)을 제공해 주세요."
