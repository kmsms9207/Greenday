from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List # List 타입을 명시적으로 import

import schemas, models, crud
from database import get_db
from dependencies import get_current_user # 수정: dependencies에서 get_current_user를 가져옵니다.

router = APIRouter(
    prefix="/plants",
    tags=["Plants"],
    # 이 라우터의 모든 API는 get_current_user 의존성을 통과해야만 실행됩니다.
    # 즉, 모든 API 호출 시 자동으로 로그인이 되어 있는지 검사합니다.
    dependencies=[Depends(get_current_user)]
)

@router.post("/", response_model=schemas.Plant, status_code=status.HTTP_201_CREATED)
def create_plant_for_user(plant: schemas.PlantCreate, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    """
    ### 새 반려식물 등록
    - **설명**: 현재 로그인된 사용자의 새 반려식물을 등록합니다.
    - **인증**: 필수
    """
    # 수정: crud.create_user_plant -> crud.create_plant
    return crud.create_plant(db=db, plant=plant, user_id=current_user.id)


@router.get("/", response_model=List[schemas.Plant])
def read_plants_for_user(current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    """
    ### 내 반려식물 목록 조회
    - **설명**: 현재 로그인된 사용자가 등록한 모든 반려식물 목록을 조회합니다.
    - **인증**: 필수
    """
    # crud.py에 정의된 함수를 호출하여 현재 사용자의 식물 목록을 가져옵니다.
    return crud.get_plants_by_owner(db=db, user_id=current_user.id)


@router.get("/{plant_id}", response_model=schemas.Plant)
def read_plant_by_id(plant_id: int, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    """
    ### 특정 반려식물 상세 정보 조회
    - **설명**: 특정 반려식물의 상세 정보를 조회합니다. 자신의 식물이 아니면 조회할 수 없습니다.
    - **인증**: 필수
    """
    # 수정: crud.get_plant -> crud.get_plant_by_id
    db_plant = crud.get_plant_by_id(db, plant_id=plant_id)
    if db_plant is None:
        raise HTTPException(status_code=404, detail="Plant not found")
    # 조회하려는 식물의 주인이 현재 로그인한 사용자인지 확인합니다.
    if db_plant.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to access this plant")
    return db_plant


@router.put("/{plant_id}", response_model=schemas.Plant)
def update_user_plant(plant_id: int, plant_update: schemas.PlantCreate, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    """
    ### 특정 반려식물 정보 수정
    - **설명**: 특정 반려식물의 정보를 수정합니다. 자신의 식물이 아니면 수정할 수 없습니다.
    - **인증**: 필수
    """
    # 수정: crud.get_plant -> crud.get_plant_by_id
    db_plant = crud.get_plant_by_id(db, plant_id=plant_id)
    if db_plant is None:
        raise HTTPException(status_code=404, detail="Plant not found")
    if db_plant.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to update this plant")
    
    return crud.update_plant(db=db, plant_id=plant_id, plant_update_data=plant_update)


@router.delete("/{plant_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user_plant(plant_id: int, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    """
    ### 특정 반려식물 삭제
    - **설명**: 특정 반려식물을 삭제합니다. 자신의 식물이 아니면 삭제할 수 없습니다.
    - **인증**: 필수
    """
    # 수정: crud.get_plant -> crud.get_plant_by_id
    db_plant = crud.get_plant_by_id(db, plant_id=plant_id)
    if db_plant is None:
        raise HTTPException(status_code=404, detail="Plant not found")
    if db_plant.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to delete this plant")
        
    crud.delete_plant(db=db, plant_id=plant_id)
    # 204 응답은 본문(body)이 없어야 하므로, 아무것도 return하지 않습니다.