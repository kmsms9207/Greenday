import 'package:flutter/material.dart';
import 'model/plant.dart';

class PlantInfoScreen extends StatelessWidget {
  final Plant plant;
  const PlantInfoScreen({super.key, required this.plant});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 전체 배경
      appBar: AppBar(
        backgroundColor: Colors.white, // AppBar 배경
        toolbarHeight: 50, // AppBar 높이
        centerTitle: true, // 중앙 정렬
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

      body: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            // 식물 별명 + 식물 종
            Center(
              child: _centerInfoTile(
                plant.nameKo,            // 식물 별명
                plant.species,           // 식물 종
                imageUrl: plant.imageUrl, // 사진 경로 (없으면 기본 카메라 아이콘)
              ),
            ),
            const SizedBox(height: 50),
              Column(
                children: [
                  _leftInfoTile("햇빛", plant.lightRequirement.isNotEmpty ? plant.lightRequirement : "정보 없음"),
                _leftInfoTile("물주기", plant.wateringType.isNotEmpty ? plant.wateringType : "정보 없음"),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: SizedBox(
          width: double.infinity,
          height: 60, // 버튼 높이
          child: ElevatedButton(
            onPressed: () async {
              // Plant 수정 화면 연동
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA4B6A4),
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              padding: EdgeInsets.zero,
            ),
            child: const Text(
              "수정 / 삭제",
              style: TextStyle(fontSize: 25),
            ),
          ),
        ),
      );
    }

  // 가운데 정렬 위젯
  Widget _centerInfoTile(String name, String species, {String? imageUrl}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 사진 영역
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey[300], // 기본 배경색 (회색)
            image: imageUrl != null && imageUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(imageUrl), // 서버 이미지
                    fit: BoxFit.cover,
                  )
                : null, // imageUrl가 없으면 빈 네모
          ),
          child: (imageUrl == null || imageUrl.isEmpty)
              ? const Icon(Icons.camera_alt, size: 40, color: Colors.white)
              : null, // 사진 없으면 카메라 아이콘
        ),
        const SizedBox(height: 5),
        Text(
          name,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Color(0xFF486B48)),
        ),
        Text(
          species,
          style: const TextStyle(fontSize: 20, color: Color(0xFFA4B6A4)),
        ),
      ],
    );
  }

  // 왼쪽 정렬 위젯
  Widget _leftInfoTile(String label, String value) {
    return Card(
      color: Color(0xFFF1F1F1),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Container(
        width: double.infinity, // 카드 폭
        height: 50, // 카드 높이
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min, // 내용에 맞게 줄 길이
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF656565),
              ),
            ),
            const SizedBox(width: 8), // label과 value 사이 간격
            Text(
              value,
              style: const TextStyle(
                fontSize: 16
              ),
            ),
          ],
        ),
      ),
    );
  }
}