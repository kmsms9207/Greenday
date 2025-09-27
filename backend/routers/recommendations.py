from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

import models, schemas, crud
from database import get_db
from dependencies import get_current_user

router = APIRouter(
    prefix="/recommendations",
    tags=["Recommendations"],
    dependencies=[Depends(get_current_user)]
)

# --- 내부 로직 (Scoring & Normalization) ---

# 사용자의 응답을 점수 계산에 사용할 표준 값으로 변환하기 위한 인덱스
_DIFF_IDX = {"하": 1, "중": 2, "상": 3}
_LIGHT_IDX = {"음지": 0, "반음지": 1, "양지": 2}

def _normalize_sunlight(x: str) -> str:
    """사용자의 햇빛 응답을 '음지/반음지/양지' 중 하나로 표준화합니다."""
    s = (x or "").strip().lower()
    if any(k in s for k in ["직사", "full", "양지", "sun"]): return "양지"
    if any(k in s for k in ["밝은 간접", "반음지", "part", "partial", "filtered", "간접"]): return "반음지"
    if any(k in s for k in ["그늘", "음지", "어두"]): return "음지"
    return "반음지" # 기본값

def _normalize_experience_to_diff(exp: str) -> str:
    """사용자의 식물 경험을 난이도 '하/중/상'으로 변환합니다."""
    e = (exp or "").strip().lower()
    if "초" in e or "begin" in e or "new" in e: return "하"
    if "상" in e or "adv" in e or "expert" in e: return "상"
    return "중" # 기본값

def _score_plant(
    plant: models.PlantMaster,
    target_diff: str,
    target_light: str,
    has_pets: bool
) -> tuple[float, list[str]]:
    """
    개별 식물에 대해 사용자의 선호도와 얼마나 일치하는지 점수를 매깁니다.
    """
    reasons: List[str] = []
    score = 0.0

    # 1. 난이도 점수 (가중치 3)
    plant_difficulty = getattr(plant, "difficulty", "중")
    if plant_difficulty in _DIFF_IDX:
        diff_gap = abs(_DIFF_IDX[plant_difficulty] - _DIFF_IDX[target_diff]) / 2
        difficulty_score = 3.0 * (1.0 - diff_gap)
        score += difficulty_score
        if difficulty_score >= 2.5:
            reasons.append(f"'{target_diff}' 난이도를 선호하는 분께 적합해요.")

    # 2. 채광 점수 (가중치 4)
    plant_light = getattr(plant, "light_requirement", "반음지")
    if plant_light in _LIGHT_IDX:
        light_gap = abs(_LIGHT_IDX[plant_light] - _LIGHT_IDX[target_light]) / 2
        light_score = 4.0 * (1.0 - light_gap)
        score += light_score
        if light_score >= 3.0:
            reasons.append(f"'{target_light}' 환경에서 잘 자라요.")

    # 3. 반려동물 안전 가점 (가중치 2)
    if has_pets and getattr(plant, "pet_safe", False) is True:
        score += 2.0
        reasons.append("반려동물에게 안전해요.")

    return round(score, 2), reasons

# --- API Endpoint ---

@router.post("/survey", response_model=List[schemas.RecommendItem])
def recommend_plants_from_survey(
    request: schemas.SurveyRecommendRequest,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    ### 설문 기반 맞춤 식물 추천
    - **설명**: 사용자가 제출한 설문 응답을 바탕으로, 가장 적합한 식물 목록을 점수와 함께 반환합니다.
    - **인증**: 필수
    """
    # 1. 사용자의 응답을 분석하여 목표 기준을 설정합니다.
    target_light = _normalize_sunlight(request.sunlight)
    exp_diff = _normalize_experience_to_diff(request.experience)
    target_diff = request.desired_difficulty if request.desired_difficulty in ["상", "중", "하"] else exp_diff

    # 2. DB에서 추천 대상이 될 식물 목록을 가져옵니다.
    master_plants = crud.get_all_master_plants(db, has_pets=request.has_pets)
    if not master_plants:
        raise HTTPException(status_code=404, detail="추천할 식물 데이터가 준비되지 않았습니다.")

    # 3. 각 식물에 대해 점수를 매깁니다.
    ranked_plants: List[schemas.RecommendItem] = []
    for plant in master_plants:
        score, reasons = _score_plant(
            plant=plant,
            target_diff=target_diff,
            target_light=target_light,
            has_pets=request.has_pets
        )
        
        # Pydantic 모델로 변환하여 리스트에 추가
        recommend_item = schemas.RecommendItem(
            id=plant.id,
            name_ko=plant.name_ko,
            image_url=plant.image_url,
            difficulty=plant.difficulty,
            light_requirement=plant.light_requirement,
            score=score,
            reasons=reasons
        )
        ranked_plants.append(recommend_item)

    # 4. 점수가 높은 순으로 정렬하여 최종 결과를 반환합니다.
    ranked_plants.sort(key=lambda p: p.score, reverse=True)

    return ranked_plants[:request.limit]