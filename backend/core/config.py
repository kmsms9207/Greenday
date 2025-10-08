from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    DB_URL: str
    SECRET_KEY: str
    ALGORITHM: str
    ACCESS_TOKEN_EXPIRE_MINUTES: int
    MAIL_USERNAME: str
    MAIL_PASSWORD: str
    MAIL_FROM: str
    MAIL_PORT: int
    MAIL_SERVER: str
    MAIL_STARTTLS: bool
    MAIL_SSL_TLS: bool

    # --- [추가] Perenual API Key ---
    PERENUAL_API_KEY: str = ""

    # --- [추가] Naver Clova X API 설정 (v1, v3 모두 지원) ---
    CLOVA_API_URL: str = ""
    CLOVA_BEARER: str = ""           # 최신 Bearer 방식 토큰
    CLOVA_API_KEY_ID: str = ""       # 이전 APIGW 방식 ID
    CLOVA_API_KEY: str = ""        # 이전 APIGW 방식 Key
    CLOVA_REQUEST_ID: str = ""


    class Config:
        env_file = ".env"
        extra="ignore"
settings = Settings()