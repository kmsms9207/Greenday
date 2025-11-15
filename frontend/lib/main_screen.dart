// lib/screens/main_screen.dart 파일의 HomePage 클래스 전체 (수정)

import 'package:flutter/material.dart';
import 'my_plant_screen.dart';
import 'my_info.dart';
import 'notification.dart';
import 'chatbot.dart';
import 'encyclopedia_list.dart';
import 'plant_diary.dart';
import 'recommend.dart';
import 'diagnosis_screen.dart';

class MainScreen extends StatefulWidget {
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
    _widgetOptions = <Widget>[
      HomePage(userName: widget.userName), // 0: 홈
      const PlantDiaryScreen(), // 1: 성장 일지
      const MyPlantScreen(), // 2: 식물 정보 (내 식물 목록)
      MyInfoScreen(userName: widget.userName), // 3: 내 정보
    ];
  }

  void _onItemTapped(int index) {
    if (index == 3 && _selectedIndex != 3) {
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
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
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
  final String userName;
  const HomePage({super.key, required this.userName});

  void _navigateToTab(BuildContext context, int index) {
    final mainScreenState = context.findAncestorStateOfType<_MainScreenState>();
    if (mainScreenState != null) {
      mainScreenState._onItemTapped(index);
    }
  }

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
                  builder: (context) => NotificationScreen(myPlants: const []),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        child: Column(
          // 메인 Column
          children: [
            // 공지사항 (기존 UI 유지)
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

            // --- 가로로 길게, 세로로 정렬된 카드 목록 ---
            // 🚨 Column으로 변경하여 세로로 카드를 쌓습니다.
            Column(
              mainAxisAlignment: MainAxisAlignment.start, // 상단부터 정렬
              crossAxisAlignment: CrossAxisAlignment.stretch, // 가로로 최대한 늘어납니다.
              children: [
                // 각 카드를 Expanded 없이 직접 배치하여 가로로 길게 만듭니다.
                _buildFeatureCard(
                  context,
                  title: '식물 백과사전',
                  icon: Icons.menu_book_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EncyclopediaListScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10), // 카드 사이의 세로 간격
                _buildFeatureCard(
                  context,
                  title: 'AI 챗봇',
                  icon: Icons.chat_bubble_outline,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatbotScreen(userName: userName),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10), // 카드 사이의 세로 간격
                _buildFeatureCard(
                  context,
                  title: '반려식물 추천',
                  icon: Icons.recommend_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RecommendScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),

            // --- 카드 목록 끝 ---
            const SizedBox(height: 16),

            // 💡 여기에 추가 콘텐츠를 배치할 공간입니다.
            // Text('여기에 인기 식물이나 최근 활동 위젯이 들어갑니다.', style: TextStyle(color: Colors.grey)),
            // const SizedBox(height: 100), // 임시 빈 공간
          ],
        ),
      ),
    );
  }

  // 5. 3개의 카드를 가로 배치하기 위한 새로운 헬퍼 위젯
  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    // 🚨 가로로 길게 만들었으므로, Card 자체에 고정 높이 대신 내부 Padding으로 높이를 조절합니다.
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        // 🚨 가로로 긴 카드에 맞게 내부 패딩을 조정합니다. 수직 패딩을 늘립니다.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
          child: Row(
            // 🚨 내부 콘텐츠를 Row로 변경하여 아이콘과 텍스트가 가로로 나란히 배치되도록 합니다.
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween, // 아이콘과 텍스트를 양 끝으로 정렬
            crossAxisAlignment: CrossAxisAlignment.center, // 세로 중앙 정렬
            children: [
              Row(
                // 아이콘과 제목을 묶어서 좌측에 배치
                children: [
                  Icon(
                    icon,
                    size: 36, // 아이콘 크기를 다시 키웁니다.
                    color: const Color(0xFF486B48),
                  ),
                  const SizedBox(width: 15), // 아이콘과 텍스트 사이 간격
                  Column(
                    // 텍스트를 세로로 정렬하기 위한 Column
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18, // 텍스트 크기를 키웁니다.
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4), // 제목과 바로가기 사이 간격
                      const Text(
                        "바로가기",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ), // 텍스트 크기를 키웁니다.
                      ),
                    ],
                  ),
                ],
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: Colors.grey,
              ), // 우측 화살표 아이콘
            ],
          ),
        ),
      ),
    );
  }
}
