import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'model/api.dart';
import 'model/plant.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

final _storage = const FlutterSecureStorage();

Future<String> _getAccessToken() async {
  final accessToken = await _storage.read(key: 'accessToken');
  if (accessToken == null) {
    throw Exception('로그인 토큰을 찾을 수 없습니다. 다시 로그인해주세요.');
  }
  return accessToken;
}

class PlantFormScreen extends StatefulWidget {
  const PlantFormScreen({super.key});

  @override
  State<PlantFormScreen> createState() => _PlantFormScreenState();
}

class _PlantFormScreenState extends State<PlantFormScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _speciesController = TextEditingController();

  List<String> _suggestions = [];
  List<Plant> _allPlants = [];
  String? _serverImageUrl;
  int? _selectedPlantMasterId;

  @override
  void initState() {
    super.initState();
    _fetchAllPlants();
  }

  Future<void> _fetchAllPlants() async {
    try {
      final plants = await fetchPlantList();
      setState(() => _allPlants = plants);
    } catch (e) {
      print('전체 식물 목록 불러오기 실패: $e');
    }
  }

  // 서버에 식물 저장
  Future<Plant> _savePlantToServer(Plant plant) async {
    if (_selectedPlantMasterId == null) {
      throw Exception('서버 식물 ID가 선택되지 않았습니다.');
    }

    final accessToken = await _getAccessToken();
    final url = Uri.parse('$baseUrl/plants/');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'name': plant.nameKo,
        'plant_master_id': _selectedPlantMasterId,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return Plant.fromJson(data);
    } else if (response.statusCode == 422) {
      throw Exception('검증 오류: ${response.body}');
    } else {
      throw Exception('알 수 없는 오류: ${response.statusCode}');
    }
  }

  Future<void> _savePlant() async {
    final nickname = _nicknameController.text.trim();
    final species = _speciesController.text.trim();

    if (nickname.isEmpty || species.isEmpty || _selectedPlantMasterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('식물의 별명과 종을 정확히 선택해주세요.')),
      );
      return;
    }

    final newPlant = Plant(
      id: 0,
      nameKo: nickname,
      species: species,
      imageUrl: _serverImageUrl ?? '',
      description: '',
      difficulty: '',
      lightRequirement: '',
      wateringType: '',
      petSafe: false,
      tags: [],
    );

    try {
      final savedPlant = await _savePlantToServer(newPlant);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('식물이 서버에 저장되었습니다.')),
      );
      Navigator.pop(context, savedPlant);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('서버 저장 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
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
                  onChanged: (value) {
                    if (value.isEmpty) {
                      setState(() => _suggestions = []);
                      return;
                    }

                    final filtered = _allPlants
                        .where((p) =>
                            p.nameKo.contains(value) ||
                            p.species.contains(value))
                        .map((p) => p.nameKo) // 한글 이름으로 표시
                        .toList();

                    setState(() => _suggestions = filtered);
                  },
                  onSuggestionTap: (s) {
                    _speciesController.text = s;
                    setState(() => _suggestions = []);

                    try {
                      final matchedPlant = _allPlants.firstWhere(
                        (p) => p.nameKo == s,
                        orElse: () => throw Exception('선택한 식물을 서버에서 찾을 수 없음'),
                      );

                      setState(() {
                        _serverImageUrl = matchedPlant.imageUrl;
                        _selectedPlantMasterId = matchedPlant.id;
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
        height: 60,
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

  Widget _centerInfoTile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            image: _serverImageUrl != null && _serverImageUrl!.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(_serverImageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: _serverImageUrl == null || _serverImageUrl!.isEmpty
              ? const Icon(Icons.eco, size: 40, color: Colors.white)
              : null,
        ),
      ],
    );
  }

  Widget inputCard({
    required TextEditingController controller,
    required String hint,
  }) {
    return Card(
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
                .map((s) => ListTile(title: Text(s), onTap: () => onSuggestionTap(s)))
                .toList(),
          ),
        ),
    ],
  );
}