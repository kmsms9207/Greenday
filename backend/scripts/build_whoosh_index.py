import os
import sys
from sqlalchemy import create_engine
import pandas as pd
from whoosh.index import create_in, open_dir
from whoosh.fields import Schema, TEXT, ID, KEYWORD, BOOLEAN
from whoosh.analysis import NgramTokenizer # 한글 검색을 위한 분석기

# 프로젝트 루트 경로 설정
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from core.config import settings

DATABASE_URL = settings.DB_URL
INDEX_DIR = "indexdir" # Whoosh 인덱스 파일이 저장될 폴더 이름

def define_schema():
    """Whoosh 인덱스 스키마 (검색할 필드 정의)"""
    # NgramTokenizer: '몬스테라'를 '몬스', '스테', '테라', '라' 등으로 분리하여 부분 검색 지원
    ngram_analyzer = NgramTokenizer(minsize=1, maxsize=3) # 1~3글자 단위로 분리

    return Schema(
        id=ID(stored=True, unique=True), # DB ID (결과 반환용)
        name_ko=TEXT(stored=True, analyzer=ngram_analyzer), # 한글 이름 (검색 대상)
        name_en=TEXT(stored=True),
        species=KEYWORD(stored=True), # 학명 (정확히 일치)
        description=TEXT(analyzer=ngram_analyzer), # 설명 (검색 대상)
        # 검색 필터링에 사용할 수 있는 필드들
        difficulty=KEYWORD(stored=True),
        light_requirement=KEYWORD(stored=True),
        pet_safe=BOOLEAN(stored=True)
    )

def build_index():
    """DB 데이터를 읽어 Whoosh 인덱스를 생성/업데이트합니다."""
    if not DATABASE_URL:
        raise ValueError(".env 파일에 DB_URL이 설정되어야 합니다.")

    print("DB에서 식물 데이터를 로드합니다...")
    engine = create_engine(DATABASE_URL)
    df = pd.read_sql("SELECT * FROM plants_master", engine)
    print(f"{len(df)}개의 식물 데이터를 로드했습니다.")

    # 인덱스 디렉토리 생성
    if not os.path.exists(INDEX_DIR):
        os.mkdir(INDEX_DIR)

    # 스키마 정의 및 인덱스 생성 (기존 파일이 있으면 덮어씀)
    schema = define_schema()
    ix = create_in(INDEX_DIR, schema)
    writer = ix.writer()

    print("Whoosh 인덱스 생성을 시작합니다...")
    added_count = 0
    for index, row in df.iterrows():
        # NaN 값을 None으로 변환
        doc = {
            "id": str(row["id"]), # ID는 문자열로 저장
            "name_ko": row["name_ko"],
            "name_en": row["name_en"],
            "species": row["species"],
            "description": row["description"],
            "difficulty": row["difficulty"],
            "light_requirement": row["light_requirement"],
            # pet_safe가 None/NaN이면 False로 처리
            "pet_safe": bool(row["pet_safe"]) if pd.notna(row["pet_safe"]) else False
        }
        # None 값 필드 제거
        doc_cleaned = {k: v for k, v in doc.items() if pd.notna(v)}
        try:
            writer.add_document(**doc_cleaned)
            added_count += 1
        except Exception as e:
            print(f"Error adding document ID {row['id']}: {e}")

    print(f"{added_count}개 문서 인덱싱 중...")
    writer.commit()

    print("-" * 50)
    print(f"✅ Whoosh 인덱스 생성이 완료되었습니다. ('{INDEX_DIR}' 폴더)")
    print("-" * 50)

if __name__ == "__main__":
    build_index()