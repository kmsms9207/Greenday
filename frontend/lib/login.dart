import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'signup.dart';
import 'main_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'model/api.dart'; // registerPushToken, fetchCurrentUserProfile 함수 사용
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storage = const FlutterSecureStorage();

  Future<void> attemptLogin() async {
    const String apiUrl = "https://276d349f8bc4.ngrok-free.app/auth/login";

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'password',
          'username': _usernameController.text,
          'password': _passwordController.text,
        },
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final accessToken = responseBody['access_token'];

        await _storage.write(key: 'accessToken', value: accessToken);

        // 🟢 [핵심 수정 시작] GET /auth/users/me 호출로 공식 사용자 프로필 획득
        final userProfile = await fetchCurrentUserProfile();

        // 🚨 [수정] 서버 PK/ID인 'id' 필드를 최우선으로 추출하고 String으로 변환합니다.
        // 이는 게시글 authorId와 일치할 가장 높은 가능성을 갖는 값입니다.
        final officialUserId = (userProfile['id'] ?? userProfile['username'])
            .toString();

        // 🟢 [저장] 이 공식 ID를 'user_display_name'으로 저장합니다.
        await _storage.write(key: 'user_display_name', value: officialUserId);

        final userNameForDisplay =
            userProfile['name'] as String? ?? officialUserId; // 화면 표시용 이름

        // FCM 토큰 발급 및 서버 전송 (기존 로직 유지)
        try {
          final fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            await registerPushToken(fcmToken);
          }
        } catch (e) {
          print("FCM 토큰 처리 중 오류 발생: $e");
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(userName: userNameForDisplay),
          ),
        );
      } else {
        // ... (로그인 실패 처리 로직)
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("로그인 중 오류가 발생했습니다.")));
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "GREEN",
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF486B48),
                      ),
                    ),
                    TextSpan(
                      text: "DAY",
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 1),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  hintText: "ID",
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Color(0xFF486B48),
                      width: 2.0,
                    ),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  hintText: "PASSWORD",
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Color(0xFF486B48),
                      width: 2.0,
                    ),
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: attemptLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA4B6A4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: const Text("LOGIN", style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      // TODO: 비밀번호 찾기 화면으로 이동
                    },
                    child: const Text(
                      "비밀번호 찾기",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const Text("|", style: TextStyle(color: Colors.grey)),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignUpScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "회원가입",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
