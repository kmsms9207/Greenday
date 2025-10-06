import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatbotScreen extends StatefulWidget {
  final String userName;
  const ChatbotScreen({super.key, required this.userName});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;
  final TextEditingController _textController = TextEditingController();

  final List<Map<String, String>> faqItems = [
    {'question': '자주 묻는 질문 1', 'answer': '첫 번째 질문에 대한 답변입니다.'},
    {'question': '자주 묻는 질문 2', 'answer': '두 번째 질문에 대한 답변입니다.'},
    {'question': '자주 묻는 질문 3', 'answer': '세 번째 질문에 대한 답변입니다.'},
    {'question': '자주 묻는 질문 4', 'answer': '네 번째 질문에 대한 답변입니다.'},
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      final newPage = _pageController.page?.round() ?? 0;
      if (_currentPage != newPage) {
        setState(() {
          _currentPage = newPage;
        });
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('앨범에서 사진 선택'),
                onTap: () {
                  Navigator.of(context).pop();
                  print('앨범 선택');
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('카메라로 사진 촬영'),
                onTap: () {
                  Navigator.of(context).pop();
                  print('카메라 촬영');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String todayDate = DateFormat('yyyy.MM.dd').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.grey[100],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () {
              // TODO: 메뉴 버튼 기능 구현
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              children: [
                _buildWelcomeMessage(),
                const SizedBox(height: 24),
                _buildFaqSection(),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildDateSeparator(todayDate),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildSystemMessage("메시지를 입력해 대화를 시작하세요."),
                ),
              ],
            ),
          ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  // 환영 메시지 위젯 (이름 부분 색상 변경)
  Widget _buildWelcomeMessage() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Color(0xFFA4B6A4),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.chat_bubble_outline,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(height: 12),
        // 1. RichText를 사용하여 텍스트 일부에만 다른 스타일을 적용합니다.
        RichText(
          text: TextSpan(
            // 기본 스타일 (전체 텍스트에 적용)
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            children: <TextSpan>[
              // 2. 사용자 이름 부분에만 초록색 스타일을 적용합니다.
              TextSpan(
                text: '${widget.userName}님',
                style: const TextStyle(color: Color(0xFF486B48)),
              ),
              const TextSpan(text: ', 안녕하세요.'),
            ],
          ),
        ),
        const Text(
          "GREEN DAY 챗봇입니다.",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildFaqSection() {
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: PageView.builder(
            controller: _pageController,
            itemCount: faqItems.length,
            itemBuilder: (context, index) {
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        faqItems[index]['question']!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 20,
                        width: 120,
                        color: const Color(0xFFD7E0D7),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 20,
                        width: 80,
                        color: const Color(0xFFD7E0D7),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(faqItems.length, (index) {
            return GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeIn,
                );
              },
              child: Container(
                width: 8.0,
                height: 8.0,
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? const Color(0xFF486B48)
                      : Colors.grey.withOpacity(0.5),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDateSeparator(String date) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(date, style: const TextStyle(color: Colors.grey)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildSystemMessage(String message) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(message, style: TextStyle(color: Colors.grey[700])),
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add, color: Colors.grey),
              onPressed: _showAttachmentOptions,
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration.collapsed(hintText: '메시지 입력'),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF486B48)),
              onPressed: () {
                if (_textController.text.isNotEmpty) {
                  print('전송할 메시지: ${_textController.text}');
                  _textController.clear();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
