from datetime import datetime
from sqlalchemy import (
    Column, Integer, String, Boolean, TIMESTAMP, ForeignKey, func,
    Text, Enum, JSON
)
from sqlalchemy.orm import relationship, Mapped, mapped_column
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

    # --- [추가] 추천용 마스터 식물 데이터 테이블 ---
# 이 테이블에는 우리가 사용자에게 추천해줄 모든 식물의 정보가 미리 저장됩니다.
class PlantMaster(Base):
    __tablename__ = "plants_master"

    id = Column(Integer, primary_key=True)
    name_ko = Column(String(150), nullable=False)
    name_en = Column(String(150), nullable=True)
    species = Column(String(190), nullable=False, unique=True)
    family = Column(String(120), nullable=True)
    image_url = Column(String(1024), nullable=True)
    description: Mapped[str | None] = mapped_column(Text) 
    difficulty = Column(Enum('상', '중', '하', name='difficulty_enum'), nullable=False, default='중')
    light_requirement = Column(Enum('음지', '반음지', '양지', name='lightreq_enum'), nullable=False, default='반음지')
    water_cycle_text: Mapped[str | None] = mapped_column(Text)   
    water_interval_days = Column(Integer, nullable=True)
    pet_safe = Column(Boolean, nullable=True)
    tags = Column(JSON, nullable=True)
    created_at = Column(TIMESTAMP, server_default=func.now())