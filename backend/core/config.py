from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # --- Database & Auth ---
    DB_URL: str
    SECRET_KEY: str
    ALGORITHM: str
    ACCESS_TOKEN_EXPIRE_MINUTES: int

    # --- Email ---
    MAIL_USERNAME: str
    MAIL_PASSWORD: str
    MAIL_FROM: str
    MAIL_PORT: int
    MAIL_SERVER: str
    MAIL_STARTTLS: bool
    MAIL_SSL_TLS: bool

    # --- App Origin (API 호출 시 절대 경로 생성용) ---
    APP_ORIGIN: str = "http://127.0.0.1:8000"

    # --- External APIs ---
    PERENUAL_API_KEY: str = ""

    # ✅ [추가] OpenAI GPT 설정 (Vision 포함)
    OPENAI_API_KEY: str = ""
    OPENAI_BASE_URL: str = "https://api.openai.com/v1"
    OPENAI_MODEL_TEXT: str = "gpt-4o-mini"
    OPENAI_MODEL_VISION: str = "gpt-4o-mini"
    OPENAI_TEMPERATURE: float = 0.2
    OPENAI_MAX_TOKENS: int = 512

    # --- (기존) Naver Clova X API 설정 ---
    CLOVA_API_URL: str = ""
    CLOVA_BEARER: str = ""
    CLOVA_API_KEY_ID: str = ""
    CLOVA_API_KEY: str = ""
    CLOVA_REQUEST_ID: str = ""

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
