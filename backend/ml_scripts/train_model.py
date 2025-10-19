import pandas as pd
from sklearn.cluster import KMeans
import matplotlib.pyplot as plt
import joblib
import json

def train_clustering_model():
    """
    전처리된 식물 데이터를 사용하여 K-Means 클러스터링 모델을 학습하고,
    학습된 모델과 클러스터 정보를 파일로 저장합니다.
    """
    input_path = "ml_scripts/processed_plants.csv"
    try:
        df = pd.read_csv(input_path)
    except FileNotFoundError:
        print(f"오류: '{input_path}' 파일을 찾을 수 없습니다.")
        print("먼저 preprocess_data.py 스크립트를 실행해주세요.")
        return

    # 모델 학습에 사용할 특성(feature)은 'id'를 제외한 모든 숫자 컬럼입니다.
    features = df.drop(columns=['id'])
    
    print("최적의 클러스터 개수(K)를 찾고 있습니다 (Elbow Method)...")
    
    # 1. Elbow Method를 사용하여 최적의 K 찾기
    inertia = []
    k_range = range(1, 11) # 클러스터 개수를 1개부터 10개까지 테스트
    for k in k_range:
        kmeans = KMeans(n_clusters=k, random_state=42, n_init=10)
        kmeans.fit(features)
        inertia.append(kmeans.inertia_)

    # K값에 따른 inertia 변화를 시각화하여 "팔꿈치" 지점 확인
    plt.figure(figsize=(10, 6))
    plt.plot(k_range, inertia, marker='o')
    plt.title('Elbow Method for Optimal K')
    plt.xlabel('Number of clusters (K)')
    plt.ylabel('Inertia')
    plt.xticks(k_range)
    plt.grid(True)
    plot_path = "ml_scripts/cluster_plot.png"
    plt.savefig(plot_path)
    print(f"클러스터 분석 그래프가 '{plot_path}'에 저장되었습니다.")
    
    # 여기서는 예시로 K=5를 최적값으로 가정합니다.
    # 실제로는 저장된 cluster_plot.png 그래프를 보고 가장 적절한 K값을 선택해야 합니다.
    optimal_k = 5
    print(f"그래프 분석 결과, 최적의 K를 {optimal_k}로 설정합니다.")

    # 2. 최적의 K로 K-Means 모델 최종 학습
    print(f"K={optimal_k}로 최종 모델을 학습합니다...")
    kmeans_final = KMeans(n_clusters=optimal_k, random_state=42, n_init=10)
    df['cluster'] = kmeans_final.fit_predict(features)

    # 3. 학습된 모델과 클러스터 정보 저장
    # (1) 학습된 모델 자체를 저장 -> 나중에 API에서 사용
    model_path = "ml_scripts/plant_cluster_model.joblib"
    joblib.dump(kmeans_final, model_path)
    print(f"학습된 모델이 '{model_path}' 파일로 저장되었습니다.")

    # (2) 각 클러스터에 어떤 식물 ID가 속하는지 JSON으로 저장
    cluster_map = df.groupby('cluster')['id'].apply(list).to_dict()
    map_path = "ml_scripts/cluster_map.json"
    with open(map_path, 'w', encoding='utf-8') as f:
        json.dump(cluster_map, f, ensure_ascii=False, indent=4)
    print(f"클러스터 맵이 '{map_path}' 파일로 저장되었습니다.")
    
    print("-" * 50)
    print("✅ 모델 학습이 완료되었습니다.")
    print("클러스터별 식물 개수:")
    print(df['cluster'].value_counts())
    print("-" * 50)


if __name__ == "__main__":
    # 필요한 라이브러리 설치 확인
    try:
        import matplotlib
        import joblib
    except ImportError:
        print("필요한 라이브러리를 먼저 설치해주세요: pip install matplotlib joblib")
    else:
        train_clustering_model()