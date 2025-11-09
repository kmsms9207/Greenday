# services/media.py
from __future__ import annotations

import os
from typing import Tuple
from sqlalchemy.orm import Session
from sqlalchemy.sql import func
from PIL import Image
import io

import models
from utils.image_meta import compute_phash64, make_thumbnail_bytes

APP_ORIGIN = os.getenv("APP_ORIGIN", "http://127.0.0.1:8000").rstrip("/")

def build_absolute_url(path: str) -> str:
    if path.startswith("http://") or path.startswith("https://"):
        return path
    if not path.startswith("/"):
        path = "/" + path
    return f"{APP_ORIGIN}{path}"

def save_image_to_db(db: Session, *, user_id: int, raw: bytes, mime: str) -> Tuple[str, str, int]:
    # PIL 로드하여 메타확인
    with Image.open(io.BytesIO(raw)) as pil:
        pil = pil.convert("RGB")
        width, height = pil.width, pil.height

    img_hash = compute_phash64(pil)
    thumb = make_thumbnail_bytes(pil, 768, "JPEG", 85)

    img = models.ImageAsset(
        user_id=user_id,
        image_hash=img_hash,
        mime=mime,
        width=width,
        height=height,
        bytes=len(raw),
        original=raw,
        thumb=thumb,
    )
    db.add(img)
    db.flush()  # id 확보

    image_url = f"/media/{img.id}/orig"
    thumb_url = f"/media/{img.id}/thumb"
    # 절대 URL 쓰고 싶으면 build_absolute_url(image_url) 사용
    return image_url, thumb_url, img_hash
