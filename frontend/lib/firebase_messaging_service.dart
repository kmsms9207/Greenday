import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

class FirebaseMessagingService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize(BuildContext context) async {
    // 1. 권한 요청 부분을 try-catch로 감쌉니다.
    try {
      print("Requesting notification permission...");
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );
      print('Permission status: ${settings.authorizationStatus}');
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        print('User declined or has not accepted permission');
      }
    } catch (e) {
      // 권한 요청 중 오류 발생 시 메시지 출력
      print("!!!!! Error requesting permission: $e !!!!!");
    }

    // 2. 토큰 가져오기 부분을 try-catch로 감쌉니다.
    try {
      print("Getting FCM token...");
      String? fcmToken = await _firebaseMessaging.getToken();
      print("FirebaseMessaging Token: $fcmToken");
      // TODO: 서버 등록 로직 (login.dart에서 처리)
    } catch (e) {
      // 토큰 가져오기 중 오류 발생 시 메시지 출력
      print("!!!!! Error getting FCM token: $e !!!!!");
    }

    // 3. 리스너 설정 부분을 try-catch로 감쌉니다.
    try {
      print("Setting up message listeners...");
      // Foreground 메시지 리스너
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Foreground message received: ${message.messageId}');
        if (message.notification != null) {
          print('Foreground notification: ${message.notification}');
          showDialog(
            context: context,
            builder: (context) => AlertDialog(/* ... 팝업 내용 ... */),
          );
        }
      });

      // Background 알림 탭 리스너
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('Background notification tapped: ${message.messageId}');
        _handleNotificationClick(context, message.data);
      });

      // Terminated 알림 탭 처리
      RemoteMessage? initialMessage = await _firebaseMessaging
          .getInitialMessage();
      if (initialMessage != null) {
        print(
          'Terminated app opened by notification: ${initialMessage.messageId}',
        );
        Future.delayed(const Duration(seconds: 1), () {
          _handleNotificationClick(context, initialMessage.data);
        });
      }

      // 백그라운드 메시지 핸들러 설정
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      print("Message listeners set up successfully.");
    } catch (e) {
      // 리스너 설정 중 오류 발생 시 메시지 출력
      print("!!!!! Error setting up message listeners: $e !!!!!");
    }
  }

  void _handleNotificationClick(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    // 알림 클릭 시 화면 이동 로직 (기존 코드 유지)
    final String? screen = data['screen'];
    final String? plantId = data['plant_id'];
    print("Handling notification click, screen: $screen, plantId: $plantId");
    // TODO: 실제 화면 이동 코드 구현
  }
}
