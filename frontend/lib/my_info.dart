import 'package:flutter/material.dart';
import 'main_screen.dart';

class MyInfoScreen extends StatelessWidget {
  const MyInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 전체 배경
      appBar: AppBar(
        backgroundColor: Colors.white, // AppBar 배경
        toolbarHeight: 50, // AppBar 높이
        centerTitle: true, // 중앙 정렬
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainScreen()), // 이전 화면으로 돌아가기
            );
          },
        ),
        title: const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: "GREEN",
                style: TextStyle(fontSize: 25, color: Color(0xFF486B48)),
              ),
              TextSpan(
                text: " DAY",
                style: TextStyle(fontSize: 25, color: Colors.black),
              ),
            ],
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            // 닉네임
            Center(
              child: _centerInfoTile("닉네임"),
            ),
            const SizedBox(height: 50),
              Column(
                children: [
                  _leftInfoTile("이름", " "),
                  _leftInfoTile("생년월일", " "),
                  _leftInfoTile("아이디", " "),
                  _leftInfoTile("비밀번호", " "),
                  _leftInfoTile("소셜 로그인 정보", " "),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: SizedBox(
          width: double.infinity,
          height: 60, // 버튼 높이
          child: ElevatedButton(
            onPressed: () async {
              // Plant 수정 화면 연동
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA4B6A4),
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              padding: EdgeInsets.zero,
            ),
            child: const Text(
              "수정",
              style: TextStyle(fontSize: 25),
            ),
          ),
        ),
      );
    }

  // 가운데 정렬 위젯
  Widget _centerInfoTile(String name, {String? imagePath}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 사진 영역
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey[300], // 기본 배경색 (회색)
            image: imagePath != null
                ? DecorationImage(
                    image: AssetImage(imagePath),
                    fit: BoxFit.cover,
                  )
                : null, // imagePath가 없으면 빈 네모
          ),
          child: imagePath == null
              ? const Icon(Icons.camera_alt, size: 40, color: Colors.white)
              : null, // 사진 없으면 카메라 아이콘
        ),
        const SizedBox(height: 5),
        Text(
          name,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Color(0xFF486B48)),
        ),
      ],
    );
  }

  // 왼쪽 정렬 위젯
  Widget _leftInfoTile(String label, String value) {
    return Card(
      color: Color(0xFFF1F1F1),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Container(
        width: double.infinity, // 카드 폭
        height: 50, // 카드 높이
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min, // 내용에 맞게 줄 길이
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF656565),
              ),
            ),
            const SizedBox(width: 8), // label과 value 사이 간격
            Text(
              value,
              style: const TextStyle(
                fontSize: 16
              ),
            ),
          ],
        ),
      ),
    );
  }
}