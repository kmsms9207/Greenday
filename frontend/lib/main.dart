import 'package:flutter/material.dart';
import 'login.dart'; // 로그인 화면 import

// 앱의 유일한 시작점
void main() {
  runApp(const MainApp());
}

// 앱의 전체적인 틀과 설정을 담당
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // 앱이 처음 켜졌을 때 보여줄 화면을 로그인 페이지로 지정
      home: const LoginScreen(),
    );
  }
}
