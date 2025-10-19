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
        "당신은 식물 관리 및 병해충 진단 전문가입니다.\n"
        "규칙:\n"
        "- 한국어, 간결하고 단계적으로 설명.\n"
        "- 불확실하면 '추정'으로 표기.\n"
        "- 수치에는 단위를 명시(예: 1:1000, 10 mL, 7일 간격).\n"
        "출력 형식(아래 섹션 제목과 순서를 그대로 사용):\n"
        "요약: <한 문장>\n"
        "원인가설: <최대 3개 불릿>\n"
        "단계별 조치:\n"
        "1) <조치1>\n"
        "2) <조치2>\n"
        "주의/안전: <필요 시 한 줄>\n"
        "다음 액션: <한 줄>\n"
        "금지: 출처 없는 치료법 단정, 의학/수의학적 진단 표현."
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
