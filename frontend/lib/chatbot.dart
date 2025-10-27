import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'model/api.dart'; // API 서비스 import
import 'model/chat_model.dart'; // 챗봇 모델 import
// TODO: 이미지 선택을 위해 'image_picker' 패키지를 추가해야 합니다.
// import 'package:image_picker/image_picker.dart';

class ChatbotScreen extends StatefulWidget {
  final String userName;
  // TODO: 이전 대화 목록을 불러오려면 '내 정보' 등에서 thread_id를 받아와야 합니다.
  // final int? initialThreadId;

  const ChatbotScreen({
    super.key,
    required this.userName,
    // this.initialThreadId,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController(); // 리스트 스크롤 제어

  // 1. 챗봇 상태 관리 변수
  int? _threadId; // 현재 대화 ID (서버 응답으로 받음)
  List<ChatMessage> _messages = []; // 전체 대화 목록
  bool _isLoading = false; // AI가 답변 중인지 여부

  @override
  void initState() {
    super.initState();
    // 2. 챗봇 화면에 처음 들어왔을 때 초기 메시지 설정
    // TODO: 만약 initialThreadId가 있다면, 여기서 getChatHistory(initialThreadId)를 호출하여
    //       _setInitialMessages() 대신 실제 대화 기록을 불러와야 합니다.
    _setInitialMessages();
  }

  // 챗봇 화면에 처음 들어왔을 때 와이어프레임처럼 초기 메시지 설정
  void _setInitialMessages() {
    setState(() {
      _messages = [
        // 환영 메시지 (커스텀 UI)
        ChatMessage(
          role: 'assistant_welcome', // 환영 메시지 구분을 위한 임시 role
          content: '${widget.userName}님, 안녕하세요.\nGREEN DAY 챗봇입니다.',
          createdAt: DateTime.now(),
        ),
        // 날짜 구분선
        ChatMessage(
          role: 'system_date', // 날짜 구분을 위한 임시 role
          content: DateFormat('yyyy.MM.dd').format(DateTime.now()),
          createdAt: DateTime.now().subtract(const Duration(seconds: 1)),
        ),
        // 대화 시작 안내
        ChatMessage(
          role: 'system_info', // 안내를 위한 임시 role
          content: '메시지를 입력해 대화를 시작하세요.',
          createdAt: DateTime.now().subtract(const Duration(seconds: 1)),
        ),
      ];
    });
  }

  // (참고) 이전 대화 기록 불러오기 함수
  Future<void> _loadChatHistory(int threadId) async {
    setState(() => _isLoading = true);
    try {
      final history = await getChatHistory(threadId);
      setState(() {
        _threadId = threadId;
        _messages = history; // 실제 대화 기록으로 덮어쓰기
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('대화 기록을 불러오는 데 실패했습니다: $e')));
    }
  }

  // 메시지 전송 함수
  Future<void> _handleSendPressed({String? imageUrl}) async {
    final messageText = _textController.text;
    if (messageText.isEmpty && imageUrl == null)
      return; // 텍스트와 이미지가 모두 없으면 전송 안 함

    // 1. 사용자가 보낸 메시지를 UI에 즉시 추가
    final userMessage = ChatMessage(
      role: 'user',
      content: messageText,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true; // AI 답변 로딩 시작
    });
    _textController.clear();
    _scrollToBottom();

    // 2. 서버에 메시지 전송
    try {
      final response = await sendChatMessage(
        message: messageText,
        threadId: _threadId,
        imageUrl: imageUrl, // 이미지 URL 전달
      );

      // 3. AI 답변을 UI에 추가
      setState(() {
        _threadId = response.threadId; // threadId 갱신
        _messages.add(response.assistantMessage);
        _isLoading = false; // 로딩 종료
      });
      _scrollToBottom();
    } catch (e) {
      // 4. 에러 발생 시 UI에 에러 메시지 추가
      final errorMessage = ChatMessage(
        role: 'assistant',
        content: '죄송합니다. 답변을 생성하는 중 오류가 발생했습니다: $e',
        createdAt: DateTime.now(),
      );
      setState(() {
        _messages.add(errorMessage);
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  // 스크롤을 맨 아래로 이동
  void _scrollToBottom() {
    // 잠시 지연을 주어 UI가 렌더링될 시간을 줌
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // '+' 버튼 눌렀을 때 이미지/카메라 선택 옵션
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
                  // TODO: 1. image_picker로 이미지 선택
                  // TODO: 2. 선택된 이미지를 백엔드 S3/스토리지에 업로드 (별도 API 필요)
                  // TODO: 3. 업로드 후 받은 image_url을 _handleSendPressed(imageUrl: '...')로 전달
                  Navigator.of(context).pop();
                  print('앨범 선택');
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('카메라로 사진 촬영'),
                onTap: () {
                  // TODO: 1. image_picker로 사진 촬영
                  // TODO: 2. 촬영된 이미지를 백엔드 S3/스토리지에 업로드 (별도 API 필요)
                  // TODO: 3. 업로드 후 받은 image_url을 _handleSendPressed(imageUrl: '...')로 전달
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
              /* TODO: 메뉴 버튼 기능 */
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 3. 대화 목록 (ListView.builder로 변경)
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length + (_isLoading ? 1 : 0), // 로딩 중이면 +1
              itemBuilder: (context, index) {
                // 로딩 중일 때 AI가 입력 중인 것처럼 표시
                if (_isLoading && index == _messages.length) {
                  return _buildChatMessage(
                    ChatMessage(
                      role: 'assistant',
                      content: '...', // '입력 중...' 표시
                      createdAt: DateTime.now(),
                    ),
                  );
                }

                final message = _messages[index];

                // 시스템 메시지(날짜, 안내) 처리
                if (message.role == 'system_date') {
                  return _buildDateSeparator(message.content);
                }
                if (message.role == 'system_info') {
                  return _buildSystemMessage(message.content);
                }
                // 와이어프레임의 환영 메시지 처리
                if (message.role == 'assistant_welcome') {
                  return _buildWelcomeMessage();
                }

                // 사용자, 어시스턴트 메시지 처리
                return _buildChatMessage(message);
              },
            ),
          ),
          // 4. 메시지 입력창
          _buildMessageComposer(),
        ],
      ),
    );
  }

  // (챗봇 UI 빌더 함수들)

  // 날짜 구분선 위젯
  Widget _buildDateSeparator(String date) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
          child: Text(date, style: const TextStyle(color: Colors.grey)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  // 시스템 메시지 위젯 (회색 말풍선)
  Widget _buildSystemMessage(String message) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 8.0),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(message, style: TextStyle(color: Colors.grey[700])),
      ),
    );
  }

  // 실제 대화 말풍선 위젯
  Widget _buildChatMessage(ChatMessage message) {
    bool isUser = message.role == 'user';
    bool isAssistant = message.role == 'assistant';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 어시스턴트 아이콘
          if (isAssistant)
            const CircleAvatar(
              backgroundColor: Color(0xFFA4B6A4),
              child: Icon(
                Icons.chat_bubble_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
          if (isAssistant) const SizedBox(width: 8),

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF486B48) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Text(
                message.content,
                style: TextStyle(color: isUser ? Colors.white : Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 환영 메시지 위젯 (와이어프레임 스타일)
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
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1.4,
            ),
            children: <TextSpan>[
              TextSpan(
                text: widget.userName,
                style: const TextStyle(color: Color(0xFF486B48)),
              ),
              const TextSpan(text: '님, 안녕하세요.\nGREEN DAY 챗봇입니다.'),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // 하단 메시지 입력창 위젯
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
              onPressed: _showAttachmentOptions, // '+' 버튼 기능 연결
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration.collapsed(hintText: '메시지 입력'),
                onSubmitted: (text) => _handleSendPressed(), // 엔터키로 전송
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF486B48)),
              onPressed: _isLoading
                  ? null
                  : () => _handleSendPressed(), // 로딩 중일 때 전송 버튼 비활성화
            ),
          ],
        ),
      ),
    );
  }
}
