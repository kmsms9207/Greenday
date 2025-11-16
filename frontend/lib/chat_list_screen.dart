// lib/chat_list_screen.dart (최종 수정본)

import 'package:flutter/material.dart';
import 'package:flutter_application_1/model/api.dart' as api;
import 'package:flutter_application_1/model/chat_model.dart';
import 'package:intl/intl.dart';

// 🟢 [수정] 1. FlutterSecureStorage import
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// 🟢 [수정] 2. 'chatbot.dart' (ChatbotScreen) import
import 'chatbot.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  Future<List<ThreadInfo>>? _threadsFuture;

  // 🟢 [추가] 3. 스토리지 및 userName 변수
  final _storage = const FlutterSecureStorage();
  String _userName = '';

  @override
  void initState() {
    super.initState();
    // 🟢 [수정] 4. 유저 이름 로드 후 -> 채팅 목록 로드
    _loadInitialData();
  }

  // 🟢 [추가] 5. 유저 이름과 채팅 목록을 순차적으로 로드
  Future<void> _loadInitialData() async {
    try {
      // 🟢 'user_display_name' 키 사용 (community_post_detail_screen.dart 참고)
      final storedName = await _storage.read(key: 'user_display_name');
      if (mounted) {
        setState(() {
          _userName = storedName ?? '사용자'; // 이름이 없으면 '사용자'
        });
      }
      // 이름 로드 후 채팅 목록 로드
      _loadChatThreads();
    } catch (e) {
      print("사용자 이름 로드 실패: $e");
      // 실패해도 기본 이름으로 채팅 목록은 로드 시도
      if (mounted) {
        setState(() {
          _userName = '사용자';
        });
      }
      _loadChatThreads();
    }
  }

  Future<void> _loadChatThreads() async {
    setState(() {
      _threadsFuture = api.fetchChatThreads();
    });
  }

  // 🟢 스와이프 삭제 처리 함수
  Future<void> _handleDelete(int threadId) async {
    try {
      final success = await api.deleteChatThread(threadId);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('대화방이 삭제되었습니다.')));
        }
        _loadChatThreads();
      } else {
        throw Exception('삭제 실패');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제 중 오류 발생: $e')));
      }
      _loadChatThreads();
    }
  }

  // 🟢 [수정] 6. _navigateToChat 함수가 'title' 대신 'threadId'만 받도록 변경
  void _navigateToChat(int? threadId) {
    // 🟢 _userName이 로드되기 전(빈 문자열)이면 잠시 대기 (혹은 로딩 표시)
    // 🟢 하지만 _loadInitialData에서 기본값을 설정하므로, 거의 발생하지 않음
    if (_userName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사용자 정보를 로드 중입니다...')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        // 🟢 [수정] 7. ChatbotScreen 호출 (userName 전달, initialThreadId 전달)
        builder: (context) =>
            ChatbotScreen(userName: _userName, initialThreadId: threadId),
      ),
    ).then((didChat) {
      // 🟢 [수정] 8. chatbot.dart가 pop(true)로 응답하면 목록 새로고침
      if (didChat == true) {
        _loadChatThreads();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 챗봇'),
        actions: [
          // 🟢 새 대화 시작 버튼
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () {
              // 🟢 [수정] 9. threadId: null 로 '새 대화' 시작
              _navigateToChat(null);
            },
            tooltip: '새 대화',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadChatThreads,
        child: FutureBuilder<List<ThreadInfo>>(
          future: _threadsFuture,
          builder: (context, snapshot) {
            // 🟢 _userName 로드 + _threadsFuture 로드 둘 다 기다리기
            if (_threadsFuture == null ||
                snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('오류: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  '아직 대화 내역이 없습니다.\n우측 상단 버튼을 눌러 새 대화를 시작해 보세요!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              );
            }

            final threads = snapshot.data!;

            return ListView.builder(
              itemCount: threads.length,
              itemBuilder: (context, index) {
                final thread = threads[index];

                final String lastMessageText = thread.lastMessage ?? '대화 내용 없음';

                // 🟢 이 displayTitle은 이제 화면 표시에만 사용됨
                final String displayTitle =
                    thread.title != null && thread.title!.isNotEmpty
                    ? thread.title!
                    : (thread.lastMessage != null &&
                              thread.lastMessage!.isNotEmpty
                          ? "'${thread.lastMessage!}'"
                          : "새 대화");

                return Dismissible(
                  key: ValueKey('thread_${thread.id}'),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('삭제 확인'),
                        content: const Text('이 대화방을 정말 삭제하시겠습니까?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              '삭제',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) {
                    _handleDelete(thread.id);
                  },
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: Text(
                      displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${thread.messageCount}개 메시지 | $lastMessageText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    trailing: Text(
                      thread.lastMessageAt != null
                          ? DateFormat(
                              'MM.dd HH:mm',
                            ).format(thread.lastMessageAt!.toLocal())
                          : DateFormat(
                              'MM.dd',
                            ).format(thread.updatedAt.toLocal()),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    onTap: () {
                      // 🟢 [수정] 10. 'title' 대신 'thread.id'만 전달
                      _navigateToChat(thread.id);
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
