// lib/model/chat_model.dart (전체 파일 - ThreadInfo 수정 완료)

// ---------------------- 1. 대화방 목록 ----------------------
class ThreadInfo {
  final int id;
  // 🟢 [수정] title이 null일 수 있음 (API 명세 참고)
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 🟢 [추가] API 명세에 따라 3개 필드 추가
  final int messageCount;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  ThreadInfo({
    required this.id,
    this.title,
    required this.createdAt,
    required this.updatedAt,
    // 🟢 [추가] 생성자에 반영
    required this.messageCount,
    this.lastMessage,
    this.lastMessageAt,
  });

  factory ThreadInfo.fromJson(Map<String, dynamic> json) {
    return ThreadInfo(
      id: json['id'] as int,
      // 🟢 [수정] title이 null일 수 있으므로 as String?
      title: json['title'] as String?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),

      // 🟢 [추가] 새 필드 파싱 (null일 경우 기본값 처리)
      messageCount: json['message_count'] as int? ?? 0,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'])
          : null,
    );
  }
}

// ---------------------- 2. 개별 메시지 ----------------------
// (GET /chat/threads/{id}/messages 응답 및 POST /chat/send 응답에 사용)
class ChatMessage {
  final String role; // 'user' 또는 'assistant'
  final String content;
  final DateTime createdAt;

  // 1. 필수 추가: imageUrl 필드 추가
  final String? imageUrl;

  ChatMessage({
    required this.role,
    required this.content,
    required this.createdAt,
    this.imageUrl, // 2. 생성자에 추가
  });

  // 서버에서 받은 JSON을 ChatMessage 객체로 변환 (기존 코드)
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    String messageContent = json['content'] ?? '';

    // 1. 만약 content가 비어있고, 숨겨진 경로에 답변이 있다면 (기존 로직 유지)
    if (messageContent.isEmpty &&
        json['provider_resp'] != null &&
        json['provider_resp']['result'] != null &&
        json['provider_resp']['result']['message'] != null &&
        json['provider_resp']['result']['message']['content'] != null) {
      // 2. 숨겨진 경로에서 실제 답변을 가져옵니다.
      messageContent = json['provider_resp']['result']['message']['content'];
    }

    // 3. image_url 파싱 추가
    final String? imageUrl = json['image_url'] as String?;

    return ChatMessage(
      role: json['role'] ?? 'unknown',
      content: messageContent, // 4. 실제 답변을 content로 사용
      createdAt: DateTime.parse(json['created_at']),
      imageUrl: imageUrl, // 5. 파싱된 imageUrl을 할당
    );
  }
}

// ---------------------- 3. 메시지 전송 응답 ----------------------
// (POST /chat/send 응답)
class ChatSendResponse {
  final int threadId;
  final ChatMessage assistantMessage;

  ChatSendResponse({required this.threadId, required this.assistantMessage});

  // JSON 응답을 ChatSendResponse 객체로 변환
  factory ChatSendResponse.fromJson(Map<String, dynamic> json) {
    return ChatSendResponse(
      threadId: json['thread_id'],
      assistantMessage: ChatMessage.fromJson(json['assistant']),
    );
  }
}
