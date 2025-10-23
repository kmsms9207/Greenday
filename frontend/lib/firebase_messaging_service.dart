import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

// 백그라운드에서 메시지를 처리하기 위한 최상위 함수
// @pragma('vm:entry-point') // Flutter 3.3.0 이상에서는 필요 없을 수 있음
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드/종료 상태에서 알림을 받았을 때 실행할 로직
  // Firebase.initializeApp() 호출이 필요할 수 있음 (앱 실행 시 이미 호출됨)
  // await Firebase.initializeApp(); // 필요 시 주석 해제

  print("Handling a background message: ${message.messageId}");
  print('Message data: ${message.data}');
  if (message.notification != null) {
    print('Message also contained a notification: ${message.notification}');
  }
  // 여기서 알림 데이터를 로컬 저장소에 저장하거나,
  // 특정 백그라운드 작업을 트리거할 수 있습니다.
}

class FirebaseMessagingService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Firebase 메시징 서비스 초기화
  Future<void> initialize(BuildContext context) async {
    // 1. 알림 권한 요청 (iOS 및 Android 13 이상)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('User declined or has not accepted permission');
      // 권한이 거부된 경우 사용자에게 안내 필요
    }

    // 2. FCM 토큰 가져오기 (login.dart에서도 호출하지만, 여기서도 확인 가능)
    String? fcmToken = await _firebaseMessaging.getToken();
    print("FirebaseMessaging Token: $fcmToken");
    // TODO: 필요하다면 여기서도 토큰을 서버에 등록하는 로직 추가 (앱 업데이트 시 등)

    // 3. 앱이 실행 중일 때 (Foreground) 메시지 수신 리스너 설정
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        // Foreground 상태에서는 알림이 자동으로 표시되지 않으므로,
        // 여기서 로컬 알림을 띄우거나 앱 내 UI를 업데이트하는 로직 필요
        // 예: flutter_local_notifications 패키지 사용
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(message.notification?.title ?? "새 알림"),
            content: Text(message.notification?.body ?? ""),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("확인"),
              ),
            ],
          ),
        );
      }
    });

    // 4. 앱이 백그라운드 상태에 있을 때 알림을 탭하여 열었을 경우 처리
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      print('Message data: ${message.data}');
      _handleNotificationClick(context, message.data);
    });

    // 5. 앱이 종료된(Terminated) 상태에서 알림을 탭하여 열었을 경우 처리
    RemoteMessage? initialMessage = await _firebaseMessaging
        .getInitialMessage();
    if (initialMessage != null) {
      print('Terminated app opened by notification');
      print('Message data: ${initialMessage.data}');
      // 앱 로딩이 완료된 후 처리하기 위해 약간의 지연 추가
      Future.delayed(Duration(seconds: 1), () {
        _handleNotificationClick(context, initialMessage.data);
      });
    }

    // 6. 백그라운드 메시지 핸들러 설정
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // 알림 클릭 시 특정 화면으로 이동하는 로직 (예시)
  void _handleNotificationClick(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    // 백엔드에서 보낸 데이터에 따라 분기 처리
    final String? screen = data['screen']; // 예: 'plant_detail'
    final String? plantId = data['plant_id']; // 예: '101'

    print("Handling notification click, screen: $screen, plantId: $plantId");

    if (screen == 'plant_detail' && plantId != null) {
      // TODO: plant_info.dart 화면으로 이동하는 코드 구현
      // Navigator.push(context, MaterialPageRoute(builder: (context) => PlantInfoScreen(plantId: int.parse(plantId))));
      print("Navigate to Plant Detail Screen with ID: $plantId");
    } else if (screen == 'notification_list') {
      // TODO: notification.dart 화면으로 이동하는 코드 구현
      // Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationScreen()));
      print("Navigate to Notification List Screen");
    }
    // TODO: 다른 종류의 알림에 대한 처리 추가
  }
}
