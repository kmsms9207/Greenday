// lib/screens/recommend.dart 파일 전체 (최종 수정)

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
    "pets": null,
    "sunlight": null,
  };

  String? _accessToken;
  final String _apiUrl = 'https://feb991a69212.ngrok-free.app/recommendations/survey'; 

  @override
  void initState() {
    super.initState();
    _loadAccessToken();
  }

  Future<void> _loadAccessToken() async {
    const storage = FlutterSecureStorage();
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
        return _buildQuestion4();
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
        // 🚨 마지막 단계(4단계)인지 먼저 확인합니다.
        final bool isFinalAnswer = _currentStep == 4;

        setState(() {
          // 답변 저장
          if (_currentStep == 1)
            _answers["place"] = value;
          else if (_currentStep == 2)
            _answers["experience"] = value;
          else if (_currentStep == 3)
            _answers["pets"] = value;
          else if (_currentStep == 4)
            _answers["sunlight"] = value;

          // 마지막 단계가 아니면 다음 단계로 이동합니다.
          if (!isFinalAnswer) {
            _nextStep();
          }
        });

        // 마지막 질문에 답했다면, 로딩 및 API 호출을 시작합니다.
        if (isFinalAnswer) {
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
    // 5단계로 UI를 전환하고 1초 지연 후 API 호출 시작
    setState(() => _currentStep = 5);
    await Future.delayed(const Duration(seconds: 1));

    try {
      if (_accessToken == null) return;

      // 🚨 [422 에러 해결] Bool 값을 String으로 변환하여 서버가 거부하지 않도록 합니다.
      final Map<String, dynamic> requestData = {
        "place": _answers["place"],
        "experience": _answers["experience"],
        "pets": _answers["pets"]?.toString(),
        "sunlight": _answers["sunlight"],
      };

      final response = await http.post(
        Uri.parse('https://feb991a69212.ngrok-free.app/recommendations/ml'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        // 🚨 [오류 수정] response.body 대신 response.bodyBytes를 사용하여 String/List<int> 오류 해결
        final String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> data = jsonDecode(responseBody);
        final List<Plant> recommendations = data
            .map<Plant>((item) => Plant.fromJson(item))
            .toList();

        if (mounted) {
          // isFirst (MainScreen)만 남기고 이동합니다.
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => ResultScreen(recommendations: recommendations),
            ),
            (Route<dynamic> route) => route.isFirst,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '추천 실패: 서버 오류 ${response.statusCode} - ${utf8.decode(response.bodyBytes)}',
              ),
            ),
          );
          // 실패 시 첫 단계로 복귀
          setState(() => _currentStep = 1);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('추천 실패: 연결 오류 $e')));
        // 실패 시 첫 단계로 복귀
        setState(() => _currentStep = 1);
      }
    }
  }
}