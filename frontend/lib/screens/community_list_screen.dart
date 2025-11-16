// lib/screens/community_list_screen.dart (UI 개선 버전)

import 'package:flutter/material.dart';
import 'package:flutter_application_1/model/post.dart';
import 'package:flutter_application_1/model/api.dart' as api;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'community_post_detail_screen.dart'; // 상세 화면
import 'community_post_form_screen.dart'; // 작성/수정 화면
import 'package:intl/intl.dart'; // 날짜 포맷팅을 위해 추가

class CommunityListScreen extends StatefulWidget {
  const CommunityListScreen({Key? key}) : super(key: key);

  @override
  _CommunityListScreenState createState() => _CommunityListScreenState();
}

class _CommunityListScreenState extends State<CommunityListScreen> {
  Future<List<Post>?>? _postsFuture;
  final _storage = const FlutterSecureStorage(); // 저장소 인스턴스는 유지

  @override
  void initState() {
    super.initState();
    _loadPosts(); // 게시글 로드 시작
  }

  Future<void> _loadPosts() async {
    setState(() {
      _postsFuture = api
          .getCommunityPosts()
          .then((postsData) {
            if (postsData != null) {
              return postsData.map((data) => Post.fromJson(data)).toList();
            }
            return null;
          })
          .catchError((e) {
            print('게시글 목록 로드 실패: $e');
            return null;
          });
    });
  }

  void _navigateToDetail(int postId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommunityPostDetailScreen(postId: postId),
      ),
    ).then((value) {
      if (value == true) {
        _loadPosts();
      }
    });
  }

  void _navigateToCreateForm() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CommunityPostFormScreen()),
    ).then((value) {
      if (value == true) {
        _loadPosts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_postsFuture == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('커뮤니티')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '커뮤니티',
          style: TextStyle(
            fontWeight: FontWeight.bold, // 제목 볼드체
            color: Color(0xFF486B48), // 앱의 주요 색상
          ),
        ),
        centerTitle: true, // 제목 가운데 정렬
        backgroundColor: Colors.white, // 앱바 배경색
        elevation: 1, // 앱바 그림자 약간
      ),
      body: FutureBuilder<List<Post>?>(
        future: _postsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Text('데이터 로드 실패: ${snapshot.error ?? "알 수 없는 오류"}'),
            );
          } else if (snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                '아직 게시글이 없습니다.\n새 글을 작성해 보세요!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final posts = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _loadPosts,
            color: const Color(0xFF486B48), // 새로고침 아이콘 색상
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0), // 전체 리스트 패딩
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];

                final String displayedAuthor =
                    (post.authorName == '작성자 불명' && post.authorId.isNotEmpty)
                    ? post
                          .authorId // 이름/유저명은 없지만 ID(PK)는 있을 경우 ID 표시
                    : post.authorName; // '이름' 또는 '유저명' 표시 (정상)

                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 6.0,
                    horizontal: 4.0,
                  ), // 카드별 마진
                  elevation: 2, // 카드 그림자
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // 카드 모서리 둥글게
                  ),
                  child: InkWell(
                    // 탭 효과를 위해 InkWell 사용
                    onTap: () => _navigateToDetail(post.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0), // 카드 내부 패딩
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1, // 제목 한 줄로 제한
                            overflow: TextOverflow.ellipsis, // 넘치면 ...
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 16,
                                color: Colors.grey[600],
                              ), // 작성자 아이콘
                              const SizedBox(width: 4),
                              Text(
                                displayedAuthor,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const Spacer(), // 중간에 공간 채우기
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: Colors.grey[600],
                              ), // 시간 아이콘
                              const SizedBox(width: 4),
                              Text(
                                DateFormat(
                                  'yyyy.MM.dd HH:mm',
                                ).format(post.createdAt.toLocal()),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          // 선택적으로 게시글 내용 미리보기 추가
                          // if (post.content.isNotEmpty) ...[
                          //   const SizedBox(height: 8),
                          //   Text(
                          //     post.content,
                          //     style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                          //     maxLines: 2,
                          //     overflow: TextOverflow.ellipsis,
                          //   ),
                          // ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateForm,
        child: const Icon(Icons.add, color: Colors.white), // 아이콘 색상
        backgroundColor: const Color(0xFF486B48), // 버튼 배경색
        tooltip: '새 글 작성',
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ), // 둥근 모양
        elevation: 4, // 그림자
      ),
    );
  }
}
