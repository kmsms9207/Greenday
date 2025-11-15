import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'model/api.dart';

class PlantDiaryFormScreen extends StatefulWidget {
  final int? plantId; // nullable
  const PlantDiaryFormScreen({Key? key, this.plantId}) : super(key: key);

  @override
  State<PlantDiaryFormScreen> createState() => _PlantDiaryFormScreenState();
}

class _PlantDiaryFormScreenState extends State<PlantDiaryFormScreen> {
  final TextEditingController _plantNameController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  File? _selectedImage;
  bool _loading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _saveDiary() async {
    if (_contentController.text.trim().isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용이나 사진을 추가해주세요.')),
      );
      return;
    }

    if (_plantNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('식물 이름을 입력해주세요.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await uploadMedia(_selectedImage!);
      }

      await createManualDiary(
        plantId: widget.plantId ?? 0,
        logMessage: _contentController.text.trim().isNotEmpty
            ? _contentController.text.trim()
            : '사진을 추가했습니다.',
        imageUrl: imageUrl,
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일지 저장 실패: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("새 일지 작성")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _plantNameController,
              decoration: const InputDecoration(
                labelText: '식물 이름',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _contentController,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: '내용',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            _selectedImage != null
                ? Image.file(_selectedImage!, height: 200)
                : const SizedBox(),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo),
              label: const Text("사진 선택"),
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveDiary,
                    child: const Text("저장"),
                  ),
          ],
        ),
      ),
    );
  }
}
