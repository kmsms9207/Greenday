from pydantic import BaseModel, EmailStr

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