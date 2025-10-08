import 'package:flutter/material.dart';
import 'my_plant_screen.dart';
import 'my_info.dart';
import 'notification.dart';
import 'chatbot.dart';
import 'encyclopedia_list.dart';

class MainScreen extends StatefulWidget {
  // 로그인 화면에서 사용자 이름을 전달받기 위한 변수
  final String userName;

  const MainScreen({super.key, required this.userName});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    // 위젯이 생성될 때, 전달받은 userName으로 화면 목록을 구성
    _widgetOptions = <Widget>[
      HomePage(userName: widget.userName), // HomePage에 userName 전달
      const Text('성장 일지 페이지'),
      const MyPlantScreen(),
      // 1. MyInfoScreen에도 userName을 전달하도록 수정합니다.
      MyInfoScreen(userName: widget.userName),
    ];
  }

  void _onItemTapped(int index) {
    if (index == 3) {
      // 2. '내 정보' 탭을 누를 때도 userName을 전달하도록 수정합니다.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MyInfoScreen(userName: widget.userName),
        ),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
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

class HomePage extends StatelessWidget {
  // HomePage도 userName을 전달받도록 수정
  final String userName;
  const HomePage({super.key, required this.userName});

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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 공지사항, 큰 회색 박스 등 기존 UI...
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
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EncyclopediaListScreen(), // 백과사전 화면
                  ),
                );
              },
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFFA4B6A4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text(
                    "식물 백과사전",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            _buildInfoCard(
              title: "AI 챗봇",
              buttonText: "챗봇 상담 받기",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatbotScreen(userName: userName),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
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
