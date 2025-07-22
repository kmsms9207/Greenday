from sqlalchemy import Column, Integer, String, TIMESTAMP, func
from .database import Base

class User(Base):
    __tablename__ = "users"  # ← tablename → __tablename__ (언더스코어 두 개)

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    username = Column(String(50), nullable=False, unique=True)
    email = Column(String(100), nullable=False, unique=True, index=True)
    password = Column(String(100), nullable=False)  # 원본은 password 컬럼
    created_at = Column(TIMESTAMP, server_default=func.now())
