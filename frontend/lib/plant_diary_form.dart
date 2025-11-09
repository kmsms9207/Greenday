import 'package:flutter/material.dart';

class PlantDiaryFormScreen extends StatefulWidget {
  const PlantDiaryFormScreen({super.key});

  @override
  State<PlantDiaryFormScreen> createState() => _PlantDiaryFormScreenState();
} 

class _PlantDiaryFormScreenState extends State<PlantDiaryFormScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  void _savePlant() {
    final nickname = _nicknameController.text.trim();
    final title = _titleController.text.trim();

    if (nickname.isEmpty || title.isEmpty) {
      // 이름이나 제목이 비어있으면 경고
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름과 제목을 입력해주세요.')),
      );
      return; // 추가하지 않고 종료
    }

    final plantData = {
      'nickname': nickname,
      'title': title,
      'content': _contentController.text,
    };
    Navigator.pop(context, plantData); 
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "GREEN DAY",
          style: TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black54),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTextField("이름", _nicknameController),
            const SizedBox(height: 16),
            _buildTextField("제목", _titleController),
            const SizedBox(height: 16),
            _buildTextField("내용", _contentController, maxLines: 15),
          ],
        ),
      ),
      bottomNavigationBar: SizedBox(
        width: double.infinity,
        height: 60, // 버튼 높이
        child: ElevatedButton(
          onPressed: _savePlant,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFA4B6A4),
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            padding: EdgeInsets.zero,
          ),
          child: const Text("저장", style: TextStyle(fontSize: 25)),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Color(0xFFF1F1F1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFA4B6A4)),
        ),
      ),
    );
  }
}