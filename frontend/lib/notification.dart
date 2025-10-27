import 'package:flutter/material.dart';
import 'model/api.dart'; // 1. API 서비스 파일을 import 합니다.
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // 2. Secure Storage import

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  // 3. Secure Storage 인스턴스 생성
  final _storage = const FlutterSecureStorage();

  // "물 줬어요" 버튼 클릭 시 실행될 함수
  Future<void> _handleWatering(BuildContext context, int plantId) async {
    try {
      // 4. 저장된 accessToken을 읽어옵니다.
      final accessToken = await _storage.read(key: 'accessToken');
      if (accessToken == null) {
        throw Exception('로그인 토큰을 찾을 수 없습니다.');
      }

      await markAsWatered(plantId, accessToken); // 5. API 호출 시 accessToken 전달
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('물주기 기록 완료!')));
      // TODO: 성공 시 알림 목록에서 해당 알림을 제거하거나 상태를 변경하는 로직 추가
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('물주기 기록 실패: $e')));
    }
  }

  // "하루 미루기" 버튼 클릭 시 실행될 함수
  Future<void> _handleSnooze(BuildContext context, int plantId) async {
    try {
      // 4. 저장된 accessToken을 읽어옵니다.
      final accessToken = await _storage.read(key: 'accessToken');
      if (accessToken == null) {
        throw Exception('로그인 토큰을 찾을 수 없습니다.');
      }

      await snoozeWatering(plantId, accessToken); // 5. API 호출 시 accessToken 전달
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('물주기 알림을 하루 미뤘습니다.')));
      // TODO: 성공 시 알림 목록에서 해당 알림을 제거하거나 상태를 변경하는 로직 추가
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('알림 미루기 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFA4B6A4);

    // 더미 데이터 수정: 물주기 알림 예시 추가 (type, plantId 포함)
    final List<Map<String, dynamic>> notifications = [
      {
        'id': 1,
        'type': 'watering',
        'plantId': 101,
        'title': '몬스테라 물 줄 시간이에요!',
        'time': '30분 전',
      },
      {
        'id': 2,
        'type': 'growth_log',
        'title': '새로운 성장일지가 등록되었습니다.',
        'time': '1시간 전',
      },
      {
        'id': 3,
        'type': 'comment',
        'title': '댓글에 답글이 달렸습니다: "예쁘게 잘 키우셨네요!"',
        'time': '3시간 전',
      },
      {
        'id': 4,
        'type': 'like',
        'title': '회원님의 게시글을 다른 사람이 좋아합니다.',
        'time': '1일 전',
      },
      {'id': 5, 'type': 'notice', 'title': '새로운 공지사항을 확인해보세요.', 'time': '2일 전'},
      {
        'id': 6,
        'type': 'event',
        'title': '[이벤트] 식물 사진 콘테스트가 시작되었습니다!',
        'time': '5일 전',
      },
    ];

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Icon(
          Icons.notifications_none_outlined,
          color: Colors.white,
          size: 30,
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.0),
          child: Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    "알림",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final bool isWateringNotification =
                          notification['type'] == 'watering';

                      return ListTile(
                        leading: _getLeadingIcon(
                          notification['type'] as String?,
                        ),
                        title: Text(notification['title'] as String),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notification['time'] as String),
                            // 2. 물주기 알림일 경우 버튼들을 추가합니다.
                            if (isWateringNotification)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    ElevatedButton(
                                      // 6. 함수 연결
                                      onPressed: () => _handleWatering(
                                        context,
                                        notification['plantId'] as int,
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        minimumSize: Size.zero, // 최소 크기 제한 제거
                                        tapTargetSize: MaterialTapTargetSize
                                            .shrinkWrap, // 터치 영역 최소화
                                        backgroundColor: Colors.blue[50],
                                        foregroundColor: Colors.blue[700],
                                      ),
                                      child: const Text(
                                        '물 줬어요',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      // 6. 함수 연결
                                      onPressed: () => _handleSnooze(
                                        context,
                                        notification['plantId'] as int,
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        backgroundColor: Colors.orange[50],
                                        foregroundColor: Colors.orange[700],
                                      ),
                                      child: const Text(
                                        '하루 미루기',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          // TODO: 각 알림을 눌렀을 때 해당 상세 페이지로 이동
                        },
                      );
                    },
                    separatorBuilder: (context, index) {
                      // 각 알림 사이에 희미한 회색 구분선 추가
                      return Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.grey[200],
                        indent: 16,
                        endIndent: 16,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 알림 타입에 따라 다른 아이콘을 반환하는 함수
  Widget _getLeadingIcon(String? type) {
    switch (type) {
      case 'watering':
        return const Icon(Icons.water_drop_outlined, color: Colors.blue);
      case 'growth_log':
        return const Icon(Icons.note_alt_outlined, color: Colors.green);
      case 'comment':
        return const Icon(Icons.comment_outlined, color: Colors.orange);
      case 'like':
        return const Icon(Icons.favorite_border, color: Colors.redAccent);
      case 'notice':
        return const Icon(Icons.campaign_outlined, color: Colors.purple);
      case 'event':
        return const Icon(Icons.celebration_outlined, color: Colors.teal);
      default:
        return const Icon(Icons.notifications_none, color: Color(0xFF486B48));
    }
  }
}
