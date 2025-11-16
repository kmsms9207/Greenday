import 'package:flutter/material.dart';
// 🟢 [수정] http 및 flutter_secure_storage import 제거
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'dart:convert';
// import 'package:http/http.dart' as http;
import 'package:dio/dio.dart'; // 🟢 DioError 처리를 위해 Dio 임포트
import 'recommend_result.dart';
import 'model/plant.dart';
// 🟢 [수정] api.dart를 'api' 별칭으로 임포트하여 sendRecommendationRequest 사용
import 'package:flutter_application_1/model/api.dart' as api;

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
    "has_pets": null,
    "sunlight": null,
    "desired_difficulty": null,
  };

  // 🟢 [추가] Dio 로딩 상태 변수
  bool _isLoading = false;

  // 🟢 [제거] _accessToken, _apiUrl, _loadAccessToken 함수 제거
  /*
  String? _accessToken;
  final String _apiUrl = '...'; 
  @override
  void initState() {
    super.initState();
    _loadAccessToken();
  }
  Future<void> _loadAccessToken() async { ... }
  */

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
    // 🟢 [수정] _buildLoadingScreen이 _isLoading 상태를 표시하도록 변경
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
        return _buildQuestion4();
      case 5:
        return _buildQuestion5();
      case 6:
        // 🟢 _buildLoadingScreen()이 _isLoading 상태를 사용
        return _buildLoadingScreen();
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

  // 2. 두 번째 질문: 경험 (experience)
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

  // 4. 네 번째 질문: 햇빛 (sunlight)
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

  // 5. 다섯 번째 질문: 난이도 (desired_difficulty)
  Widget _buildQuestion5() {
    return _buildQuestion(
      title: "선호하는 관리 난이도는 어느 정도인가요?",
      options: [
        _optionTile(Icons.sentiment_very_satisfied, "쉬움 (하)", "하"),
        _optionTile(Icons.sentiment_neutral, "보통 (중)", "중"),
        _optionTile(Icons.sentiment_very_dissatisfied, "어려움 (상)", "상"),
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
        if (_currentStep == 1) _answers["place"] = value;
        if (_currentStep == 2) _answers["experience"] = value;
        if (_currentStep == 3) _answers["has_pets"] = value;
        if (_currentStep == 4) _answers["sunlight"] = value;
        if (_currentStep == 5) _answers["desired_difficulty"] = value;

        if (_currentStep < 5) {
          _nextStep();
        } else if (_currentStep == 5) {
          setState(() {
            _currentStep = 6;
          });
          _startLoading(); // 🟢 로딩 시작
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
    // 🟢 _isLoading 상태를 반영하여 텍스트 변경
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFA4B6A4)),
          const SizedBox(height: 40),
          Text(
            _isLoading ? "AI가 당신에게 맞는 식물을 찾고 있어요..." : "요청 완료 대기 중...",
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }

  // 🟢 [수정] api.dart의 Dio 함수를 사용하도록 로직 전체 변경
  void _startLoading() async {
    // 이미 로딩 중이면 중복 실행 방지
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 요청 데이터 준비
      final requestData = {
        "place": _answers["place"],
        "sunlight": _answers["sunlight"],
        "experience": _answers["experience"],
        "has_pets": _answers["has_pets"],
        "desired_difficulty": _answers["desired_difficulty"],
        "limit": 3,
      };

      // 2. api.dart 함수 호출 (인증은 api.dart가 내부적으로 처리)
      final Response response = await api.sendRecommendationRequest(
        requestData,
      );

      // 3. 🟢 [핵심 수정] 서버가 Map이 아닌 List를 직접 반환하므로, response.data를 List로 받습니다.
      // ❌ final List<dynamic> data = response.data['recommendations'] as List<dynamic>;
      final List<dynamic> data = response.data as List<dynamic>;

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
    } on DioError catch (e) {
      // DioError (서버 4xx, 5xx 에러 등)
      print("Dio 에러 발생: ${e.response?.data ?? e.message}");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep = 5; // 5단계로 복귀
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('추천 실패: ${e.response?.data?['detail'] ?? '서버 오류'}'),
          ),
        );
      }
    } catch (e) {
      // 🟢 'String' is not a subtype of 'int' 오류가 여기서 잡혔습니다.
      print("서버 연결 실패: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep = 5; // 5단계로 복귀
        });
        ScaffoldMessenger.of(
          context,
          // 🟢 오류 메시지를 좀 더 명확하게 변경
        ).showSnackBar(const SnackBar(content: Text('데이터 처리 중 오류가 발생했습니다.')));
      }
    }
  }
}
