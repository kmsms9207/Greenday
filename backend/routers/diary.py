# routers/diary.py (새로운 전체 코드)

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

import crud
import schemas
import models
from database import get_db
from dependencies import get_current_user

router = APIRouter(
    prefix="/diary",
    tags=["Diary (Event Log)"],
    dependencies=[Depends(get_current_user)]
)

@router.post("/{plant_id}/manual", response_model=schemas.Diary, status_code=status.HTTP_201_CREATED)
def create_manual_diary(
    plant_id: int,
    entry: schemas.DiaryCreateManual,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    ### 수동 성장 일지 작성 (메모 또는 사진)
    - `log_message`만 보내면 'NOTE' 타입으로, `image_url`을 보내면 'PHOTO' 타입으로 자동 저장됩니다.
    - **인증**: 필수
    """
    db_diary = crud.create_manual_diary_entry(
        db=db, plant_id=plant_id, entry=entry, user_id=current_user.id
    )
    if db_diary is None:
        raise HTTPException(status_code=404, detail="식물을 찾을 수 없거나 소유자가 아닙니다.")
    return db_diary

@router.get("/{plant_id}", response_model=List[schemas.Diary])
def read_diaries_for_plant(
    plant_id: int,
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    ### 특정 식물의 전체 성장 일지(타임라인) 조회
    - '물주기', '진단', '수동 메모' 등 모든 기록이 최신순으로 반환됩니다.
    - **인증**: 필수
    """
    diaries = crud.get_diaries_by_plant(
        db=db, plant_id=plant_id, user_id=current_user.id, skip=skip, limit=limit
    )
    return diaries

@router.put("/{diary_id}/manual", response_model=schemas.Diary)
def update_manual_diary(
    diary_id: int,
    entry_update: schemas.DiaryCreateManual,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    ### 수동 작성 일지(메모/사진) 수정
    - **'수동'**으로 작성한 `NOTE` 또는 `PHOTO` 타입의 일지만 수정 가능합니다.
    - '자동'으로 기록된 물주기, 진단 로그는 수정할 수 없습니다.
    - **인증**: 필수 (작성자 본인만 가능)
    """
    db_diary = crud.update_manual_diary_entry(
        db=db, diary_id=diary_id, entry_update=entry_update, user_id=current_user.id
    )
    if db_diary is None:
        raise HTTPException(status_code=403, detail="수정 권한이 없거나, 자동 로그는 수정할 수 없습니다.")
    return db_diary

@router.delete("/{diary_id}/manual", status_code=status.HTTP_204_NO_CONTENT)
def delete_manual_diary(
    diary_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    ### 수동 작성 일지(메모/사진) 삭제
    - **'수동'**으로 작성한 `NOTE` 또는 `PHOTO` 타입의 일지만 삭제 가능합니다.
    - '자동'으로 기록된 물주기, 진단 로그는 삭제할 수 없습니다.
    - **인증**: 필수 (작성자 본인만 가능)
    """
    db_diary = crud.delete_manual_diary_entry(db=db, diary_id=diary_id, user_id=current_user.id)
    if db_diary is None:
        raise HTTPException(status_code=403, detail="삭제 권한이 없거나, 자동 로그는 삭제할 수 없습니다.")
    return