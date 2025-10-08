import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; 
import 'model/api.dart';

class PlantFormScreen extends StatefulWidget {
  const PlantFormScreen({super.key});

  @override
  State<PlantFormScreen> createState() => _PlantFormScreenState();
}

class _PlantFormScreenState extends State<PlantFormScreen> {
  File? _selectedImage; // 선택한 이미지 파일

  TextEditingController _speciesController = TextEditingController();
  List<String> _suggestions = []; // API에서 받아올 추천 목록

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

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
            const SizedBox(height: 30),
            Column(
              children: [
                inputCard("식물의 별명을 입력해 주세요."),
                inputCardWithSuggestions(
                  controller: _speciesController,
                  hint: "식물의 종을 입력해 주세요.",
                  suggestions: _suggestions,
                  onChanged: (value) async {
                    if (value.isEmpty) {
                      setState(() => _suggestions = []);
                      return;
                    }
                    final suggestions = await fetchPlantSpecies(value);
                    setState(() => _suggestions = suggestions);
                  },
                  onSuggestionTap: (s) {
                    setState(() {
                      _speciesController.text = s;
                      _suggestions = [];
                    });
                  },
                ),
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
          child: const Text("저장", style: TextStyle(fontSize: 25)),
        ),
      ),
    );
  }

  // 가운데 정렬 위젯
  Widget _centerInfoTile(String name, String species) {
    final hasImage = _selectedImage != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _pickImage, // 누르면 사진 선택
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[300], // 기본 배경색 (회색)
              image: _selectedImage != null
                  ? DecorationImage(
                      image: FileImage(_selectedImage!),
                      fit: BoxFit.cover,
                    )
                  : null, // _selectedImage가 없으면 빈 네모
            ),
            child: _selectedImage == null
                ? const Icon(Icons.camera_alt, size: 40, color: Colors.white)
                : null, // 사진 없으면 카메라 아이콘
          ),
        ),

        Container(
          height: 30, // 텍스트 영역 최소 높이
          alignment: Alignment.center,
          child: Opacity(
            opacity: hasImage ? 0 : 1, // 사진이 있으면 글씨 숨김, 없으면 보임
            child: Row(
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
          ),
        )
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

Widget inputCardWithSuggestions({
  required TextEditingController controller,
  required String hint,
  required List<String> suggestions,
  required Function(String) onChanged,
  required Function(String) onSuggestionTap,
}) {
  return Column(
    children: [
      Card(
        color: const Color(0xFFF1F1F1),
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Container(
          width: double.infinity,
          height: 50,
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            style: const TextStyle(fontSize: 16, color: Color(0xFF656565)),
            onChanged: onChanged,
          ),
        ),
      ),
      if (suggestions.isNotEmpty)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(10),
          ),
          height: 150,
          child: ListView(
            children: suggestions
                .map((s) => ListTile(
                      title: Text(s),
                      onTap: () => onSuggestionTap(s),
                    ))
                .toList(),
          ),
        ),
    ],
  );
}
