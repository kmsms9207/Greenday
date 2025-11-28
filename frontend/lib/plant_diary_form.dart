import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../model/api.dart'; // createManualDiary, uploadMedia
import '../model/media_model.dart'; // MediaUploadResponse (api.dart import를 통해 간접 사용)

class PlantDiaryFormScreen extends StatefulWidget {
  final int plantId;

  const PlantDiaryFormScreen({super.key, required this.plantId});

  @override
  State<PlantDiaryFormScreen> createState() => _PlantDiaryFormScreenState();
}

class _PlantDiaryFormScreenState extends State<PlantDiaryFormScreen> {
  File? _selectedImage;
  bool _uploading = false;

  // 🟢 [수정] title과 content 컨트롤러 분리
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  // 갤러리 선택
  Future<void> _pickImageFromGallery() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null)
      setState(() => _selectedImage = File(pickedFile.path));
  }

  // 카메라 촬영
  Future<void> _takePhotoWithCamera() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
    );
    if (pickedFile != null)
      setState(() => _selectedImage = File(pickedFile.path));
  }

  // 업로드 및 일지 저장
  Future<void> _saveDiary() async {
    // 🟢 [수정] title, content 값 가져오기
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // 🟢 [수정] 제목은 필수로 입력
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제목을 입력해주세요.')));
      return;
    }

    if (content.isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('내용 또는 이미지를 추가해주세요.')));
      return;
    }

    setState(() => _uploading = true);

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        // --- ⬇️ [핵심 수정] MediaUploadResponse 처리 ⬇️ ---
        // 1. MediaUploadResponse 객체를 받습니다.
        final MediaUploadResponse uploadResponse = await uploadMedia(_selectedImage!);
        // 2. 객체 안의 imageUrl 문자열만 꺼내서 할당합니다.
        imageUrl = uploadResponse.imageUrl;
        // --- ⬆️ [핵심 수정 완료] ⬆️ ---
      }

      // 🟢 [수정] logType 결정 (이미지가 있으면 PHOTO, 없으면 NOTE)
      final String logType = _selectedImage != null ? 'PHOTO' : 'NOTE';

      // 🟢 [수정] createManualDiary 호출 시 title, logType 파라미터 추가
      await createManualDiary(
        plantId: widget.plantId,
        title: title, // 🟢 title 전달
        logMessage: content,
        imageUrl: imageUrl,
        logType: logType, // 🟢 logType 전달
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('성장 일지 저장 완료!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('일지 저장 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
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

  Widget _buildSelectedImagePreview() {
    if (_selectedImage == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Image.file(_selectedImage!, height: 250, fit: BoxFit.cover),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('성장 일지 작성'),
        backgroundColor: const Color(0xFFA4B6A4),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🟢 [추가] 제목 입력 필드
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '제목',
                hintText: '일지 제목을 입력하세요 (필수)',
              ),
            ),
            const SizedBox(height: 16),
            // 🟢 [수정] 내용 입력 필드
            TextField(
              controller: _contentController,
              maxLines: 10, // 라인 수 줄임
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '내용',
                hintText: '내용을 입력하세요...',
              ),
            ),
            const SizedBox(height: 30),
            _buildImagePickerRow(),
            _buildSelectedImagePreview(),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _uploading ? null : _saveDiary,
                icon: _uploading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.save),
                label: Text(_uploading ? '저장 중...' : '일지 저장'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA4B6A4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}