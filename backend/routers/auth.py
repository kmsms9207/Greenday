from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy.orm import Session
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig
import crud, schemas, database
from core import security
from core.config import settings

router = APIRouter(prefix="/auth", tags=["Authentication"])

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

@router.post("/login", response_model=schemas.Token)
def login(form_data: schemas.UserLogin, db: Session = Depends(database.get_db)):
    user = crud.get_user_by_email(db, email=form_data.email)
    if not user or not security.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="아이디 또는 비밀번호가 올바르지 않습니다.")
    if not user.is_verified:
         raise HTTPException(status_code=403, detail="이메일 인증이 필요합니다. 전송된 이메일을 확인해주세요.")
    access_token = security.create_access_token(data={"sub": user.email})
    return {"accessToken": access_token}