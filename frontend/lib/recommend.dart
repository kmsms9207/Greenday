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
  
  // 🚨 API 명세에 맞춰 5가지 필드 모두 포함 및 초기화
  final Map<String, dynamic> _answers = {
    "place": null,
    "experience": null,
    "has_pets": null, // Boolean 값 저장 (true/false)
    "sunlight": null,
    "desired_difficulty": null, // 난이도 필드 추가 (하, 중, 상)
  };

  String? _accessToken;
  final String _apiUrl = 'https://feb991a69212.ngrok-free.app/recommendations/survey'; 

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

  // 🚨 총 5단계 질문 + 6단계 로딩으로 구성
  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildQuestion1(); // 1. 장소 (place)
      case 2:
        return _buildQuestion2(); // 2. 경험 (experience)
      case 3:
        return _buildQuestion3(); // 3. 반려동물 (has_pets)
      case 4:
        return _buildQuestion4(); // 4. 햇빛 (sunlight)
      case 5:
        return _buildQuestion5(); // 🚨 5. 난이도 (desired_difficulty)
      case 6:
        return _buildLoadingScreen(); // 6. 로딩 시작
      default:
        return const SizedBox.shrink();
    }
  }

  // 1. 첫 번째 질문: 장소 (place)
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

  // 2. 두 번째 질문: 경험 (experience) 🚨 복구
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

  // 3. 세 번째 질문: 반려동물 (has_pets)
  Widget _buildQuestion3() {
    return _buildQuestion(
      title: "반려동물과 함께 지내시나요?",
      options: [
        _optionTile(Icons.pets, "예", true),
        _optionTile(Icons.close, "아니오", false),
      ],
    );
  }

  // 4. 네 번째 질문: 햇빛 (sunlight) 🚨 복구
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

  // 🚨 5. 다섯 번째 질문: 난이도 (desired_difficulty)
  Widget _buildQuestion5() {
    return _buildQuestion(
      title: "선호하는 관리 난이도는 어느 정도인가요?",
      options: [
        _optionTile(Icons.sentiment_very_satisfied, "쉬움", "하"),
        _optionTile(Icons.sentiment_neutral, "보통", "중"),
        _optionTile(Icons.sentiment_very_dissatisfied, "어려움", "상"),
      ],
    );
  }

  // 질문 공통 위젯 - 기존과 동일
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
        // 🚨 5단계 질문에 맞춰 값 저장 로직 변경
        if (_currentStep == 1) _answers["place"] = value;
        if (_currentStep == 2) _answers["experience"] = value;
        if (_currentStep == 3) _answers["has_pets"] = value; 
        if (_currentStep == 4) _answers["sunlight"] = value;
        if (_currentStep == 5) _answers["desired_difficulty"] = value; 

        // 🚨 5단계 질문 후, 6단계 로딩으로 이동
        if (_currentStep < 5) {
          _nextStep();
        } else if (_currentStep == 5) {
          setState(() {
            _currentStep = 6;
          });
          _startLoading();
        }
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
    await Future.delayed(const Duration(seconds: 1)); 

    if (_accessToken == null) {
      if (mounted) {
        setState(() => _currentStep = 5); // 5단계(난이도 질문)로 복귀
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
      }
      return;
    }

    try {
      // 🚨 최종 API 요청 바디 구성 (5가지 필수 필드 + limit)
      final response = await http.post(
        Uri.parse(_apiUrl), 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: jsonEncode({
          "place": _answers["place"],
          "sunlight": _answers["sunlight"],
          "experience": _answers["experience"],
          "has_pets": _answers["has_pets"], 
          "desired_difficulty": _answers["desired_difficulty"], 
          "limit": 10, // API 명세에 따라 10으로 설정
        }),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<Plant> recommendations = data
            .map<Plant>((item) => Plant.fromJson(item))
            .toList();

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResultScreen(recommendations: recommendations),
            ),
          );
        }
      } else {
        print("서버 에러 발생: ${response.statusCode}");
        print("응답 본문: ${response.body}");
        if (mounted) {
          setState(() => _currentStep = 5); // 5단계로 복귀
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('추천 정보를 가져오는 데 실패했습니다.')),
          );
        }
      }
    } catch (e) {
      print("서버 연결 실패: $e");
      if (mounted) {
        setState(() => _currentStep = 5); // 5단계로 복귀
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('네트워크 오류가 발생했습니다.')),
        );
      }
    }
  }
}