import os
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# 1. .env 파일에서 환경 변수를 로드합니다.
#    이 코드가 .env 파일에 있는 변수들을 읽어들입니다.
load_dotenv()

# 2. .env 파일에 정의된 DB_URL 환경 변수를 가져옵니다.
SQLALCHEMY_DATABASE_URL = os.getenv("DB_URL")

# 만약 DB_URL이 .env 파일에 없다면, 에러를 발생시켜 문제를 바로 알 수 있게 합니다.
if SQLALCHEMY_DATABASE_URL is None:
    raise ValueError("DB_URL 환경 변수가 설정되지 않았습니다. .env 파일을 확인해주세요.")

# 3. SQLAlchemy 엔진을 생성합니다.
#    이 엔진이 데이터베이스와의 실제 연결을 담당합니다.
engine = create_engine(SQLALCHEMY_DATABASE_URL)

# 4. 데이터베이스 세션(Session)을 생성하는 클래스입니다.
#    autocommit=False: 데이터를 변경했을 때 자동으로 커밋하지 않음 (수동으로 커밋 필요)
#    autoflush=False: 세션에 변경사항을 자동으로 반영하지 않음
#    bind=engine: 이 세션이 사용할 DB 엔진을 지정
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# 5. DB 모델(ORM 클래스)들이 상속받을 기본 클래스입니다.
#    models.py 파일에서 이 Base를 상속받아 테이블 모델을 만들게 됩니다.
Base = declarative_base()


# API가 호출될 때마다 독립적인 DB 세션을 생성하고, 끝나면 닫아주는 함수입니다.
# 이 함수 덕분에 여러 요청이 동시에 들어와도 DB 연결이 꼬이지 않습니다.
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()