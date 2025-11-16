// lib/screens/chatbot.dart 파일 전체 (안내 문구 추가)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'model/api.dart' as api;
import 'model/chat_model.dart';

class ChatbotScreen extends StatefulWidget {
  final String userName;
  final int? initialThreadId;

  const ChatbotScreen({
    super.key,
    required this.userName,
    this.initialThreadId,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int? _threadId;
  List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialThreadId != null) {
      _loadChatHistory(widget.initialThreadId!);
    } else {
      _threadId = null; // 🟢 새 채팅임을 명시
      _setInitialMessages();
    }
  }

  void _setInitialMessages() {
    setState(() {
      _messages = [
        ChatMessage(
          role: 'assistant_welcome',
          content: '${widget.userName}님, 안녕하세요.\nGREEN DAY 챗봇입니다.',
          createdAt: DateTime.now(),
        ),
        ChatMessage(
          role: 'system_date',
          content: DateFormat('yyyy.MM.dd').format(DateTime.now()),
          createdAt: DateTime.now().subtract(const Duration(seconds: 1)),
        ),
        ChatMessage(
          role: 'system_info',
          content: '메시지를 입력해 대화를 시작하세요.',
          createdAt: DateTime.now().subtract(const Duration(seconds: 1)),
        ),
        // 🟢 [수정 1] "AI는 실수를 할 수 있습니다." 메시지 추가
        ChatMessage(
          role: 'system_info_faint', // 👈 새로운 role을 지정
          content: 'AI는 실수를 할 수 있습니다.',
          createdAt: DateTime.now().subtract(const Duration(seconds: 1)),
        ),
      ];
    });
  }

  Future<void> _loadChatHistory(int threadId) async {
    setState(() => _isLoading = true);
    try {
      final history = await api.getChatHistory(threadId);

      if (!mounted) return;

      setState(() {
        _threadId = threadId;
        _messages = history;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('대화 기록을 불러오는 데 실패했습니다: $e')));
    }
  }

  Future<void> _handleSendPressed() async {
    final messageText = _textController.text;

    if (messageText.isEmpty) return;

    final userMessage = ChatMessage(
      content: messageText,
      role: 'user',
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });
    _textController.clear();
    setState(() {});
    _scrollToBottom();

    try {
      final response = await api.sendChatMessage(
        message: messageText,
        threadId: _threadId,
      );

      if (!mounted) return;

      setState(() {
        _threadId = response.threadId;
        _messages.add(response.assistantMessage);
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      final errorMessage = ChatMessage(
        content: '죄송합니다. 답변을 생성하는 중 오류가 발생했습니다: $e',
        role: 'assistant',
        createdAt: DateTime.now(),
      );
      setState(() {
        _messages.add(errorMessage);
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.grey[100],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(_threadId != null),
        ),
        actions: [],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isLoading && index == _messages.length) {
                  return _buildChatMessage(
                    ChatMessage(
                      role: 'assistant',
                      content: 'AI가 답변을 생성 중입니다...',
                      createdAt: DateTime.now(),
                    ),
                  );
                }
                final message = _messages[index];
                if (message.role == 'system_date') {
                  return _buildDateSeparator(message.content);
                }
                if (message.role == 'system_info') {
                  return _buildSystemMessage(message.content);
                }
                // 🟢 [수정 2] 새로운 role('system_info_faint')을 처리
                if (message.role == 'system_info_faint') {
                  return _buildFaintSystemMessage(message.content);
                }
                if (message.role == 'assistant_welcome') {
                  return _buildWelcomeMessage();
                }
                return _buildChatMessage(message);
              },
            ),
          ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  // -----------------------------------------------------------
  // UI 빌더 함수들
  // -----------------------------------------------------------

  // 🟢 [수정 3] "AI는 실수를 할 수 있습니다."를 위한 헬퍼 위젯 추가
  Widget _buildFaintSystemMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          message,
          style: TextStyle(
            color: Colors.grey[500], // 👈 연한 회색 글씨
            fontSize: 12, // 👈 조금 더 작은 폰트
          ),
        ),
      ),
    );
  }

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

  Widget _buildChatMessage(ChatMessage message) {
    bool isUser = message.role == 'user';
    final hasImage = false;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.role == 'assistant')
            const CircleAvatar(
              backgroundColor: Color(0xFFA4B6A4),
              child: Icon(
                Icons.chat_bubble_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
          if (message.role == 'assistant') const SizedBox(width: 8),

          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (hasImage) const SizedBox.shrink(),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
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
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration.collapsed(
                      hintText: '메시지 입력',
                    ),
                    onSubmitted: (text) => _handleSendPressed(),
                    onChanged: (text) => setState(() {}),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF486B48)),
                  onPressed: _isLoading || _textController.text.isEmpty
                      ? null
                      : () => _handleSendPressed(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
