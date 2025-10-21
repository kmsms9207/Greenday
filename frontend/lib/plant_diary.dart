import 'package:flutter/material.dart';
import 'plant_diary_form.dart';

class PlantDiaryScreen extends StatefulWidget {
  const PlantDiaryScreen({super.key});

  @override
  State<PlantDiaryScreen> createState() => _PlantDiaryScreenState();
}

class _PlantDiaryScreenState extends State<PlantDiaryScreen> {
  List<Map<String, String>> diaryList = []; // 저장된 일지 목록

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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
  
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 날짜
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0), // 원하는 여백 크기
                          child: Text(
                            "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2,'0')}-${DateTime.now().day.toString().padLeft(2,'0')}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // 아이콘
                        ElevatedButton(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PlantDiaryFormScreen(),
                              ),
                            );
                            if (result != null && result is Map<String,String>) {
                              setState(() {
                                diaryList.add(result);
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(12),
                            backgroundColor: const Color(0xFFD7E0D7), // 연한 회색
                            foregroundColor: Colors.black54,
                            elevation: 2,
                          ),
                          child: const Icon(Icons.edit, size: 20),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 박스
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: diaryList.isEmpty
                          ? const Center(
                              child: Icon(Icons.eco, size: 40, color: Color(0xFF486B48)),
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  diaryList.last['nickname'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF486B48)
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
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
                                    diaryList.last['title'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 14, // 글씨 크기 조절
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis, 
                                  ),
                                ),
                              ],
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