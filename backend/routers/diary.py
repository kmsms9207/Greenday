from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import Optional, List

import models, schemas
from database import get_db
from dependencies import get_current_user  # 인증 의존성 (반드시 로그인 필요)

router = APIRouter(prefix="/diary", tags=["Diary"])

# 소유자 권한 체크 헬퍼
def _get_owned_post_or_404(db: Session, post_id: int, user_id: int) -> models.DiaryPost:
    post = (
        db.query(models.DiaryPost)
        .filter(models.DiaryPost.id == post_id, models.DiaryPost.owner_id == user_id)
        .first()
    )
    if not post:
        raise HTTPException(status_code=404, detail="일지를 찾을 수 없거나 접근 권한이 없습니다.")
    return post

@router.post("", status_code=status.HTTP_201_CREATED)
def create_post(
    req: schemas.DiaryCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    post = models.DiaryPost(owner_id=user.id, title=req.title, body=req.body)
    db.add(post); db.flush()

    # media 삽입
    for m in req.media:
        db.add(models.DiaryMedia(
            post_id=post.id, url=str(m.url),
            thumb_url=str(m.thumb_url) if m.thumb_url else None,
            width=m.width, height=m.height, order=m.order
        ))
    db.commit(); db.refresh(post)

    return {"id": post.id, "created_at": post.created_at}

@router.get("", response_model=schemas.DiaryListOut)
def list_posts(
    q: Optional[str] = Query(None, description="제목/본문 검색어"),
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    query = db.query(models.DiaryPost).filter(models.DiaryPost.owner_id == user.id)
    if q:
        like = f"%{q}%"
        query = query.filter((models.DiaryPost.title.ilike(like)) | (models.DiaryPost.body.ilike(like)))

    query = query.order_by(models.DiaryPost.created_at.desc())
    items = query.limit(size).offset((page - 1) * size).all()

    # cover(썸네일) 계산
    result = []
    for p in items:
        cover = None
        if p.media:
            cover = p.media[0].thumb_url or p.media[0].url
        result.append(
            schemas.DiaryItemOut(id=p.id, title=p.title, created_at=p.created_at, cover=cover)
        )

    next_page = page + 1 if len(items) == size else None
    return schemas.DiaryListOut(items=result, next_page=next_page)

@router.get("/{post_id}", response_model=schemas.DiaryDetailOut)
def get_detail(
    post_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    post = _get_owned_post_or_404(db, post_id, user.id)
    media = [
        schemas.DiaryMediaIn(
            url=m.url, thumb_url=m.thumb_url, width=m.width, height=m.height, order=m.order
        ) for m in post.media
    ]
    return schemas.DiaryDetailOut(
        id=post.id, title=post.title, body=post.body,
        created_at=post.created_at, updated_at=post.updated_at, media=media
    )

@router.patch("/{post_id}")
def update_post(
    post_id: int,
    req: schemas.DiaryUpdate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    post = _get_owned_post_or_404(db, post_id, user.id)

    if req.title is not None:
        post.title = req.title
    if req.body is not None:
        post.body = req.body

    if req.media is not None:
        # 전체 교체
        db.query(models.DiaryMedia).filter(models.DiaryMedia.post_id == post.id).delete()
        for m in req.media:
            db.add(models.DiaryMedia(
                post_id=post.id, url=str(m.url),
                thumb_url=str(m.thumb_url) if m.thumb_url else None,
                width=m.width, height=m.height, order=m.order
            ))

    db.commit()
    return {"ok": True}

@router.delete("/{post_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_post(
    post_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    post = _get_owned_post_or_404(db, post_id, user.id)
    db.delete(post); db.commit()
    return