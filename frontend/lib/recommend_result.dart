import 'package:flutter/material.dart';
import 'model/plant.dart';
import 'encyclopedia_detail.dart'; 

class ResultScreen extends StatelessWidget {
  final List<Plant> recommendations;

  const ResultScreen({super.key, required this.recommendations});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          // 🚨 [수정]: 단순 pop으로 복구합니다. (이전 화면이 MainScreen이므로 홈으로 복귀)
          onPressed: () => Navigator.pop(context),
        ),
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
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: recommendations.length,
        itemBuilder: (context, index) {
          final plant = recommendations[index];

          // 🚨 [기능 추가]: InkWell로 Card를 감싸서 탭 기능을 구현합니다.
          return InkWell(
            onTap: () {
              // 백과사전 상세 화면으로 이동하며, 식물의 ID를 전달합니다.
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EncyclopediaDetailScreen(plantId: plant.id),
                ),
              );
            },
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              margin: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              color: const Color(0xFFA4B6A4), // 카드 색 변경
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 원형 배경 + 이미지
                    Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(
                        color: Colors.white, // 카드 배경색
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: plant.imageUrl.isNotEmpty
                            ? Image.network(plant.imageUrl, fit: BoxFit.cover)
                            : const Icon(
                                Icons.eco,
                                size: 60,
                                color: Color(0xFF486B48),
                              ), // 이미지 없을 때 eco 아이콘
                      ),
                    ),
                    const SizedBox(height: 10),
                    // 식물 이름
                    Text(
                      plant.nameKo,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 5),
                    // 난이도 + 설명
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "난이도: ${plant.difficulty}",
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}