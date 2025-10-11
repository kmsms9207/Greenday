def send_push_notification(token: str, title: str, body: str):
    """
    실제 푸시 알림을 발송하는 서비스 함수입니다.
    (현재는 테스트를 위해 콘솔에 출력하는 가상(mock) 기능으로 구현)
    
    Args:
        token (str): 알림을 받을 사용자의 디바이스 푸시 토큰
        title (str): 푸시 알림의 제목
        body (str): 푸시 알림의 내용
    """
    
    print("--- 푸시 알림 발송 ---")
    print(f"To: {token}")
    print(f"Title: {title}")
    print(f"Body: {body}")
    print("--------------------------")

    # TODO: 추후 실제 FCM 연동 로직을 여기에 구현합니다.
    # 예시:
    # import firebase_admin
    # from firebase_admin import credentials, messaging
    #
    # if not firebase_admin._apps:
    #     cred = credentials.Certificate("path/to/your/firebase-credentials.json")
    #     firebase_admin.initialize_app(cred)
    #
    # message = messaging.Message(
    #     notification=messaging.Notification(title=title, body=body),
    #     token=token,
    # )
    # response = messaging.send(message)
    # print('Successfully sent message:', response)
    
    return {"status": "success", "message": "Notification sent (mock)"}