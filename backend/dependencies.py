# 역할: 여러 파일에서 공통으로 사용하는 의존성 함수를 관리합니다.
# 경로: backend/dependencies.py
# =====================================================================================
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

import crud, database, models
from core import security

# tokenUrl은 실제 토큰을 발급해주는 API의 주소를 가리킵니다.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(database.get_db)):
    """
    요청 헤더의 토큰을 검증하고, 유효하다면 현재 로그인된 사용자 정보를 반환합니다.
    이 함수를 통과하지 못하면 API가 실행되지 않습니다.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    email = security.verify_token(token)
    if email is None:
        raise credentials_exception
    user = crud.get_user_by_email(db, email=email)
    if user is None:
        raise credentials_exception
    return user
