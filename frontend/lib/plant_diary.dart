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
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  Future<void> _initScreen() async {
    await _loadAccessToken();
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
      final myPlants = await fetchMyPlants();
      List<DiaryEntry> combinedEntries = [];

      for (var plant in myPlants) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일지 불러오기 실패: $e')),
      );
    }
  }

  // PlantDiaryForm으로 이동 후 새로고침
  Future<void> _navigateToAddDiary() async {
    final plants = await fetchMyPlants();
    if (plants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('작성할 식물이 없습니다.')),
      );
      return;
    }

    final firstPlantId = plants.first.id;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlantDiaryFormScreen(plantId: firstPlantId),
      ),
    );

    await _fetchAllDiaryEntries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFA4B6A4), // 수정된 배경색
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

  Widget _buildDiaryCard(DiaryEntry entry) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 타입 및 날짜
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getLogTypeLabel(entry.logType),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 22),
                ),
                Text(
                  _formatDateTime(entry.createdAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 내용
            if (entry.logMessage.isNotEmpty)
              Text(entry.logMessage, style: const TextStyle(fontSize: 20)),
            // 이미지
            if (entry.imageUrl != null &&
                entry.imageUrl!.isNotEmpty &&
                _accessToken != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Image.network(
                  baseUrl + entry.imageUrl!,
                  headers: {'Authorization': 'Bearer $_accessToken'},
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