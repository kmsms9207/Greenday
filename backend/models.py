from datetime import datetime
from sqlalchemy import Column, Integer, String, Boolean, TIMESTAMP, ForeignKey, func
from sqlalchemy.orm import relationship
from database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), nullable=False, unique=True, index=True)
    email = Column(String(100), nullable=False, unique=True, index=True)
    name = Column(String(50), nullable=False)
    # 수정: password -> hashed_password
    hashed_password = Column(String(255), nullable=False)
    created_at = Column(TIMESTAMP, server_default=func.now())
    is_verified = Column(Boolean, default=False)

    # 1:N 관계 (User → Plant)
    plants = relationship(
        "Plant",
        back_populates="owner",
        cascade="all, delete-orphan"
    )


class Plant(Base):
    __tablename__ = "plants"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)  # 식물 고유 번호
    name = Column(String(100), nullable=False)                               # 식물 애칭 (예: "몬순이")
    species = Column(String(150), nullable=False)                            # 식물 종류 (예: "몬스테라 델리시오사")
    image_url = Column(String(255), nullable=True)                           # 식물 사진 URL
    created_at = Column(TIMESTAMP, server_default=func.now())                # 등록일

    # 외래 키: 이 식물의 주인 (users.id 참조)
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    # 역방향 관계 (Plant → User)
    owner = relationship("User", back_populates="plants")