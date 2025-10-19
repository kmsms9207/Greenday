import os
import pandas as pd
from sqlalchemy import create_engine
from sklearn.preprocessing import OneHotEncoder
import sys, joblib

# ⭐️ 중요: DB 접속을 위해 프로젝트의 core.config를 import합니다.
# 경로가 맞지 않으면 '..' 등을 추가하여 상위 폴더를 참조해야 할 수 있습니다.
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from core.config import settings

DATABASE_URL = settings.DB_URL

def preprocess_plant_data():
    """
    plants_master 테이블의 데이터를 머신러닝에 사용할 수 있도록
    숫자 형태로 변환(One-Hot Encoding)하고 CSV 파일로 저장합니다.
    """
    if not DATABASE_URL:
        raise ValueError("DB_URL이 .env 파일에 설정되지 않았습니다.")
        
    print("DB에서 식물 데이터를 로드합니다...")
    engine = create_engine(DATABASE_URL)
    
    # pandas를 이용해 plants_master 테이블 전체를 DataFrame으로 읽어옵니다.
    df = pd.read_sql("SELECT id, name_ko, difficulty, light_requirement, pet_safe FROM plants_master", engine)

    print(f"{len(df)}개의 식물 데이터를 로드했습니다. 전처리를 시작합니다...")

    # 1. 범주형(Categorical) 데이터 선택
    # pet_safe는 True/False를 1/0으로 자동 변환 가능하므로 그대로 둡니다.
    categorical_features = ['difficulty', 'light_requirement']
    df_categorical = df[categorical_features]
    
    # 2. One-Hot Encoder 생성 및 학습
    # handle_unknown='ignore'는 나중에 새로운 데이터가 들어와도 에러를 내지 않습니다.
    encoder = OneHotEncoder(sparse_output=False, handle_unknown='ignore')
    encoder.fit(df_categorical)

    # 3. 데이터 변환
    encoded_data = encoder.transform(df_categorical)
    
    # 4. 변환된 데이터를 새로운 컬럼으로 DataFrame에 추가
    # get_feature_names_out()은 'difficulty_상', 'light_requirement_양지' 같은 컬럼명을 만들어줍니다.
    encoded_df = pd.DataFrame(encoded_data, columns=encoder.get_feature_names_out(categorical_features))
    
    # 5. 기존 DataFrame과 병합 및 정리
    final_df = pd.concat([df.reset_index(drop=True), encoded_df], axis=1)
    
    # 원본 텍스트 컬럼과 불필요한 컬럼은 모델 학습에서 제외
    final_df = final_df.drop(columns=['difficulty', 'light_requirement', 'name_ko'])
    
    # pet_safe 컬럼을 숫자(0 또는 1)로 변환
    final_df['pet_safe'] = final_df['pet_safe'].astype(int)

    # 6. 결과 CSV 파일로 저장
    output_path = "ml_scripts/processed_plants.csv"
    final_df.to_csv(output_path, index=False)

    # 7. 학습된 OneHotEncoder (번역기) 저장
    encoder_path = "ml_scripts/plant_encoder.joblib"
    joblib.dump(encoder, encoder_path)
    
    print("-" * 50)
    print("✅ 데이터 전처리가 완료되었습니다.")
    print(f"결과가 '{output_path}' 파일에 저장되었습니다.")
    print("저장된 데이터 샘플:")
    print(final_df.head())
    print("-" * 50)

if __name__ == "__main__":
    # 필요한 라이브러리 설치 확인
    try:
        import pandas
        import sklearn
    except ImportError:
        print("필요한 라이브러리를 먼저 설치해주세요: pip install pandas scikit-learn")
    else:
        preprocess_plant_data()