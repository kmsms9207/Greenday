from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List

import crud, models, schemas
from database import get_db
from dependencies import get_current_user

router = APIRouter(
    prefix="/recommendations",
    tags=["Recommendations"],
    dependencies=[Depends(get_current_user)]
)

# --- 추천 로직 (스코어링) ---

# 각 설문 응답을 점수화하기 위한 기준 맵
DIFFICULTY_MAP = {"하": 1, "중": 2, "상": 3}
LIGHT_MAP = {"음지": 1, "반음지": 2, "양지": 3}

def _normalize_survey_answers(req: schemas.SurveyRecommendRequest):
    """프론트엔드에서 받은 설문 응답을 분석하기 쉬운 형태로 정규화합니다."""
    # 경험 -> 목표 난이도
    exp_diff_map = {"초보": "하", "중급": "중", "상급": "상"}
    target_difficulty = req.desired_difficulty or exp_diff_map.get(req.experience, "중")

    # 장소/햇빛 -> 목표 광량
    light_hint_map = {"베란다": "양지", "창가": "양지", "거실": "반음지", "사무실": "반음지", "침실": "반음지", "욕실": "음지", "현관": "음지"}
    target_light = light_hint_map.get(req.place) or "반음지"
    
    return {
        "target_difficulty": target_difficulty,
        "target_light": target_light,
    }

def _score_plant(plant: models.PlantMaster, normalized_answers: dict):
    """개별 식물에 대해 추천 점수를 매깁니다."""
    score = 0.0
    reasons = []

    # 1. 난이도 점수 (가중치 4)
    plant_diff_score = DIFFICULTY_MAP.get(plant.difficulty, 2)
    target_diff_score = DIFFICULTY_MAP.get(normalized_answers["target_difficulty"], 2)
    diff_gap = abs(plant_diff_score - target_diff_score)
    difficulty_score = max(0, 4 - (diff_gap * 2))
    score += difficulty_score
    if difficulty_score >= 3:
        reasons.append(f"원하는 난이도('{normalized_answers['target_difficulty']}')와 잘 맞아요.")

    # 2. 광량 점수 (가중치 5)
    plant_light_score = LIGHT_MAP.get(plant.light_requirement, 2)
    target_light_score = LIGHT_MAP.get(normalized_answers["target_light"], 2)
    light_gap = abs(plant_light_score - target_light_score)
    light_score = max(0, 5 - (light_gap * 2.5))
    score += light_score
    if light_score >= 4:
        reasons.append(f"환경('{normalized_answers['target_light']}')에 잘 자라요.")
        
    return round(score, 2), reasons

# --- API 엔드포인트 ---

@router.post("/survey", response_model=List[schemas.RecommendItem])
def recommend_plants_from_survey(
    req: schemas.SurveyRecommendRequest,
    db: Session = Depends(get_db)
):
    """
    ### 설문 기반 맞춤 식물 추천
    - **설명**: 사용자의 설문 응답을 바탕으로 가장 적합한 식물 목록을 점수와 함께 반환합니다.
    - **인증**: 필수
    """
    # 1. DB에서 추천 대상 식물 목록을 가져옵니다.
    master_plants = crud.get_all_master_plants(db, has_pets=req.has_pets)

    # 2. 설문 응답을 분석 가능한 형태로 정규화합니다.
    normalized_answers = _normalize_survey_answers(req)
    
    # 3. 각 식물에 대해 점수를 매깁니다.
    scored_plants = []
    for plant in master_plants:
        score, reasons = _score_plant(plant, normalized_answers)
        
        # 점수가 0점 이상인 식물만 결과에 포함
        if score > 0:
            recommend_item = schemas.RecommendItem(
                id=plant.id,
                name_ko=plant.name_ko,
                image_url=plant.image_url,
                difficulty=plant.difficulty,
                light_requirement=plant.light_requirement,
                score=score,
                reasons=reasons
            )
            scored_plants.append(recommend_item)

    # 4. 점수가 높은 순으로 정렬합니다.
    scored_plants.sort(key=lambda x: x.score, reverse=True)

    # 5. 요청한 개수(limit)만큼 잘라서 반환합니다.
    return scored_plants[:req.limit]