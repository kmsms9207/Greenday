// lib/screens/community_post_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_application_1/model/post.dart';
import 'package:flutter_application_1/model/api.dart'; // createCommunityPost 함수 사용
import 'package:flutter_application_1/model/post.dart'; // Post 모델 사용 (수정 시 사용될 수 있음)

class CommunityPostFormScreen extends StatefulWidget {
  final Post? postToEdit; // 수정 시 사용

  const CommunityPostFormScreen({Key? key, this.postToEdit}) : super(key: key);

  @override
  State<CommunityPostFormScreen> createState() =>
      _CommunityPostFormScreenState();
}

class _CommunityPostFormScreenState extends State<CommunityPostFormScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.postToEdit != null) {
      _titleController.text = widget.postToEdit!.title;
      _contentController.text = widget.postToEdit!.content;
    }
  }

  Future<void> _handleSave() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제목과 내용을 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.postToEdit == null) {
        // 새 글 작성
        await createCommunityPost(
          _titleController.text,
          _contentController.text,
        );
      } else {
        // 기존 글 수정
        // API 문서는 PUT /posts/{post_id}를 사용합니다.
        // 현재 updateCommunityPost 함수는 title, content를 모두 요구하는 것으로 구현되어 있습니다.
        await updateCommunityPost(
          widget.postToEdit!.id,
          _titleController.text,
          _contentController.text,
        );
      }

      // 저장 성공 후 목록 화면으로 돌아가기 (true를 반환하여 목록 갱신 유도)
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.postToEdit == null ? '새 글 작성' : '글 수정'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              maxLines: 10,
              decoration: const InputDecoration(labelText: '내용'),
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _handleSave,
                    child: Text(widget.postToEdit == null ? '게시하기' : '수정 완료'),
                  ),
          ],
        ),
      ),
    );
  }
}
