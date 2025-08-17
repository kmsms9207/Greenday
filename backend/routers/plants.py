from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

import schemas, models, crud
from database import get_db
from routers.auth import get_current_user # auth.py에서 get_current_user 함수를 가져옵니다.

router = APIRouter(
    prefix="/plants",
    tags=["Plants"],
    # 이 라우터의 모든 API는 get_current_user 의존성을 통과해야만 실행됩니다.
    # 즉, 모든 API 호출 시 자동으로 로그인이 되어 있는지 검사합니다.
    dependencies=[Depends(get_current_user)]
)

@router.post("/", response_model=schemas.Plant, status_code=status.HTTP_201_CREATED)
def create_plant(plant: schemas.PlantCreate, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    """
    ### 새 반려식물 등록
    - **설명**: 현재 로그인된 사용자의 새 반려식물을 등록합니다.
    - **인증**: 필수
    """
    # TODO: DB 담당자가 crud.create_user_plant 함수를 만들면 아래 주석을 해제하고 실제 로직을 구현합니다.
    # return crud.create_user_plant(db=db, plant=plant, user_id=current_user.id)
    print(f"'{current_user.username}' 사용자가 새 식물 '{plant.name}' 등록을 요청했습니다.")
    # 임시 응답 (실제 DB 연동 전 테스트용)
    return {
        "id": 1, 
        "owner_id": current_user.id, 
        "created_at": "2025-08-17T16:50:00", 
        "name": plant.name,
        "species": plant.species,
        "image_url": plant.image_url
    }


@router.get("/", response_model=list[schemas.Plant])
def read_plants(current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    """
    ### 내 반려식물 목록 조회
    - **설명**: 현재 로그인된 사용자가 등록한 모든 반려식물 목록을 조회합니다.
    - **인증**: 필수
    """
    # TODO: DB 담당자가 crud.get_plants_by_owner 함수를 만들면 아래 주석을 해제하고 실제 로직을 구현합니다.
    # return crud.get_plants_by_owner(db=db, user_id=current_user.id)
    print(f"'{current_user.username}' 사용자가 자신의 식물 목록 조회를 요청했습니다.")
    return [] # 임시 응답


@router.get("/{plant_id}", response_model=schemas.Plant)
def read_plant(plant_id: int, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    """
    ### 특정 반려식물 상세 정보 조회
    - **설명**: 특정 반려식물의 상세 정보를 조회합니다. 자신의 식물이 아니면 조회할 수 없습니다.
    - **인증**: 필수
    """
    # TODO: DB 담당자가 crud.get_plant 함수를 만들면 아래 주석을 해제하고 실제 로직을 구현합니다.
    # db_plant = crud.get_plant(db, plant_id=plant_id)
    # if db_plant is None or db_plant.owner_id != current_user.id:
    #     raise HTTPException(status_code=404, detail="Plant not found")
    # return db_plant
    print(f"'{current_user.username}' 사용자가 식물 ID({plant_id}) 조회를 요청했습니다.")
    # 임시 응답
    return {
        "id": plant_id, 
        "name": "임시 식물", 
        "species": "임시 종", 
        "image_url": None, 
        "owner_id": current_user.id, 
        "created_at": "2025-08-17T16:50:00"
    }


@router.put("/{plant_id}", response_model=schemas.Plant)
def update_plant(plant_id: int, plant: schemas.PlantCreate, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    """
    ### 특정 반려식물 정보 수정
    - **설명**: 특정 반려식물의 정보를 수정합니다. 자신의 식물이 아니면 수정할 수 없습니다.
    - **인증**: 필수
    """
    # TODO: DB 담당자가 crud.update_plant 함수를 만들면 아래 주석을 해제하고 실제 로직을 구현합니다.
    print(f"'{current_user.username}' 사용자가 식물 ID({plant_id}) 수정을 요청했습니다.")
    # 임시 응답
    return {
        "id": plant_id, 
        "owner_id": current_user.id, 
        "created_at": "2025-08-17T16:50:00", 
        **plant.dict()
    }


@router.delete("/{plant_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_plant(plant_id: int, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    """
    ### 특정 반려식물 삭제
    - **설명**: 특정 반려식물을 삭제합니다. 자신의 식물이 아니면 삭제할 수 없습니다.
    - **인증**: 필수
    """
    # TODO: DB 담당자가 crud.delete_plant 함수를 만들면 아래 주석을 해제하고 실제 로직을 구현합니다.
    print(f"'{current_user.username}' 사용자가 식물 ID({plant_id}) 삭제를 요청했습니다.")
    return # 204 응답은 본문이 없어야 합니다.
