# services/openai_chat.py
from __future__ import annotations

import os
import json
import httpx
from typing import Any, Dict, List, Optional

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "").strip()
OPENAI_BASE_URL = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1").rstrip("/")
OPENAI_MODEL_TEXT = os.getenv("OPENAI_MODEL_TEXT", "gpt-4o-mini").strip()
OPENAI_MODEL_VISION = os.getenv("OPENAI_MODEL_VISION", "gpt-4o-mini").strip()
OPENAI_TEMPERATURE = float(os.getenv("OPENAI_TEMPERATURE", "0.2"))
OPENAI_MAX_TOKENS = int(os.getenv("OPENAI_MAX_TOKENS", "512"))

if not OPENAI_API_KEY:
    raise RuntimeError("OPENAI_API_KEY not set")

_default_headers = {
    "Authorization": f"Bearer {OPENAI_API_KEY}",
    "Content-Type": "application/json",
}

async def _post_chat_completions(payload: Dict[str, Any]) -> Dict[str, Any]:
    url = f"{OPENAI_BASE_URL}/chat/completions"
    timeout = httpx.Timeout(60.0, connect=15.0)
    async with httpx.AsyncClient(timeout=timeout) as client:
        r = await client.post(url, headers=_default_headers, json=payload)
        if r.status_code >= 400:
            # 에러 본문 그대로 전달
            raise RuntimeError(f"Error code: {r.status_code} - {r.text}")
        return r.json()

def _coerce_to_text(resp: Dict[str, Any]) -> str:
    try:
        return resp["choices"][0]["message"]["content"] or ""
    except Exception:
        return json.dumps(resp, ensure_ascii=False)[:1500]

async def openai_chat_complete(
    messages: List[Dict[str, Any]],
    *,
    temperature: Optional[float] = None,
    max_tokens: Optional[int] = None,
    use_vision: bool = False,
) -> Dict[str, Any]:
    """
    messages: OpenAI Chat API 포맷
    - 텍스트 전용:
        {"role":"user","content":"hello"}
    - 멀티모달(비전):
        {"role":"user","content":[
            {"type":"text","text":"..."},
            {"type":"image_url","image_url":{"url":"data:image/png;base64,...."}}
        ]}
    """
    model = OPENAI_MODEL_VISION if use_vision else OPENAI_MODEL_TEXT
    payload = {
        "model": model,
        "messages": messages,
        "temperature": OPENAI_TEMPERATURE if temperature is None else temperature,
    }
    if max_tokens is None:
        payload["max_tokens"] = OPENAI_MAX_TOKENS
    else:
        payload["max_tokens"] = max_tokens

    resp = await _post_chat_completions(payload)
    text = _coerce_to_text(resp)

    return {
        "raw": resp,
        "text": text,
        "usage": resp.get("usage"),
        "finish_reason": resp.get("choices", [{}])[0].get("finish_reason"),
    }

async def get_openai_vision_response(
    *,
    settings=None,        # 호환성용 파라미터 (미사용해도 OK)
    messages,
    max_tokens: int = None,
):
    """
    GPT-4o(vision) 호출 후 '원본 OpenAI 응답 JSON'을 반환합니다.
    diagnose_llm.py가 이 형태를 기대합니다.
    """
    # openai_chat_complete는 가공된 dict를 돌려주므로,
    # 여기서는 원본 JSON을 위해 내부 POST를 직접 호출합니다.
    model = OPENAI_MODEL_VISION
    payload = {
        "model": model,
        "messages": messages,
        "temperature": OPENAI_TEMPERATURE,
        "max_tokens": OPENAI_MAX_TOKENS if max_tokens is None else max_tokens,
    }
    resp_json = await _post_chat_completions(payload)
    return resp_json