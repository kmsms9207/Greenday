import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../model/api.dart'; // fetchMyPlants, fetchDiary, createManualDiary 포함
import '../model/diary_model.dart';
import '../model/plant.dart';
import 'plant_diary_form.dart'; // 수동 일지 작성 화면

class PlantDiaryScreen extends StatefulWidget {
  const PlantDiaryScreen({super.key});

  @override
  State<PlantDiaryScreen> createState() => _PlantDiaryScreenState();
}

class _PlantDiaryScreenState extends State<PlantDiaryScreen> {
  final _storage = const FlutterSecureStorage();
  List<DiaryEntry> _allEntries = [];
  bool _loading = true;
  String? _accessToken; // 🟢 이미지 표시를 위해 accessToken 유지

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  Future<void> _initScreen() async {
    await _loadAccessToken(); // 🟢 이미지 로드를 위해 토큰 로드
    await _fetchAllDiaryEntries();
  }

  Future<void> _loadAccessToken() async {
    try {
      final token = await _storage.read(key: 'accessToken');
      if (mounted) setState(() => _accessToken = token);
    } catch (e) {
      print('Access Token 로드 실패: $e');
    }
  }

  Future<void> _fetchAllDiaryEntries() async {
    setState(() => _loading = true);
    try {
      // 🟢 api.dart의 함수는 내부적으로 인증 처리
      final myPlants = await fetchMyPlants();
      List<DiaryEntry> combinedEntries = [];

      for (var plant in myPlants) {
        // 🟢 api.dart의 함수는 내부적으로 인증 처리
        final entries = await fetchDiary(plant.id);
        combinedEntries.addAll(entries);
      }

      combinedEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _allEntries = combinedEntries;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('일지 불러오기 실패: $e')));
    }
  }

  // PlantDiaryForm으로 이동 후 새로고침
  Future<void> _navigateToAddDiary() async {
    // 🟢 일지 작성 전 식물이 있는지 확인
    final plants = await fetchMyPlants();
    if (plants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일지를 작성할 식물이 없습니다. 먼저 식물을 등록해주세요.')),
      );
      return;
    }

    // 🟢 TODO: (이슈D) 현재는 첫 번째 식물을 무조건 선택합니다.
    // 추후 이 부분에서 식물 선택 다이얼로그를 띄워야 합니다.
    final firstPlantId = plants.first.id;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        // 🟢 plantId는 이제 필수입니다.
        builder: (context) => PlantDiaryFormScreen(plantId: firstPlantId),
      ),
    );

    // 폼에서 true(저장 성공)를 반환하면 목록 새로고침
    if (result == true) {
      await _fetchAllDiaryEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFA4B6A4),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _allEntries.isEmpty
          ? const Center(child: Text('작성된 일지가 없습니다.'))
          : RefreshIndicator(
              onRefresh: _fetchAllDiaryEntries,
              child: ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: _allEntries.length,
                itemBuilder: (context, index) {
                  final entry = _allEntries[index];
                  return _buildDiaryCard(entry);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddDiary,
        backgroundColor: const Color(0xFFA4B6A4),
        child: const Icon(Icons.edit),
      ),
    );
  }

  // 🟢 [수정] UI 카드 수정
  Widget _buildDiaryCard(DiaryEntry entry) {
    // 🟢 title이 비어있으면 logType을 제목으로 사용
    final String displayTitle = entry.title != null && entry.title!.isNotEmpty
        ? entry.title!
        : _getLogTypeLabel(entry.logType);

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 제목 (Title)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 🟢 [수정] displayTitle 표시
                Text(
                  displayTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ), // 크기 조정
                ),
                Text(
                  _formatDateTime(entry.createdAt),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ), // 크기 조정
                ),
              ],
            ),

            // 2. 부제목 (LogType, title이 있을 경우에만 표시)
            if (entry.title != null && entry.title!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  _getLogTypeLabel(entry.logType), // 🟢 logType을 부제목으로
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // 3. 내용 (Content)
            if (entry.logMessage.isNotEmpty)
              Text(
                entry.logMessage,
                style: const TextStyle(fontSize: 16),
              ), // 크기 조정
            // 4. 이미지 (Image)
            if (entry.imageUrl != null &&
                entry.imageUrl!.isNotEmpty &&
                _accessToken != null)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                // 🟢 이미지 로드를 위해 accessToken 유지
                child: Image.network(
                  baseUrl + entry.imageUrl!,
                  headers: {'Authorization': 'Bearer $_accessToken'},
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getLogTypeLabel(String logType) {
    switch (logType) {
      case 'DIAGNOSIS':
        return '🩺 진단';
      case 'WATERING':
        return '💧 물주기';
      case 'NOTE':
        return '📝 메모';
      case 'PHOTO':
        return '📸 사진';
      case 'BIRTHDAY':
        return '🎂 생일';
      default:
        return logType;
    }
  }

  String _formatDateTime(DateTime dateTime) =>
      '${dateTime.year}-${_twoDigits(dateTime.month)}-${_twoDigits(dateTime.day)} '
      '${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}';

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
}
