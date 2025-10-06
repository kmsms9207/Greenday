import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFA4B6A4);

    // 더미 데이터 필요
    final List<Map<String, String>> notifications = [
      {'title': '새로운 성장일지가 등록되었습니다.', 'time': '1시간 전'},
      {'title': '댓글에 답글이 달렸습니다: "예쁘게 잘 키우셨네요!"', 'time': '3시간 전'},
      {'title': '회원님의 게시글을 다른 사람이 좋아합니다.', 'time': '1일 전'},
      {'title': '새로운 공지사항을 확인해보세요.', 'time': '2일 전'},
      {'title': '[이벤트] 식물 사진 콘테스트가 시작되었습니다!', 'time': '5일 전'},
    ];

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
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
                      return ListTile(
                        leading: const Icon(
                          Icons.eco_outlined,
                          color: Color(0xFF486B48),
                        ),
                        title: Text(notifications[index]['title']!),
                        subtitle: Text(notifications[index]['time']!),
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
}
