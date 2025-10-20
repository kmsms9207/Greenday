import 'package:flutter/material.dart';

class MyInfoScreen extends StatelessWidget {
  // 1. MainScreen으로부터 사용자 이름을 전달받기 위한 변수를 선언합니다.
  final String userName;

  // 2. 생성자를 수정하여 userName을 필수로 받도록 설정합니다.
  const MyInfoScreen({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("내 정보")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person, size: 80),
            const SizedBox(height: 24),
            // 3. 전달받은 userName을 화면에 표시합니다.
            Text(
              "$userName 님",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () {
                // 로그인 화면으로 이동하고 이전 페이지들을 모두 제거
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              },
              child: const Text("로그아웃"),
            ),
          ],
        ),
      ),
    );
  }
}
