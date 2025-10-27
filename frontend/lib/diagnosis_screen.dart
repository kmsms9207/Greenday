import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // 1. image_picker import
import 'dart:io'; // 2. File 객체 import
import 'model/api.dart'; // 3. API 서비스 import
import 'model/diagnosis_model.dart'; // 4. 진단 모델 import
import 'remedy_screen.dart'; // 5. 처방전 화면 import

class DiagnosisScreen extends StatefulWidget {
  const DiagnosisScreen({super.key});

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  File? _selectedImage; // 사용자가 선택한 이미지 파일
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false; // 진단 요청 중 로딩 상태
  DiagnosisResponse? _diagnosisResult; // 서버로부터 받은 진단 결과

  // 갤러리에서 이미지 선택
  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _diagnosisResult = null; // 새 이미지 선택 시 이전 결과 초기화
      });
    }
  }

  // "진단하기" 버튼 클릭 시
  Future<void> _handleDiagnosis() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('진단할 식물 사진을 먼저 선택해주세요.')));
      return;
    }

    setState(() {
      _isLoading = true; // 로딩 시작
      _diagnosisResult = null;
    });

    try {
      // api.dart의 diagnosePlant 함수 호출
      final result = await diagnosePlant(_selectedImage!);
      setState(() {
        _diagnosisResult = result; // 결과 저장
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('진단에 실패했습니다: $e')));
    } finally {
      setState(() {
        _isLoading = false; // 로딩 종료
      });
    }
  }

  // "해결 방법 보기" 버튼 클릭 시 (처방전 화면으로 이동)
  void _navigateToRemedy() {
    if (_diagnosisResult == null || !_diagnosisResult!.isSuccess) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RemedyScreen(diseaseKey: _diagnosisResult!.label),
      ),
    );
    print("처방전 화면으로 이동. 질병 키: ${_diagnosisResult!.label}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI 식물 진단")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 이미지 선택 영역
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey),
              ),
              child: _selectedImage != null
                  ? Image.file(_selectedImage!, fit: BoxFit.cover)
                  : const Center(
                      child: Text(
                        '사진을 선택해주세요',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImageFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('갤러리'),
                ),
                // --- '카메라' 버튼이 여기서 삭제되었습니다 ---
              ],
            ),
            const SizedBox(height: 24),
            // 2. "진단하기" 버튼
            ElevatedButton(
              onPressed: _isLoading ? null : _handleDiagnosis,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('진단하기', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            // 3. 진단 결과 표시 영역
            _buildResultSection(),
          ],
        ),
      ),
    );
  }

  // 진단 결과를 표시하는 위젯
  Widget _buildResultSection() {
    if (_isLoading) {
      return const Center(child: Text("AI가 식물을 분석 중입니다..."));
    }

    if (_diagnosisResult == null) {
      return const Center(child: Text('사진을 선택하고 "진단하기" 버튼을 눌러주세요.'));
    }

    // CASE 1: 진단 성공
    if (_diagnosisResult!.isSuccess) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _diagnosisResult!.labelKo, // "흰가루병"
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '신뢰도: ${(_diagnosisResult!.score * 100).toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 16, color: Colors.blueGrey),
          ),
          if (_diagnosisResult!.severity != null)
            Text(
              '심각도: ${_diagnosisResult!.severity}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _navigateToRemedy, // 처방전 화면으로 이동
            child: const Text('해결 방법 보기'),
          ),
        ],
      );
    }
    // CASE 2: 진단 불확실
    else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '판단 불확실',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _diagnosisResult!.reasonKo ?? 'AI가 사진을 인식하기 어렵습니다. 다시 시도해주세요.',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      );
    }
  }
}
