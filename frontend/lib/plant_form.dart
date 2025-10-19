import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; 
import 'model/api.dart';
import 'model/plant.dart';

// 임시 저장용 리스트 (앱 종료 시 초기화됨)
List<Plant> myPlants = [];

class PlantFormScreen extends StatefulWidget {
  const PlantFormScreen({super.key});

  @override
  State<PlantFormScreen> createState() => _PlantFormScreenState();
}

class _PlantFormScreenState extends State<PlantFormScreen> {
  TextEditingController _nicknameController = TextEditingController();
  TextEditingController _speciesController = TextEditingController();
  List<String> _suggestions = []; // API에서 받아올 추천 목록
  String? _serverImageUrl;
  List<Plant> _allPlants = []; // 전체 식물 목록 저장

  @override
  void initState() {
    super.initState();
    fetchPlantList().then((plants) {
      setState(() {
        _allPlants = plants;
      });
    }).catchError((e) {
      print('전체 식물 목록 불러오기 실패: $e');
    });
  }

  Future<void> savePlantToServer(Plant plant) async {
    final url = Uri.parse('https://f9b21d7edc72.ngrok-free.app/plants');
    
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': plant.nameKo,
        'species': plant.species,
        'master_image_url': plant.imageUrl, // 서버에서 접근 가능한 URL이어야 함
      }),
    );

    if (response.statusCode == 201) {
      print('식물 저장 성공');
    } else if (response.statusCode == 422) {
      print('검증 오류: ${response.body}');
    } else {
      print('알 수 없는 오류: ${response.statusCode}');
    }
  }

  // 저장 함수
  Future<void> _savePlant() async {
    final nickname = _nicknameController.text;
    final species = _speciesController.text;

    if (nickname.isEmpty || species.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('식물의 별명과 종을 입력해주세요.')),
      );
      return;
    }

    final newPlant = Plant(
      id: myPlants.length + 1,
      nameKo: nickname,
      species: species,
      imageUrl: _serverImageUrl ?? '', // 서버 이미지 URL 저장
      description: '',
      difficulty: '',
      lightRequirement: '',
      wateringType: '',
      petSafe: false,
      tags: [],
    );

    myPlants.add(newPlant); // 로컬 저장

    try {
      await savePlantToServer(newPlant); // 서버 저장
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('식물이 서버에 저장되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('서버 저장 실패: $e')),
      );
    }
    
    Navigator.pop(context, newPlant); // 이전 화면으로 돌아가기
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
            Center(child: _centerInfoTile()),
            const SizedBox(height: 50),
            Column(
              children: [
                inputCard(
                  controller: _nicknameController,
                  hint: "식물의 별명을 입력해 주세요.",
                ),
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
                    _speciesController.text = s;
                    _suggestions = [];

                    try {
                      final matchedPlant = _allPlants.firstWhere(
                        (p) => p.nameKo == s,
                        orElse: () => Plant(
                          id: 0,
                          nameKo: '',
                          species: '',
                          imageUrl: '',
                          description: '',
                          difficulty: '',
                          lightRequirement: '',
                          wateringType: '',
                          petSafe: false,
                          tags: [],
                        ),
                      );

                    setState(() {
                      _serverImageUrl = matchedPlant.imageUrl; // 서버 이미지 URL 저장
                    });
                  } catch (e) {
                    print('서버 이미지 불러오기 실패: $e');
                  }
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
          onPressed: _savePlant,
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
  Widget _centerInfoTile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[300], // 기본 배경색 (회색)
            image: _serverImageUrl != null && _serverImageUrl!.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(_serverImageUrl!),
                    fit: BoxFit.cover,
                  )
                : null, // _selectedImage가 없으면 빈 네모
          ),
          child: _serverImageUrl == null || _serverImageUrl!.isEmpty
              ? const Icon(Icons.eco, size: 40, color: Colors.white)
              : null, // 사진 없으면 카메라 아이콘
        ),
      ],
    );
  }

  // 왼쪽 정렬 위젯
  Widget inputCard({required TextEditingController controller, required String hint}) {
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
          controller: controller,
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
