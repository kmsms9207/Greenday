import os
from datetime import datetime, date
from apscheduler.schedulers.blocking import BlockingScheduler
from sqlalchemy import create_engine, and_
from sqlalchemy.orm import Session


from core.config import settings
from models import Plant, User, PlantMaster
from services.push_sender import send_push_notification # ⭐️ 푸시 발송 서비스 (별도 구현 필요)
from core.constants import WATERING_CYCLE_MAP # ⭐️ 우리가 정의한 물주기 주기 맵

DATABASE_URL = settings.DB_URL
engine = create_engine(DATABASE_URL)

def check_watering_schedules():
    """매일 실행될 메인 스케줄러 함수"""
    today = date.today()
    print(f"[{datetime.now()}] 스케줄러 실행: 오늘 날짜 - {today}")
    
    notifications_to_send = {} # {user_id: [plant_name_1, plant_name_2, ...]}

    with Session(engine) as db:
        # 1. 알림이 켜져 있고, 미루기 상태가 아닌 모든 식물을 조회
        plants_to_check = db.query(Plant).filter(
            Plant.is_notification_enabled == True,
            and_(
                Plant.notification_snoozed_until == None,
                Plant.notification_snoozed_until < today
            )
        ).all()

        for plant in plants_to_check:
            # 2. PlantMaster 정보를 join하여 watering_type 가져오기
            master_info = db.query(PlantMaster).filter(PlantMaster.species == plant.species).first()
            if not master_info or not master_info.watering_type:
                continue

            # 3. 다음 물 줄 날짜 계산
            cycle_days = WATERING_CYCLE_MAP.get(master_info.watering_type, 7) # 기본값 7일
            if not plant.last_watered_at:
                continue
                
            next_watering_date = plant.last_watered_at.date() + timedelta(days=cycle_days)

            # 4. 오늘이 물 주는 날인지 확인
            if next_watering_date == today:
                user_id = plant.owner_id
                if user_id not in notifications_to_send:
                    notifications_to_send[user_id] = []
                notifications_to_send[user_id].append(plant.name)

    print(f"알림 발송 대상: {len(notifications_to_send)}명")
    
    # 5. 사용자별로 그룹화된 알림 발송
    with Session(engine) as db:
        for user_id, plant_names in notifications_to_send.items():
            user = db.query(User).filter(User.id == user_id).first()
            if not user or not user.push_token: # ⭐️ User 모델에 push_token 컬럼이 있다고 가정
                continue

            plant_list_str = ", ".join(plant_names)
            message = (
                f"오늘은 {plant_list_str} 물 주는 날이에요! 💧\n"
                "※ 흙 상태를 먼저 확인하고, 축축하다면 1~2일 뒤에 주세요."
            )
            
            # 실제 푸시 알림 발송 로직 호출
            send_push_notification(user.push_token, "Green Day 물주기 알림", message)
            print(f"  - User {user_id}에게 푸시 발송 완료: {plant_list_str}")

# --- 스케줄러 설정 및 실행 ---
scheduler = BlockingScheduler(timezone='Asia/Seoul')

# 매일 오전 9시에 check_watering_schedules 함수 실행
scheduler.add_job(check_watering_schedules, 'cron', hour=9, minute=0)

if __name__ == "__main__":
    print("스케줄러를 시작합니다. (매일 오전 9시 실행)")
    scheduler.start()
