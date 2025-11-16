# crud.py
from typing import Optional, List
from sqlalchemy.orm import Session, joinedload
import models, schemas
from core.security import get_password_hash
from datetime import datetime, timedelta, timezone

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

def set_verification_code(db: Session, user_id: int, code: str, expires_in_minutes: int = 10) -> Optional[models.User]:
    """사용자에게 인증번호와 만료 시간을 설정합니다."""
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user:
        user.verification_code = code
        # UTC 기준으로 만료 시간 계산 (DB 타임존 설정에 따라 조정 필요할 수 있음)
        user.verification_expires_at = datetime.now(timezone.utc) + timedelta(minutes=expires_in_minutes)
        db.commit()
        db.refresh(user)
        return user
    return None

def clear_verification_code(db: Session, user_id: int) -> Optional[models.User]:
    """사용자의 인증번호 정보를 초기화합니다."""
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user:
        user.verification_code = None
        user.verification_expires_at = None
        db.commit()
        db.refresh(user)
        return user
    return None

def delete_user(db: Session, user_id: int) -> Optional[models.User]:
    """지정된 ID의 사용자를 DB에서 삭제합니다."""
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user:
        db.delete(user)
        db.commit()
        return user
    return None

def verify_user_code(db: Session, email: str, code: str) -> bool:
    """이메일과 인증번호가 유효한지 확인합니다."""
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        return False # 사용자가 없음
    if not user.verification_code or not user.verification_expires_at:
        return False # 코드가 설정되지 않았거나 만료 시간이 없음

    # 현재 시간 (UTC)과 만료 시간 비교
    now_utc = datetime.now(timezone.utc)
    
    # DB에 저장된 시간의 타임존 정보 확인 필요
    # 만약 DB 시간이 naive(타임존 정보 없음) 하다면, UTC로 가정하고 비교
    expires_at = user.verification_expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc) # UTC로 가정

    if now_utc > expires_at:
        return False # 코드 만료

    if user.verification_code != code:
        return False # 코드 불일치

    # 모든 검증 통과
    return True

def activate_user(db: Session, email: str) -> Optional[models.User]:
    """사용자 계정을 활성화하고 인증 코드를 초기화합니다."""
    user = db.query(models.User).filter(models.User.email == email).first()
    if user:
        user.is_verified = True
        user.verification_code = None
        user.verification_expires_at = None
        db.commit()
        db.refresh(user)
        return user
    return None

# --- Plant CRUD ---

def create_plant(db: Session, user_id: int, name: str, species: str, plant_master_id: int) -> models.Plant:
    """
    사용자의 새 반려식물을 생성합니다.
    - name: 사용자가 직접 입력한 애칭
    - species: PlantMaster DB에서 가져온 정확한 학명
    - plant_master_id: 참조하는 PlantMaster의 ID
    """
    db_plant = models.Plant(
        name=name,
        species=species,
        owner_id=user_id,
        plant_master_id=plant_master_id, # [수정] 전달받은 plant_master_id를 저장
        image_url=None
    )
    db.add(db_plant)
    db.commit()
    db.refresh(db_plant)
    return db_plant

def get_plants_by_owner(db: Session, user_id: int) -> List[models.Plant]:
    return db.query(models.Plant)\
        .options(joinedload(models.Plant.master_info))\
        .filter(models.Plant.owner_id == user_id)\
        .order_by(models.Plant.id.desc())\
        .all()

def get_plant_by_id(db: Session, plant_id: int) -> Optional[models.Plant]:
    return db.query(models.Plant)\
        .options(joinedload(models.Plant.master_info))\
        .filter(models.Plant.id == plant_id)\
        .first()

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
    has_pets: Optional[bool] = None,
    difficulty: Optional[str] = None,       # 👈 [추가] 난이도 파라미터
    light_requirement: Optional[str] = None, # 👈 [추가] 햇빛 파라미터
    sort_by: Optional[str] = None,
    order: Optional[str] = "asc"
) -> List[models.PlantMaster]:
    """
    PlantMaster 테이블에서 모든 식물 목록 조회 (필터링 기능 추가)
    """
    query = db.query(models.PlantMaster)

    # 필터링 로직 추가
    if has_pets is True:
        query = query.filter(models.PlantMaster.pet_safe == True)
    if difficulty:
        query = query.filter(models.PlantMaster.difficulty == difficulty)
    if light_requirement:
        query = query.filter(models.PlantMaster.light_requirement == light_requirement)

    if sort_by:
        sort_column = getattr(models.PlantMaster, sort_by, None)
        if sort_column:
            if order.lower() == "desc":
                query = query.order_by(sort_column.desc())
            else:
                query = query.order_by(sort_column.asc())

    return query.offset(skip).limit(limit).all()

