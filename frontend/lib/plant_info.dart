import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'model/api.dart';
import 'model/plant.dart';
import 'diagnosis_screen.dart';
import 'plant_diary.dart';

// 🚨 [제거] _storage 변수 및 _getAccessToken 함수는 api.dart의 함수들이 처리하므로 제거됩니다.
/*
final _storage = const FlutterSecureStorage();

Future<String> _getAccessToken() async {
  final accessToken = await _storage.read(key: 'accessToken');
  if (accessToken == null) {
    throw Exception('로그인 토큰을 찾을 수 없습니다. 다시 로그인해주세요.');
  }
  return accessToken;
}
*/

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
    // 초기 위젯의 plant 객체를 먼저 설정 (로딩 실패 시 대비)
    _plant = widget.plant;
    _fetchPlantDetail();
  }

  Future<void> _fetchPlantDetail() async {
    try {
      final updatedPlant = await fetchMyPlantDetail(widget.plant.id);
      setState(() {
        _plant = updatedPlant;
        // 서버에서 lastWateredAt 정보가 있다면 반영 (현재 Plant 모델에 해당 필드가 있다고 가정)
        // _lastWateredAt = updatedPlant.lastWateredAt;
        _loading = false;
      });
    } catch (e) {
      print('식물 정보 불러오기 실패: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _handleWatering(BuildContext context) async {
    if (_plant == null) return;
    try {
      // 🚨 [수정] 토큰을 가져오는 로컬 로직 제거
      // final accessToken = await _getAccessToken();
      // 🟢 [수정] markAsWatered 함수 호출 시 accessToken 인자를 제거
      await markAsWatered(_plant!.id);

      setState(() => _lastWateredAt = DateTime.now());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('물주기 기록 완료!')));

      // 물주기 일지 자동 저장 (옵션)
      await createManualDiary(plantId: _plant!.id, logMessage: '물을 주었습니다.');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('물주기 기록 실패: $e')));
    }
  }

  Future<void> _handleSnooze(BuildContext context) async {
    if (_plant == null) return;
    try {
      // 🚨 [수정] 토큰을 가져오는 로컬 로직 제거
      // final accessToken = await _getAccessToken();
      // 🟢 [수정] snoozeWatering 함수 호출 시 accessToken 인자를 제거
      await snoozeWatering(_plant!.id);

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
                  // 🚨 [수정] deleteMyPlant 함수는 이미 인자를 받지 않도록 api.dart에서 수정됨
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

  // -------------------- 병해충 진단 버튼 핸들러 --------------------
  Future<void> _handleDiagnosis(BuildContext context) async {
    if (_plant == null) return;

    // DiagnosisScreen 호출 시 plantId를 필수로 전달합니다. (에러 해결!)
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        // 'plantId' required 에러 해결: plantId 전달
        builder: (_) => DiagnosisScreen(plantId: _plant!.id),
      ),
    );

    // DiagnosisScreen에서 Navigator.pop으로 결과가 반환될 경우 처리
    if (result != null && result is Map) {
      final title = result['title'] as String?;
      // final content = result['content'] as String?; // 사용 안 함

      if (title != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$title 진단 완료!')));

        // -------------------- 자동 성장 일지 저장 --------------------
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
                _leftInfoTile("물 주기", _plant!.wateringType),
                _leftInfoTile(
                  "물 준 날",
                  // _lastWateredAt 값이 null이 아닐 때만 포매팅
                  _lastWateredAt != null
                      ? _formatDateTime(_lastWateredAt!)
                      : (_plant!.lastWateredAt != null
                            ? _formatDateTime(_plant!.lastWateredAt!)
                            : "정보 없음"),
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
    // 위젯 구현부는 그대로 유지
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
    // 위젯 구현부는 그대로 유지
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

  // DateTime 포맷 함수 구현
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${_twoDigits(dateTime.month)}-${_twoDigits(dateTime.day)} '
        '${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}';
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
}
