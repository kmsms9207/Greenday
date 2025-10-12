# backend/routers/chat.py
from __future__ import annotations
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
import models, schemas
from database import get_db
from dependencies import get_current_user
from services.clova_chat import chat_complete

router = APIRouter(
    prefix="/chat",
    tags=["Chat"],
    dependencies=[Depends(get_current_user)]
)

def _load_history(db: Session, thread_id: int, user_id: int, limit: int = 20):
    msgs = (
        db.query(models.ChatMessage)
        .join(models.ChatThread, models.ChatThread.id == models.ChatMessage.thread_id)
        .filter(models.ChatThread.id == thread_id, models.ChatThread.user_id == user_id)
        .order_by(models.ChatMessage.id.desc())
        .limit(limit)
        .all()
    )
    # LLM 형식으로 변환 (최신→과거 정렬이므로 뒤집기)
    msgs = list(reversed(msgs))
    out = []
    for m in msgs:
        out.append({"role": m.role, "content": m.content})
    return out

@router.post("/send", response_model=schemas.ChatSendResponse)
async def chat_send(
    req: schemas.ChatSendRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    # 1) 스레드 확보/신규 생성
    thread = None
    if req.thread_id:
        thread = db.query(models.ChatThread).filter(
            models.ChatThread.id == req.thread_id,
            models.ChatThread.user_id == current_user.id
        ).first()
        if not thread:
            raise HTTPException(status_code=404, detail="대화 스레드를 찾을 수 없습니다.")
    else:
        thread = models.ChatThread(user_id=current_user.id, title=None)
        db.add(thread); db.flush()  # thread.id 확보

    # 2) 사용자 메시지 저장
    user_msg = models.ChatMessage(
        thread_id=thread.id, role="user", content=req.message, image_url=req.image_url
    )
    db.add(user_msg); db.flush()

    # 3) 히스토리 불러와 LLM 호출
    history = _load_history(db, thread.id, current_user.id, limit=20)
    result = await chat_complete(history)
    text = result["text"]

    # 4) 어시스턴트 메시지 저장
    asst_msg = models.ChatMessage(
        thread_id=thread.id, role="assistant", content=text, provider_resp=result["raw"]
    )
    db.add(asst_msg); db.commit()

    return schemas.ChatSendResponse(
        thread_id=thread.id,
        assistant=schemas.ChatMessageOut.model_validate(asst_msg)
    )

@router.get("/threads/{thread_id}/messages", response_model=List[schemas.ChatMessageOut])
def list_messages(
    thread_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    msgs = (
        db.query(models.ChatMessage)
        .join(models.ChatThread, models.ChatThread.id == models.ChatMessage.thread_id)
        .filter(models.ChatThread.id == thread_id, models.ChatThread.user_id == current_user.id)
        .order_by(models.ChatMessage.id.asc())
        .all()
    )
    return [schemas.ChatMessageOut.model_validate(m) for m in msgs]
