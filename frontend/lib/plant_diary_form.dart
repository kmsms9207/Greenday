import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// Plant 모델 및 API 함수가 정의된 파일을 임포트
import '../model/api.dart'; 

class PlantDiaryFormScreen extends StatefulWidget {
  final int? plantId; // 일지를 작성할 식물의 ID (필수)

  // 수정 기능은 제외하므로 entryToEdit 인자는 필요 없습니다.
  const PlantDiaryFormScreen({
    super.key,
    required this.plantId, 
  });

  @override
  State<PlantDiaryFormScreen> createState() => _PlantDiaryFormScreenState();
}

class _PlantDiaryFormScreenState extends State<PlantDiaryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController(); // 제목 필드 추가
  final _messageController = TextEditingController(); // 내용 필드
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // --- 이미지 처리 ---

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  // --- 저장 로직 (생성) ---

  Future<void> _saveDiary() async {
    // 1. 유효성 검사: 내용이 비어있고, 이미지도 선택되지 않았다면 저장할 내용이 없음
    if (_titleController.text.isEmpty && _messageController.text.isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목, 내용 중 하나를 입력하거나 사진을 선택해주세요.')),
      );
      return;
    }

    // plantId가 없으면 저장 불가 (명세 확인된 API만 사용)
    if (widget.plantId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('오류: 식물 ID가 없어 일지를 작성할 수 없습니다.')),
        );
        return;
    }

    setState(() => _isLoading = true);
    String? imageUrl; // 서버에 업로드 후 반환받을 URL

    try {
      // 1. 이미지가 선택된 경우, 서버에 업로드합니다.
      if (_selectedImage != null) {
        imageUrl = await uploadMedia(_selectedImage!);
      } 
      
      // 2. 제목과 내용을 합쳐서 logMessage로 전송 (서버 요구사항에 맞춤)
      // 서버는 log_message 하나만 받으므로, 제목과 내용을 구분하여 보냅니다.
      final combinedMessage = '제목: ${_titleController.text}\n내용: ${_messageController.text}';

      // 3. 일지 생성 API 호출
      // 🚨 createManualDiary 함수는 api.dart에 구현되어 있어야 합니다.
      await createManualDiary(
        plantId: widget.plantId!,
        logMessage: combinedMessage,
        imageUrl: imageUrl,
      );

      // 성공 처리
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일지 작성 성공!')),
        );
        Navigator.pop(context, true); // 성공적으로 저장했음을 알리고 화면을 닫음
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- UI 구성 ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('새 일지 작성'),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _isLoading ? null : _saveDiary,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. 사진 선택/미리보기 영역
              _buildImageArea(),
              const SizedBox(height: 16),

              // 2. 제목 입력 필드
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: '일지 제목',
                  border: OutlineInputBorder(),
                  labelText: '제목',
                ),
                maxLines: 1,
                maxLength: 50,
              ),
              const SizedBox(height: 16),

              // 3. 내용 입력 필드
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: '자세한 일지 내용을 작성해주세요.',
                  border: OutlineInputBorder(),
                  labelText: '내용',
                ),
                maxLines: 8,
              ),
              const SizedBox(height: 24),
              
              // 🚨 주의: 삭제 기능은 일반적으로 타임라인 화면에 위치해야 하지만, 
              // API 테스트를 위해 임시로 여기에 삭제 버튼 예시를 추가합니다.
              // _buildDeleteButtonExample(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    final bool hasImage = _selectedImage != null;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: hasImage ? null : Border.all(color: Colors.grey.shade400, width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 이미지 미리보기
          if (_selectedImage != null)
            Image.file(
              _selectedImage!,
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          
          // 이미지 선택 버튼
          if (!hasImage)
            TextButton.icon(
              icon: const Icon(Icons.add_a_photo, size: 30),
              label: const Text('사진 선택'),
              onPressed: _pickImage,
            ),

          // 이미지 제거 버튼
          if (hasImage)
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _clearImage,
                ),
              ),
            ),
        ],
      ),
    );
  }
}