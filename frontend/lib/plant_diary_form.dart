import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../model/api.dart';

class PlantDiaryFormScreen extends StatefulWidget {
  final int plantId;

  const PlantDiaryFormScreen({super.key, required this.plantId});

  @override
  State<PlantDiaryFormScreen> createState() => _PlantDiaryFormScreenState();
}

class _PlantDiaryFormScreenState extends State<PlantDiaryFormScreen> {
  File? _selectedImage;
  bool _uploading = false;
  final TextEditingController _contentController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  // 갤러리 선택
  Future<void> _pickImageFromGallery() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) setState(() => _selectedImage = File(pickedFile.path));
  }

  // 카메라 촬영
  Future<void> _takePhotoWithCamera() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) setState(() => _selectedImage = File(pickedFile.path));
  }

  // 업로드 및 일지 저장
  Future<void> _saveDiary() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용 또는 이미지를 추가해주세요.')),
      );
      return;
    }

    setState(() => _uploading = true);

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await uploadMedia(_selectedImage!);
      }

      await createManualDiary(
        plantId: widget.plantId,
        logMessage: content,
        imageUrl: imageUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('성장 일지 저장 완료!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('일지 저장 실패: $e')),
        );
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
            TextField(
              controller: _contentController,
              maxLines: 15,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
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
