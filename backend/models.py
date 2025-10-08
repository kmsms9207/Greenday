from datetime import datetime
from sqlalchemy import (
    Column, Integer, String, Boolean, TIMESTAMP, ForeignKey, func,
    Text, Enum, JSON, BigInteger, DateTime, Index, Numeric
)
from sqlalchemy.dialects.mysql import LONGBLOB, MEDIUMBLOB
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.mysql import BIGINT as MYSQL_BIGINT
from database import Base

# User
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), nullable=False, unique=True, index=True)
    email = Column(String(100), nullable=False, unique=True, index=True)
    name = Column(String(50), nullable=False)
    hashed_password = Column(String(255), nullable=False)
    created_at = Column(TIMESTAMP, server_default=func.now())
    is_verified = Column(Boolean, default=False)
    plants = relationship("Plant", back_populates="owner", cascade="all, delete-orphan")

# Plant
class Plant(Base):
    __tablename__ = "plants"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    name = Column(String(100), nullable=False)
    species = Column(String(150), nullable=False)
    image_url = Column(String(255), nullable=True)
    created_at = Column(TIMESTAMP, server_default=func.now())
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    owner = relationship("User", back_populates="plants")

# PlantMaster 
class PlantMaster(Base):
    __tablename__ = "plants_master"

    id = Column(Integer, primary_key=True)
    name_ko = Column(String(150), nullable=False)
    name_en = Column(String(150), nullable=True)
    species = Column(String(190), nullable=False, unique=True)
    family = Column(String(120), nullable=True)
    image_url = Column(String(1024), nullable=True)
    description = Column(Text, nullable=True)
    difficulty = Column(Enum('상', '중', '하', name='difficulty_enum'), nullable=False)
    light_requirement = Column(Enum('음지', '반음지', '양지', name='lightreq_enum'), nullable=False)

    # [수정] 물주기 관련 컬럼 보강
    watering_type = Column(String(50), nullable=True) # 예: "자주", "보통", "적게"
    
    pet_safe = Column(Boolean, nullable=True)
    tags = Column(JSON, nullable=True)
    created_at = Column(TIMESTAMP, server_default=func.now())


class ImageAsset(Base):
    __tablename__ = "image_assets"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    # ▼ INT로 변경 (users.id와 동일)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    image_hash = Column(MYSQL_BIGINT(unsigned=True), index=True, nullable=False)
    mime = Column(String(64))
    width = Column(Integer)
    height = Column(Integer)
    bytes = Column(Integer)
    original = Column(LONGBLOB)    # ← 원본은 LONGBLOB
    thumb    = Column(MEDIUMBLOB)  # ← 썸네일은 MEDIUMBLOB
    created_at = Column(DateTime, server_default=func.now(), nullable=False)

    user = relationship("User", backref="image_assets")

    __table_args__ = (
        Index("idx_image_assets_user_hash", "user_id", "image_hash"),
        Index("idx_image_assets_created", "created_at"),
    )


class Diagnosis(Base):
    __tablename__ = "diagnoses"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    # ▼ INT로 변경 (users.id와 동일)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    image_hash = Column(BigInteger, index=True, nullable=False)
    image_url = Column(String(512))
    thumb_url = Column(String(512))
    width = Column(Integer)
    height = Column(Integer)
    bytes = Column(Integer)
    mime = Column(String(64))

    disease_key = Column(String(64), nullable=False)
    disease_ko  = Column(String(64), nullable=False)
    score = Column(Numeric(6, 4), nullable=False)
    severity = Column(Enum("LOW", "MEDIUM", "HIGH", name="severity_enum"), nullable=False)
    mode = Column(String(32), nullable=False, default="disease_only")
    reason_ko = Column(Text, nullable=True)  # ← 길이 없는 VARCHAR 대신 Text

    source = Column(Enum("hf", "llm", "ensemble", "disease_only", name="source_enum"),
                    nullable=False, default="disease_only")
    tta_used = Column(Boolean, nullable=False, default=False)
    preprocess_used = Column(Boolean, nullable=False, default=True)
    models = Column(JSON)
    clip_model = Column(String(128))
    thresholds = Column(JSON)
    per_model = Column(JSON)
    clip_votes = Column(JSON)

    created_at = Column(DateTime, server_default=func.now(), nullable=False)

    user = relationship("User", backref="diagnoses")

    __table_args__ = (
        Index("idx_diagnoses_user_created", "user_id", "created_at"),
        Index("idx_diagnoses_img_hash", "image_hash"),
        Index("idx_diagnoses_disease", "disease_key"),
    )