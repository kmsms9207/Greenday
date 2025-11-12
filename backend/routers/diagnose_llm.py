# routers/diagnose_llm.py

from __future__ import annotations
import logging
import re
from typing import Dict, Any

from fastapi import APIRouter, Depends, HTTPException, Path
from sqlalchemy.orm import Session

import models
import crud
import schemas
from database import get_db
from dependencies import get_current_user
from core import config
from services.remedy import get_remedy
from services import openai_chat, media as media_service, remedy as remedy_service

logger = logging.getLogger(__name__)

router = APIRouter(
    tags=["AI Diagnosis v3 (LLM)"],
    dependencies=[Depends(get_current_user)]
)

# ---------------------------
# 유효성 검사 유틸
# ---------------------------
_VALID_MEDIA_RE = re.compile(r"^/media/\d+/(orig|thumb)$")

def _is_valid_image_url(u: str) -> bool:
    if not u or u == "string":
        return False
    if u.startswith("data:"):
        return True
    if u.startswith("http://") or u.startswith("https://"):
        return True
    return _VALID_MEDIA_RE.match(u) is not None


# ---------------------------
# 내부 Vision 호출 유틸
# ---------------------------
async def _call_vision_api(
    settings: config.Settings,
    image_url: str,
    prompt_key: str
) -> Dict[str, Any]:
    """
    image_url -> data URI 변환 후 GPT Vision 호출.
    응답 JSON은 remedy_service.parse_llm_diagnosis_result로 표준화.
    """
    data_uri = await media_service.get_image_data_uri(image_url, settings=settings)
    if not data_uri:
        raise HTTPException(
            status_code=400,
            detail="image_url을 읽어올 수 없습니다. /media/{id}/orig 또는 http(s) URL을 사용해 주세요."
        )

    # ✅ 프롬프트 강화: JSON만, 라벨 집합 중 하나를 선택(unknown 남발 억제)
    messages_base = {
        "default": [
            {
                "role": "system",
                "content": (
                    "You are a plant disease assistant. "
                    "반드시 한국어 JSON만 반환하세요(마크다운/설명/코드블록 금지). "
                    '스키마: {"disease_key": string, "disease_ko": string, '
                    '"reason_ko": string, "score": number, "severity": "LOW"|"MEDIUM"|"HIGH"}. '
                    "disease_key는 아래 집합 중 가장 근접한 하나를 고르세요(모호해도 가장 가까운 것을 선택): "
                    "powdery_mildew, downy_mildew, leaf_spot, anthracnose, bacterial_leaf_spot, rust, "
                    "early_blight, late_blight, botrytis, sooty_mold, chlorosis, leaf_scorch, edema, root_rot, "
                    "overwatering_damage, underwatering_damage, sunburn, spider_mites, mealybugs, scale_insects, "
                    "aphids, thrips, whiteflies, leaf_miner, virus_mosaic. "
                    '정말 분류 불가일 때만 disease_key를 "unknown"으로 하되 score는 0.2 미만으로 하세요.'
                ),
            },
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": (
                            "이 식물 잎의 문제(병해충/생리장해)를 추정하고, "
                            "근거를 reason_ko에 간단히, 자신있는 정도를 0~1 사이 score로, "
                            "심각도를 LOW/MEDIUM/HIGH 중 하나로 판단해 주세요."
                        )
                    },
                    {"type": "image_url", "image_url": {"url": data_uri}},
                ],
            },
        ],
    }

    messages = messages_base.get(prompt_key, messages_base["default"])

    try:
        response_json = await openai_chat.get_openai_vision_response(
            settings=settings,
            messages=messages,
            max_tokens=600,
        )
        return remedy_service.parse_llm_diagnosis_result(response_json)
    except Exception as e:
        logger.error(f"GPT Vision API 호출 실패: {e}")
        raise HTTPException(status_code=502, detail=f"AI 서버 통신 오류: {e}")


# ---------------------------
# 라우터
# ---------------------------
@router.post(
    "/plants/{plant_id}/diagnose-llm",
    response_model=schemas.DiagnosisLLMResponse
)
async def diagnose_by_llm_for_plant(
    request: schemas.DiagnosisLLMRequest,
    plant_id: int = Path(..., description="진단할 식물의 ID"),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """
    ### LLM 기반 병해충 진단 (일지 기록 연동)
    - 1단계: `/media/upload`로 이미지 URL을 받습니다.
    - 2단계: 이 API로 image_url을 보내 진단을 요청하면, 진단 결과가 **성장 일지에 자동으로 기록**됩니다.
    """
    # 0) image_url 유효성 검사 (Swagger "string" 실수 방지)
    if not _is_valid_image_url(request.image_url):
        raise HTTPException(
            status_code=400,
            detail=(
                "image_url이 유효하지 않습니다. "
                "/media/{id}/orig 또는 /media/{id}/thumb, 혹은 http(s) URL을 입력하세요. "
                "예: /media/123/orig (먼저 /media/upload 응답의 image_url을 사용)"
            ),
        )

    # 1) 식물 소유권 확인
    plant = crud.get_plant_by_id(db, plant_id=plant_id)
    if not plant or plant.owner_id != current_user.id:
        raise HTTPException(status_code=404, detail="식물을 찾을 수 없거나 소유자가 아닙니다.")

    # 2) AI 진단 호출
    diagnosis_result = await _call_vision_api(
        settings=config.settings,
        image_url=request.image_url,
        prompt_key=request.prompt_key
    )

    # 3) '성장 일지' 자동 기록 (정상 진단인 경우에만)
    if diagnosis_result.get("disease_key") != "unknown":
        try:
            crud.create_diary_log(
                db=db,
                plant_id=plant_id,
                log_type="DIAGNOSIS",
                log_message=f"[{diagnosis_result.get('disease_ko', '진단')}] 진단을 받았습니다.",
            )
        except Exception as e:
            logger.error(f"Diary 로그 기록 실패 (Plant ID: {plant_id}): {e}")

    # ✅ 4) 해결 가이드 자동 생성 (remedy.py 이용)
    guide = get_remedy(
        disease_key=diagnosis_result["disease_key"],
        disease_ko_hint=diagnosis_result.get("disease_ko"),
        severity_hint=diagnosis_result.get("severity"),
        score=diagnosis_result.get("score"),
        plant_name=getattr(plant, "name", None),
    )
    diagnosis_result["guide"] = guide

    # ✅ 5) 결과 반환 (schemas.DiagnosisLLMResponse에 guide 포함됨)
    return schemas.DiagnosisLLMResponse(**diagnosis_result)
