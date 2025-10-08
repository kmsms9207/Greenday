from __future__ import annotations
import io, hashlib
from PIL import Image
import numpy as np

try:
    import imagehash  # pip install ImageHash (있으면 pHash 사용)
except Exception:
    imagehash = None

def compute_phash64(pil: Image.Image) -> int:
    """
    64bit 지각(퍼셉추얼) 해시.
    - imagehash가 있으면 pHash 사용
    - 없으면 8x8 aHash로 64bit 정수 생성 (fallback)
    """
    if imagehash is not None:
        try:
            val = int(str(imagehash.phash(pil)), 16)
            # ▼ 부호 있는 BIGINT 범위(63bit)로 마스킹
            return val & ((1 << 63) - 1)
        except Exception:
            pass

    # Fallback: 8x8 aHash
    img = pil.convert("L").resize((8, 8), Image.Resampling.LANCZOS)
    arr = np.asarray(img, dtype=np.float32)
    mean = float(arr.mean())
    bits = (arr > mean).astype(np.uint8).flatten()

    acc = 0
    for b in bits:
        acc = (acc << 1) | int(b)
    # ▼ 63bit 마스킹
    return acc & ((1 << 63) - 1)

def make_thumbnail_bytes(pil: Image.Image, max_side: int = 768, fmt: str = "JPEG", quality: int = 85) -> bytes:
    """
    썸네일을 JPEG로 만들어 바이트로 반환
    """
    im = pil.copy()
    im.thumbnail((max_side, max_side))
    buf = io.BytesIO()
    im.save(buf, format=fmt, quality=quality)
    return buf.getvalue()
