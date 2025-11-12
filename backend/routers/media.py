# routers/media.py

from __future__ import annotations
import io
import logging
from typing import Optional

from fastapi import (
    APIRouter, Depends, HTTPException, status,
    UploadFile, File, Response
)
from sqlalchemy.orm import Session
from PIL import Image

import models
import schemas
from database import get_db
from dependencies import get_current_user

# 해시/썸네일 유틸
from utils.image_meta import compute_phash64, make_thumbnail_bytes

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Media"])


# --- Helpers ---

def _get_image_asset_or_404(db: Session, image_id: int, user_id: int) -> models.ImageAsset:
    """DB에서 ImageAsset 조회, 없거나 소유자가 아니면 404"""
    asset = (
        db.query(models.ImageAsset)
        .filter(
            models.ImageAsset.id == image_id,
            models.ImageAsset.user_id == user_id,
        )
        .first()
    )
    if not asset:
        raise HTTPException(status_code=404, detail="Image not found or not authorized")
    return asset


def _save_image_to_db(
    db: Session,
    user_id: int,
    image_bytes: bytes,
    mime_type: str,
) -> models.ImageAsset:
    """
    이미지 바이트를 읽어 PIL 메타 추출, pHash 계산, 썸네일 생성 후 DB 저장
    """
    try:
        with Image.open(io.BytesIO(image_bytes)) as pil:
            pil_image = pil.convert("RGB")
            width, height = pil_image.size
    except Exception as e:
        logger.warning(f"PIL 이미지 로드 실패: {e}")
        raise HTTPException(status_code=400, detail="유효하지 않은 이미지 파일입니다.")

    # ✅ 핵심: 해시는 PIL 이미지로 계산해야 함
    image_hash = compute_phash64(pil_image)

    # ✅ 썸네일도 PIL 이미지에서 생성
    thumb_bytes = make_thumbnail_bytes(pil_image, max_side=768, fmt="JPEG", quality=85)

    db_asset = models.ImageAsset(
        user_id=user_id,
        image_hash=image_hash,
        mime=mime_type,
        width=width,
        height=height,
        bytes=len(image_bytes),
        original=image_bytes,
        thumb=thumb_bytes,
    )
    db.add(db_asset)
    db.commit()
    db.refresh(db_asset)
    return db_asset


# --- Routes ---

@router.post(
    "/media/upload",
    response_model=schemas.MediaUploadResponse,
    status_code=status.HTTP_201_CREATED,
)
async def upload_image(
    image: UploadFile = File(..., description="업로드할 이미지 파일"),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """이미지 업로드"""
    if not image.content_type or not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="이미지 파일만 업로드할 수 있습니다.")

    image_bytes = await image.read()
    if len(image_bytes) > 20 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="파일이 너무 큽니다(최대 20MB).")

    try:
        db_asset = _save_image_to_db(
            db=db,
            user_id=current_user.id,
            image_bytes=image_bytes,
            mime_type=image.content_type,
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"이미지 저장 실패: {e}")
        raise HTTPException(status_code=500, detail="이미지를 서버에 저장하는 중 오류가 발생했습니다.")

    return schemas.MediaUploadResponse(
        image_id=db_asset.id,
        image_url=f"/media/{db_asset.id}/orig",
        thumb_url=f"/media/{db_asset.id}/thumb",
        content_type=db_asset.mime,
        width=db_asset.width,
        height=db_asset.height,
    )


@router.get("/media/{image_id}/orig")
def get_original_image(
    image_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """원본 이미지 조회 (본인 인증 필요)"""
    asset = _get_image_asset_or_404(db, image_id, user_id=current_user.id)
    return Response(content=asset.original, media_type=asset.mime)


@router.get("/media/{image_id}/thumb")
def get_thumbnail_image(
    image_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """썸네일 이미지 조회 (본인 인증 필요)"""
    asset = _get_image_asset_or_404(db, image_id, user_id=current_user.id)
    return Response(content=asset.thumb, media_type="image/jpeg")
