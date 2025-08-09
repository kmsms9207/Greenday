from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig

import crud, schemas, models, database
from core import security
from core.config import settings

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

async def send_verification_email(email: str, token: str):
    html = f"""<p>안녕하세요! Green Day에 오신 것을 환영합니다.</p>
               <p>계정 인증을 완료하려면 아래 버튼을 클릭해주세요.</p>
               <a href="http://localhost:3000/verify-email?token={token}" 
                  style="display:inline-block; padding:10px 20px; color:white; background-color:#28a745; text-decoration:none; border-radius:5px;">
                  이메일 인증하기
               </a>"""
    message = MessageSchema(subject="[Green Day] 계정 인증을 완료해주세요.", recipients=[email], body=html, subtype="html")
    fm = FastMail(conf)
    await fm.send_message(message)

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
    token = security.create_verification_token(email=created_user.email)
    background_tasks.add_task(send_verification_email, created_user.email, token)
    
    return {"message": "회원가입이 완료되었습니다. 이메일을 확인하여 계정을 활성화해주세요.", "userId": created_user.id}

@router.post("/verify-email")
def verify_email(request: schemas.EmailVerification, db: Session = Depends(database.get_db)):
    email = security.verify_token(request.token)
    if not email:
        raise HTTPException(status_code=400, detail="유효하지 않거나 만료된 토큰입니다.")
    
    user = crud.get_user_by_email(db, email=email)
    if not user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")
    if user.is_verified:
        raise HTTPException(status_code=400, detail="이미 인증된 계정입니다.")
        
    crud.verify_user_email(db, email)
    return {"message": "이메일 인증이 완료되었습니다. 이제 로그인할 수 있습니다."}

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