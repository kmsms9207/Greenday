# backend/services/remedy.py
from __future__ import annotations
from typing import Dict, List, Tuple

# v3에서 사용하는 disease_key 정규화와 동일 규칙 일부 반영
def _norm_key(s: str) -> str:
    return (s or "").strip().lower().replace("-", "_").replace(" ", "_").replace("__", "_")

def normalize_disease_key(name: str) -> str:
    k = _norm_key(name)
    synonyms = {
        "gray_mold": "botrytis",
        "botrytis_gray_mold": "botrytis",
        "sooty_mould": "sooty_mold",
        "powdery mildew": "powdery_mildew",
        "downy mildew": "downy_mildew",
        "leaf miner": "leaf_miner",
        "spider_mite": "spider_mites",
        "mealybug": "mealybugs",
        "scale": "scale_insects",
        "whitefly": "whiteflies",
        "thrip": "thrips",
        "mosaic_virus": "virus_mosaic",
        "mosaic": "virus_mosaic",
        "late_blight": "late_blight",
        "early_blight": "early_blight",
        "leaf_spots": "leaf_spot",
    }
    return synonyms.get(k, k)

# 한국어 병명 간단 매핑(진단 단계에서 이미 disease_ko가 있으면 그걸 우선 사용)
DISEASE_KO: Dict[str, str] = {
    "powdery_mildew": "흰가루병",
    "downy_mildew": "노균병",
    "leaf_spot": "잎마름병/반점병",
    "anthracnose": "탄저병",
    "bacterial_leaf_spot": "세균성 잎반점병",
    "rust": "녹병",
    "early_blight": "겹무늬병",
    "late_blight": "역병",
    "botrytis": "회색곰팡이병(보트리티스)",
    "sooty_mold": "그을음병",
    "chlorosis": "엽록소결핍(황화)",
    "leaf_scorch": "잎마름/잎끝타들음",
    "edema": "부종",
    "root_rot": "뿌리썩음",
    "overwatering_damage": "과습 피해",
    "underwatering_damage": "건조 피해",
    "sunburn": "일소 피해",
    "spider_mites": "응애",
    "mealybugs": "깔따구/깍지진딧물(밀가루깍지벌레)",
    "scale_insects": "깍지벌레",
    "aphids": "진딧물",
    "thrips": "총채벌레",
    "whiteflies": "가루이",
    "leaf_miner": "굴파리",
    "virus_mosaic": "바이러스 모자이크",
    "unknown": "불확실",
}

