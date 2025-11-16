import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'model/api.dart'; // diagnosePlant, fetchRemedy, uploadMedia, createManualDiary
import 'model/diagnosis_model.dart'; // DiagnosisResponse
import 'remedy_screen.dart'; // RemedyScreen

class DiagnosisScreen extends StatefulWidget {
  final int plantId; // 필수: plantId
  const DiagnosisScreen({super.key, required this.plantId});

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  DiagnosisResponse? _diagnosisResult;
  List<String> _immediateActions = []; // 사용자 처리 추천 목록

  // 갤러리 이미지 선택
  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) _resetState(File(image.path));
  }

  // 카메라 촬영
  Future<void> _takePhotoWithCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) _resetState(File(image.path));
  }

  void _resetState(File imageFile) {
    setState(() {
      _selectedImage = imageFile;
      _diagnosisResult = null;
      _immediateActions = [];
    });
  }

  Future<void> _handleDiagnosis() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('진단할 식물 사진을 먼저 선택해주세요.')));
      return;
    }

    setState(() {
      _isLoading = true;
      _diagnosisResult = null;
      _immediateActions = [];
    });

    try {
      // 1️⃣ File 그대로 diagnosePlant 호출
      final result = await diagnosePlant(_selectedImage!, widget.plantId);

      setState(() {
        _diagnosisResult = result;
      });

      if (result.isSuccess) {
        // 2️⃣ 즉각적인 액션 정보 가져오기
        final remedy = await fetchRemedy(result.label);
        setState(() {
          _immediateActions = remedy.immediateActions;
        });

        // 3️⃣ 자동 성장 일지 기록
        try {
          final uploadedImageUrl = await uploadMedia(_selectedImage!);
          await createManualDiary(
            plantId: widget.plantId,
            logMessage: '[${result.labelKo}] 진단 완료',
            imageUrl: uploadedImageUrl,
          );
        } catch (e) {
          print('자동 일지 기록 실패: $e');
        }

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${result.labelKo} 진단 완료')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('진단에 실패했습니다: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToRemedy() {
    if (_diagnosisResult == null || !_diagnosisResult!.isSuccess) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RemedyScreen(diseaseKey: _diagnosisResult!.label),
      ),
    );
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
            _buildImageDisplay(),
            const SizedBox(height: 16),
            _buildImagePickerRow(),
            const SizedBox(height: 24),
            _buildDiagnosisButton(),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            _buildResultSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageDisplay() {
    return Container(
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
              child: Text('사진을 선택해주세요', style: TextStyle(color: Colors.grey)),
            ),
    );
  }

  Widget _buildImagePickerRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: _pickImageFromGallery,
          icon: const Icon(Icons.photo_library),
          label: const Text('갤러리'),
        ),
        ElevatedButton.icon(
          onPressed: _takePhotoWithCamera,
          icon: const Icon(Icons.camera_alt),
          label: const Text('카메라'),
        ),
      ],
    );
  }

  Widget _buildDiagnosisButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleDiagnosis,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: _isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('진단하기', style: TextStyle(fontSize: 18)),
    );
  }

  Widget _buildResultSection() {
    if (_isLoading) return const Center(child: Text("AI가 식물을 분석 중입니다..."));
    if (_diagnosisResult == null) {
      return const Center(child: Text('사진을 선택하고 "진단하기" 버튼을 눌러주세요.'));
    }

    if (_diagnosisResult!.isSuccess) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '✅ ${_diagnosisResult!.labelKo}',
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
          if (_immediateActions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '사용자 처리 추천:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            ..._immediateActions
                .map((e) => Text('• $e', style: const TextStyle(fontSize: 16)))
                .toList(),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _navigateToRemedy,
            child: const Text('해결 방법 보기'),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🤔 판단 불확실',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _diagnosisResult!.reasonKo ??
                'AI가 사진을 인식하기 어렵습니다. 다시 시도해주세요.',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      );
    }
  }
}