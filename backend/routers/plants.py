from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List # List 타입을 명시적으로 import
import logging

import schemas, models, crud
from database import get_db
from dependencies import get_current_user # 수정: dependencies에서 get_current_user를 가져옵니다.

logger = logging.getLogger(__name__)
router = APIRouter(
    prefix="/plants",
    tags=["Plants"],
    # 이 라우터의 모든 API는 get_current_user 의존성을 통과해야만 실행됩니다.
    # 즉, 모든 API 호출 시 자동으로 로그인이 되어 있는지 검사합니다.
    dependencies=[Depends(get_current_user)]
)

@router.post("/", response_model=schemas.Plant, status_code=status.HTTP_201_CREATED)
def create_plant_for_user(
    plant_create: schemas.PlantCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    master_plant = crud.get_master_plant_by_id(db, plant_id=plant_create.plant_master_id)
    if not master_plant:
        raise HTTPException(status_code=404, detail="PlantMaster not found")

    new_plant = crud.create_plant(
        db=db,
        user_id=current_user.id,
        name=plant_create.name,
        species=master_plant.species,
        plant_master_id=master_plant.id
    )

    try:
        crud.create_diary_log(
            db=db,
            plant_id=new_plant.id,
            log_type="BIRTHDAY", # 👈 '생일' 타입
            log_message=f"'{new_plant.name}'와(과) 함께하기 시작했습니다."
        )
    except Exception as e:
        logger.error(f"생일 일지 기록 실패 (Plant ID: {new_plant.id}): {e}")

    # [신규] 응답 스키마에 master_image_url을 채워주기 위한 로직
    result = schemas.Plant.model_validate(new_plant)
    result.master_image_url = master_plant.image_url
    return result


@router.get("/", response_model=List[schemas.Plant])
def read_plants_for_user(current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    db_plants = crud.get_plants_by_owner(db=db, user_id=current_user.id)

    results = []
    for plant in db_plants:
        plant_schema = schemas.Plant.model_validate(plant)
        if plant.master_info:
            plant_schema.master_image_url = plant.master_info.image_url
            plant_schema.difficulty = plant.master_info.difficulty
            plant_schema.light_requirement = plant.master_info.light_requirement
            plant_schema.watering_type = plant.master_info.watering_type
            plant_schema.pet_safe = plant.master_info.pet_safe
        results.append(plant_schema)
    return results


@router.get("/{plant_id}", response_model=schemas.Plant)
def read_plant_by_id(plant_id: int, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    db_plant = crud.get_plant_by_id(db=db, plant_id=plant_id)
    if db_plant is None:
        raise HTTPException(status_code=404, detail="Plant not found")
    if db_plant.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to access this plant")

    result = schemas.Plant.model_validate(db_plant)
    if db_plant.master_info:
        # --- ⬇️ master_info에서 상세 정보 가져와 채우기 ⬇️ ---
        result.master_image_url = db_plant.master_info.image_url
        result.difficulty = db_plant.master_info.difficulty
        result.light_requirement = db_plant.master_info.light_requirement
        result.watering_type = db_plant.master_info.watering_type
        result.pet_safe = db_plant.master_info.pet_safe
        # --- ⬆️ 추가 완료 ⬆️ ---
    return result


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


@router.post(
    "/{plant_id}/water",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="'물 줬어요' 기록",
    description="특정 식물의 '마지막으로 물 준 날짜'를 현재 시간으로 업데이트합니다."
)
def record_watering(
    plant_id: int,
    db: Session = Depends(get_db),
    current_user: schemas.UserInfo = Depends(get_current_user)
):
    plant = crud.get_plant_by_id(db, plant_id)
    if not plant:
        raise HTTPException(status_code=404, detail="Plant not found")
    if plant.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to update this plant")
    
    crud.update_last_watered_at(db, plant_id=plant_id)
    try:
        crud.create_diary_log(
            db=db,
            plant_id=plant_id,
            log_type="WATERING", # 👈 '물주기' 타입
            log_message="물을 주었습니다."
        )
    except Exception as e:
        logger.error(f"물주기 일지 기록 실패 (Plant ID: {plant_id}): {e}")
    return

@router.post(
    "/{plant_id}/snooze",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="물주기 알림 '하루 미루기'",
    description="특정 식물의 물주기 알림을 내일로 미룹니다."
)
def snooze_watering_notification(
    plant_id: int,
    db: Session = Depends(get_db),
    current_user: schemas.UserInfo = Depends(get_current_user)
):
    plant = crud.get_plant_by_id(db, plant_id)
    if not plant:
        raise HTTPException(status_code=404, detail="Plant not found")
    if plant.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to update this plant")

    crud.snooze_notification_for_plant(db, plant_id=plant_id)
    return