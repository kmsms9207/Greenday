# routers/chat.py
from __future__ import annotations

import base64
from datetime import datetime
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy.orm import Session

import models, schemas
from database import get_db
from dependencies import get_current_user
from services.media import save_image_to_db
from services.openai_chat import openai_chat_complete

router = APIRouter(
    prefix="/chat",
    tags=["Chat (OpenAI)"],
    dependencies=[Depends(get_current_user)],
)

def _db_message_to_chatmessageout(m: models.ChatMessage) -> schemas.ChatMessageOut:
    return schemas.ChatMessageOut.model_validate(m)

@router.post("/send", response_model=schemas.ChatSendResponse)
async def chat_send(
    message: str = Form(...),
    thread_id: Optional[int] = Form(None),
    image: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    # 1) 스레드 확보(없으면 생성)
    if not thread_id or thread_id == 0:
        th = models.ChatThread(
            user_id=current_user.id,
            title=None,
        )
        db.add(th); db.flush()
        thread_id = th.id
    else:
        th = db.query(models.ChatThread).filter(
            models.ChatThread.id == thread_id,
            models.ChatThread.user_id == current_user.id
        ).first()
        if not th:
            raise HTTPException(404, "THREAD_NOT_FOUND")

    # 2) 유저 메시지 저장 (+ 이미지 저장)
    saved_image_url: Optional[str] = None
    data_uri: Optional[str] = None

    if image:
        raw = await image.read()
        if not image.content_type or not image.content_type.startswith("image/"):
            raise HTTPException(400, "이미지 파일만 업로드할 수 있습니다.")
        img_url, thumb_url, _ = save_image_to_db(
            db, user_id=current_user.id, raw=raw, mime=image.content_type
        )
        saved_image_url = img_url
        b64 = base64.b64encode(raw).decode("ascii")
        data_uri = f"data:{image.content_type};base64,{b64}"

    user_msg = models.ChatMessage(
        thread_id=thread_id,
        role="user",
        content=message,
        image_url=saved_image_url,  # 우리 DB 미디어용 (LLM에는 data_uri로 별도 전달)
        provider_resp=None,
        tokens_in=None,
        tokens_out=None,
    )
    db.add(user_msg); db.flush()

    # 3) 히스토리 구성 (최근 10개)
    hist: List[models.ChatMessage] = db.query(models.ChatMessage)\
        .filter(models.ChatMessage.thread_id == thread_id)\
        .order_by(models.ChatMessage.id.asc())\
        .limit(10).all()

    # OpenAI용 messages 변환
    messages: List[Dict[str, Any]] = [{"role": "system", "content": "당신은 식물 도우미 챗봇입니다. 한국어로 답하세요."}]
    for m in hist:
        if m.role == "user":
            if m.image_url and m.id == user_msg.id and data_uri:
                messages.append({
                    "role": "user",
                    "content": [
                        {"type": "text", "text": m.content},
                        {"type": "image_url", "image_url": {"url": data_uri}},
                    ]
                })
            else:
                messages.append({"role": "user", "content": m.content})
        else:
            messages.append({"role": "assistant", "content": m.content})

    # 4) LLM 호출
    try:
        use_vision = data_uri is not None
        result = await openai_chat_complete(messages, use_vision=use_vision)
        answer_text = result["text"] or ""
        provider_raw = result["raw"]

        asst_msg = models.ChatMessage(
            thread_id=thread_id,
            role="assistant",
            content=answer_text,
            image_url=saved_image_url,  # 사용자가 보낸 이미지 경로 그대로 표시(선택)
            provider_resp=provider_raw,
            tokens_in=(result.get("usage") or {}).get("prompt_tokens"),
            tokens_out=(result.get("usage") or {}).get("completion_tokens"),
        )
        db.add(asst_msg); db.commit(); db.refresh(asst_msg)

        return {
            "thread_id": thread_id,
            "assistant": _db_message_to_chatmessageout(asst_msg),
        }
    except Exception as e:
        # 실패시에도 assistant 메시지로 남겨 UX 유지
        asst_msg = models.ChatMessage(
            thread_id=thread_id,
            role="assistant",
            content=f"(오류) LLM 호출 실패: {e}",
            image_url=saved_image_url,
            provider_resp=None,
        )
        db.add(asst_msg); db.commit(); db.refresh(asst_msg)

        return {
            "thread_id": thread_id,
            "assistant": _db_message_to_chatmessageout(asst_msg),
        }