# 각 병해충별 기본 가이드(실내 관엽/가정용 기준, 약제는 '라벨 따르기' 원칙)
# severity: HIGH/MEDIUM/LOW에 따라 즉각할 일/관리 강도 달리 적용
REMEDY_DB: Dict[str, Dict[str, List[str]]] = {
    "powdery_mildew": {
        "immediate": [
            "병든 잎을 가능한 한 즉시 제거하고 일반 쓰레기로 폐기(퇴비 금지).",
            "공기 순환을 위해 식물 주변을 띄워 배치하고 과습을 피함.",
            "잎을 물에 적시지 말고 상부 관수 대신 바닥 관수 권장.",
        ],
        "care": [
            "실내용 원예용 살균제(흰가루병 표기) 제품을 라벨 지침에 따라 희석·살포.",
            "가벼운 경우 베이킹소다 1L당 1/4~1/2작은술 + 유화제 소량 혼합해 시험 살포(민감종 주의).",
            "1주 간격으로 2~3회 재관찰 후 필요시 반복.",
        ],
        "prevent": [
            "과습·통풍불량 개선, 과다 질소비료 지양.",
            "가지치기로 내부 밀도 낮추기.",
        ],
        "caution": [
            "약제는 실내용/가정원예 등록 제품만 사용, 라벨의 희석배수·환기·보호장비 준수.",
            "애완동물/유아 접근 금지, 약제 건조 전 접촉 금지.",
        ],
        "pro": [
            "잎 전체가 하얗게 뒤덮이고 신초가 왜화되는 등 급속 확산 시.",
            "민감 고가 식물에서 반복 재발 시.",
        ],
    },
    "downy_mildew": {
        "immediate": [
            "감염 잎 제거·폐기, 저녁/습한 시간대 분무 중단.",
            "통풍 증대 및 밀식 해소.",
        ],
        "care": [
            "라벨에 '노균병' 표기된 실내용 살균제 사용, 7일 간격 관찰.",
            "관수는 흙이 마른 뒤 아침 시간대에 실시.",
        ],
        "prevent": [
            "밤 사이 잎이 젖어있지 않도록 습도 관리(50~60% 권장).",
            "하부에서 물주기, 받침물 물은 바로 버리기.",
        ],
        "caution": ["낙엽은 실내 보관 금지, 즉시 폐기."],
        "pro": ["새 잎까지 급격히 전염되면 약제 순환계열 전환·전문가 상담."],
    },
    "leaf_spot": {
        "immediate": [
            "갈색/검은 반점 잎을 깨끗한 도구로 제거·폐기.",
            "물방울 튐 최소화(상부 분무 중단).",
        ],
        "care": [
            "세균성 의심 시 살균제보다는 위생·통풍 개선이 핵심.",
            "곰팡이성 의심 시 병명표기 살균제 라벨대로 살포.",
        ],
        "prevent": ["잎 표면 장시간 습윤 회피, 과비·광부족 교정."],
        "caution": ["도구 소독(알코올/락스 희석), 재사용 토양 금지."],
        "pro": ["반점이 중심부에서 바깥으로 급속히 확대 시 폐기 고려."],
    },
    "anthracnose": {
        "immediate": ["병반 잎·줄기 제거, 상처부 건조 유지.", "관수 후 통풍."],
        "care": [
            "탄저병 표기 살균제 라벨대로 사용, 7~10일 간격 재점검.",
            "광량·환기 확보로 조직 강화.",
        ],
        "prevent": ["밀식·과습 감소, 도구/분갈이 위생관리."],
        "caution": ["민감종은 저농도로 소면적 시험 살포 후 확대."],
        "pro": ["새순 괴사·전식 시 전문가 상담."],
    },
    "bacterial_leaf_spot": {
        "immediate": ["수분 접촉 최소화, 상처부 접촉 금지.", "감염 조직 제거·폐기."],
        "care": [
            "세균성은 약제 효과 제한적, 위생·건조·통풍이 중요.",
            "동제(구리) 성분 제품은 민감종에 약해 가능성, 소규모 테스트 후 결정.",
        ],
        "prevent": ["물 튀김 방지, 도구 소독, 식물 간 거리 확보."],
        "caution": ["잎 표면 젖은 상태로 야간 유지 금지."],
        "pro": ["수침상 병반이 빠르게 퍼지고 줄기 괴사 시 폐기 고려."],
    },
    "rust": {
        "immediate": ["뒷면의 녹갈색 포자 부착 잎 제거·폐기.", "환기 강화."],
        "care": ["녹병 표기 살균제 사용, 7일 후 재점검.", "감염 잎 반복 제거."],
        "prevent": ["밀식 피하고 햇빛/통풍 균형."],
        "caution": ["잎 문지르지 말 것(포자 확산)."],
        "pro": ["신초까지 변색/왜화 시 전문가 상담."],
    },
    "early_blight": {
        "immediate": ["병든 잎 제거, 물 튐 방지."],
        "care": ["겹무늬병 표기 살균제 라벨대로 처리."],
        "prevent": ["낙엽 정리, 통풍, 균형 시비."],
        "caution": ["과도한 잎 제거는 광합성 저하 유의."],
        "pro": ["줄기 괴사·과다 낙엽 시."],
    },
    "late_blight": {
        "immediate": ["감염부 신속 제거·폐기, 인접 식물 격리.", "과습 중단·통풍 최대화."],
        "care": [
            "역병 표기 살균제 사용(실내용/가정원예 등록 제품), 지침 준수.",
            "급속 확산 시 오염 범위 폐기 권고.",
        ],
        "prevent": ["배수 개선, 잎 젖은 상태 방지.", "용기/토양 교체 검토."],
        "caution": ["재사용 토양 금지, 분 무기구 소독 철저."],
        "pro": ["수일 내 전식하는 경우 즉시 확산 차단."],
    },
    "botrytis": {
        "immediate": ["회색 곰팡이/솜털 보이면 해당 부위 즉시 제거·폐기.", "환기·건조 강화."],
        "care": ["보트리티스 표기 살균제 사용, 5~7일 관찰.", "감염 부위 건조 유지."],
        "prevent": ["낙엽·꽃대 제거 습관화, 과습 회피."],
        "caution": ["꽃/연한 조직 약해 주의, 저농도 시험."],
        "pro": ["꽃/새순 전면 감염 시 신속 대응 필요."],
    },
    "sooty_mold": {
        "immediate": ["잎 표면 끈적임(감로) 및 검은 그을음은 젖은 천으로 부드럽게 닦기."],
        "care": ["감로 원인 해충(진딧물/가루이/깍지벌레 등) 동시 방제."],
        "prevent": ["해충 초기 탐지·방제, 잎 표면 정기 세척."],
        "caution": ["강한 세제로 문지르지 말 것(잎 상처)."],
        "pro": ["그을음 재발 시 해충 근원 정밀 탐색 필요."],
    },
    "chlorosis": {
        "immediate": ["배수 점검, 과습/건조 교정."],
        "care": ["철분 결핍 의심 시 킬레이트 철분 비료 소량 보충(라벨 기준)."],
        "prevent": ["적정 pH 유지, 균형 시비."],
        "caution": ["과비 금지, 원인 파악 우선."],
        "pro": ["정상 광량/급수에도 진행 시 토양·뿌리 진단 필요."],
    },
    "leaf_scorch": {
        "immediate": ["직사광·열풍 회피, 엽면 수분 증발 억제 환경으로 이동."],
        "care": ["손상 잎은 점진적으로 제거, 뿌리 스트레스 완화 관수."],
        "prevent": ["강광 환경엔 순치 후 점진 노출."],
        "caution": ["과습 보상 과잉 급수 금지."],
        "pro": ["새잎 계속 마름 시 뿌리계 점검."],
    },
    "edema": {
        "immediate": ["밤 사이 과습·저온 확인, 관수 간격 늘리기."],
        "care": ["과습 교정 후 자연 회복 관찰, 잎 표면 통풍."],
        "prevent": ["밤 관수 피하기, 배수/통풍 확보."],
        "caution": ["병해로 오인해 불필요 약제 사용 금지."],
        "pro": ["수포·코르크화가 전면 확산 시 환경 재설계 필요."],
    },
    "root_rot": {
        "immediate": ["물에 젖은 토양 제거, 뿌리 세척 후 썩은 뿌리 절단·소독.", "배수 좋은 토양으로 분갈이."],
        "care": ["관수는 새 뿌리 발생까지 최소화, 과습 원인 제거(받침물 물 비우기)."],
        "prevent": ["배수층/통기성 토양, 과습 주기 교정."],
        "caution": ["분갈이 도구 소독, 오염 토양 재사용 금지."],
        "pro": ["뿌리 대부분 흑갈색 괴사 시 회생 어려움—삽수 번식 고려."],
    },
    "overwatering_damage": {
        "immediate": ["과습 해소(받침물 물 버리기), 통풍·광량 확보."],
        "care": ["토양 2~3cm 건조 확인 후 관수, 뿌리 악취·질감 점검."],
        "prevent": ["화분 크기/토양 물빠짐 재평가."],
        "caution": ["회복 전 잦은 분무 금지."],
        "pro": ["잎 대량 낙엽 지속 시 뿌리 썩음 동반 의심."],
    },
    "underwatering_damage": {
        "immediate": ["바닥 관수로 토양 전체 적심 후 과잉수 배출.", "고온·강풍 회피."],
        "care": ["주기/양을 식물·화분 크기에 맞게 재설정."],
        "prevent": ["토양 수분계 활용/손가락 테스트 습관화."],
        "caution": ["한 번에 과도한 급수로 과습 전환 주의."],
        "pro": ["급수 교정 후에도 시듦 지속 시 뿌리 상태 점검."],
    },
    "sunburn": {
        "immediate": ["직사광 차단, 반그늘 이동."],
        "care": ["손상 잎은 광합성 가능하면 유지 후 점진 제거."],
        "prevent": ["광량은 1~2주에 걸쳐 점진 노출(순치)."],
        "caution": ["유리창 뒤 초여름 직광 주의."],
        "pro": ["새잎까지 지속적으로 생기면 위치·광관리 재설계."],
    },
    "spider_mites": {
        "immediate": ["잎 뒷면 중심으로 미지근한 물샤워 세척(거미줄 제거).", "감염 식물 격리."],
        "care": [
            "원예용 살충비누 또는 식물성 오일(Neem 등) 제품 라벨대로 3~4일 간격 반복 처리.",
            "심하면 실내용 등록 살충제 라벨 지침 준수.",
        ],
        "prevent": ["실내 건조기 피하고 적정 습도 유지.", "정기적 잎 뒷면 점검."],
        "caution": ["민감종 약해 주의, 소면적 시험 후 전처리."],
        "pro": ["연쇄 감염/재발 잦으면 약제 교대살포·전문가 상담."],
    },
    "mealybugs": {
        "immediate": ["면봉에 알코올 묻혀 점형 제거, 감염 부위 세척.", "격리."],
        "care": ["살충비누/식물성 오일 반복 처리, 필요시 실내용 등록 살충제 사용."],
        "prevent": ["새 식물 도입 시 2주 격리 관찰."],
        "caution": ["관절·겨드랑이 부위 집중 점검."],
        "pro": ["줄기·뿌리 내부까지 퍼지면 박멸 어렵고 폐기 고려."],
    },
    "scale_insects": {
        "immediate": ["딱딱한 깍지 제거(스크레이핑), 격리."],
        "care": ["오일계 제품 침투 효과 활용, 반복 처리.", "심하면 실내용 등록 살충제 사용."],
        "prevent": ["통풍·광량 개선, 새 식물 검역."],
        "caution": ["잎 상처 주지 않도록 기계적 제거 시 주의."],
        "pro": ["내부 목질화 줄기로 확산 시 박멸 난이도 높음."],
    },
    "aphids": {
        "immediate": ["물살 세척으로 군체 제거, 감염 식물 격리."],
        "care": ["살충비누/오일제 라벨대로 처리, 3~4일 간격 반복."],
        "prevent": ["새순 시기 집중 관찰, 감로 제거."],
        "caution": ["개화기 화분엔 벌 방문 고려해 실내용 약제만 사용."],
        "pro": ["감염 범위가 빠르게 확대되면 전문가 상담."],
    },
    "thrips": {
        "immediate": ["손상 꽃/잎 제거·폐기, 격리.", "점착트랩(파랑)으로 성충 모니터링."],
        "care": ["실내용 등록 살충제/살충비누 교대살포, 라벨 준수."],
        "prevent": ["환기·청결, 원예도구 소독."],
        "caution": ["꽃잎 얇은 식물 약해 주의."],
        "pro": ["재발 잦고 신초 왜화 지속 시 전문가 상담."],
    },
    "whiteflies": {
        "immediate": ["잎 뒷면 성충 털어내고 격리.", "노랑/파랑 점착트랩 설치."],
        "care": ["살충비누/오일/실내용 등록 살충제 라벨 준수 반복 처리."],
        "prevent": ["환기 확보, 과밀식재 완화."],
        "caution": ["알·약충 단계까지 반복 관리 필요."],
        "pro": ["실내 전파 징후면 즉시 방제 전략 강화."],
    },
    "leaf_miner": {
        "immediate": ["굴 터널 잎 제거·폐기.", "격리."],
        "care": ["성충 방제 병행, 라벨 지침 준수.", "피해 잎은 빠르게 제거가 핵심."],
        "prevent": ["방충망/트랩으로 성충 유입 억제."],
        "caution": ["살충제는 알·약충·성충 단계별 접근 필요."],
        "pro": ["새잎 지속 터널 발생 시 전문 방제 필요."],
    },
    "virus_mosaic": {
        "immediate": ["감염 의심 개체는 즉시 격리.", "도구·손 소독."],
        "care": ["바이러스는 치료 불가. 중요한 컬렉션이면 폐기 권장."],
        "prevent": ["해충(진딧물 등) 매개 차단, 새 식물 검역 철저."],
        "caution": ["접목/삽목 도구 공유 금지."],
        "pro": ["컬렉션/상업 목적이면 즉시 폐기·소독 권장."],
    },
    "unknown": {
        "immediate": [
            "선명한 잎 앞/뒷면 근접샷, 전체샷 추가 촬영.",
            "상부 분무 중단, 통풍 확보, 과습 중단.",
        ],
        "care": [
            "1~2일 관찰 후 진행 방향 평가.",
            "동일 증상 반복 시 샘플 추가 업로드 권장.",
        ],
        "prevent": ["물주기/광량/통풍 기준 점검."],
        "caution": ["확실치 않은 약제 무분별 사용 금지."],
        "pro": ["급속 진행/전염 의심 시 격리·폐기 고려."],
    },
}

