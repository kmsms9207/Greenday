# routers/diagnose_llm.py
from __future__ import annotations

import io
import base64
from typing import Any, Dict
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, Query
from sqlalchemy.orm import Session
from PIL import Image, ImageOps

import models
from database import get_db
from dependencies import get_current_user
from services.media import save_image_to_db
from services.openai_chat import openai_chat_complete

router = APIRouter(
    prefix="/diagnose",
    tags=["LLM Diagnosis (OpenAI Vision)"],
    dependencies=[Depends(get_current_user)],
)

@router.post("/llm")
async def diagnose_llm(
    image: UploadFile = File(..., description="식물 잎 사진 (jpg/png)"),
    force: bool = Query(False),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if not image.content_type or not image.content_type.startswith("image/"):
        raise HTTPException(400, "이미지 파일만 업로드할 수 있습니다.")

    raw = await image.read()
    # 이미지를 DB에 저장 (미디어 URL 확보)
    image_url, thumb_url, img_hash = save_image_to_db(
        db, user_id=current_user.id, raw=raw, mime=image.content_type
    )

    # Data URI (LLM에 URL 대신 바이트 직접 전달)
    b64 = base64.b64encode(raw).decode("ascii")
    data_uri = f"data:{image.content_type};base64,{b64}"

    # 프롬프트
    messages = [
        {
            "role": "system",
            "content": "You are a plant disease assistant. 답변은 한국어로 간결하게.",
        },
        {
            "role": "user",
            "content": [
                {"type": "text", "text": "이 식물 잎의 문제(병해충/생리장해)를 추정하고, 근거와 즉시할 조치를 3줄 이내로 요약해줘."},
                {"type": "image_url", "image_url": {"url": data_uri}},
            ],
        },
    ]

    try:
        result = await openai_chat_complete(messages, use_vision=True)
        text = result["text"] or ""

        # 최소 진단 레코드 저장(LLM 모드)
        diag = models.Diagnosis(
            user_id=current_user.id,
            image_hash=img_hash,
            image_url=image_url,
            thumb_url=thumb_url,
            width=None, height=None, bytes=len(raw), mime=image.content_type,
            disease_key="llm_only",
            disease_ko="LLM 판독",
            score=0.0,
            severity="LOW",
            mode="llm",
            reason_ko=text[:2000],
            source="llm",
            tta_used=False, preprocess_used=False,
            models=None, clip_model=None,
            thresholds=None, per_model=None, clip_votes=None,
        )
        db.add(diag); db.commit(); db.refresh(diag)

        return {
            "label": "llm_only",
            "label_ko": "LLM 판독",
            "score": 0.0,
            "severity": "LOW",
            "reason_ko": text,
            "image_url": image_url,
            "thumb_url": thumb_url,
            "diagnosis_id": diag.id,
            "cached": False,
            "mode": "llm",
            "source": "llm",
        }
    except Exception as e:
        # 실패 사유를 그대로 노출(개발 중)
        return {
            "label": "unknown",
            "label_ko": "불확실",
            "score": 0.0,
            "severity": "LOW",
            "reason_ko": f"LLM 호출 실패: {e}",
            "image_url": image_url,
            "thumb_url": thumb_url,
            "diagnosis_id": None,
            "cached": False,
            "mode": "llm",
            "source": "llm",
        }
