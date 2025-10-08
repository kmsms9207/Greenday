# routers/media.py (신규)
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import Response
from sqlalchemy.orm import Session
from database import get_db
import models

router = APIRouter(prefix="/media", tags=["Media"])

@router.get("/{image_id}/orig")
def get_original(image_id: int, db: Session = Depends(get_db)):
    img = db.get(models.ImageAsset, image_id)
    if not img or not img.original:
        raise HTTPException(404, "image not found")
    return Response(
        content=img.original,
        media_type=img.mime or "application/octet-stream",
        headers={"Cache-Control": "public, max-age=2592000"}  # 30d
    )

@router.get("/{image_id}/thumb")
def get_thumb(image_id: int, db: Session = Depends(get_db)):
    img = db.get(models.ImageAsset, image_id)
    if not img or not img.thumb:
        raise HTTPException(404, "thumbnail not found")
    return Response(
        content=img.thumb,
        media_type="image/jpeg",
        headers={"Cache-Control": "public, max-age=2592000"}
    )
