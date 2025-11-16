// lib/screens/community_post_detail_screen.dart (최종 수정본)

import 'package:flutter/material.dart';
import 'package:flutter_application_1/model/api.dart' as api;
import 'package:flutter_application_1/model/post.dart';
import 'package:flutter_application_1/model/comment.dart';
import 'community_post_form_screen.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // 1. Storage 임포트

// 2. ❌ 하드코딩된 ID 제거
// const String CURRENT_USER_ID = 'test_user';

class CommunityPostDetailScreen extends StatefulWidget {
  final int postId;
  const CommunityPostDetailScreen({Key? key, required this.postId})
    : super(key: key);

  @override
  State<CommunityPostDetailScreen> createState() =>
      _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState extends State<CommunityPostDetailScreen> {
  // 3. 🟢 'late'를 제거하고 Nullable 타입 '?'로 변경
  Future<Post?>? _postFuture;
  final _commentController = TextEditingController();
  bool _isCommentLoading = false;

  final _storage = const FlutterSecureStorage();
  String _currentUserId = ''; // 로그인한 사용자의 공식 ID

  @override
  void initState() {
    super.initState();
    // 4. 🟢 위젯이 시작될 때 ID 로드 및 게시글 로드를 순차적으로 실행
    _loadInitialData();
  }

  // 5. 🟢 ID 로드 및 게시글 로드를 통합한 함수
  Future<void> _loadInitialData() async {
    // 6. 🟢 ID를 먼저 불러와서 변수에 저장 (setState ❌)
    final userId = await _storage.read(key: 'user_display_name');
    if (mounted) {
      _currentUserId = userId ?? ''; // ID가 없을 경우 빈 문자열
    }

    // 7. 🟢 ID 로드가 완료된 후, Post 로드를 시작 (setState ⭕)
    //    이 setState는 _postFuture를 할당하고 화면 갱신을 요청합니다.
    setState(() {
      _postFuture = api
          .getCommunityPostDetail(widget.postId)
          .then((data) {
            if (data == null) throw Exception('게시글 데이터를 찾을 수 없습니다.');
            return Post.fromJson(data);
          })
          .catchError((e) {
            print('게시글 상세 로드 실패: $e');
            return null;
          });
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------
  // (댓글 및 게시글 관리 함수들은 수정할 필요 없이 원본 유지)
  // ... _handleCommentSubmit() ...
  // ... _handleCommentDelete() ...
  // ... _navigateToEditPost() ...
  // ... _handleDeletePost() ...
  // -----------------------------------------------------------

  // 댓글 작성
  Future<void> _handleCommentSubmit() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isCommentLoading = true);
    try {
      await api.createComment(widget.postId, content);
      _commentController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('댓글 작성 완료!')));

      // 🟢 갱신을 위해 _loadInitialData 대신 _loadPostDetail만 호출
      //    (ID는 이미 로드되어 있으므로)
      setState(() {
        _postFuture = api
            .getCommunityPostDetail(widget.postId)
            .then((data) => data != null ? Post.fromJson(data) : null);
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('댓글 작성 실패: $e')));
    } finally {
      if (mounted) setState(() => _isCommentLoading = false);
    }
  }

  // 댓글 삭제
  Future<void> _handleCommentDelete(int commentId) async {
    try {
      final success = await api.deleteComment(commentId);
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('댓글 삭제 완료')));

        // 🟢 갱신
        setState(() {
          _postFuture = api
              .getCommunityPostDetail(widget.postId)
              .then((data) => data != null ? Post.fromJson(data) : null);
        });
      } else {
        throw Exception('삭제 권한이 없거나 서버 오류');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('댓글 삭제 실패: $e')));
    }
  }

  // 게시글 수정 화면 이동
  void _navigateToEditPost(Post post) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommunityPostFormScreen(postToEdit: post),
      ),
    );
    // 수정 완료 후 상세 정보 갱신 후 목록 갱신을 위해 true 반환
    if (result == true) {
      // 🟢 갱신
      setState(() {
        _postFuture = api
            .getCommunityPostDetail(widget.postId)
            .then((data) => data != null ? Post.fromJson(data) : null);
      });
      if (mounted) Navigator.pop(context, true);
    }
  }

  // 게시글 삭제
  Future<void> _handleDeletePost(int postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('정말로 이 게시글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final success = await api.deleteCommunityPost(postId);
        if (success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('게시글 삭제 완료')));
          if (mounted) Navigator.pop(context, true); // 목록 화면으로 돌아가기
        } else {
          throw Exception('삭제 권한이 없거나 서버 오류');
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('게시글 삭제 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 8. 🟢 _postFuture가 아직 할당되지 않은(null) 초기 상태인지 확인
    if (_postFuture == null) {
      // ID 로드 중이거나, Post 로드가 아직 시작되지 않음
      return Scaffold(
        appBar: AppBar(title: const Text('게시글 상세')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 9. 🟢 _postFuture가 할당된 후 FutureBuilder 실행
    return FutureBuilder<Post?>(
      future: _postFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            body: Center(
              child: Text('게시글을 불러올 수 없습니다: ${snapshot.error ?? "데이터 없음"}'),
            ),
          );
        }

        final post = snapshot.data!;
        // 10. 🟢 [핵심 수정] 하드코딩된 ID 대신 state 변수(_currentUserId) 사용
        final bool isPostAuthor = post.authorId == _currentUserId;

        return Scaffold(
          appBar: AppBar(
            title: const Text('게시글 상세'),
            actions: [
              if (isPostAuthor) // 🟢 이 로직이 이제 정확하게 동작합니다.
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert), // 세로 점 세 개 아이콘
                  onSelected: (value) {
                    if (value == 'edit') {
                      _navigateToEditPost(post);
                    } else if (value == 'delete') {
                      _handleDeletePost(post.id);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('수정하기')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('삭제하기', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
            ],
          ),
          body: Column(
            children: [
              // 1. 게시글 내용 영역 (스크롤 가능)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPostHeader(context, post),
                      _buildPostBody(post),
                      const Divider(height: 1),
                      _buildCommentList(post.comments), // 댓글 목록
                    ],
                  ),
                ),
              ),
              // 2. 댓글 작성 입력창
              _buildCommentComposer(),
            ],
          ),
        );
      },
    );
  }

  // ---------------- UI 헬퍼 위젯 (수정 X) ----------------

  Widget _buildPostHeader(BuildContext context, Post post) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('작성자: ${post.authorName}', style: const TextStyle(fontSize: 16)),
          Text(
            '작성일: ${DateFormat('yyyy.MM.dd HH:mm').format(post.createdAt.toLocal())}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPostBody(Post post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Text(post.content, style: const TextStyle(fontSize: 16)),
    );
  }

  Widget _buildCommentList(List<Comment> comments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '댓글 (${comments.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ...comments.map((comment) {
          // 11. 🟢 [핵심 수정] 댓글 삭제 권한 확인
          final bool isCommentAuthor = comment.authorId == _currentUserId;
          return ListTile(
            title: Text(
              comment.authorName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(comment.content),
            trailing:
                isCommentAuthor // 🟢 이 로직이 이제 정확하게 동작합니다.
                ? IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () => _handleCommentDelete(comment.id),
                  )
                : null,
          );
        }).toList(),
      ],
    );
  }

  Widget _buildCommentComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  hintText: '댓글을 입력하세요...',
                  border: InputBorder.none,
                ),
                enabled: !_isCommentLoading,
                maxLines: 4,
                minLines: 1,
              ),
            ),
            _isCommentLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF486B48)),
                    onPressed: _handleCommentSubmit,
                  ),
          ],
        ),
      ),
    );
  }
}