def pick_severity(user_given: str | None, score: float | None) -> str:
    if user_given in {"LOW", "MEDIUM", "HIGH"}:
        return user_given
    # 점수 기준은 진단단에서 HIGH(>=0.8), MEDIUM(>=0.5)와 일치
    if score is None:
        return "MEDIUM"
    if score >= 0.8:
        return "HIGH"
    if score >= 0.5:
        return "MEDIUM"
    return "LOW"

def get_remedy(disease_key: str, disease_ko_hint: str | None, severity_hint: str | None, score: float | None, plant_name: str | None = None):
    key = normalize_disease_key(disease_key or "unknown")
    data = REMEDY_DB.get(key) or REMEDY_DB["unknown"]
    disease_ko = disease_ko_hint or DISEASE_KO.get(key, key)
    sev = pick_severity(severity_hint, score)

    # 심각도에 따라 즉시 조치/관리 플랜 강조도 변경(간단 규칙)
    immediate = list(data["immediate"])
    care = list(data["care"])
    if sev == "HIGH":
        immediate = ["[우선순위↑] " + s for s in immediate] + ["증상 급속 확산 시 감염부 과감히 제거·폐기."]
        care = ["[빈도↑] " + s for s in care]
    elif sev == "LOW":
        care = ["[관찰] " + s for s in care]

    title = f"{disease_ko} 해결 가이드"
    summary = f"{plant_name or '식물'}에서 의심되는 '{disease_ko}' 대응 요약입니다. 심각도: {sev}."

    return {
        "disease_key": key,
        "disease_ko": disease_ko,
        "title_ko": title,
        "severity": sev,
        "summary_ko": summary,
        "immediate_actions": immediate,
        "care_plan": care,
        "prevention": data["prevent"],
        "caution": data["caution"],
        "when_to_call_pro": data["pro"],
    }
