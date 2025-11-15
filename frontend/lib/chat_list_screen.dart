// lib/screens/chat_list_screen.dart 파일 전체

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../model/api.dart' as api; // fetchChatThreads 함수 사용
import '../model/chat_model.dart'; // ThreadInfo 모델 사용
import 'chatbot.dart'; // 대화방 화면 (ChatbotScreen)

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  Future<List<ThreadInfo>>? _threadsFuture;

  @override
  void initState() {
    super.initState();
    _threadsFuture = api.fetchChatThreads(); // 대화방 목록 API 호출
  }

  // 새로고침 기능 (Pull-to-refresh)
  Future<void> _refreshThreads() async {
    setState(() {
      _threadsFuture = api.fetchChatThreads();
    });
  }

  // 대화방으로 이동
  void _navigateToChat(ThreadInfo? thread) {
    // 현재 목록 화면을 닫고, 새로운 ChatbotScreen으로 교체하며 이동합니다.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChatbotScreen(
          // userName은 실제 앱에서 로그인 정보를 통해 받아와야 합니다.
          userName: '현재 사용자',
          initialThreadId: thread?.id, // 기존 대화는 ID 전달, 새 대화는 null
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 전체 화면으로 동작합니다.
    return Scaffold(
      appBar: AppBar(
        title: const Text('대화 기록'),
        // 목록 화면이므로 뒤로 가기 버튼을 제공합니다.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToChat(null), // 새 대화 시작
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshThreads,
        child: FutureBuilder<List<ThreadInfo>>(
          future: _threadsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '기록을 불러오는 데 실패했습니다:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('시작된 대화가 없습니다.'),
                    TextButton.icon(
                      onPressed: () => _navigateToChat(null),
                      icon: const Icon(Icons.add_box),
                      label: const Text('새 대화 시작하기'),
                    ),
                  ],
                ),
              );
            }

            final threads = snapshot.data!;
            return ListView.separated(
              itemCount: threads.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final thread = threads[index];
                return ListTile(
                  title: Text(
                    thread.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    // updatedAt이 null일 경우를 대비한 널 안전성 처리
                    '${thread.updatedAt?.toLocal().toString().substring(0, 16) ?? '날짜 없음'}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColorLight,
                    child: Text(
                      thread.id.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  onTap: () => _navigateToChat(thread), // 기존 대화방으로 이동
                );
              },
            );
          },
        ),
      ),
    );
  }
}
