import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login.dart'; // 인증 성공 후 돌아갈 로그인 화면

class VerifyEmailScreen extends StatefulWidget {
  final String email; // 회원가입 화면에서 전달받은 이메일 주소

  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _tokenController = TextEditingController();

  // 이메일 인증 API를 호출하는 함수
  Future<void> attemptVerification() async {
    const String apiUrl =
        "https://d23c6db83f6a.ngrok-free.app/auth/verify-email";

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        // API 명세에 따라 JSON 형식으로 토큰을 보냅니다.
        body: jsonEncode({'token': _tokenController.text}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        print("이메일 인증 성공!");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("이메일 인증에 성공했습니다. 다시 로그인해주세요.")),
        );

        // 인증 성공 후, 이전의 모든 화면을 닫고 로그인 화면으로 이동
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false, // 모든 이전 경로를 제거
        );
      } else {
        print("이메일 인증 실패: ${response.statusCode}");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("인증 코드가 올바르지 않습니다.")));
      }
    } catch (e) {
      print("인증 요청 중 오류 발생: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("이메일 인증")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "${widget.email} 주소로 전송된 인증 코드를 입력해주세요.",
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(labelText: "인증 코드"),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: attemptVerification,
              child: const Text("인증 확인"),
            ),
          ],
        ),
      ),
    );
  }
}
