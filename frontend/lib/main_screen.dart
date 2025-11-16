// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'my_plant_screen.dart';
import 'my_info.dart';
import 'notification.dart';
import 'chatbot.dart';
import 'encyclopedia_list.dart';
import 'plant_diary.dart'; // 전체 식물 일지 화면
import 'recommend.dart';

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
      const PlantDiaryScreen(), // 1: 성장 일지 (전체 식물)
      const MyPlantScreen(), // 2: 식물 정보 (내 식물 목록)
      MyInfoScreen(userName: widget.userName), // 3: 내 정보
    ];
  }

  void _onItemTapped(int index) {
    // 3: 내 정보는 push로 이동, 나머지는 상태 변경
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

// ---------------------- 홈 화면 ----------------------
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

            // 기능 카드
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                const SizedBox(height: 10),
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
                const SizedBox(height: 10),
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
                const SizedBox(height: 10),
                _buildFeatureCard(
                  context,
                  title: '커뮤니티',
                  icon: Icons.people_alt_outlined,
                  onTap: () {
                    print('커뮤니티');
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 36,
                    color: const Color(0xFF486B48),
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "바로가기",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