# def search_master_plants(db: Session, q: str, skip: int = 0, limit: int = 100):
#     """한국어 이름으로 PlantMaster 테이블에서 식물 검색"""
#     return db.query(models.PlantMaster)\
#              .filter(models.PlantMaster.name_ko.contains(q))\
#              .offset(skip)\
#              .limit(limit)\
#              .all()

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

# ⭐️ FCM 푸시 토큰 저장/갱신
def update_user_push_token(db: Session, user_id: int, token: str) -> models.User:
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user:
        user.push_token = token
        db.commit()
        db.refresh(user)
    return user

# ==============================================================================
# Community: Post CRUD (게시글)
# ==============================================================================

def create_post(db: Session, post: schemas.PostCreate, user_id: int) -> models.Post:
    """새 게시글 생성"""
    db_post = models.Post(
        title=post.title,
        content=post.content,
        owner_id=user_id
    )
    db.add(db_post)
    db.commit()
    db.refresh(db_post)
    return db_post

def get_posts(db: Session, skip: int = 0, limit: int = 100) -> List[models.Post]:
    """게시글 목록 조회 (최신순, 작성자 정보 포함)"""
    return db.query(models.Post)\
        .options(joinedload(models.Post.owner))\
        .order_by(models.Post.created_at.desc())\
        .offset(skip)\
        .limit(limit)\
        .all()

def get_post(db: Session, post_id: int) -> Optional[models.Post]:
    """게시글 1개 상세 조회 (작성자, 댓글 및 댓글 작성자 정보 포함)"""
    return db.query(models.Post)\
        .options(
            joinedload(models.Post.owner), # 게시글 작성자
            joinedload(models.Post.comments).joinedload(models.Comment.owner) # 댓글 및 댓글 작성자
        )\
        .filter(models.Post.id == post_id)\
        .first()

def update_post(db: Session, post_id: int, post_update: schemas.PostUpdate, user_id: int) -> Optional[models.Post]:
    """게시글 수정 (작성자 본인만 가능)"""
    db_post = db.query(models.Post).filter(models.Post.id == post_id).first()
    
    if not db_post or db_post.owner_id != user_id:
        return None # 게시글이 없거나 권한이 없음
        
    update_data = post_update.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_post, key, value)
    
    db_post.updated_at = datetime.now(timezone.utc) # 수정 시간 갱신
    db.commit()
    db.refresh(db_post)
    return db_post

def delete_post(db: Session, post_id: int, user_id: int) -> Optional[models.Post]:
    """게시글 삭제 (작성자 본인만 가능)"""
    db_post = db.query(models.Post).filter(models.Post.id == post_id).first()
    
    if not db_post or db_post.owner_id != user_id:
        return None # 게시글이 없거나 권한이 없음
        
    db.delete(db_post)
    db.commit()
    return db_post

# ==============================================================================
# Community: Comment CRUD (댓글)
# ==============================================================================

def create_comment(db: Session, comment: schemas.CommentCreate, post_id: int, user_id: int) -> models.Comment:
    """새 댓글 생성"""
    db_comment = models.Comment(
        content=comment.content,
        post_id=post_id,
        owner_id=user_id
    )
    db.add(db_comment)
    db.commit()
    db.refresh(db_comment)
    return db_comment

def get_comments_by_post(db: Session, post_id: int, skip: int = 0, limit: int = 100) -> List[models.Comment]:
    """특정 게시글의 댓글 목록 조회 (작성자 정보 포함)"""
    return db.query(models.Comment)\
        .options(joinedload(models.Comment.owner))\
        .filter(models.Comment.post_id == post_id)\
        .order_by(models.Comment.created_at.asc())\
        .offset(skip)\
        .limit(limit)\
        .all()

def update_comment(db: Session, comment_id: int, comment_update: schemas.CommentUpdate, user_id: int) -> Optional[models.Comment]:
    """댓글 수정 (작성자 본인만 가능)"""
    db_comment = db.query(models.Comment).filter(models.Comment.id == comment_id).first()
    
    if not db_comment or db_comment.owner_id != user_id:
        return None # 댓글이 없거나 권한이 없음
    
    update_data = comment_update.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_comment, key, value)
        
    db_comment.updated_at = datetime.now(timezone.utc) # 수정 시간 갱신
    db.commit()
    db.refresh(db_comment)
    return db_comment

