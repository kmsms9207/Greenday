from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

import crud
import schemas
import models
from database import get_db
from dependencies import get_current_user

router = APIRouter(
    prefix="/community",
    tags=["Community"],
    dependencies=[Depends(get_current_user)]  # 👈 이 라우터의 모든 API는 로그인 필수
)

# ==============================================================================
# Post (게시글) API
# ==============================================================================

@router.post("/posts/", response_model=schemas.PostSimple, status_code=status.HTTP_201_CREATED)
def create_new_post(
    post: schemas.PostCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    ### 새 게시글 작성
    - **인증**: 필수
    """
    db_post = crud.create_post(db=db, post=post, user_id=current_user.id)
    return db_post

@router.get("/posts/", response_model=List[schemas.PostSimple])
def read_all_posts(
    skip: int = 0,
    limit: int = 20, # 게시판은 보통 한 페이지에 20개 정도 표시
    db: Session = Depends(get_db)
):
    """
    ### 전체 게시글 목록 조회
    - 최신순으로 정렬됩니다.
    - **응답**: 댓글을 제외한 게시글 목록이 반환됩니다.
    - **인증**: 필수
    """
    posts = crud.get_posts(db=db, skip=skip, limit=limit)
    return posts

@router.get("/posts/{post_id}", response_model=schemas.Post)
def read_single_post(
    post_id: int,
    db: Session = Depends(get_db)
):
    """
    ### 특정 게시글 상세 조회
    - **응답**: 댓글 목록을 포함한 게시글 상세 정보가 반환됩니다.
    - **인증**: 필수
    """
    db_post = crud.get_post(db=db, post_id=post_id)
    if db_post is None:
        raise HTTPException(status_code=404, detail="게시글을 찾을 수 없습니다.")
    return db_post

@router.put("/posts/{post_id}", response_model=schemas.PostSimple)
def update_existing_post(
    post_id: int,
    post_update: schemas.PostUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    ### 게시글 수정
    - **작성자 본인**만 수정할 수 있습니다.
    - **인증**: 필수
    """
    db_post = crud.update_post(db=db, post_id=post_id, post_update=post_update, user_id=current_user.id)
    if db_post is None:
        raise HTTPException(status_code=403, detail="수정 권한이 없거나 게시글이 없습니다.")
    return db_post

@router.delete("/posts/{post_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_existing_post(
    post_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    ### 게시글 삭제
    - **작성자 본인**만 삭제할 수 있습니다.
    - 게시글 삭제 시, 연관된 모든 댓글도 함께 삭제됩니다.
    - **인증**: 필수
    """
    db_post = crud.delete_post(db=db, post_id=post_id, user_id=current_user.id)
    if db_post is None:
        raise HTTPException(status_code=403, detail="삭제 권한이 없거나 게시글이 없습니다.")
    return

# ==============================================================================
# Comment (댓글) API
# ==============================================================================

@router.post("/posts/{post_id}/comments/", response_model=schemas.Comment, status_code=status.HTTP_201_CREATED)
def create_new_comment(
    post_id: int,
    comment: schemas.CommentCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    ### 새 댓글 작성
    - **인증**: 필수
    """
    # 게시글이 존재하는지 먼저 확인
    db_post = crud.get_post(db=db, post_id=post_id)
    if db_post is None:
        raise HTTPException(status_code=404, detail="댓글을 작성할 게시글이 없습니다.")
        
    db_comment = crud.create_comment(db=db, comment=comment, post_id=post_id, user_id=current_user.id)
    return db_comment

@router.get("/posts/{post_id}/comments/", response_model=List[schemas.Comment])
def read_all_comments_for_post(
    post_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db)
):
    """
    ### 특정 게시글의 댓글 목록 조회
    - 오래된 순(오름차순)으로 정렬됩니다.
    - **인증**: 필수
    """
    # 게시글 존재 여부 확인 (선택 사항이지만, 명확성을 위해)
    db_post = crud.get_post(db=db, post_id=post_id)
    if db_post is None:
        raise HTTPException(status_code=404, detail="게시글을 찾을 수 없습니다.")

    comments = crud.get_comments_by_post(db=db, post_id=post_id, skip=skip, limit=limit)
    return comments

@router.put("/comments/{comment_id}", response_model=schemas.Comment)
def update_existing_comment(
    comment_id: int,
    comment_update: schemas.CommentUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    ### 댓글 수정
    - **작성자 본인**만 수정할 수 있습니다.
    - **인증**: 필수
    """
    db_comment = crud.update_comment(db=db, comment_id=comment_id, comment_update=comment_update, user_id=current_user.id)
    if db_comment is None:
        raise HTTPException(status_code=403, detail="수정 권한이 없거나 댓글이 없습니다.")
    return db_comment

@router.delete("/comments/{comment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_existing_comment(
    comment_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """
    ### 댓글 삭제
    - **작성자 본인**만 삭제할 수 있습니다.
    - **인증**: 필수
    """
    db_comment = crud.delete_comment(db=db, comment_id=comment_id, user_id=current_user.id)
    if db_comment is None:
        raise HTTPException(status_code=403, detail="삭제 권한이 없거나 댓글이 없습니다.")
    return