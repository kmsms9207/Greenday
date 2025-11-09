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

  Future<String> _getAccessToken() async {
    final accessToken = await _storage.read(key: 'accessToken');
    if (accessToken == null) {
      throw Exception('로그인 토큰을 찾을 수 없습니다.');
    }
    return accessToken;
  }

  // 물 줬어요 버튼
  Future<void> _handleWatering(int notificationId, int plantId) async {
    setState(() {
      _wateredOrSnoozedNotifications.add(notificationId);
    });

    try {
      final accessToken = await _getAccessToken();
      await markAsWatered(plantId, accessToken);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('물주기 기록 완료!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('물주기 기록 실패: $e')),
      );
    }
  }

  // 하루 미루기 버튼
  Future<void> _handleSnooze(int notificationId, int plantId) async {
    setState(() {
      _wateredOrSnoozedNotifications.add(notificationId);
    });

    try {
      final accessToken = await _getAccessToken();
      await snoozeWatering(plantId, accessToken);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('물주기 알림을 하루 미뤘습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('알림 미루기 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFA4B6A4);

    // myPlants 기반으로 물주기 알림 생성
    final List<Map<String, dynamic>> notifications = widget.myPlants.map((plant) {
      return {
        'id': plant.id,
        'type': 'watering',
        'plantId': plant.id,
        'title': '${plant.nameKo} 물 줄 시간이에요!',
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
                      final bool showButtons = !_wateredOrSnoozedNotifications.contains(notification['id']);
                      final bool isWateringNotification = notification['type'] == 'watering';

                      return ListTile(
                        leading: const Icon(Icons.water_drop_outlined, color: Colors.blue),
                        title: Text(notification['title'] as String),
                        subtitle: showButtons && isWateringNotification
                            ? Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: () => _handleWatering(notification['id'] as int, notification['plantId'] as int),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[50],
                                      foregroundColor: Colors.blue[700],
                                      minimumSize: Size.zero,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    ),
                                    child: const Text('물 줬어요', style: TextStyle(fontSize: 12)),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () => _handleSnooze(notification['id'] as int, notification['plantId'] as int),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange[50],
                                      foregroundColor: Colors.orange[700],
                                      minimumSize: Size.zero,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    ),
                                    child: const Text('하루 미루기', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              )
                            : null,
                        onTap: () {
                          // 클릭하면 해당 식물 정보 화면으로 이동
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlantInfoScreen(
                                plant: widget.myPlants.firstWhere((p) => p.id == notification['plantId']),
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
}