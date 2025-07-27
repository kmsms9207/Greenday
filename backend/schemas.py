from pydantic import BaseModel, EmailStr

# --- 유저 관련 ---
class UserCreate(BaseModel):
    email: EmailStr
    username: str
    name: str
    password: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

# --- 토큰 관련 ---
class Token(BaseModel):
    accessToken: str

class EmailVerification(BaseModel):
    token: str