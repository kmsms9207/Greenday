# services/clova_chat.py
import os, httpx, logging
log = logging.getLogger("clova")

def _headers():
    h = {"Content-Type": "application/json; charset=utf-8"}
    # 1) Bearer 키: CLOVA_BEARER -> CLOVASTUDIO_API_KEY -> CLOVA_API_KEY 순서로 탐색
    bearer = os.getenv("CLOVA_BEARER") or os.getenv("CLOVASTUDIO_API_KEY") or os.getenv("CLOVA_API_KEY")
    if bearer:
        h["Authorization"] = f"Bearer {bearer}"
    # 2) (선택) 요청 식별자 헤더
    req_id = os.getenv("CLOVA_REQUEST_ID")
    if req_id:
        h["X-NCP-CLOVASTUDIO-REQUEST-ID"] = req_id
    return h

def _sys_prompt():
    return (
        "당신은 가정용 식물 관리 도우미입니다. "
        "모든 답변은 한국어로 간결하게 작성하세요. "
        "불확실하면 사진/추가 정보를 요청하세요."
    )

async def chat_complete(messages, timeout=20.0):
    url = (os.getenv("CLOVA_API_URL") or "").strip()
    if not url:
        raise RuntimeError("CLOVA_API_URL not set")

    # v3 엔드포인트(/v3/chat-completions/모델명)는 모델이 URL에 이미 포함
    payload = {
        "messages": [{"role": "system", "content": _sys_prompt()}] + messages,
        "temperature": float(os.getenv("CLOVA_TEMPERATURE", "0.5")),
        "topP": float(os.getenv("CLOVA_TOP_P", "0.8")),
        "maxTokens": int(os.getenv("CLOVA_MAX_TOKENS", "800")),
    }
    if "/v3/" not in url:
        payload["model"] = os.getenv("CLOVA_MODEL", "HCX-Chat")

    async with httpx.AsyncClient(timeout=timeout) as client:
        r = await client.post(url, headers=_headers(), json=payload)
        log.info("[CLOVA] status=%s req_id=%s", r.status_code, r.headers.get("X-NCP-CLOVASTUDIO-REQUEST-ID"))
        r.raise_for_status()
        data = r.json()

    # 안전 추출
    text = (
        (data.get("choices") or [{}])[0].get("message", {}).get("content")
        or data.get("result", {}).get("output_text")
        or data.get("output", "")
        or ""
    )
    return {"text": text, "raw": data}
