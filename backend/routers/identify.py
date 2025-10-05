# backend/routers/identify.py
from fastapi import APIRouter

router = APIRouter(prefix="/identify", tags=["identify"])

@router.get("/health")
def health():
    return {"ok": True}
