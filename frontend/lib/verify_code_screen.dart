import 'package:flutter/material.dart';
import 'model/api.dart'; // API 서비스 import
import 'login.dart'; // 인증 성공 후 이동할 로그인 화면 import

class VerifyCodeScreen extends StatefulWidget {
  final String email; // 회원가입 화면에서 전달받은 이메일

  const VerifyCodeScreen({super.key, required this.email});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false; // 로딩 상태 표시

  Future<void> _verifyCode() async {
    setState(() => _isLoading = true); // 로딩 시작

    try {
      final result = await verifyEmailCode(widget.email, _codeController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? '이메일 인증 성공!')),
      );

      // 인증 성공 후, 이전의 모든 화면을 닫고 로그인 화면으로 이동
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false, // 모든 이전 경로를 제거
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('인증 실패: $e')));
    } finally {
      setState(() => _isLoading = false); // 로딩 종료
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("인증번호 입력")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "${widget.email} 주소로 발송된 6자리 인증번호를 입력해주세요.",
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: "인증번호 6자리"),
              keyboardType: TextInputType.number, // 숫자 키패드
              maxLength: 6, // 6자리 제한
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              // 로딩 중일 때는 버튼 비활성화
              onPressed: _isLoading || _codeController.text.length != 6
                  ? null
                  : _verifyCode,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("인증하기"),
            ),
            // TODO: 인증번호 재발송 버튼 추가 (선택 사항)
          ],
        ),
      ),
    );
  }
}