def delete_comment(db: Session, comment_id: int, user_id: int) -> Optional[models.Comment]:
    """댓글 삭제 (작성자 본인만 가능)"""
    db_comment = db.query(models.Comment).filter(models.Comment.id == comment_id).first()
    
    if not db_comment or db_comment.owner_id != user_id:
        return None # 댓글이 없거나 권한이 없음
        
    db.delete(db_comment)
    db.commit()
    return db_comment

# ==============================================================================
# Diary (성장 일지 - 이벤트 로그 방식)
# ==============================================================================

def create_diary_log(
    db: Session, 
    plant_id: int, 
    log_type: str, # 'WATERING', 'DIAGNOSIS', 'BIRTHDAY' 등
    log_message: Optional[str] = None,
    image_url: Optional[str] = None,
    reference_id: Optional[int] = None
) -> models.Diary:
    """
    [자동 기록용] 시스템 이벤트(물주기, 진단 등)를 Diary에 기록합니다.
    """
    db_diary_log = models.Diary(
        plant_id=plant_id,
        log_type=log_type,
        log_message=log_message,
        image_url=image_url,
        reference_id=reference_id
    )
    db.add(db_diary_log)
    db.commit()
    db.refresh(db_diary_log)
    return db_diary_log

def create_manual_diary_entry(
    db: Session, 
    plant_id: int, 
    entry: schemas.DiaryCreateManual, 
    user_id: int
) -> Optional[models.Diary]:
    """
    [수동 기록용] 사용자가 직접 메모(NOTE)나 사진(PHOTO)을 Diary에 기록합니다.
    """
    # 1. 식물의 소유권 확인
    plant = db.query(models.Plant).filter(models.Plant.id == plant_id).first()
    if not plant or plant.owner_id != user_id:
        return None # 식물이 없거나 내 식물이 아님

    # 2. 로그 타입 결정 (사진 우선)
    log_type = "NOTE"
    if entry.image_url:
        log_type = "PHOTO"

    return create_diary_log(
        db=db,
        plant_id=plant_id,
        log_type=log_type,
        log_message=entry.log_message,
        image_url=entry.image_url
    )

def get_diaries_by_plant(db: Session, plant_id: int, user_id: int, skip: int = 0, limit: int = 100) -> List[models.Diary]:
    """특정 식물의 전체 일지 목록을 최신순으로 조회합니다."""
    # 식물 소유권 확인
    plant = db.query(models.Plant).filter(models.Plant.id == plant_id).first()
    if not plant or plant.owner_id != user_id:
        return [] # 빈 리스트 반환

    return db.query(models.Diary)\
        .filter(models.Diary.plant_id == plant_id)\
        .order_by(models.Diary.created_at.desc())\
        .offset(skip)\
        .limit(limit)\
        .all()

def get_diary_entry(db: Session, diary_id: int, user_id: int) -> Optional[models.Diary]:
    """특정 일지 항목 1개를 조회합니다."""
    db_diary = db.query(models.Diary).filter(models.Diary.id == diary_id).first()
    if not db_diary:
        return None
    
    # 식물 소유권 확인
    plant = db_diary.plant
    if plant.owner_id != user_id:
        return None

    return db_diary

def update_manual_diary_entry(
    db: Session, 
    diary_id: int, 
    entry_update: schemas.DiaryCreateManual, 
    user_id: int
) -> Optional[models.Diary]:
    """'수동'으로 작성된 일지(NOTE, PHOTO)만 수정합니다."""
    db_diary = get_diary_entry(db=db, diary_id=diary_id, user_id=user_id)
    
    # 일지가 없거나, 소유권이 없거나, 자동 로그(WATERING 등)이면 수정 불가
    if not db_diary or db_diary.log_type not in ['NOTE', 'PHOTO']:
        return None

    update_data = entry_update.model_dump(exclude_unset=True)
    
    # 로그 타입 재설정 (사진이 추가/삭제되었을 수 있으므로)
    db_diary.log_type = "NOTE"
    if update_data.get("image_url", db_diary.image_url): # 기존 이미지 URL도 확인
        db_diary.log_type = "PHOTO"
        
    db_diary.log_message = update_data.get("log_message", db_diary.log_message)
    db_diary.image_url = update_data.get("image_url", db_diary.image_url)
    
    db.commit()
    db.refresh(db_diary)
    return db_diary

def delete_manual_diary_entry(db: Session, diary_id: int, user_id: int) -> Optional[models.Diary]:
    """'수동'으로 작성된 일지(NOTE, PHOTO)만 삭제합니다."""
    db_diary = get_diary_entry(db=db, diary_id=diary_id, user_id=user_id)
    
    # 일지가 없거나, 소유권이 없거나, 자동 로그(WATERING 등)이면 삭제 불가
    if not db_diary or db_diary.log_type not in ['NOTE', 'PHOTO']:
        return None
        
    db.delete(db_diary)
    db.commit()
    return db_diary

