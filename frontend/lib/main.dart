import 'package:flutter/material.dart';
import 'login.dart'; // 1. 로그인 화면을 import 합니다.
import 'main_screen.dart';

// 앱의 유일한 시작점
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

// 앱의 전체적인 틀과 설정을 담당
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF486B48)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF486B48), width: 2),
          ),
          labelStyle: TextStyle(color: Colors.black),
        ),
      ),
      routes: {
        '/login': (context) => const LoginScreen()
      },
      // 2. 앱이 처음 켜졌을 때 보여줄 화면을 로그인 페이지로 정확히 지정합니다.
      home: const MainScreen(userName: 'test'),
    );
  }
}