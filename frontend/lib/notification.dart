import 'package:flutter/material.dart';
import 'model/plant.dart';
import 'model/api.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'plant_info.dart';

class NotificationScreen extends StatefulWidget {
  final List<Plant> myPlants;
  const NotificationScreen({super.key, required this.myPlants});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _storage = const FlutterSecureStorage();

  // 버튼이 사라질 알림 ID를 저장
  final Set<int> _wateredOrSnoozedNotifications = {};

  // 로컬에서 화면용으로 마지막 물 준 시간 저장
  final Map<int, DateTime> _tempLastWateredAt = {};

  // 🚨 [제거] _getAccessToken 함수는 api.dart의 함수들이 내부적으로 처리하므로 제거됩니다.
  /*
  Future<String> _getAccessToken() async {
    final accessToken = await _storage.read(key: 'accessToken');
    if (accessToken == null) {
      throw Exception('로그인 토큰을 찾을 수 없습니다.');
    }
    return accessToken;
  }
  */

  // ---------------- 물 줬어요 버튼 ----------------
  Future<void> _handleWatering(int notificationId, int plantId) async {
    try {
      // 🚨 [수정] 토큰을 로컬에서 가져오는 로직과 인자 전달 제거
      // final accessToken = await _getAccessToken();
      await markAsWatered(plantId); // 🟢 수정: accessToken 인자 제거

      setState(() {
        _wateredOrSnoozedNotifications.add(notificationId);
        _tempLastWateredAt[plantId] = DateTime.now(); // 화면용 갱신
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('물주기 기록 완료!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('물주기 기록 실패: $e')));
    }
  }

  // ---------------- 하루 미루기 버튼 ----------------
  Future<void> _handleSnooze(int notificationId, int plantId) async {
    try {
      // 🚨 [수정] 토큰을 로컬에서 가져오는 로직과 인자 전달 제거
      // final accessToken = await _getAccessToken();
      await snoozeWatering(plantId); // 🟢 수정: accessToken 인자 제거

      setState(() {
        _wateredOrSnoozedNotifications.add(notificationId);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('물주기 알림을 하루 미뤘습니다.')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('알림 미루기 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFA4B6A4);

    // myPlants 기반으로 물주기 알림 생성
    final List<Map<String, dynamic>> notifications = widget.myPlants.map((
      plant,
    ) {
      // 화면에 표시할 마지막 물 준 시간
      String lastWateredText = _tempLastWateredAt.containsKey(plant.id)
          ? '마지막 물 준 시간: ${_formatDateTime(_tempLastWateredAt[plant.id]!)}'
          : '';

      return {
        'id': plant.id,
        'type': 'watering',
        'plantId': plant.id,
        'title': '${plant.nameKo} 물 줄 시간이에요!',
        'lastWateredText': lastWateredText,
        'time': '지금',
      };
    }).toList();

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
                      final bool showButtons = !_wateredOrSnoozedNotifications
                          .contains(notification['id']);
                      final bool isWateringNotification =
                          notification['type'] == 'watering';

                      return ListTile(
                        leading: const Icon(
                          Icons.water_drop_outlined,
                          color: Colors.blue,
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notification['title'] as String),
                            if (notification['lastWateredText'] != '')
                              Text(
                                notification['lastWateredText'],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                        subtitle: showButtons && isWateringNotification
                            ? Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: () => _handleWatering(
                                      notification['id'] as int,
                                      notification['plantId'] as int,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[50],
                                      foregroundColor: Colors.blue[700],
                                      minimumSize: Size.zero,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                    ),
                                    child: const Text(
                                      '물 줬어요',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () => _handleSnooze(
                                      notification['id'] as int,
                                      notification['plantId'] as int,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange[50],
                                      foregroundColor: Colors.orange[700],
                                      minimumSize: Size.zero,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                    ),
                                    child: const Text(
                                      '하루 미루기',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              )
                            : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlantInfoScreen(
                                plant: widget.myPlants.firstWhere(
                                  (p) => p.id == notification['plantId'],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.grey[200],
                      indent: 16,
                      endIndent: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 화면 표시용 날짜 포맷
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${_twoDigits(dateTime.month)}-${_twoDigits(dateTime.day)} '
        '${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}';
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
}
