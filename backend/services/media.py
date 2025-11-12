# services/media.py
from __future__ import annotations

import io
import re
import base64
import logging
from typing import Tuple, Optional

import httpx
from PIL import Image
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session

import models
from utils.image_meta import compute_phash64, make_thumbnail_bytes
from core import config

logger = logging.getLogger(__name__)

# --- DB engine / SessionLocal for internal DB reads (used only for bypass) ---
# Note: we create these at module import time to avoid re-creating engine per call.
_DB_URL = getattr(config.settings, "DB_URL", None)
if not _DB_URL:
    # It's okay if DB_URL is missing in some dev contexts; DB bypass will fail gracefully.
    _engine = None
    SessionLocal = None
else:
    _engine = create_engine(_DB_URL, pool_pre_ping=True)
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=_engine)


APP_ORIGIN = getattr(config.settings, "APP_ORIGIN", "http://127.0.0.1:8000").rstrip("/")


def build_absolute_url(path: str) -> str:
    if path.startswith("http://") or path.startswith("https://"):
        return path
    if not path.startswith("/"):
        path = "/" + path
    return f"{APP_ORIGIN}{path}"


def save_image_to_db(db: Session, *, user_id: int, raw: bytes, mime: str) -> Tuple[str, str, int]:
    """
    원본 바이트를 읽어 메타 추출(PIL), pHash 계산, 썸네일 생성 후 DB 저장.
    반환: (image_url, thumb_url, image_hash)
    """
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


async def get_image_data_uri(
    image_url: str,
    settings: Optional[config.Settings] = None,
) -> Optional[str]:
    """
    이미지 URL(상대경로 또는 절대 URL)을 읽어 data URI로 변환합니다.

    우선순위:
    1) image_url이 이미 data: 로 시작하면 그대로 반환
    2) image_url이 내부 엔드포인트(`/media/{id}/orig` 또는 `/media/{id}/thumb`)일 경우:
         - DB에서 직접 바이트를 읽어 data URI 생성 (권한 우회)
    3) 그 외: httpx로 URL 요청하여 바이트를 읽고 data URI 생성
    """
    if not image_url:
        return None
    if image_url.startswith("data:"):
        return image_url

    settings = settings or config.settings

    # ---- 내부 경로 확인: /media/{id}/orig 또는 /media/{id}/thumb ----
    m = re.match(r"^/media/(\d+)/(orig|thumb)$", image_url)
    if m and SessionLocal is not None:
        image_id = int(m.group(1))
        which = m.group(2)  # "orig" or "thumb"
        try:
            db: Session = SessionLocal()
            try:
                asset = db.query(models.ImageAsset).filter(models.ImageAsset.id == image_id).first()
                if not asset:
                    logger.warning(f"get_image_data_uri: image id {image_id} not found in DB")
                    return None
                if which == "orig":
                    content = bytes(asset.original) if asset.original is not None else None
                    mime = asset.mime or "image/jpeg"
                else:
                    content = bytes(asset.thumb) if asset.thumb is not None else None
                    # thumb stored as binary but mime for thumb we assume jpeg
                    mime = asset.mime or "image/jpeg"

                if not content:
                    logger.warning(f"get_image_data_uri: no content for image id {image_id} ({which})")
                    return None

                b64 = base64.b64encode(content).decode("ascii")
                return f"data:{mime};base64,{b64}"
            finally:
                db.close()
        except Exception as e:
            logger.exception(f"get_image_data_uri: DB fetch failed for image id {image_id}: {e}")
            # fall back to httpx approach below

    # ---- 절대/원격 URL 접근 (httpx) ----
    url = build_absolute_url(image_url) if not image_url.startswith("http") else image_url
    try:
        timeout = httpx.Timeout(20.0, connect=10.0)
        async with httpx.AsyncClient(timeout=timeout) as client:
            resp = await client.get(url)
            if resp.status_code >= 400:
                logger.warning(f"get_image_data_uri: http status {resp.status_code} for {url}")
                return None
            content_type = resp.headers.get("Content-Type", "image/jpeg")
            mime = content_type.split(";")[0].strip() if content_type else "image/jpeg"
            b64 = base64.b64encode(resp.content).decode("ascii")
            return f"data:{mime};base64,{b64}"
    except Exception as e:
        logger.exception(f"get_image_data_uri: httpx fetch failed for {url}: {e}")
        return None
