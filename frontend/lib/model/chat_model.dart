// 서버와 주고받는 채팅 메시지의 구조
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

  // 서버에서 받은 JSON을 ChatMessage 객체로 변환 (수정된 부분)
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

// 메시지 전송(POST /chat) 시 서버로부터 받는 응답의 구조
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

// model/chat_model.dart 파일에 추가

class ThreadInfo {
  final int id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  ThreadInfo({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ThreadInfo.fromJson(Map<String, dynamic> json) {
    return ThreadInfo(
      id: json['id'] as int,
      title: json['title'] as String,
      // ISO 8601 형식의 문자열을 DateTime 객체로 파싱
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
