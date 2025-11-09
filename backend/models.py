from datetime import datetime
from sqlalchemy import (
    Column, Integer, String, Boolean, TIMESTAMP, ForeignKey, func,
    Text, Enum, JSON, BigInteger, DateTime, Index, Numeric, Date
)
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.mysql import LONGBLOB, MEDIUMBLOB, BIGINT as MYSQL_BIGINT
from database import Base

# ==============================================================================
# User & Plant Models
# ==============================================================================

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), nullable=False, unique=True, index=True)
    email = Column(String(100), nullable=False, unique=True, index=True)
    name = Column(String(50), nullable=False)
    hashed_password = Column(String(255), nullable=False)
    created_at = Column(TIMESTAMP, server_default=func.now())
    is_verified = Column(Boolean, default=False)
    verification_code = Column(String(6), nullable=True) # 6자리 인증번호 저장
    verification_expires_at = Column(DateTime(timezone=True), nullable=True) # 인증번호 만료 시간
    push_token = Column(String(255), nullable=True, unique=True)
    plants = relationship("Plant", back_populates="owner", cascade="all, delete-orphan")
    image_assets = relationship("ImageAsset", back_populates="user")
    diagnoses = relationship("Diagnosis", back_populates="user")

class Plant(Base):
    __tablename__ = "plants"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    name = Column(String(100), nullable=False)
    species = Column(String(150), nullable=False)
    image_url = Column(String(255), nullable=True)
    created_at = Column(TIMESTAMP, server_default=func.now())
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    plant_master_id = Column(Integer, ForeignKey("plants_master.id"), nullable=False)
    owner = relationship("User", back_populates="plants")
    master_info = relationship("PlantMaster")
    # --- ⬇️ 물주기 알림 기능  ⬇️ ---
    last_watered_at = Column(DateTime(timezone=True), nullable=True, server_default=func.now())
    is_notification_enabled = Column(Boolean, nullable=False, default=True)
    notification_time = Column(String(5), nullable=True, default="09:00")
    notification_snoozed_until = Column(Date, nullable=True)

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
    watering_type = Column(String(50), nullable=True)
    pet_safe = Column(Boolean, nullable=True)
    tags = Column(JSON, nullable=True)
    created_at = Column(TIMESTAMP, server_default=func.now())

# ==============================================================================
# Asset & Diagnosis Models
# ==============================================================================

class ImageAsset(Base):
    __tablename__ = "image_assets"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    image_hash = Column(MYSQL_BIGINT(unsigned=True), index=True, nullable=False)
    mime = Column(String(64))
    width = Column(Integer)
    height = Column(Integer)
    bytes = Column(Integer)
    original = Column(LONGBLOB)
    thumb = Column(MEDIUMBLOB)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)

    user = relationship("User", back_populates="image_assets")

    __table_args__ = (
        Index("idx_image_assets_user_hash", "user_id", "image_hash"),
        Index("idx_image_assets_created", "created_at"),
    )

class Diagnosis(Base):
    __tablename__ = "diagnoses"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    image_hash = Column(MYSQL_BIGINT(unsigned=True), index=True, nullable=False)
    image_url = Column(String(512))
    thumb_url = Column(String(512))
    width = Column(Integer)
    height = Column(Integer)
    bytes = Column(Integer)
    mime = Column(String(64))
    disease_key = Column(String(64), nullable=False)
    disease_ko = Column(String(64), nullable=False)
    score = Column(Numeric(6, 4), nullable=False)
    severity = Column(Enum("LOW", "MEDIUM", "HIGH", name="severity_enum"), nullable=False)
    mode = Column(String(32), nullable=False, default="disease_only")
    reason_ko = Column(Text, nullable=True)
    source = Column(Enum("hf", "llm", "ensemble", "disease_only", name="source_enum"),
                      nullable=False, default="disease_only")
    tta_used = Column(Boolean, nullable=False, default=False)
    preprocess_used = Column(Boolean, nullable=False, default=True)
    models = Column(JSON)
    clip_model = Column(String(128))
    thresholds = Column(JSON)
    per_model = Column(JSON)
    clip_votes = Column(JSON)
    remedy_ko = Column(Text, nullable=True)
    remedy_source = Column(Enum("kb", "llm", "mixed", name="remedy_source_enum"), nullable=True)
    remedy_meta = Column(JSON, nullable=True)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)

    user = relationship("User", back_populates="diagnoses")

    __table_args__ = (
        Index("idx_diagnoses_user_created", "user_id", "created_at"),
        Index("idx_diagnoses_img_hash", "image_hash"),
        Index("idx_diagnoses_disease", "disease_key"),
    )

# ==============================================================================
# Chat Models
# ==============================================================================

class ChatThread(Base):
    __tablename__ = "chat_threads"
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    title = Column(String(120), nullable=True)
    # ★ 기본값 추가(없어서 1364 에러 발생했었음)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now(), nullable=False)

class ChatMessage(Base):
    __tablename__ = "chat_messages"
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    thread_id = Column(BigInteger, ForeignKey("chat_threads.id"), nullable=False, index=True)
    role = Column(Enum("system","user","assistant", name="chat_role"), nullable=False)
    content = Column(Text, nullable=False)
    image_url = Column(String(512), nullable=True)
    provider_resp = Column(JSON, nullable=True)
    tokens_in = Column(Integer, nullable=True)
    tokens_out = Column(Integer, nullable=True)
    # ★ 기본값 추가(없어서 1364 에러 발생했었음)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)

class DiaryPost(Base):
    __tablename__ = "diary_posts"

    id = Column(Integer, primary_key=True)
    owner_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)

    title = Column(String(120), nullable=False)
    body  = Column(Text, nullable=False)

    created_at = Column(DateTime, server_default=func.now(), index=True)
    updated_at = Column(DateTime, onupdate=func.now())

    media = relationship("DiaryMedia", back_populates="post", cascade="all, delete-orphan", order_by="DiaryMedia.order")

class DiaryMedia(Base):
    __tablename__ = "diary_media"

    id = Column(Integer, primary_key=True)
    post_id = Column(Integer, ForeignKey("diary_posts.id", ondelete="CASCADE"), index=True, nullable=False)
    url = Column(String(512), nullable=False)        # 최종 접근 URL
    thumb_url = Column(String(512), nullable=True)   # 썸네일(없으면 url 사용)
    width = Column(Integer)
    height = Column(Integer)
    order = Column(Integer, default=0)               # 표시 순서

    post = relationship("DiaryPost", back_populates="media")

# ==============================================================================
# Community Models (게시판 기능)
# ==============================================================================

class Post(Base):
    __tablename__ = "posts"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(200), nullable=False, index=True) # 검색을 위해 title에도 index 추가
    content = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    owner_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    # Post 객체에서 .owner로 작성자 User 정보 접근
    owner = relationship("User") 
    # Post 객체에서 .comments로 댓글 목록 접근 (게시글 삭제 시 댓글도 자동 삭제)
    comments = relationship("Comment", back_populates="post", cascade="all, delete-orphan")

class Comment(Base):
    __tablename__ = "comments"

    id = Column(Integer, primary_key=True, index=True)
    content = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    owner_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    post_id = Column(Integer, ForeignKey("posts.id", ondelete="CASCADE"), nullable=False)
    
    # Comment 객체에서 .owner로 작성자 User 정보 접근
    owner = relationship("User")
    # Comment 객체에서 .post로 부모 Post 정보 접근
    post = relationship("Post", back_populates="comments")