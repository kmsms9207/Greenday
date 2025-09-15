from pydantic import BaseModel, EmailStr
from datetime import datetime 

# --- User Schemas ---
class UserBase(BaseModel):
    email: EmailStr
    username: str
    name: str

class UserCreate(UserBase):
    password: str

class UserInfo(UserBase):
    id: int
    model_config = ConfigDict(from_attributes=True)

# --- Auth Schemas ---
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
    species: str
    image_url: Optional[str] = None

class PlantCreate(PlantBase):
    pass

class Plant(PlantBase):
    id: int
    owner_id: int
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

# --- Recommendation Schemas ---

# 추천 요청 시 프론트엔드로부터 받을 설문 데이터 양식
class SurveyRecommendRequest(BaseModel):
    place: str
    sunlight: str
    water_cycle: Optional[str] = None
    experience: str
    has_pets: bool = False
    desired_difficulty: Optional[str] = None
    limit: int = 10

# 추천 결과로 프론트엔드에 보내줄 개별 식물 데이터 양식
class RecommendItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name_ko: str
    image_url: Optional[str] = None
    difficulty: str
    light_requirement: str
    # 추천 점수와 이유를 함께 보내 UX를 개선합니다.
    score: float
    reasons: List[str] = []
