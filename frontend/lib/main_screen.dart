import 'package:flutter/material.dart';
import 'my_plant_screen.dart';
import 'my_info.dart';
import 'notification.dart';
import 'chatbot.dart';
import 'encyclopedia_list.dart';
import 'plant_diary.dart';
import 'recommend.dart';
import 'diagnosis_screen.dart'; // 1. 'AI 식물 진단' 화면을 import 합니다.

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
      const PlantDiaryScreen(),
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
            icon: Icon(Icons.home_outlined), // 아이콘을 집 모양으로 변경
            label: '홈', // 라벨을 '홈'으로 변경
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
                  // builder: (context) => const NotificationScreen(),
                  builder: (context) => NotificationScreen(myPlants: []),
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

            // --- 2. 레이아웃을 2x2 그리드로 변경 ---
            GridView.count(
              crossAxisCount: 2, // 한 줄에 2개
              shrinkWrap: true, // SingleChildScrollView 안에서 필수
              physics: const NeverScrollableScrollPhysics(), // 스크롤 충돌 방지
              crossAxisSpacing: 16, // 좌우 간격
              mainAxisSpacing: 16, // 상하 간격
              childAspectRatio: 0.9, // 카드의 가로세로 비율 (조절 가능)
              children: [
                _buildGridCard(
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
                _buildGridCard(
                  context,
                  title: 'AI 식물 진단', // 3. 새 카드 추가
                  icon: Icons.local_florist_outlined,
                  onTap: () {
                    // 4. DiagnosisScreen으로 연결
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DiagnosisScreen(),
                      ),
                    );
                  },
                ),
                _buildGridCard(
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
                _buildGridCard(
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
            // --- 그리드 끝 ---
          ],
        ),
      ),
    );
  }

  // 5. 4개의 카드를 그리기 위한 새로운 공통 헬퍼 위젯
  Widget _buildGridCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        // 클릭 효과
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 40, color: const Color(0xFF486B48)),
              const SizedBox(height: 16),
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
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
