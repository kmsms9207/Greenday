from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional

import crud, schemas
from database import get_db

# 라우터를 생성할 때 prefix와 tags를 직접 정의합니다.
router = APIRouter(
    prefix="/encyclopedia",
    tags=["Encyclopedia"]
)

@router.get("/", response_model=List[schemas.PlantMasterInfo])
def get_encyclopedia_plants(
    q: Optional[str] = Query(None, description="한국어 이름으로 식물 검색"),
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db)
):
    """
    백과사전에서 모든 식물 목록을 가져오거나, 한국어 이름으로 검색합니다.
    """
    if q:
        plants = crud.search_master_plants(db, q=q, skip=skip, limit=limit)
    else:
        plants = crud.get_all_master_plants(db, skip=skip, limit=limit)
    return plants

@router.get("/{plant_id}", response_model=schemas.PlantMasterInfo)
def get_encyclopedia_plant_detail(
    plant_id: int,
    db: Session = Depends(get_db)
):
    """
    백과사전에서 특정 식물의 상세 정보를 가져옵니다.
    """
    plant = crud.get_master_plant_by_id(db, plant_id=plant_id)
    if plant is None:
        raise HTTPException(status_code=404, detail="백과사전에서 해당 식물을 찾을 수 없습니다.")
    return plant