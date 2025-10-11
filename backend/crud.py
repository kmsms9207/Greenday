from typing import Optional, List
from sqlalchemy.orm import Session
import models, schemas
from core.security import get_password_hash

# --- User CRUD ---

def get_user_by_email(db: Session, email: str):
    return db.query(models.User).filter(models.User.email == email).first()

def get_user_by_username(db: Session, username: str):
    return db.query(models.User).filter(models.User.username == username).first()

def create_user(db: Session, user: schemas.UserCreate):
    hashed_password = get_password_hash(user.password)
    db_user = models.User(
        email=user.email,
        username=user.username,
        name=user.name,
        hashed_password=hashed_password
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def verify_user_email(db: Session, email: str):
    user = get_user_by_email(db, email)
    if user:
        user.is_verified = True
        db.commit()
        db.refresh(user)
    return user

def update_user_password(db: Session, email: str, new_password: str):
    user = get_user_by_email(db, email=email)
    if user:
        hashed_password = get_password_hash(new_password)
        user.hashed_password = hashed_password
        db.commit()
        db.refresh(user)
    return user

# --- Plant CRUD ---

def create_plant(db: Session, plant: schemas.PlantCreate, user_id: int) -> models.Plant:
    new_plant = models.Plant(
        name=plant.name,
        species=plant.species,
        image_url=plant.image_url,
        owner_id=user_id,
    )
    db.add(new_plant)
    db.commit()
    db.refresh(new_plant)
    return new_plant

def get_plants_by_owner(db: Session, user_id: int) -> List[models.Plant]:
    return db.query(models.Plant).filter(models.Plant.owner_id == user_id).order_by(models.Plant.id.desc()).all()

def get_plant_by_id(db: Session, plant_id: int) -> Optional[models.Plant]:
    return db.query(models.Plant).filter(models.Plant.id == plant_id).first()

def update_plant(db: Session, plant_id: int, plant_update_data: schemas.PlantCreate) -> Optional[models.Plant]:
    plant_obj = get_plant_by_id(db, plant_id)
    if not plant_obj:
        return None
    
    update_data = plant_update_data.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(plant_obj, key, value)

    db.add(plant_obj)
    db.commit()
    db.refresh(plant_obj)
    return plant_obj

def delete_plant(db: Session, plant_id: int) -> bool:
    plant_obj = get_plant_by_id(db, plant_id)
    if not plant_obj:
        return False
    db.delete(plant_obj)
    db.commit()
    return True

# --- [추가] PlantMaster CRUD ---

def get_master_plant_by_id(db: Session, plant_id: int):
    """PlantMaster 테이블에서 ID로 단일 식물 정보 조회"""
    return db.query(models.PlantMaster).filter(models.PlantMaster.id == plant_id).first()

def get_all_master_plants(
    db: Session, 
    skip: int = 0, 
    limit: int = 100, 
    has_pets: Optional[bool] = None
) -> List[models.PlantMaster]:
    """
    PlantMaster 테이블에서 모든 식물 목록 조회
    - skip, limit: 페이징
    - has_pets: None(모두), True(반려동물 안전한 것만), False(반려동물 위험한 것만)
    """
    query = db.query(models.PlantMaster)
    
    # 반려동물 필터링 (옵션)
    if has_pets is not None:
        query = query.filter(models.PlantMaster.pet_safe == has_pets)
    
    return query.offset(skip).limit(limit).all()

def search_master_plants(db: Session, q: str, skip: int = 0, limit: int = 100):
    """한국어 이름으로 PlantMaster 테이블에서 식물 검색"""
    return db.query(models.PlantMaster)\
             .filter(models.PlantMaster.name_ko.contains(q))\
             .offset(skip)\
             .limit(limit)\
             .all()

# ⭐️ (관리자용) PlantMaster 데이터 생성
def create_master_plant(db: Session, plant: models.PlantMaster) -> models.PlantMaster:
    """서비스 계층에서 완전히 조립된 PlantMaster 객체를 받아 DB에 저장합니다."""
    db.add(plant)
    db.commit()
    db.refresh(plant)
    return plant

# ⭐️ (관리자용) 종(species) 이름으로 중복 확인
def get_master_plant_by_species(db: Session, species: str) -> Optional[models.PlantMaster]:
    """종(species) 이름으로 PlantMaster 테이블에서 식물을 조회합니다."""
    return db.query(models.PlantMaster).filter(models.PlantMaster.species == species).first()

# ⭐️ 알람: '물 줬어요' 기능
def update_last_watered_at(db: Session, plant_id: int) -> models.Plant:
    plant = db.query(models.Plant).filter(models.Plant.id == plant_id).first()
    if plant:
        plant.last_watered_at = datetime.now(plant.created_at.tzinfo) # DB 타임존과 일치
        plant.notification_snoozed_until = None # 미루기 상태 초기화
        db.commit()
        db.refresh(plant)
    return plant

# ⭐️ 알람: '하루 미루기' 기능
def snooze_notification_for_plant(db: Session, plant_id: int) -> models.Plant:
    plant = db.query(models.Plant).filter(models.Plant.id == plant_id).first()
    if plant:
        plant.notification_snoozed_until = datetime.utcnow().date() + timedelta(days=1)
        db.commit()
        db.refresh(plant)
    return plant