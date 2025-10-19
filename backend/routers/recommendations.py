from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
import json
import joblib
import pandas as pd

import schemas, models, crud
from database import get_db
from dependencies import get_current_user

router = APIRouter(
    prefix="/recommendations",
    tags=["Recommendations"],
    dependencies=[Depends(get_current_user)]
)

# --- [신규] 머신러닝 모델 및 관련 파일 로드 ---
# 서버가 시작될 때 한 번만 로드하여 메모리에 올려둡니다.
try:
    ml_model = joblib.load("ml_scripts/plant_cluster_model.joblib")
    ml_encoder = joblib.load("ml_scripts/plant_encoder.joblib")
    with open("ml_scripts/cluster_map.json", 'r', encoding='utf-8') as f:
        cluster_map = json.load(f)
    print("✅ ML 추천 모델 및 관련 파일 로드 완료.")
except FileNotFoundError:
    ml_model = None
    ml_encoder = None
    cluster_map = None
    print("⚠️ ML 추천 모델 파일이 없습니다. /recommendations/ml API는 작동하지 않습니다.")


# --- [기존] 규칙 기반 추천 로직 (수정 없음) ---
def _normalize_sunlight(place: str) -> str:
    place_map = {"창가": "양지", "실내": "반음지", "화장실": "음지"}
    return place_map.get(place, "반음지")

def _normalize_experience_to_diff(experience: str) -> str:
    exp_map = {"초보": "하", "경험자": "중", "전문가": "상"}
    return exp_map.get(experience, "중")


# --- [기존] 규칙 기반 추천 API ---
@router.post("/survey", response_model=List[schemas.RecommendItem], summary="규칙 기반 맞춤 식물 추천")
def recommend_plants_with_survey(
    request: schemas.SurveyRecommendRequest,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    target_light = _normalize_sunlight(request.sunlight)
    exp_diff = _normalize_experience_to_diff(request.experience)
    target_diff = request.desired_difficulty if request.desired_difficulty in ["상", "중", "하"] else exp_diff

    all_plants = crud.get_all_master_plants(db, has_pets=request.has_pets)
    
    scored_plants = []
    for plant in all_plants:
        score = 0
        reasons = []
        
        # 1. 채광 점수 (가중치 4)
        if plant.light_requirement == target_light:
            score += 4
            reasons.append(f"채광 조건('{target_light}')이 잘 맞아요.")
        
        # 2. 난이도 점수 (가중치 3)
        if plant.difficulty == target_diff:
            score += 3
            reasons.append(f"관리 난이도('{target_diff}')가 적절해요.")
        elif plant.difficulty == exp_diff:
            score += 1 # 희망 난이도는 아니지만 경험 수준에는 맞음
        
        # 3. 반려동물 안전 점수 (가중치 5 - 필수조건)
        if request.has_pets and plant.pet_safe:
            score += 5
            reasons.append("반려동물에게 안전해요.")

        if score > 0:
            scored_plants.append({
                "plant": plant,
                "score": score,
                "reasons": reasons
            })

    scored_plants.sort(key=lambda x: x["score"], reverse=True)
    
    top_plants = scored_plants[:request.limit]
    
    return [
        schemas.RecommendItem(
            id=item["plant"].id,
            name_ko=item["plant"].name_ko,
            image_url=item["plant"].image_url,
            difficulty=item["plant"].difficulty,
            light_requirement=item["plant"].light_requirement,
            score=round(item["score"], 1),
            reasons=item["reasons"]
        ) for item in top_plants
    ]


# --- [신규] 머신러닝 기반 추천 API ---
@router.post("/ml", response_model=List[schemas.RecommendItem], summary="[신규] AI 클러스터링 기반 추천")
def recommend_plants_with_ml(
    request: schemas.SurveyRecommendRequest,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    ### ML 클러스터링 기반 맞춤 식물 추천
    - **설명**: 사용자의 설문을 바탕으로, AI가 가장 유사한 식물 그룹을 찾아 추천합니다.
    - **인증**: 필수
    """
    if not all([ml_model, ml_encoder, cluster_map]):
        raise HTTPException(status_code=503, detail="ML 추천 기능이 현재 비활성화 상태입니다.")

    # 1. 사용자 설문 답변을 숫자 데이터로 변환 준비
    target_light = _normalize_sunlight(request.sunlight)
    exp_diff = _normalize_experience_to_diff(request.experience)
    target_diff = request.desired_difficulty if request.desired_difficulty in ["상", "중", "하"] else exp_diff
    
    user_input = pd.DataFrame([{'difficulty': target_diff, 'light_requirement': target_light}])

    # 2. '번역기(Encoder)'로 사용자 입력을 숫자(One-Hot) 벡터로 변환
    user_encoded = ml_encoder.transform(user_input)
    
    # 3. 반려동물 안전 정보(0 또는 1)를 추가하여 최종 사용자 특성 벡터 생성
    user_features = list(user_encoded[0]) + [1 if request.has_pets else 0]

    # 4. 'AI 모델'로 사용자가 어떤 그룹(클러스터)에 속하는지 예측
    predicted_cluster = ml_model.predict([user_features])[0]
    
    # 5. 예측된 그룹에 속한 식물 ID 목록을 맵에서 조회
    recommended_ids = cluster_map.get(str(predicted_cluster), [])
    if not recommended_ids:
        raise HTTPException(status_code=404, detail="추천할 식물을 찾지 못했습니다.")

    # 6. ID 목록으로 DB에서 실제 식물 상세 정보 조회
    recommended_plants = db.query(models.PlantMaster).filter(models.PlantMaster.id.in_(recommended_ids)).limit(request.limit).all()

    # 7. 최종 응답 형태로 변환하여 반환
    return [
        schemas.RecommendItem(
            id=plant.id,
            name_ko=plant.name_ko,
            image_url=plant.image_url,
            difficulty=plant.difficulty,
            light_requirement=plant.light_requirement,
            score=10.0,
            reasons=[f"AI가 당신의 취향과 가장 잘 맞는 식물 그룹으로 추천했어요."]
        ) for plant in recommended_plants
    ]