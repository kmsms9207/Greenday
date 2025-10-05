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

# --- [추가] Recommendation CRUD ---

def get_all_master_plants(db: Session, has_pets: bool = False) -> List[models.PlantMaster]:
    """
    추천 대상이 되는 모든 마스터 식물 데이터를 조회합니다.
    - has_pets: True일 경우, 반려동물에게 안전한 식물만 필터링합니다.
    """
    query = db.query(models.PlantMaster)
    if has_pets:
        # models.py의 PlantMaster에 pet_safe 컬럼이 True인 경우만 필터링
        query = query.filter(models.PlantMaster.pet_safe == True)
    return query.all()

# --- [추가] PlantMaster CRUD ---

def get_master_plant_by_id(db: Session, plant_id: int):
    """PlantMaster 테이블에서 ID로 단일 식물 정보 조회"""
    return db.query(models.PlantMaster).filter(models.PlantMaster.id == plant_id).first()

def get_all_master_plants(db: Session, skip: int = 0, limit: int = 100):
    """PlantMaster 테이블에서 모든 식물 목록 조회"""
    return db.query(models.PlantMaster).offset(skip).limit(limit).all()

def search_master_plants(db: Session, q: str, skip: int = 0, limit: int = 100):
    """한국어 이름으로 PlantMaster 테이블에서 식물 검색"""
    return db.query(models.PlantMaster)\
             .filter(models.PlantMaster.name_ko.contains(q))\
             .offset(skip)\
             .limit(limit)\
             .all()