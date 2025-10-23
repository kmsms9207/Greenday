from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig

import crud, schemas, models, database
from core import security
from core.config import settings

import random  
import string

router = APIRouter(prefix="/auth", tags=["Authentication"])

# "/auth/login" 주소에서 토큰을 가져오겠다고 FastAPI에게 알려줌
# 이 방식을 사용하면 /docs 페이지에서 편리한 자물쇠 UI를 사용할 수 있습니다.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

# --- 이메일 설정 ---
conf = ConnectionConfig(
    MAIL_USERNAME = settings.MAIL_USERNAME,
    MAIL_PASSWORD = settings.MAIL_PASSWORD,
    MAIL_FROM = settings.MAIL_FROM,
    MAIL_PORT = settings.MAIL_PORT,
    MAIL_SERVER = settings.MAIL_SERVER,
    MAIL_STARTTLS = settings.MAIL_STARTTLS,
    MAIL_SSL_TLS = settings.MAIL_SSL_TLS,
    USE_CREDENTIALS = True
)
async def send_verification_code_email(email: str, code: str):
    html = f"""<p>안녕하세요! Green Day에 오신 것을 환영합니다.</p>
             <p>계정 인증을 완료하려면 아래 인증번호를 앱에 입력해주세요.</p>
             <p style="font-size: 24px; font-weight: bold; color: #28a745;">{code}</p>
             <p>이 인증번호는 10분간 유효합니다.</p>"""
    message = MessageSchema(subject="[Green Day] 계정 인증번호 안내", recipients=[email], body=html, subtype="html")
    fm = FastMail(conf)
    await fm.send_message(message)

#async def send_verification_email(email: str, token: str):
#    html = f"""<p>안녕하세요! Green Day에 오신 것을 환영합니다.</p>
#               <p>계정 인증을 완료하려면 아래 버튼을 클릭해주세요.</p>
#               <a href="http://localhost:3000/verify-email?token={token}" 
#                  style="display:inline-block; padding:10px 20px; color:white; background-color:#28a745; text-decoration:none; border-radius:5px;">
#                  이메일 인증하기
#               </a>"""
#    message = MessageSchema(subject="[Green Day] 계정 인증을 완료해주세요.", recipients=[email], body=html, subtype="html")
#    fm = FastMail(conf)
#    await fm.send_message(message)

# --- 의존성 함수 (Dependency) ---
# 이 함수는 토큰을 검증하고, 유효하다면 현재 로그인된 사용자 정보를 반환합니다.
def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(database.get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    email = security.verify_token(token)
    if email is None:
        raise credentials_exception
    user = crud.get_user_by_email(db, email=email)
    if user is None:
        raise credentials_exception
    return user

# --- API 엔드포인트 ---

@router.post("/signup", status_code=status.HTTP_201_CREATED)
async def signup(user: schemas.UserCreate, background_tasks: BackgroundTasks, db: Session = Depends(database.get_db)):
    if crud.get_user_by_email(db, email=user.email):
        raise HTTPException(status_code=409, detail="이미 사용 중인 이메일입니다.")
    if crud.get_user_by_username(db, username=user.username):
        raise HTTPException(status_code=409, detail="이미 사용 중인 사용자 이름입니다.")
    
    created_user = crud.create_user(db=db, user=user)
    
    # --- ⬇️ 토큰 생성 대신 인증번호 생성 및 저장 로직으로 변경 ⬇️ ---
    verification_code = "".join(random.choices(string.digits, k=6)) # 6자리 숫자 코드 생성
    crud.set_verification_code(db=db, user_id=created_user.id, code=verification_code) # DB에 코드 저장
    
    # 이메일 발송 함수 호출 (변경된 함수 이름 사용)
    background_tasks.add_task(send_verification_code_email, created_user.email, verification_code)
    # --- ⬆️ 변경 완료 ⬆️ ---
    
    return {"message": "회원가입이 완료되었습니다. 이메일로 발송된 인증번호를 확인해주세요.", "userId": created_user.id}

# 인증번호 검증 API
@router.post("/verify-code", status_code=status.HTTP_200_OK)
def verify_signup_code(request: schemas.VerifyCodeRequest, db: Session = Depends(database.get_db)):
    """회원가입 시 이메일로 받은 인증번호를 검증합니다."""
    
    # 1. crud 함수를 이용해 코드 유효성 검증
    is_valid = crud.verify_user_code(db, email=request.email, code=request.code)
    
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="인증번호가 유효하지 않거나 만료되었습니다."
        )

    # 2. 코드가 유효하면 사용자 계정 활성화 (is_verified = True) 및 코드 초기화
    activated_user = crud.activate_user(db, email=request.email)
    
    if not activated_user:
        # 이론상 발생하기 어렵지만, 혹시 모를 경우 처리
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

    return {"message": "이메일 인증이 성공적으로 완료되었습니다. 이제 로그인할 수 있습니다."}

