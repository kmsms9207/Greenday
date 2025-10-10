# backend/services/llm_advice.py
from __future__ import annotations
import os, json, re
from typing import Dict, Any, List, Optional
import httpx

# 프롬프트: 한국어 고정 + 안전 가이드라인 + JSON만 반환
_SYSTEM_PROMPT = """당신은 실내 원예(가정용) 병해충 관리 전문가입니다.
- 한국어로 간결하고 실천 가능한 조치만 제시합니다.
- 애완동물/유아 안전에 유의하고, 약제는 '실내용/가정원예 등록 제품'과 '라벨 지침 준수'를 명시합니다.
- 확실치 않은 내용은 추정이라 말하고 과도한 약제 사용은 피하도록 안내합니다.
- 반환은 반드시 유효한 JSON 객체 한 개만 출력하세요. JSON 외 텍스트 금지.
- 필드명과 출력 스키마를 엄격히 따르세요.
"""

_USER_TEMPLATE = """다음 정보를 바탕으로 해결 가이드를 작성하세요.
- disease_key: {disease_key}
- disease_ko: {disease_ko}
- severity: {severity}  # LOW | MEDIUM | HIGH
- plant_name: {plant_name}

출력(JSON only):
{{
  "disease_key": "{disease_key}",
  "disease_ko": "{disease_ko}",
  "title_ko": "{disease_ko} 해결 가이드",
  "severity": "{severity}",
  "summary_ko": "간단 요약을 1문장으로.",
  "immediate_actions": [ "오늘 바로 할 일 3~6개, 짧은 문장" ],
  "care_plan": [ "1~2주 관리 계획 3~6개" ],
  "prevention": [ "재발 방지 팁 3~5개" ],
  "caution": [ "주의사항 2~5개 (약제 라벨, 애완동물 주의 등)" ],
  "when_to_call_pro": [ "전문가/폐기 기준 1~3개" ]
}}"""

def _headers() -> Dict[str, str]:
    key_id = os.getenv("CLOVA_API_KEY_ID", "")
    key = os.getenv("CLOVA_API_KEY", "")
    return {
        "Content-Type": "application/json; charset=utf-8",
        "X-NCP-APIGW-API-KEY-ID": key_id,
        "X-NCP-APIGW-API-KEY": key,
    }

def _extract_json(text: str) -> Dict[str, Any]:
    # 혹시 JSON 밖 문자가 섞여와도 복구
    m = re.search(r"\{.*\}", text, re.S)
    if not m:
        raise ValueError("JSON not found in model response")
    return json.loads(m.group(0))

async def get_llm_remedy(
    disease_key: str,
    disease_ko: str,
    severity: str = "MEDIUM",
    plant_name: Optional[str] = None,
    timeout: float = 15.0,
) -> Dict[str, Any]:
    url = os.getenv("CLOVA_API_URL", "").strip()
    model = os.getenv("CLOVA_MODEL", "HCX-Chat")
    if not url:
        raise RuntimeError("CLOVA_API_URL is not set")

    system = _SYSTEM_PROMPT
    user = _USER_TEMPLATE.format(
        disease_key=disease_key or "unknown",
        disease_ko=disease_ko or disease_key or "불확실",
        severity=(severity or "MEDIUM").upper(),
        plant_name=plant_name or "식물",
    )

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        # 보수적 생성 파라미터
        "temperature": 0.3,
        "topP": 0.8,
        "maxTokens": 900,
    }

    async with httpx.AsyncClient(timeout=timeout) as client:
        r = await client.post(url, headers=_headers(), json=payload)
        r.raise_for_status()
        data = r.json()

    # ▼ 응답 포맷은 게이트웨이/모델 설정에 따라 다를 수 있어 안전하게 추출
    # 일반적으로 choices[0].message.content 또는 result.output_text 유사 키에 존재
    text = None
    if isinstance(data, dict):
        # 여러 케이스 시도
        text = (
            data.get("choices", [{}])[0].get("message", {}).get("content")
            or data.get("result", {}).get("output_text")
            or data.get("result", {}).get("message")
            or data.get("output", "")
        )
    if not text:
        raise ValueError(f"Unexpected response shape: {list(data.keys())}")

    return _extract_json(text)
