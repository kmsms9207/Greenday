from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

import schemas
import crud
from database import get_db
from services import importer # ⭐️ services/importer.py를 import

router = APIRouter(
    prefix="/admin",
    tags=["Admin"],
    # dependencies=[Depends(get_current_admin_user)] # TODO: 관리자 인증 로직 추가
)

@router.post(
    "/plants/",
    response_model=schemas.PlantMasterInfo,
    status_code=status.HTTP_201_CREATED,
    summary="관리자가 실시간으로 식물 데이터 추가",
    description="관리자가 입력한 핵심 정보와 외부 API 데이터를 조합하여 PlantMaster DB에 새 식물을 추가합니다."
)
def add_new_plant_master(
    plant_request: schemas.PlantCreateRequest,
    db: Session = Depends(get_db)
):
    """
    관리자용 실시간 식물 추가 엔드포인트입니다.

    - **plant_request**: 관리자가 입력한 식물 핵심 정보 (schemas.PlantCreateRequest)
    - **동작**:
        1. DB에 동일한 학명(species)의 식물이 있는지 중복 확인
        2. `services.importer`의 핵심 로직을 호출하여 데이터 완성
        3. `crud.create_master_plant`를 통해 DB에 최종 저장
    """
    # 1. 중복 확인
    existing_plant = crud.get_master_plant_by_species(db, species=plant_request.species)
    if existing_plant:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Species '{plant_request.species}' already exists in the database."
        )

    # 2. 서비스 계층 호출 (핵심 로직)
    try:
        new_plant = importer.enrich_and_create_plant(db=db, request_data=plant_request)
    except Exception as e:
        # 외부 API 오류 등 서비스 로직에서 발생할 수 있는 모든 예외 처리
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred while creating the plant: {e}"
        )

    return new_plant