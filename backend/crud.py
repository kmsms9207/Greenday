from sqlalchemy.orm import Session
from models import User
from schemas import UserCreate  # Pydantic 모델 (요청 데이터 형식에 따라 다를 수 있음)
from werkzeug.security import generate_password_hash

# 1. 이메일로 사용자 찾기
def get_user_by_email(db: Session, email: str):
    return db.query(User).filter(User.email == email).first()

# 2. 사용자 이름으로 사용자 찾기
def get_user_by_username(db: Session, username: str):
    return db.query(User).filter(User.username == username).first()

# 3. 사용자 생성
def create_user(db: Session, user: UserCreate):
    hashed_password = generate_password_hash(user.password)
    db_user = User(
        username=user.username,
        email=user.email,
        password=hashed_password,
        is_verified=False  # 기본값으로 이메일 인증은 False
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

# 4. 이메일 인증 처리
def verify_user_email(db: Session, email: str):
    user = db.query(User).filter(User.email == email).first()
    if user:
        user.is_verified = True
        db.commit()
        db.refresh(user)
    return user