# ==============================================================================
# Chat CRUD (신규): 스레드 목록 / 메시지 조회 / 스레드 삭제
# ==============================================================================

def get_threads_with_summary(
    db: Session,
    user_id: int,
    skip: int = 0,
    limit: int = 50,
):
    """
    N+1 없이, 한 번의 쿼리로 대화 스레드 목록 + 메시지 요약 정보를 가져옵니다.
    반환 컬럼:
      - id, title, created_at, updated_at
      - message_count
      - last_message
      - last_message_at
    """
    Thread = models.ChatThread
    Message = models.ChatMessage

    # 각 스레드별 메시지 개수
    count_sub = (
        db.query(
            Message.thread_id.label("thread_id"),
            func.count(Message.id).label("message_count"),
        )
        .group_by(Message.thread_id)
        .subquery()
    )

    # 각 스레드별 마지막 메시지 ID
    last_id_sub = (
        db.query(
            Message.thread_id.label("thread_id"),
            func.max(Message.id).label("last_msg_id"),
        )
        .group_by(Message.thread_id)
        .subquery()
    )

    query = (
        db.query(
            Thread.id,
            Thread.title,
            Thread.created_at,
            Thread.updated_at,
            func.coalesce(count_sub.c.message_count, 0).label("message_count"),
            Message.content.label("last_message"),
            Message.created_at.label("last_message_at"),
        )
        .outerjoin(count_sub, count_sub.c.thread_id == Thread.id)
        .outerjoin(last_id_sub, last_id_sub.c.thread_id == Thread.id)
        .outerjoin(Message, Message.id == last_id_sub.c.last_msg_id)
        .filter(Thread.user_id == user_id)
        .order_by(Thread.updated_at.desc(), Thread.id.desc())
        .offset(skip)
        .limit(limit)
    )

    return query.all()

def get_threads_by_user(db: Session, user_id: int, skip: int = 0, limit: int = 50) -> List[models.ChatThread]:
    """
    (이전 버전) 사용자 소유의 대화 스레드 목록을 최신순(updated_at desc)으로 반환합니다.
    N+1 문제 때문에 list_threads에서는 가급적 get_threads_with_summary를 사용하세요.
    """
    return (
        db.query(models.ChatThread)
        .filter(models.ChatThread.user_id == user_id)
        .order_by(models.ChatThread.updated_at.desc(), models.ChatThread.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )

def get_messages_by_thread(
    db: Session,
    thread_id: int,
    user_id: int,
    limit: int = 100,
    before_id: Optional[int] = None,
    after_id: Optional[int] = None,
    asc: bool = True,
) -> Optional[List[models.ChatMessage]]:
    """
    특정 스레드의 메시지 목록을 반환합니다.
    - 소유권 확인 포함
    - before_id/after_id로 커서 페이지네이션 지원
    - asc=False로 최신→과거 정렬(내림차순)
    """
    # 소유권 확인
    thread = (
        db.query(models.ChatThread)
        .filter(models.ChatThread.id == thread_id, models.ChatThread.user_id == user_id)
        .first()
    )
    if not thread:
        return None

    q = db.query(models.ChatMessage).filter(models.ChatMessage.thread_id == thread_id)

    if before_id is not None:
        q = q.filter(models.ChatMessage.id < before_id)
    if after_id is not None:
        q = q.filter(models.ChatMessage.id > after_id)

    q = q.order_by(models.ChatMessage.id.asc() if asc else models.ChatMessage.id.desc()).limit(limit)
    rows = q.all()

    # 내림차순으로 가져왔으면 프론트 편의상 다시 과거→최신으로 뒤집어 전달
    if not asc:
        rows.reverse()
    return rows

def delete_chat_thread(db: Session, thread_id: int, user_id: int) -> bool:
    """
    스레드를 삭제합니다(본인 소유만). ChatMessage에 FK가 걸려있으므로
    안전하게 해당 스레드의 메시지를 먼저 삭제하고 스레드를 지웁니다.
    """
    thread = (
        db.query(models.ChatThread)
        .filter(models.ChatThread.id == thread_id, models.ChatThread.user_id == user_id)
        .first()
    )
    if not thread:
        return False

    # 먼저 메시지 삭제
    db.query(models.ChatMessage).filter(models.ChatMessage.thread_id == thread_id).delete(synchronize_session=False)
    # 그 다음 스레드 삭제
    db.delete(thread)
    db.commit()
    return True
