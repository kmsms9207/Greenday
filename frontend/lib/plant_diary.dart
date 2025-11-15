import 'dart:io';
import 'package:flutter/material.dart';
import 'model/api.dart';
import 'plant_diary_form.dart';

class PlantDiaryScreen extends StatefulWidget {
  final int? plantId; // nullable
  const PlantDiaryScreen({Key? key, this.plantId}) : super(key: key);

  @override
  State<PlantDiaryScreen> createState() => _PlantDiaryScreenState();
}

class _PlantDiaryScreenState extends State<PlantDiaryScreen> {
  List<DiaryEntry> _diaryList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchDiary();
  }

  Future<void> _fetchDiary() async {
    if (widget.plantId == null) {
      setState(() {
        _diaryList = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final diary = await fetchDiary(widget.plantId!);
      setState(() {
        _diaryList = diary;
        _loading = false;
      });
    } catch (e) {
      print('일지 불러오기 실패: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _openFormScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlantDiaryFormScreen(plantId: widget.plantId),
      ),
    );

    if (result == true) {
      _fetchDiary(); // 새 일지 작성 후 갱신
    }
  }

  // ------------------- 팝업으로 상세 보기 -------------------
  void _showDiaryDetail(DiaryEntry entry) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry.imageUrl != null)
                  Image.network(
                    '$baseUrl${entry.imageUrl}',
                    fit: BoxFit.contain,
                  ),
                const SizedBox(height: 16),
                Text(entry.logMessage, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text(
                  '${entry.logType} • ${entry.createdAt.toLocal()}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('닫기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('성장 일지'),
        centerTitle: true,
        backgroundColor: Color(0xFFA4B6A4),
        foregroundColor: Colors.black87,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _diaryList.isEmpty
          ? const Center(child: Text('등록된 일지가 없습니다.'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _diaryList.length,
              itemBuilder: (context, index) {
                final entry = _diaryList[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text(
                      entry.logMessage,
                      style: const TextStyle(fontSize: 16),
                    ),
                    subtitle: Text(
                      '${entry.logType} • ${entry.createdAt.toLocal()}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: entry.imageUrl != null
                        ? Image.network(
                            '$baseUrl${entry.imageUrl}',
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          )
                        : null,
                    onTap: () => _showDiaryDetail(entry), // 클릭 시 팝업
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openFormScreen,
        child: const Icon(Icons.add),
        backgroundColor: Color(0xFF486B48),
      ),
    );
  }
}
