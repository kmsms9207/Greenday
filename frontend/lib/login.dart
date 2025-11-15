import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'signup.dart';
import 'main_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'model/api.dart';
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
    const String apiUrl = "https://f9fae591fe6d.ngrok-free.app/auth/login";

    try {
      // 1. 로그인 API는 JSON이 아닌 Form-urlencoded 방식을 사용합니다.
      final response = await http.post(
        Uri.parse(apiUrl),
        // 2. 헤더를 'Form' 형식으로 다시 변경합니다.
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        // 3. body를 jsonEncode하지 않고 Map<String, String>으로 보냅니다.
        body: {
          // 4. 'grant_type': 'password' 필드가 다시 필요합니다.
          'grant_type': 'password',
          'username': _usernameController.text,
          'password': _passwordController.text,
        },
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final accessToken = responseBody['access_token'];
        print("로그인 성공! 토큰: $accessToken");

        await _storage.write(key: 'accessToken', value: accessToken);

        // FCM 토큰 발급 및 서버 전송
        try {
          final fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            print("FCM Token: $fcmToken");
            await registerPushToken(fcmToken, accessToken);
          } else {
            print("FCM 토큰 발급 실패");
          }
        } catch (e) {
          print("FCM 토큰 처리 중 오류 발생: $e");
        }

        final email = _usernameController.text;
        final userName = email.split('@').first;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(userName: userName),
          ),
        );
      } else {
        // 5. 서버가 보내는 실제 오류 메시지를 표시하도록 수정
        String errorMessage = "ID 또는 비밀번호가 잘못되었습니다.";
        try {
          final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
          if (responseBody.containsKey('detail')) {
            errorMessage = responseBody['detail'];
          }
        } catch (_) {} // JSON 파싱 실패 시 기본 메시지 사용

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
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
