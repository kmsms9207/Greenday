import 'package:flutter/material.dart';

class PlantFormScreen extends StatefulWidget {
  const PlantFormScreen({super.key});

  @override
  State<PlantFormScreen> createState() => _PlantFormScreenState();
}

class _PlantFormScreenState extends State<PlantFormScreen> {
  String? _imagePath; // 선택한 이미지 경로

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
            Center(child: _centerInfoTile("사진", "을 추가해 주세요.")),
            const SizedBox(height: 50),
            Column(
              children: [
                inputCard("식물의 별명을 입력해 주세요."),
                inputCard("식물의 종을 입력해 주세요."),
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
          child: const Text("완료", style: TextStyle(fontSize: 25)),
        ),
      ),
    );
  }

  // 가운데 정렬 위젯
  Widget _centerInfoTile(String name, String species, {String? imagePath}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 사진 영역
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[300], // 기본 배경색 (회색)
            image: imagePath != null
                ? DecorationImage(
                    image: AssetImage(imagePath),
                    fit: BoxFit.cover,
                  )
                : null, // imagePath가 없으면 빈 네모
          ),
          child: imagePath == null
              ? const Icon(Icons.camera_alt, size: 40, color: Colors.white)
              : null, // 사진 없으면 카메라 아이콘
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 20, color: Color(0xFF486B48)),
            ),
            Text(
              species,
              style: const TextStyle(fontSize: 20, color: Colors.black),
            ),
          ],
        ),
      ],
    );
  }

  // 왼쪽 정렬 위젯
  Widget inputCard(String hint) {
    return Card(
      color: const Color(0xFFF1F1F1),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: double.infinity, // 카드 폭
        height: 50, // 카드 높이
        padding: const EdgeInsets.all(12),
        child: TextField(
          decoration: InputDecoration(
            hintText: hint,
            border: InputBorder.none,
            isDense: true, // 높이 맞춤
            contentPadding: EdgeInsets.zero, // 내부 패딩 제거
          ),
          style: const TextStyle(fontSize: 16, color: Color(0xFF656565)),
        ),
      ),
    );
  }
}
