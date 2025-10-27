import 'package:flutter/material.dart';
import 'model/api.dart'; // 1. API 서비스 import
import 'login.dart'; // 2. 로그아웃 후 이동할 로그인 화면 import
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // 3. Secure Storage import

class MyInfoScreen extends StatelessWidget {
  final String userName;
  const MyInfoScreen({super.key, required this.userName});

  // 4. Secure Storage 인스턴스 생성 및 클래스 필드로 정의
  final _storage = const FlutterSecureStorage();

  // 회원 탈퇴 확인 다이얼로그를 보여주는 함수
  Future<void> _showDeleteConfirmationDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // 다이얼로그 바깥을 눌러도 닫히지 않음
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('회원 탈퇴 확인'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('정말로 탈퇴하시겠습니까?'),
                SizedBox(height: 8),
                Text(
                  '모든 데이터(식물, 진단 기록 등)가 영구적으로 삭제되며 복구할 수 없습니다.',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // 다이얼로그 닫기
              },
            ),
            TextButton(
              child: const Text('탈퇴하기', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // 다이얼로그 닫기
                await _handleAccountDeletion(context); // 실제 탈퇴 함수 호출
              },
            ),
          ],
        );
      },
    );
  }

  // 실제 회원 탈퇴 API를 호출하고 로그아웃 처리하는 함수
  Future<void> _handleAccountDeletion(BuildContext context) async {
    try {
      // 5. 저장된 accessToken을 읽어옵니다.
      final accessToken = await _storage.read(key: 'accessToken');
      if (accessToken == null) {
        throw Exception('로그인 토큰을 찾을 수 없습니다.');
      }

      final result = await deleteAccount(
        accessToken,
      ); // 6. API 호출 시 accessToken 전달
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result['message'] ?? '회원 탈퇴 성공')));

      // 7. 탈퇴 성공 시 저장된 AccessToken 삭제
      await _storage.delete(key: 'accessToken');

      // 모든 이전 화면을 닫고 로그인 화면으로 이동
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('회원 탈퇴 실패: $e')));
    }
  }

  // 로그아웃 기능을 처리하는 함수 (이전 요청 반영)
  Future<void> _handleLogout(BuildContext context) async {
    try {
      await _storage.delete(key: 'accessToken');
      print('로그아웃 성공. 토큰 삭제 완료.');

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('로그아웃 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("내 정보"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person, size: 80),
            const SizedBox(height: 24),
            Text(
              "$userName 님",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () {
                _handleLogout(context); // 로그아웃 함수 호출
              },
              child: const Text("로그아웃"),
            ),
            const SizedBox(height: 24), // 로그아웃 버튼과 간격 추가
            TextButton(
              onPressed: () {
                _showDeleteConfirmationDialog(context); // 확인 다이얼로그 띄우기
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("회원 탈퇴"),
            ),
          ],
        ),
      ),
    );
  }
}
