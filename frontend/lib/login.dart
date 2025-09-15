import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 1. 회원가입 화면(signup.dart)을 가져옵니다.
import 'signup.dart';

// TODO: 메인 화면 등 필요한 페이지를 import 하세요.
// import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> attemptLogin() async {
    const String apiUrl = "https://1701b9791fc0.ngrok-free.app/auth/login";

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
        print("로그인 성공! 토큰: $accessToken");

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("로그인에 성공했습니다!")));
        // TODO: 토큰 저장 및 메인 화면으로 이동
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("ID 또는 비밀번호가 잘못되었습니다.")));
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
                      /* TODO: 아이디/비밀번호 찾기 화면으로 이동 */
                    },
                    child: const Text(
                      "비밀번호 찾기",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const Text("|", style: TextStyle(color: Colors.grey)),
                  TextButton(
                    // 2. '회원가입' 버튼을 누르면 SignUpScreen으로 이동하도록 수정
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
              const Spacer(flex: 1),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      "SNS계정으로 간편 로그인",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSnsLoginButton('assets/kakao.png', () {
                    /* TODO: 카카오 로그인 */
                  }),
                  const SizedBox(width: 24),
                  _buildSnsLoginButton('assets/naver.png', () {
                    /* TODO: 네이버 로그인 */
                  }),
                  const SizedBox(width: 24),
                  _buildSnsLoginButton('assets/google.png', () {
                    /* TODO: 구글 로그인 */
                  }),
                ],
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSnsLoginButton(String imagePath, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(25),
      child: Image.asset(
        imagePath,
        width: 50,
        height: 50,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey,
            ),
          );
        },
      ),
    );
  }
}
