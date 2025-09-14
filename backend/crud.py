from typing import Optional, List, Union, Dict, Any
from sqlalchemy.orm import Session
import models, schemas
from core.security import get_password_hash  # werkzeug 대신 passlib 사용


# =========================
# User CRUD
# =========================

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
        # 수정: password -> hashed_password
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

# =========================
# Plant CRUD
# =========================

# Pydantic 또는 dict를 모두 허용하기 위한 유틸
Payload = Union[Dict[str, Any], object]

def _get_attr_or_key(payload: Payload, key: str, default=None):
    if isinstance(payload, dict):
        return payload.get(key, default)
    return getattr(payload, key, default)


def create_plant(db: Session, plant: Payload, user_id: int) -> models.Plant:
    """
    Plant 생성.
    - plant: schemas.PlantCreate 또는 dict(name, species, image_url?)
    - user_id: 소유자(User) PK
    """
    new_plant = models.Plant(
        name=_get_attr_or_key(plant, "name"),
        species=_get_attr_or_key(plant, "species"),
        image_url=_get_attr_or_key(plant, "image_url"),
        owner_id=user_id,
    )
    db.add(new_plant)
    db.commit()
    db.refresh(new_plant)
    return new_plant


def get_plants_by_owner(db: Session, user_id: int) -> List[models.Plant]:
    """
    특정 사용자의 모든 식물 목록 조회.
    """
    return (
        db.query(models.Plant)
        .filter(models.Plant.owner_id == user_id)
        .order_by(models.Plant.id.desc())
        .all()
    )


def get_plant_by_id(db: Session, plant_id: int) -> Optional[models.Plant]:
    """
    PK로 단일 Plant 조회.
    """
    return db.query(models.Plant).filter(models.Plant.id == plant_id).first()


def update_plant(db: Session, plant_id: int, plant_update_data: Payload) -> Optional[models.Plant]:
    """
    Plant 부분 업데이트.
    - plant_update_data: schemas.PlantUpdate 또는 dict
      - name, species는 None이면 무시(유지)
      - image_url은 None 할당도 허용(정책에 맞게 조정 가능)
    """
    plant_obj = get_plant_by_id(db, plant_id)
    if not plant_obj:
        return None

    # name
    name = _get_attr_or_key(plant_update_data, "name", default="__MISSING__")
    if name != "__MISSING__" and name is not None:
        plant_obj.name = name

    # species
    species = _get_attr_or_key(plant_update_data, "species", default="__MISSING__")
    if species != "__MISSING__" and species is not None:
        plant_obj.species = species

    # image_url (None 값으로 비우는 것도 허용)
    image_url_marker = object()
    image_url = _get_attr_or_key(plant_update_data, "image_url", default=image_url_marker)
    if image_url is not image_url_marker:
        plant_obj.image_url = image_url

    db.add(plant_obj)
    db.commit()
    db.refresh(plant_obj)
    return plant_obj


def delete_plant(db: Session, plant_id: int) -> bool:
    """
    Plant 삭제. 성공 시 True, 대상 없음 시 False.
    """
    plant_obj = get_plant_by_id(db, plant_id)
    if not plant_obj:
        return False
    db.delete(plant_obj)
    db.commit()
    return True


def update_user_password(db: Session, email: str, new_password: str):
            """
            사용자의 비밀번호를 새로운 해시값으로 업데이트합니다.
            """
            user = get_user_by_email(db, email=email)
            if user:
                hashed_password = get_password_hash(new_password)
                user.hashed_password = hashed_password
                db.commit()
                db.refresh(user)
            return user