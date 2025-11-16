// lib/screens/recommend.dart 파일 전체 (최종 수정 및 안정화)

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:dio/dio.dart'; // DioError, Response 사용
// 🚨 [수정] http 및 flutter_secure_storage import 제거
import 'recommend_result.dart';
import 'model/plant.dart';
// 🟢 [수정] api.dart를 'api' 별칭으로 임포트하여 sendRecommendationRequest 사용
import 'package:flutter_application_1/model/api.dart' as api;

// 설문조사 단계를 나타내는 Enum (예시)
enum RecommendStep { place, sunlight, experience, pets, difficulty, complete }

class RecommendScreen extends StatefulWidget {
  const RecommendScreen({super.key});

  @override
  State<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen> {
  // 🚨 [수정] 초기값 1 대신 Enum 사용에 맞게 변경
  RecommendStep _currentStep = RecommendStep.place;

  final Map<String, dynamic> _answers = {
    "place": null,
    "experience": null,
    "has_pets": null,
    "sunlight": null,
    "desired_difficulty": null,
  };

  // 🚨 [수정] _accessToken 변수 및 _apiUrl 제거
  // String? _accessToken;
  // final String _apiUrl = ...;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 🚨 [수정] _loadAccessToken() 함수 제거
  }

  void _nextStep() {
    setState(() {
      // 🚨 [수정] Enum 인덱스 증가를 통해 다음 단계로 이동
      if (_currentStep.index < RecommendStep.complete.index) {
        _currentStep = RecommendStep.values[_currentStep.index + 1];
      }
    });
  }

  void _prevStep() {
    if (_currentStep.index > RecommendStep.place.index) {
      setState(() {
        _currentStep = RecommendStep.values[_currentStep.index - 1];
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  // 에러 메시지를 사용자에게 표시하는 헬퍼 함수
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // -----------------------------------------------------
  // 🟢 [수정] Dio 기반 API 요청 로직으로 완전히 변경
  // -----------------------------------------------------
  void _startLoading() async {
    // 이미 로딩 중이면 중복 실행 방지
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 🚨 최종 API 요청 바디 구성 (5가지 필수 필드 + limit)
      final requestData = {
        "place": _answers["place"],
        "sunlight": _answers["sunlight"],
        "experience": _answers["experience"],
        "has_pets": _answers["has_pets"] == true, // Boolean 값으로 변환
        "desired_difficulty": _answers["desired_difficulty"],
        "limit": 3,
      };

      // 🟢 [핵심 수정] api.dart의 Dio 기반 요청 함수 사용
      final Response response = await api.sendRecommendationRequest(
        requestData,
      );

      if (response.statusCode == 200) {
        // Dio 응답은 response.data로 접근
        final List<dynamic> data =
            response.data['recommendations'] as List<dynamic>;
        final List<Plant> recommendations = data
            .map<Plant>((item) => Plant.fromJson(item))
            .toList();

        if (mounted) {
          // 결과 화면 이동 시 스택 정리 (route.isFirst: 메인 화면만 남김)
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => ResultScreen(recommendations: recommendations),
            ),
            (route) => route.isFirst,
          );
        }
      } else {
        if (mounted) {
          setState(
            () => _currentStep = RecommendStep.difficulty,
          ); // 난이도 질문으로 복귀
          _showError('추천 정보를 가져오는 데 실패했습니다. 코드: ${response.statusCode}');
        }
      }
    } on DioError catch (e) {
      if (mounted) {
        setState(() => _currentStep = RecommendStep.difficulty); // 난이도 질문으로 복귀
        _showError('서버 연결 오류: ${e.response?.data ?? e.message}');
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _currentStep = RecommendStep.difficulty); // 난이도 질문으로 복귀
        _showError('알 수 없는 오류 발생: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      case RecommendStep.place:
        return _buildQuestion1(); // 1. 장소 (place)
      case RecommendStep.experience:
        return _buildQuestion2(); // 2. 경험 (experience)
      case RecommendStep.pets:
        return _buildQuestion3(); // 3. 반려동물 (has_pets)
      case RecommendStep.sunlight:
        return _buildQuestion4(); // 4. 햇빛 (sunlight)
      case RecommendStep.difficulty:
        return _buildQuestion5(); // 5. 난이도 (desired_difficulty)
      case RecommendStep.complete:
        return _buildLoadingScreen(); // 6. 로딩 시작
      default:
        return const SizedBox.shrink();
    }
  }

  // 1. 첫 번째 질문: 장소 (place)
  Widget _buildQuestion1() {
    return _buildQuestion(
      title: "어디서 식물을 키우실 건가요?",
      fieldName: "place", // 필드명 추가
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
      fieldName: "experience",
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
      fieldName: "has_pets",
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
      fieldName: "sunlight",
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
      fieldName: "desired_difficulty",
      options: [
        _optionTile(Icons.sentiment_very_satisfied, "쉬움 (하)", "하"),
        _optionTile(Icons.sentiment_neutral, "보통 (중)", "중"),
        _optionTile(Icons.sentiment_very_dissatisfied, "어려움 (상)", "상"),
      ],
    );
  }

  // 질문 공통 위젯 - 값 저장 로직 통합
  Widget _buildQuestion({
    required String title,
    required String fieldName,
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
          ...options.map((option) {
            // 옵션 타일 위젯의 onTap 로직을 여기서 바인딩합니다.
            if (option is GestureDetector) {
              return option; // 이미 GestureDetector로 래핑된 경우
            }
            return option;
          }).toList(),
        ],
      ),
    );
  }

  // 옵션 카드 (원래 로직에 맞게 onTap 내부 로직을 수정합니다.)
  Widget _optionTile(IconData icon, String label, dynamic value) {
    // 🚨 _optionTile은 내부에서 어떤 질문인지 알 수 없으므로, Question 위젯 내에서 onTap 로직을 완성합니다.
    return GestureDetector(
      onTap: () {
        // 🚨 Enum에 맞게 현재 단계에 따른 fieldName을 결정하여 값 저장
        String fieldName = '';
        switch (_currentStep) {
          case RecommendStep.place:
            fieldName = "place";
            break;
          case RecommendStep.experience:
            fieldName = "experience";
            break;
          case RecommendStep.pets:
            fieldName = "has_pets";
            break;
          case RecommendStep.sunlight:
            fieldName = "sunlight";
            break;
          case RecommendStep.difficulty:
            fieldName = "desired_difficulty";
            break;
          default:
            return;
        }

        _answers[fieldName] = value;

        // 🚨 5단계 질문 후, 6단계 로딩으로 이동 및 로딩 시작
        if (_currentStep == RecommendStep.difficulty) {
          setState(() {
            _currentStep = RecommendStep.complete;
          });
          _startLoading();
        } else {
          _nextStep();
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFA4B6A4)),
          const SizedBox(height: 40),
          Text(
            _isLoading ? "AI가 당신에게 맞는 식물을 찾고 있어요..." : "로딩 완료 (화면 전환 대기 중)",
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }
}
