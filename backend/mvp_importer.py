#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
mvp_importer.py (CSV-First 최종 버전)
1. manual_species_list.csv 에서 핵심 관리 정보(난이도, 햇빛, 물주기 등)를 읽어옵니다.
2. Perenual API에서는 보조 정보(id, image_url, family, 영문명)만 가져와 보강합니다.
3. LLM(Clova X)으로 최종 설명을 생성합니다.
4. 사용법 : python mvp_importer.py
"""
import os
import csv
import json
import time
import argparse
import logging
import re
from typing import Dict, Any, List, Optional

import httpx
from dotenv import load_dotenv
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session
from models import PlantMaster, Base # models.py에서 직접 import

# ------------------------- 환경설정 -------------------------
load_dotenv()
PERENUAL_API_KEY = os.getenv("PERENUAL_API_KEY")
CLOVA_API_URL = os.getenv("CLOVA_API_URL")
CLOVA_BEARER = os.getenv("CLOVA_BEARER")
CLOVA_REQUEST_ID = os.getenv("CLOVA_REQUEST_ID", "mvp-importer")
DATABASE_URL = os.getenv("DB_URL")
USER_AGENT = "MvpImporter/2.0 (contact: team@greenday.local)"
logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
logger = logging.getLogger("mvp_importer")

# ------------------------- HTTP 유틸 -------------------------
def http_get_json(url: str, params: Dict[str, Any] = None) -> Dict[str, Any]:
    with httpx.Client(timeout=30.0, headers={"User-Agent": USER_AGENT}) as client:
        r = client.get(url, params=params or {})
        r.raise_for_status()
        return r.json()

def http_post_json(url: str, json_body: Dict[str, Any], headers: Dict[str, str]) -> Dict[str, Any]:
    with httpx.Client(timeout=60.0, headers=headers) as client:
        r = client.post(url, json=json_body)
        r.raise_for_status()
        return r.json()

# ------------------------- CSV 로드 -------------------------
def fetch_manual_species_list_from_csv(filename: str = "manual_species_list.csv") -> List[Dict[str, Any]]:
    if not os.path.exists(filename):
        logger.error(f"'{filename}'을 찾을 수 없습니다.")
        return []
    results = []
    with open(filename, mode='r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for row in reader:
            # CSV 헤더가 species와 name_ko로 변경되었음을 가정
            if row.get("species") and row.get("name_ko"):
                results.append(row)
    return results

# ------------------------- Perenual -------------------------
def perenual_get_supplementary_data(scientific_name: str) -> Dict[str, Any]:
    """Perenual에서 보조 정보(image_url, family, 영문명)만 가져옵니다."""
    if not PERENUAL_API_KEY: return {}
    try:
        params = {"key": PERENUAL_API_KEY, "q": scientific_name}
        data = http_get_json("https://perenual.com/api/v2/species-list", params=params)
        result = data.get("data", [])
        if not result: return {}
        
        plant = result[0]
        image_data = plant.get("default_image", {}) or {}
        return {
            "image_url": image_data.get("regular_url") or image_data.get("original_url"),
            # family는 CSV에 존재하지만 Perenual에서 가져오는 경우를 대비
            "family": plant.get("family"), 
            "name_en": plant.get("common_name"),
        }
    except Exception as e:
        logger.warning(f"Perenual 보조 정보 조회 오류 ({scientific_name}): {e}")
        return {}

# ------------------------- LLM(Clova) -------------------------
def generate_one_liner_ko(data: Dict[str, Any]) -> str:
    # LLM에게 보낼 핵심 정보만 간추림
    prompt_data = {
        "이름": data.get('name_ko'),
        "난이도": data.get('difficulty'),
        "햇빛": data.get('light_requirement'),
        # 💡 수정: 'watering_type' 필드를 사용
        "물주기": data.get('watering_type'), 
    }
    tmpl = f"{prompt_data['이름']}은(는) 난이도 '{prompt_data['난이도']}'의 식물로, {prompt_data['햇빛']} 환경을 선호합니다."
    if not CLOVA_API_URL or not CLOVA_BEARER: return tmpl
    try:
        headers = {"Authorization": f"Bearer {CLOVA_BEARER}", "X-NCP-CLOVASTUDIO-REQUEST-ID": CLOVA_REQUEST_ID, "Content-Type": "application/json"}
        prompt = f"다음 식물 데이터를 바탕으로, 초보자도 이해하기 쉬운 한국어 한 줄 설명을 100자 이내로 만들어줘.\n\n데이터: {json.dumps(prompt_data, ensure_ascii=False)}"
        body = {"messages": [{"role": "user", "content": prompt}], "maxTokens": 120, "temperature": 0.5}
        res = http_post_json(CLOVA_API_URL, body, headers)
        content = res.get("result", {}).get("message", {}).get("content", tmpl)
        return re.sub(r'\s+', ' ', content).strip()
    except Exception as e:
        logger.warning(f"Clova X 호출 오류: {e}")
        return tmpl

# ------------------------- MAIN 로직 -------------------------
def run(dry_run: bool = False):
    if not DATABASE_URL: raise RuntimeError(".env 파일에 DB_URL이 설정되어야 합니다.")
    engine = create_engine(DATABASE_URL)
    Base.metadata.create_all(engine)

    initial_plants = fetch_manual_species_list_from_csv()
    if not initial_plants: return
    logger.info(f"CSV 파일에서 {len(initial_plants)}개의 식물을 로드했습니다.")

    with Session(engine) as session:
        for plant_data in initial_plants:
            species = plant_data["species"]
            logger.info(f"--- {species} ({plant_data['name_ko']}) 처리 중 ---")

            supplementary_data = perenual_get_supplementary_data(species)
            
            # 최종 DB 삽입을 위한 딕셔너리 구성
            final_row = {
                # 1. CSV에서 가져오는 핵심 정보
                "species": species,
                "name_ko": plant_data.get("name_ko"),
                "difficulty": plant_data.get("difficulty"),
                "light_requirement": plant_data.get("light_requirement"),
                
                # 💡 수정: CSV의 물주기 정보를 'watering_type' 필드에 매핑
                "watering_type": plant_data.get("watering_type"), 
                
                "pet_safe": True if plant_data.get("pet_safe", "").lower() == '안전' else False,
                # CSV의 'family'를 우선 사용. Perenual 정보가 있다면 보조적으로 사용
                "family": plant_data.get("family") or supplementary_data.get("family"), 
                
                # 2. Perenual 또는 NULL 처리 필드 (DB 스키마를 위해 명시적으로 설정)
                "image_url": supplementary_data.get("image_url"),
                "name_en": supplementary_data.get("name_en"),
                "tags": None,
            }
            
            final_row["description"] = generate_one_liner_ko(final_row)
            
            # DB UPSERT
            existing = session.execute(select(PlantMaster).where(PlantMaster.species == species)).scalar_one_or_none()
            if existing:
                logger.info(f"[UPDATE] {species}")
                # final_row에서 description과 created_at을 제외한 모든 키를 업데이트
                update_data = {k: v for k, v in final_row.items() if k not in ['created_at']}
                for key, value in update_data.items(): setattr(existing, key, value)
            else:
                logger.info(f"[INSERT] {species}")
                session.add(PlantMaster(**final_row))
            
            time.sleep(1) # API Rate Limit 회피를 위한 대기

        if dry_run:
            session.rollback()
            logger.info("Dry-run 모드입니다. DB 변경사항을 롤백했습니다.")
        else:
            session.commit()
            logger.info(f"{len(initial_plants)}개의 식물 데이터가 DB에 저장되었습니다.")

# ------------------------- CLI -------------------------
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="CSV 파일을 기반으로 PlantMaster DB를 채웁니다.")
    parser.add_argument("--dry-run", action="store_true", help="DB에 실제로 저장하지 않고 시뮬레이션만 실행합니다.")
    args = parser.parse_args()
    try:
        run(dry_run=args.dry_run)
    except Exception as e:
        logger.exception(f"스크립트 실행 중 오류 발생: {e}")