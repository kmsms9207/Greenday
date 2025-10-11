import os
import httpx
import json
import re
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

import schemas
import crud
import models
from core.config import settings # ⭐️ .env 설정을 중앙에서 관리

# ------------------------- HTTP 유틸 (mvp_importer.py에서 재사용) -------------------------
def http_get_json(url: str, params: dict = None) -> dict:
    with httpx.Client(timeout=30.0, headers={"User-Agent": "GreenDay/1.0"}) as client:
        try:
            r = client.get(url, params=params or {})
            r.raise_for_status()
            return r.json()
        except httpx.HTTPStatusError as e:
            raise HTTPException(
                status_code=e.response.status_code,
                detail=f"External API failed: {e.response.text}"
            )

def http_post_json(url: str, json_body: dict, headers: dict) -> dict:
    with httpx.Client(timeout=60.0, headers=headers) as client:
        try:
            r = client.post(url, json=json_body)
            r.raise_for_status()
            return r.json()
        except httpx.HTTPStatusError as e:
            raise HTTPException(
                status_code=e.response.status_code,
                detail=f"External API failed: {e.response.text}"
            )

# ------------------------- Perenual API (mvp_importer.py에서 재사용 및 수정) -------------------------
def perenual_get_supplementary_data(scientific_name: str) -> dict:
    """Perenual에서 보조 정보(image_url, 영문명)만 가져옵니다."""
    if not settings.PERENUAL_API_KEY:
        return {} # API 키가 없으면 빈 dict 반환
    try:
        params = {"key": settings.PERENUAL_API_KEY, "q": scientific_name}
        data = http_get_json("https://perenual.com/api/v2/species-list", params=params)
        
        result = data.get("data", [])
        if not result:
            return {}
        
        plant = result[0]
        image_data = plant.get("default_image", {}) or {}
        return {
            "image_url": image_data.get("regular_url") or image_data.get("original_url"),
            "name_en": plant.get("common_name"),
        }
    except Exception:
        # Perenual API 오류가 발생해도 핵심 기능은 동작해야 하므로, 오류를 로깅하고 무시
        # logger.warning(...) # TODO: 로깅 추가
        return {}

# ------------------------- LLM(Clova) API (mvp_importer.py에서 재사용 및 수정) -------------------------
def generate_one_liner_ko(data: dict) -> str:
    """Clova X를 이용해 식물의 한 줄 설명을 생성합니다."""
    prompt_data = {
        "이름": data.get('name_ko'),
        "난이도": data.get('difficulty'),
        "햇빛": data.get('light_requirement'),
        "물주기": data.get('watering_type'),
    }
    
    # Clova API가 없거나 실패할 경우를 대비한 기본 템플릿
    fallback_tmpl = f"{prompt_data['이름']}은(는) 난이도 '{prompt_data['난이도']}'의 식물로, {prompt_data['햇빛']} 환경을 선호합니다."

    if not all([settings.CLOVA_API_URL, settings.CLOVA_BEARER, settings.CLOVA_REQUEST_ID]):
        return fallback_tmpl
        
    try:
        headers = {
            "Authorization": f"Bearer {settings.CLOVA_BEARER}",
            "X-NCP-CLOVASTUDIO-REQUEST-ID": settings.CLOVA_REQUEST_ID,
            "Content-Type": "application/json"
        }
        prompt = f"다음 식물 데이터를 바탕으로, 초보자도 이해하기 쉬운 한국어 한 줄 설명을 100자 이내로 만들어줘.\n\n데이터: {json.dumps(prompt_data, ensure_ascii=False)}"
        body = {"messages": [{"role": "user", "content": prompt}], "maxTokens": 120, "temperature": 0.5}
        
        res = http_post_json(settings.CLOVA_API_URL, body, headers)
        content = res.get("result", {}).get("message", {}).get("content", fallback_tmpl)
        return re.sub(r'\s+', ' ', content).strip()
    except Exception:
        # logger.warning(...) # TODO: 로깅 추가
        return fallback_tmpl

# ------------------------- ⭐️ 메인 서비스 함수 (Chef's Logic) -------------------------
def enrich_and_create_plant(db: Session, request_data: schemas.PlantCreateRequest) -> models.PlantMaster:
    """
    관리자 요청 데이터를 받아 외부 API로 강화하고 DB에 최종 저장하는 메인 함수
    """
    # 1. Perenual API로 보조 정보(이미지 등) 가져오기
    supplementary_data = perenual_get_supplementary_data(request_data.species)

    # 2. 관리자 입력 데이터와 외부 API 데이터 조합
    final_data = request_data.model_dump()
    final_data["image_url"] = supplementary_data.get("image_url")
    final_data["name_en"] = supplementary_data.get("name_en")

    # 3. Clova X로 설명 생성
    final_data["description"] = generate_one_liner_ko(final_data)

    # 4. 최종 데이터를 PlantMaster DB 모델 객체로 변환
    new_plant_obj = models.PlantMaster(**final_data)

    # 5. CRUD 함수를 호출하여 DB에 저장
    return crud.create_master_plant(db=db, plant=new_plant_obj)