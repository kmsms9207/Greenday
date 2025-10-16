from pydantic import BaseModel, EmailStr, ConfigDict
from datetime import datetime
from typing import Optional, List

# --- User Schemas ---

class UserCreate(BaseModel):
    email: EmailStr
    username: str
    name: str
    password: str

class UserInfo(BaseModel):
    id: int
    email: EmailStr
    username: str
    name: str
    model_config = ConfigDict(from_attributes=True)

class Token(BaseModel):
    access_token: str
    token_type: str

class EmailVerification(BaseModel):
    token: str

class ForgotPasswordRequest(BaseModel):
    email: EmailStr

class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str

# --- Plant Schemas ---

class PlantBase(BaseModel):
    name: str
    

class PlantCreate(PlantBase):
    plant_master_id: int # 백과사전에서 선택한 식물의 고유 ID

class Plant(PlantBase):
    id: int
    owner_id: int
    created_at: datetime
    name: str
    species: str # DB에는 학명이 저장되므로, 응답 시에는 포함됩니다.
    master_image_url: Optional[str] = None
    model_config = ConfigDict(from_attributes=True)

# --- Recommendation Schemas ---

# 추천 요청 시 프론트엔드로부터 받을 설문 데이터 양식
class SurveyRecommendRequest(BaseModel):
    place: str
    sunlight: str
    experience: str
    has_pets: bool = False
    desired_difficulty: Optional[str] = None
    limit: int = 10

# 추천 결과로 프론트엔드에 보내줄 개별 식물 데이터 양식
class RecommendItem(BaseModel):
    id: int
    name_ko: str
    image_url: Optional[str] = None
    difficulty: str
    light_requirement: str
    # 추천 점수와 이유를 함께 보내 UX를 개선합니다.
    score: float
    reasons: List[str] = []
    model_config = ConfigDict(from_attributes=True)

# --- Encyclopedia Schemas ---

class PlantMasterInfo(BaseModel):
    id: int
    name_ko: str
    name_en: Optional[str] = None
    species: str
    family: Optional[str] = None
    image_url: Optional[str] = None
    description: Optional[str] = None
    difficulty: str
    light_requirement: str
    watering_type: Optional[str] = None
    pet_safe: Optional[bool] = None
    tags: Optional[List] = None # JSON 필드는 보통 List나 Dict로 받습니다.
    model_config = ConfigDict(from_attributes=True)

# ⭐️ 관리자용 스키마
class PlantCreateRequest(BaseModel):
    species: str
    name_ko: str
    difficulty: str
    light_requirement: str
    watering_type: str
    pet_safe: bool
    family: Optional[str] = None


# AI 진단 응답 스키마
class DiagnosisResult(BaseModel):
    label: str # 예: 'Tomato___Late_blight'
    score: float # 0.0 ~ 1.0

      # 추가: 분리/한글 매핑
    plant: str            # 예: "Potato"
    disease: str          # 예: "Early_Blight"
    plant_ko: str         # 예: "감자"
    disease_ko: str       # 예: "겹무늬병"
    label_ko: str         # 예: "감자 겹무늬병" 또는 "감자 정상"

class RemedyRequest(BaseModel):
    disease_key: str              # 예: "powdery_mildew"
    severity: Optional[str] = None  # "LOW" | "MEDIUM" | "HIGH" (없으면 자동 판단)
    plant_name: Optional[str] = None  # 식물명(선택)

class RemedyAdvice(BaseModel):
    disease_key: str
    disease_ko: str
    title_ko: str
    severity: str                  # 최종 판단된 심각도
    summary_ko: str
    immediate_actions: List[str]   # 바로 할 일(오늘)
    care_plan: List[str]           # 1~2주 관리 플랜
    prevention: List[str]          # 재발 방지
    caution: List[str]             # 주의사항(애완동물/약제 등)
    when_to_call_pro: List[str]    # 폐기/전문가 문의 기준

class ChatMessageOut(BaseModel):
    id: int
    thread_id: int
    role: str
    content: str
    image_url: Optional[str] = None
    provider_resp: Optional[dict] = None  # JSON이라면 dict
    tokens_in: Optional[int] = None
    tokens_out: Optional[int] = None
    created_at: datetime   # ← str → datetime 로 변경
    model_config = ConfigDict(from_attributes=True)

class ChatSendRequest(BaseModel):
    thread_id: Optional[int] = None
    message: str
    image_url: Optional[str] = None  # 이미지 프롬프트가 있으면 사용

class ChatSendResponse(BaseModel):
    thread_id: int
    assistant: ChatMessageOut

# --- Push Notification Schemas ---
class PushTokenUpdateRequest(BaseModel):
    push_token: str