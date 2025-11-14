import 'package:flutter/material.dart';
import 'plant_diary_form.dart';
import 'model/api.dart';

class PlantDiaryScreen extends StatefulWidget {
  final int plantId; // 서버 저장용 plantId 필요

  const PlantDiaryScreen({super.key, required this.plantId});

  @override
  State<PlantDiaryScreen> createState() => _PlantDiaryScreenState();
}

class _PlantDiaryScreenState extends State<PlantDiaryScreen> {
  List<Map<String, String>> diaryList = [];

  // AI 진단 또는 사용자 작성 일지 추가
  void addDiary({
    String? nickname, // 사용자 작성일 경우만 nickname 사용, AI 자동 저장은 null
    required String title, // 병명 또는 사용자 입력 제목
    required String content, // 처리 추천 또는 사용자 입력 내용
    bool isDiagnosis = false, // 진단 기록 여부
  }) async {
    final diaryEntry = {
      'nickname': isDiagnosis ? '' : (nickname ?? ''),
      'title': isDiagnosis ? '진단 기록' : title,
      'content': content,
      'date':
          "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2,'0')}-${DateTime.now().day.toString().padLeft(2,'0')}",
    };

    setState(() {
      diaryList.add(diaryEntry);
    });

    // 서버 저장 시도
    try {
      await createManualDiary(
        plantId: widget.plantId,
        logMessage: diaryEntry['content'] ?? '',
      );
      print("서버 저장 성공: ${diaryEntry['title']}");
    } catch (e) {
      print("서버 저장 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFA4B6A4);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "GREEN DAY",
          style: TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black54),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 날짜 표시
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2,'0')}-${DateTime.now().day.toString().padLeft(2,'0')}",
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        // 일지 추가 버튼
                        ElevatedButton(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const PlantDiaryFormScreen(),
                              ),
                            );

                            if (result != null && result is Map<String, String>) {
                              if ((result['title'] ?? '').isNotEmpty &&
                                  (result['nickname'] ?? '').isNotEmpty) {
                                addDiary(
                                  nickname: result['nickname'],
                                  title: result['title']!,
                                  content: result['content'] ?? '',
                                  isDiagnosis: false,
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(12),
                            backgroundColor: const Color(0xFFD7E0D7),
                            foregroundColor: Colors.black54,
                            elevation: 2,
                          ),
                          child: const Icon(Icons.edit, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 일지 목록 표시
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: diaryList.isEmpty
                          ? const Center(
                              child: Icon(Icons.eco,
                                  size: 40, color: Color(0xFF486B48)),
                            )
                          : Column(
                              children: diaryList.reversed.map((diary) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: InkWell(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            title: Text(diary['title'] ?? ''),
                                            content: SingleChildScrollView(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if ((diary['nickname'] ?? '').isNotEmpty)
                                                    Text("이름: ${diary['nickname']}"),
                                                  const SizedBox(height: 4),
                                                  Text("날짜: ${diary['date'] ?? ''}"),
                                                  const SizedBox(height: 8),
                                                  Text(diary['content'] ?? ''),
                                                ],
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('닫기'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        if ((diary['nickname'] ?? '').isNotEmpty)
                                          Text(
                                            diary['nickname'] ?? '',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF486B48)),
                                          ),
                                        if ((diary['nickname'] ?? '').isNotEmpty)
                                          const Padding(
                                            padding:
                                                EdgeInsets.symmetric(horizontal: 6),
                                            child: Text(
                                              '|',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Color(0xFF486B48),
                                              ),
                                            ),
                                          ),
                                        Expanded(
                                          child: Text(
                                            diary['title'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}