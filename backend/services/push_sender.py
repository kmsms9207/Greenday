import firebase_admin
from firebase_admin import credentials, messaging

# 1. Firebase Admin SDK 초기화
try:
    cred = credentials.Certificate("greenday-firebase-credentials.json")
    firebase_admin.initialize_app(cred)
    print("Firebase Admin SDK가 성공적으로 초기화되었습니다.")
except Exception as e:
    print(f"Firebase Admin SDK 초기화 오류: {e}")
    # 실제 운영 환경에서는 logger.error() 등을 사용해 기록해야 합니다.


def send_push_notification(token: str, title: str, body: str):
    """
    Firebase Cloud Messaging(FCM)을 통해 실제 푸시 알림을 발송합니다.
    """
    if not firebase_admin._apps:
        print("Firebase 앱이 초기화되지 않아 푸시를 보낼 수 없습니다.")
        return

    message = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        token=token,
    )
    
    try:
        response = messaging.send(message)
        print(f"[{token[:10]}...]에게 성공적으로 메시지를 보냈습니다: {response}")
        return {"status": "success", "response": response}
    except Exception as e:
        print(f"[{token[:10]}...]에게 메시지 보내기 실패: {e}")
        # 예: 토큰이 유효하지 않은 경우 등 다양한 에러 처리 가능
        return {"status": "error", "message": str(e)}