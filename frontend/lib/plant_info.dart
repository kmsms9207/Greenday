import 'package:flutter/material.dart';
import 'model/plant.dart';
import 'model/api.dart'; // 1. API 서비스 파일을 import 합니다.
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // 2. Secure Storage import

class PlantInfoScreen extends StatelessWidget {
  final Plant plant;
  const PlantInfoScreen({super.key, required this.plant});

  // 3. Secure Storage 인스턴스 생성
  final _storage = const FlutterSecureStorage();

  // "물 줬어요" 버튼 클릭 시 실행될 함수
  Future<void> _handleWatering(BuildContext context) async {
    try {
      // 4. 저장된 accessToken을 읽어옵니다.
      final accessToken = await _storage.read(key: 'accessToken');
      if (accessToken == null) {
        throw Exception('로그인 토큰을 찾을 수 없습니다.');
      }

      await markAsWatered(plant.id, accessToken); // 5. API 호출 시 accessToken 전달
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('물주기 기록 완료!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('물주기 기록 실패: $e')));
    }
  }

  // "하루 미루기" 버튼 클릭 시 실행될 함수
  Future<void> _handleSnooze(BuildContext context) async {
    try {
      // 4. 저장된 accessToken을 읽어옵니다.
      final accessToken = await _storage.read(key: 'accessToken');
      if (accessToken == null) {
        throw Exception('로그인 토큰을 찾을 수 없습니다.');
      }

      await snoozeWatering(plant.id, accessToken); // 5. API 호출 시 accessToken 전달
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('물주기 알림을 하루 미뤘습니다.')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('알림 미루기 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        toolbarHeight: 50,
        centerTitle: true,
        leading: IconButton(
          // AppBar에 뒤로가기 버튼 추가
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: "GREEN",
                style: TextStyle(fontSize: 25, color: Color(0xFF486B48)),
              ),
              TextSpan(
                text: " DAY",
                style: TextStyle(fontSize: 25, color: Colors.black),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        // 내용이 길어질 수 있으므로 스크롤 추가
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Center(
              child: _centerInfoTile(
                plant.nameKo,
                plant.species,
                imageUrl: plant.imageUrl,
              ),
            ),
            const SizedBox(height: 30), // 간격 조절
            Column(
              children: [
                _leftInfoTile("햇빛", plant.lightRequirement),
                _leftInfoTile("물주기", plant.wateringType),
              ],
            ),
            const SizedBox(height: 30), // 버튼 위 간격 추가
            // "물 줬어요" 와 "하루 미루기" 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _handleWatering(context), // 6. 함수 연결
                  icon: const Icon(Icons.water_drop_outlined),
                  label: const Text("물 줬어요"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[100],
                    foregroundColor: Colors.blue[800],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _handleSnooze(context), // 6. 함수 연결
                  icon: const Icon(Icons.snooze),
                  label: const Text("하루 미루기"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[100],
                    foregroundColor: Colors.orange[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30), // 버튼 아래 간격 추가
          ],
        ),
      ),
      bottomNavigationBar: SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          onPressed: () async {
            // TODO: Plant 수정 화면 연동
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFA4B6A4),
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
          child: const Text("수정 / 삭제", style: TextStyle(fontSize: 25)),
        ),
      ),
    );
  }

  // 가운데 정렬 위젯 (이미지 부분 수정: NetworkImage 사용)
  Widget _centerInfoTile(String name, String species, {String? imageUrl}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            image: imageUrl != null && imageUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(imageUrl), // NetworkImage로 변경
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: (imageUrl == null || imageUrl.isEmpty)
              ? const Icon(Icons.camera_alt, size: 40, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 5),
        Text(
          name,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Color(0xFF486B48),
          ),
        ),
        Text(
          species,
          style: const TextStyle(fontSize: 20, color: Color(0xFFA4B6A4)),
        ),
      ],
    );
  }

  // 왼쪽 정렬 위젯 (기존 코드와 동일)
  Widget _leftInfoTile(String label, String value) {
    return Card(
      color: const Color(0xFFF1F1F1),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: double.infinity,
        height: 50,
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF656565),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value.isNotEmpty ? value : "정보 없음", // 값이 비어있을 경우 처리
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
