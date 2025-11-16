// lib/model/post.dart

import 'comment.dart'; // Comment 모델 import (같은 디렉토리)

class Post {
  final int id;
  final String title;
  final String content;
  final String authorName;
  final DateTime createdAt;
  final String authorId; // 작성자 ID (현재 사용자 비교용)
  final List<Comment> comments; // 상세 조회 시에만 포함됨

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.authorName,
    required this.createdAt,
    required this.authorId,
    required this.comments,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    var commentList = json['comments'] as List?;
    List<Comment> postComments = commentList != null
        ? commentList
              .map((i) => Comment.fromJson(i as Map<String, dynamic>))
              .toList()
        : [];

    // 🟢 [수정] 백엔드 API가 보내주는 키 이름인 'owner'를 사용하도록 변경
    final authorInfo = json['owner'] as Map<String, dynamic>?;

    final String parsedAuthorName = authorInfo != null
        ? (authorInfo['name'] ?? authorInfo['username'] ?? '작성자 정보 없음')
              as String
        : '작성자 불명';

    // 🟢 authorId: author 객체 내부의 'id' (PK)를 String으로 변환
    final String parsedAuthorId = (authorInfo?['id'] ?? '').toString();

    return Post(
      id: json['id'] as int,
      title: json['title'] as String,
      content: json['content'] as String? ?? '',
      authorName: parsedAuthorName,
      authorId: parsedAuthorId,
      createdAt: DateTime.parse(json['created_at'] as String),
      comments: postComments,
    );
  }
}