@router.post("/login")
def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(database.get_db)):
    # OAuth2PasswordRequestForm은 username 필드에 이메일을, password 필드에 비밀번호를 담아 보냅니다.
    user = crud.get_user_by_email(db, email=form_data.username)
    if not user or not security.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="아이디 또는 비밀번호가 올바르지 않습니다.",
        )
    if not user.is_verified:
         raise HTTPException(status_code=403, detail="이메일 인증이 필요합니다. 전송된 이메일을 확인해주세요.")

    access_token = security.create_access_token(data={"sub": user.email})
    # FastAPI 표준에 맞춰 응답 형식을 수정합니다.
    return {"access_token": access_token, "token_type": "bearer"}

# --- 로그인 필수 API 예시 ---
@router.get("/users/me", response_model=schemas.UserInfo)
def read_users_me(current_user: models.User = Depends(get_current_user)):
    """
    ### 내 정보 조회 (로그인 필요)
    - **설명**: 현재 로그인된 사용자의 정보를 반환합니다.
    - **사용법**: /docs 페이지 우측 상단의 'Authorize' 버튼을 통해 로그인 후 테스트할 수 있습니다.
    """
    return current_user

@router.post("/forgot-password", status_code=status.HTTP_200_OK)
async def forgot_password(request: schemas.ForgotPasswordRequest, background_tasks: BackgroundTasks, db: Session = Depends(database.get_db)):
    """
    ### 비밀번호 재설정 이메일 발송
    - **설명**: 사용자가 입력한 이메일로 비밀번호를 재설정할 수 있는 링크를 보냅니다.
    """
    user = crud.get_user_by_email(db, email=request.email)
    # 가입되지 않은 이메일이라도, 보안을 위해 성공 메시지를 보냅니다.
    if user:
        # 토큰을 생성하고 이메일을 백그라운드에서 보냅니다.
        token = security.create_verification_token(email=user.email)
        background_tasks.add_task(send_password_reset_email, user.email, token)
    
    return {"message": "비밀번호 재설정 이메일을 발송했습니다. 메일함을 확인해주세요."}

async def send_password_reset_email(email: str, token: str):
    html = f"""
    <p>안녕하세요! Green Day 비밀번호 재설정 요청을 받았습니다.</p>
    <p>아래 버튼을 클릭하여 비밀번호를 다시 설정해주세요.</p>
    <a href="http://localhost:3000/reset-password?token={token}" 
       style="display:inline-block; padding:10px 20px; color:white; background-color:#28a745; text-decoration:none; border-radius:5px;">
       비밀번호 재설정하기
    </a>
    """
    message = MessageSchema(
        subject="[Green Day] 비밀번호 재설정 안내",
        recipients=[email],
        body=html,
        subtype="html"
    )
    fm = FastMail(conf)
    await fm.send_message(message)

@router.post("/reset-password", status_code=status.HTTP_200_OK)
def reset_password(request: schemas.ResetPasswordRequest, db: Session = Depends(database.get_db)):
    """
    ### 새 비밀번호로 재설정
    - **설명**: 이메일로 받은 토큰과 새 비밀번호로 최종 재설정을 완료합니다.
    """
    # 1. 토큰을 검증하여 이메일을 알아냅니다.
    email = security.verify_token(request.token)
    if not email:
        raise HTTPException(status_code=400, detail="유효하지 않거나 만료된 토큰입니다.")
    
    # 2. DB 담당자가 만든 crud 함수를 호출하여 DB의 비밀번호를 업데이트합니다.
    user = crud.update_user_password(db, email=email, new_password=request.new_password)
    if not user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

    return {"message": "비밀번호가 성공적으로 재설정되었습니다."}

# ⭐️ FCM 푸시 토큰 등록/갱신
@router.post(
    "/users/me/push-token",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="FCM 푸시 토큰 등록/갱신"
)
def update_push_token(
    token_data: schemas.PushTokenUpdateRequest,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(get_current_user) # ⭐️ 스키마 대신 모델을 사용
):
    
    crud.update_user_push_token(
        db=db, 
        user_id=current_user.id, 
        token=token_data.push_token
    )
    return

# ⭐️ 회원 탈퇴
@router.delete("/users/me", response_model=schemas.UserDeleteResponse)
def delete_current_user(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(database.get_db)
):
    """
    ### 회원 탈퇴 (로그인 필요)
    - **설명**: 현재 로그인된 사용자의 계정을 삭제합니다.
    - **경고**: 이 작업은 되돌릴 수 없으며, 모든 식물 및 진단 기록이 함께 삭제됩니다.
    """
    deleted_user = crud.delete_user(db=db, user_id=current_user.id)
    if not deleted_user:
        # 인증된 사용자이므로 이론상 이 오류는 발생하지 않아야 함
        raise HTTPException(status_code=404, detail="User not found")

    return {"message": "회원 탈퇴가 성공적으로 처리되었습니다.", "deleted_email": deleted_user.email}