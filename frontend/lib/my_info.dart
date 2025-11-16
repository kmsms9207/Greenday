import 'package:flutter/material.dart';
import 'model/api.dart'; // API 서비스 import
import 'login.dart'; // 로그아웃 후 이동할 로그인 화면 import
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Secure Storage import

class MyInfoScreen extends StatelessWidget {
  final String userName;
  const MyInfoScreen({super.key, required this.userName});

  final _storage = const FlutterSecureStorage();

  // 회원 탈퇴 확인 다이얼로그
  Future<void> _showDeleteConfirmationDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
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
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('탈퇴하기', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _handleAccountDeletion(context);
              },
            ),
          ],
        );
      },
    );
  }

  // 실제 회원 탈퇴 처리
  Future<void> _handleAccountDeletion(BuildContext context) async {
    try {
      // 🚨 [제거] 로컬에서 토큰을 읽고 유효성을 검사하는 로직 제거.
      // api.dart의 deleteAccount 함수 내부에서 처리하며, 토큰이 없으면 Exception이 던져짐.
      /*
      final accessToken = await _storage.read(key: 'accessToken');
      if (accessToken == null) {
        throw Exception('로그인 토큰을 찾을 수 없습니다.');
      }
      */

      // 🟢 [수정] deleteAccount 함수 호출 시 accessToken 인자 제거
      await deleteAccount();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회원 탈퇴가 성공적으로 처리되었습니다.')));

      await _storage.delete(key: 'accessToken');

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

  // 로그아웃 처리
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
              onPressed: () async {
                await _handleLogout(context); // void 문제 해결
              },
              child: const Text("로그아웃"),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () async {
                await _showDeleteConfirmationDialog(context); // void 문제 해결
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
