// lib/model/comment.dart

class Comment {
  final int id;
  final int postId;
  final String content;
  final String authorName;
  final DateTime createdAt;
  final String authorId; // 댓글 작성자 ID 필드

  Comment({
    required this.id,
    required this.postId,
    required this.content,
    required this.authorName,
    required this.createdAt,
    required this.authorId,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    // 🟢 [수정] 백엔드 API가 보내주는 키 이름인 'owner'를 사용하도록 변경
    final authorInfo = json['owner'] as Map<String, dynamic>?;

    return Comment(
      id: json['id'] as int,
      postId: json['post_id'] as int,
      content: json['content'] as String,
      authorName: authorInfo != null
          ? (authorInfo['name'] ?? authorInfo['username'] ?? '작성자 정보 없음')
                as String
          : '작성자 불명',
      // 🟢 authorId를 모든 타입에 대해 .toString()으로 강제 변환합니다.
      authorId: (authorInfo?['id'] ?? '').toString(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
