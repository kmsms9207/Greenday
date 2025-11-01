from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional

import schemas, crud, models

import crud, schemas
from database import get_db

# --- [신규] Whoosh 관련 import ---
from whoosh.index import open_dir
from whoosh.qparser import QueryParser, MultifieldParser
from whoosh.query import Term # 정확한 필터링을 위해 추가

INDEX_DIR = "indexdir"

# --- [신규] Whoosh 인덱스 로드 ---
try:
    ix = open_dir(INDEX_DIR)
    # 검색할 필드 지정 (name_ko와 description)
    # allow_wildcard=False, require_ands=True 등의 옵션 추가 가능
    qp = MultifieldParser(["name_ko", "description"], schema=ix.schema)
    print("✅ Whoosh 인덱스 로드 완료.")
except Exception as e:
    ix = None
    qp = None
    print(f"⚠️ Whoosh 인덱스 로드 실패: {e}. 검색 API가 작동하지 않을 수 있습니다.")

# 라우터를 생성할 때 prefix와 tags를 직접 정의합니다.
router = APIRouter(
    prefix="/encyclopedia",
    tags=["Encyclopedia"]
)

@router.get("/search", response_model=List[schemas.PlantMasterInfo])
def search_plants(
    q: str = Query(..., min_length=1, description="검색어 (한글, 영어 등)"),
    skip: int = 0,
    limit: int = 10,
    db: Session = Depends(get_db) # DB는 결과 상세 정보 조회에 필요
):
    """
    ### 식물 백과사전 검색 (Whoosh 기반)
    - 이름 또는 설명에서 검색어를 포함하는 식물을 찾습니다.
    - 한글 초성, 부분 일치 등을 지원합니다.
    """
    if not ix or not qp:
        raise HTTPException(status_code=503, detail="검색 기능이 현재 비활성화 상태입니다.")

    try:
        # Whoosh 쿼리 파싱
        query = qp.parse(q)

        results_ids = []
        with ix.searcher() as searcher:
            # Whoosh 검색 실행 (limit은 Whoosh 내부에서 처리)
            results = searcher.search(query, limit=skip + limit)
            # 결과에서 DB ID만 추출 (skip 적용)
            results_ids = [int(hit['id']) for hit in results[skip:]]

        if not results_ids:
            return []

        # 추출된 ID 목록으로 DB에서 전체 정보 조회 (순서 유지)
        # SQLAlchemy의 in_()은 순서를 보장하지 않으므로, 직접 순서 정렬 필요
        plant_details = db.query(models.PlantMaster)\
                          .filter(models.PlantMaster.id.in_(results_ids))\
                          .all()

        # Whoosh 검색 결과 순서대로 DB 결과 정렬
        plant_map = {plant.id: plant for plant in plant_details}
        ordered_plants = [plant_map[id] for id in results_ids if id in plant_map]

        return ordered_plants

    except Exception as e:
        # Whoosh 쿼리 파싱 오류 등 처리
        print(f"Whoosh 검색 오류: {e}")
        raise HTTPException(status_code=500, detail="검색 중 오류가 발생했습니다.")

@router.get("/", response_model=List[schemas.PlantMasterInfo])
def read_all_plants(
    skip: int = 0,
    limit: int = 100,
    # [추가] 필터링 옵션들
    difficulty: Optional[str] = Query(None, enum=["상", "중", "하"]),
    light_requirement: Optional[str] = Query(None, enum=["음지", "반음지", "양지"]),
    pet_safe: Optional[bool] = Query(None),
    sort_by: Optional[str] = Query(None, description="정렬 기준: name_ko, difficulty 등"),
    order: Optional[str] = Query("asc", description="정렬 순서: asc (오름차순) 또는 desc (내림차순)"),
    db: Session = Depends(get_db)
):
    plants = crud.get_all_master_plants(
        db=db, skip=skip, limit=limit,
        difficulty=difficulty,
        light_requirement=light_requirement,
        has_pets=pet_safe, # crud 함수 파라미터 이름에 맞춤
        sort_by=sort_by, # 정렬 기준 전달
        order=order      # 정렬 순서 전달
    )
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