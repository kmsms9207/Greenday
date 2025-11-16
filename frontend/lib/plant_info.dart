import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'model/api.dart';
import 'model/plant.dart';
import 'diagnosis_screen.dart';

// 전역 변수는 그대로 유지
final _storage = const FlutterSecureStorage();

Future<String> _getAccessToken() async {
  final accessToken = await _storage.read(key: 'accessToken');
  if (accessToken == null) {
    throw Exception('로그인 토큰을 찾을 수 없습니다. 다시 로그인해주세요.');
  }
  return accessToken;
}

class PlantInfoScreen extends StatefulWidget {
  final Plant plant;
  const PlantInfoScreen({super.key, required this.plant});

  @override
  State<PlantInfoScreen> createState() => _PlantInfoScreenState();
}

class _PlantInfoScreenState extends State<PlantInfoScreen> {
  Plant? _plant;
  bool _loading = true;
  DateTime? _lastWateredAt;

  @override
  void initState() {
    super.initState();
    _plant = widget.plant;
    _lastWateredAt = widget.plant.lastWateredAt;
    _fetchPlantDetail();
  }

  Future<void> _fetchPlantDetail() async {
    try {
      final updatedPlant = await fetchMyPlantDetail(widget.plant.id);
      if (mounted) {
        setState(() {
          _plant = updatedPlant;
          _lastWateredAt = updatedPlant.lastWateredAt;
          _loading = false;
        });
      }
    } catch (e) {
      print('식물 정보 불러오기 실패: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // 🚨 [새로운 기능]: 물주기 타입에 따라 일수를 매핑하는 헬퍼 함수 추가
  String getWateringCycle(String type) {
    switch (type) {
      case '자주':
        return ' (5일)';
      case '보통':
        return ' (10일)';
      case '적게':
        return ' (15일)';
      default:
        return '';
    }
  }

  Future<void> _handleWatering(BuildContext context) async {
    if (_plant == null) return;
    try {
      final accessToken = await _getAccessToken();
      await markAsWatered(_plant!.id, accessToken);
      
      // 물주기 일지 자동 저장
      await createManualDiary(plantId: _plant!.id, logMessage: '물을 주었습니다.');

      if (mounted) {
        setState(() => _lastWateredAt = DateTime.now());
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('물주기 기록 및 일지 저장 완료!')));
      
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('물주기 기록 실패: $e')));
    }
  }

  Future<void> _handleSnooze(BuildContext context) async {
    if (_plant == null) return;
    try {
      final accessToken = await _getAccessToken();
      await snoozeWatering(_plant!.id, accessToken);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('물주기 알림을 하루 미뤘습니다.')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('알림 미루기 실패: $e')));
    }
  }

  Future<void> _showDeletePlantDialog(BuildContext context) async {
    if (_plant == null) return;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('식물 삭제 확인'),
          content: const Text('정말로 이 식물을 삭제하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await deleteMyPlant(_plant!.id);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('식물이 삭제되었습니다.')));
                  Navigator.pop(context, true);
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleDiagnosis(BuildContext context) async {
    if (_plant == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiagnosisScreen(plantId: _plant!.id), 
      ),
    );

    if (result != null && result is Map) {
      final title = result['title'] as String?;

      if (title != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$title 진단 완료!')));

        try {
          await createManualDiary(
            plantId: _plant!.id,
            logMessage: '[AI 진단] $title',
          );
          print('자동 성장 일지 저장 성공: [AI 진단] $title');
        } catch (e) {
          print('자동 성장 일지 서버 저장 실패: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _plant == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        toolbarHeight: 50,
        centerTitle: true,
        title: const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: "GREEN",
                style: TextStyle(fontSize: 25, color: Color(0xFF486B48)),
              ),
              TextSpan(
                text: " DAY",
                style: TextStyle(fontSize: 25, color: Colors.black),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Center(
              child: _centerInfoTile(
                _plant!.nameKo,
                _plant!.species,
                imageUrl: _plant!.imageUrl,
              ),
            ),
            const SizedBox(height: 30),
            Column(
              children: [
                _leftInfoTile("햇빛", _plant!.lightRequirement),
                
                // 🚨 [수정 적용]: 물주기 타입과 일수 매핑 결과를 결합하여 표시
                _leftInfoTile(
                  "물 주기", 
                  _plant!.wateringType + getWateringCycle(_plant!.wateringType)
                ),
                
                _leftInfoTile(
                  "물 준 날짜",
                  _lastWateredAt != null
                      ? _formatDateTime(_lastWateredAt!)
                      : (_plant!.lastWateredAt != null
                              ? _formatDateTime(_plant!.lastWateredAt!)
                              : "기록 없음"),
                ),
                _leftInfoTile("난이도", _plant!.difficulty),
                _leftInfoTile("반려동물 안전", _plant!.petSafe ? "안전" : "주의"),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _handleWatering(context),
                  icon: const Icon(Icons.water_drop_outlined),
                  label: const Text("물 줬어요"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[100],
                    foregroundColor: Colors.blue[800],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _handleSnooze(context),
                  icon: const Icon(Icons.snooze),
                  label: const Text("하루 미루기"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[100],
                    foregroundColor: Colors.orange[800],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _handleDiagnosis(context),
                  icon: const Icon(Icons.medical_services),
                  label: const Text("병해충 진단"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[100],
                    foregroundColor: Colors.green[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
      bottomNavigationBar: SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          onPressed: () => _showDeletePlantDialog(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[400],
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
          child: const Text("삭제", style: TextStyle(fontSize: 25)),
        ),
      ),
    );
  }

  Widget _centerInfoTile(String name, String species, {String? imageUrl}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            image: imageUrl != null && imageUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: (imageUrl == null || imageUrl.isEmpty)
              ? const Icon(Icons.eco, size: 40, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 5),
        Text(
          name,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Color(0xFF486B48),
          ),
        ),
        Text(
          species,
          style: const TextStyle(fontSize: 20, color: Color(0xFFA4B6A4)),
        ),
      ],
    );
  }

  Widget _leftInfoTile(String label, String value) {
    return Card(
      color: const Color(0xFFF1F1F1),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: double.infinity,
        height: 50,
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF656565),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value.isNotEmpty ? value : "정보 없음",
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${_twoDigits(dateTime.month)}-${_twoDigits(dateTime.day)} '
        '${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}';
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
}