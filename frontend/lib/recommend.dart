import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'recommend_result.dart';
import 'model/plant.dart';

class RecommendScreen extends StatefulWidget {
  const RecommendScreen({super.key});

  @override
  State<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen> {
  int _currentStep = 1;
  final Map<String, dynamic> _answers = {
    "place": null,
    "experience": null,
    "pets": null,
    "sunlight": null, // 서버 API에서 요구하는 필드 추가
  };

  String? _accessToken;

  @override
  void initState() {
    super.initState();
    _loadAccessToken();
  }

  Future<void> _loadAccessToken() async {
    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: 'accessToken');
    setState(() {
      _accessToken = token;
    });
  }

  void _nextStep() {
    setState(() {
      _currentStep++;
    });
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.grey[100],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _prevStep,
        ),
      ),
      body: _buildStepContent(),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildQuestion1();
      case 2:
        return _buildQuestion2();
      case 3:
        return _buildQuestion3();
      case 4:
        return _buildQuestion4(); // 햇빛 질문 추가
      case 5:
        return _buildLoadingScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  // 첫 번째 질문: 장소
  Widget _buildQuestion1() {
    return _buildQuestion(
      title: "어디서 식물을 키우실 건가요?",
      options: [
        _optionTile(Icons.window, "창가", "window"),
        _optionTile(Icons.home, "실내", "indoor"),
        _optionTile(Icons.shower, "그늘진", "bathroom"),
      ],
    );
  }

  // 두 번째 질문: 경험
  Widget _buildQuestion2() {
    return _buildQuestion(
      title: "식물 관리 경험은 어느 정도인가요?",
      options: [
        _optionTile(Icons.emoji_people, "초보", "beginner"),
        _optionTile(Icons.spa, "경험자", "intermediate"),
        _optionTile(Icons.eco, "전문가", "expert"),
      ],
    );
  }

  // 세 번째 질문: 반려동물
  Widget _buildQuestion3() {
    return _buildQuestion(
      title: "반려동물과 함께 지내시나요?",
      options: [
        _optionTile(Icons.pets, "예", true),
        _optionTile(Icons.close, "아니오", false),
      ],
    );
  }

  // 네 번째 질문: 햇빛
  Widget _buildQuestion4() {
    return _buildQuestion(
      title: "식물이 받을 햇빛은 어느 정도인가요?",
      options: [
        _optionTile(Icons.wb_sunny, "적음", "low"),
        _optionTile(Icons.wb_sunny, "보통", "medium"),
        _optionTile(Icons.wb_sunny, "많음", "high"),
      ],
    );
  }

  // 질문 공통 위젯
  Widget _buildQuestion({
    required String title,
    required List<Widget> options,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Card(
              margin: EdgeInsets.zero,
              color: const Color.fromARGB(255, 144, 167, 144),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 20, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 50),
          ...options,
        ],
      ),
    );
  }

  // 옵션 카드
  Widget _optionTile(IconData icon, String label, dynamic value) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_currentStep == 1) _answers["place"] = value;
          if (_currentStep == 2) _answers["experience"] = value;
          if (_currentStep == 3) _answers["pets"] = value;
          if (_currentStep == 4) _answers["sunlight"] = value; // 햇빛 값 저장
          if (_currentStep < 5) _nextStep();
          if (_currentStep == 5) _startLoading();
        });
      },
      child: SizedBox(
        width: double.infinity,
        child: Card(
          color: Colors.grey[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: const EdgeInsets.only(bottom: 15),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Icon(icon, size: 28, color: Colors.black54),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(fontSize: 18, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 로딩 화면
  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFA4B6A4)),
          SizedBox(height: 40),
          Text("AI가 당신에게 맞는 식물을 찾고 있어요...", style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  void _startLoading() async {
    await Future.delayed(const Duration(seconds: 1)); // 최소 로딩 시간

    try {
      if (_accessToken == null) return;

      final response = await http.post(
        Uri.parse('https://33ec24b88e40.ngrok-free.app/recommendations/ml'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken', // 반드시 null 아님 확인 후
        },
        body: jsonEncode(_answers),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<Plant> recommendations = data
            .map<Plant>((item) => Plant.fromJson(item))
            .toList();

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ResultScreen(recommendations: recommendations),
            ),
          );
        }
      } else {
        print("서버 에러 발생: ${response.statusCode}");
        print("응답 본문: ${response.body}");
        print("보낸 데이터: ${jsonEncode(_answers)}");
      }
    } catch (e) {
      print("서버 연결 실패: $e");
    }
  }
}
