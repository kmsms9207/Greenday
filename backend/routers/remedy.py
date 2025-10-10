# backend/routers/remedy.py
from __future__ import annotations
import os
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

import models, schemas
from database import get_db
from dependencies import get_current_user
from services.remedy import get_remedy, normalize_disease_key, DISEASE_KO
from services.llm_advice import get_llm_remedy

router = APIRouter(
    prefix="",
    tags=["Remedy (care guidance)"],
    dependencies=[Depends(get_current_user)]
)

def _use_llm() -> bool:
    return os.getenv("REMEDY_USE_LLM", "true").lower() in {"1","true","yes"}

@router.post("/remedy", response_model=schemas.RemedyAdvice)
async def build_remedy(
    req: schemas.RemedyRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    key = normalize_disease_key(req.disease_key or "unknown")
    sev = (req.severity or "MEDIUM").upper()
    disease_ko = DISEASE_KO.get(key, req.disease_key or "불확실")

    if _use_llm():
        try:
            data = await get_llm_remedy(
                disease_key=key, disease_ko=disease_ko, severity=sev, plant_name=req.plant_name
            )
            return data
        except Exception:
            # LLM 장애/타임아웃 시 규칙 기반으로 즉시 백업
            pass

    # fallback: 로컬 룰베이스
    return get_remedy(key, disease_ko_hint=disease_ko, severity_hint=sev, score=None, plant_name=req.plant_name)

@router.get("/diagnoses/{diag_id}/remedy", response_model=schemas.RemedyAdvice)
async def build_remedy_from_diag(
    diag_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    diag = db.query(models.Diagnosis).filter(
        models.Diagnosis.id == diag_id,
        models.Diagnosis.user_id == current_user.id
    ).first()
    if not diag:
        raise HTTPException(status_code=404, detail="진단 결과를 찾을 수 없습니다.")

    key = normalize_disease_key(diag.disease_key or "unknown")
    disease_ko = diag.disease_ko or DISEASE_KO.get(key, key)
    sev = (diag.severity or "MEDIUM").upper()
    score = float(diag.score) if diag.score is not None else None

    if _use_llm():
        try:
            data = await get_llm_remedy(
                disease_key=key, disease_ko=disease_ko, severity=sev, plant_name=None
            )
            return data
        except Exception:
            pass

    return get_remedy(key, disease_ko_hint=disease_ko, severity_hint=sev, score=score, plant_name=None)
