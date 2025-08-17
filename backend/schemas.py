from pydantic import BaseModel, EmailStr
from datetime import datetime 

class UserCreate(BaseModel):
    email: EmailStr
    username: str
    name: str
    password: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class Token(BaseModel):
    accessToken: str

class EmailVerification(BaseModel):
    token: str

# --- 내 정보 조회를 위한 응답 모델 추가 ---
class UserInfo(BaseModel):
    id: int
    email: EmailStr
    username: str
    name: str

    # 이 설정은 SQLAlchemy 모델 객체를 Pydantic 모델로 변환할 수 있게 해줍니다.
    class Config:
        from_attributes = True

# --- Plant 관련 스키마 ---

# Plant의 기본 데이터 형식
class PlantBase(BaseModel):
    name: str
    species: str
    image_url: str | None = None # 선택적 필드로 변경

# 새 식물을 등록할 때 받는 데이터 형식
class PlantCreate(PlantBase):
    pass

# DB에서 식물 정보를 읽어올 때 사용하는 기본 형식
class Plant(PlantBase):
    id: int
    owner_id: int
    created_at: datetime

    # SQLAlchemy 모델 객체를 Pydantic 모델로 변환할 수 있게 해줌
    class Config:
        from_attributes = True