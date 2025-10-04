import 'package:flutter/material.dart';
import 'my_plant_screen.dart'; // 1. '내 식물' 화면을 import 합니다.

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // 2. 하단 탭과 연결될 화면 목록을 정의합니다.
  static const List<Widget> _widgetOptions = <Widget>[
    HomePage(), // 0번 인덱스: 커뮤니티
    Text('성장 일지 페이지'), // 1번 인덱스: 성장 일지
    MyPlantScreen(), // 2번 인덱스: '식물 정보'를 MyPlantScreen으로 변경
    Text('내 정보 페이지'), // 3번 인덱스: 내 정보
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            label: '커뮤니티',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            label: '성장 일지',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.eco_outlined),
            label: '식물 정보',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: '내 정보',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF486B48),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

// MainScreen의 첫 번째 탭에 해당하는 홈 페이지 위젯
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.grey[200],
        elevation: 0,
        title: const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: "GREEN",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF486B48),
                ),
              ),
              TextSpan(
                text: "DAY",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {
              // TODO: 알림 버튼 기능 구현
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 공지사항
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFD7E0D7),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFF486B48)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.volume_up_outlined, color: Colors.black54),
                  SizedBox(width: 8),
                  Text("공지사항", style: TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 큰 회색 박스
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFFA4B6A4),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 16),
            // AI 챗봇 카드
            _buildInfoCard(
              title: "AI 챗봇",
              buttonText: "챗봇 상담 받기",
              onPressed: () {
                // TODO: 챗봇 상담 기능 구현
              },
            ),
            const SizedBox(height: 16),
            // 반려식물 추천 카드
            _buildInfoCard(
              title: "반려식물 추천",
              buttonText: "반려 식물 추천 받기",
              onPressed: () {
                // TODO: 반려식물 추천 기능 구현
              },
            ),
          ],
        ),
      ),
    );
  }

  // AI 챗봇, 반려식물 추천에 사용되는 공통 카드 위젯
  Widget _buildInfoCard({
    required String title,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD7E0D7),
                      foregroundColor: Colors.black54,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(buttonText),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
