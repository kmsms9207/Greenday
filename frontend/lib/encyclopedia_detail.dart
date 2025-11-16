// lib/encyclopedia_detail.dart (최종 수정 완료)

import 'package:flutter/material.dart';
import 'model/api.dart';
import 'model/plant.dart';

class EncyclopediaDetailScreen extends StatelessWidget {
  final int plantId;

  const EncyclopediaDetailScreen({super.key, required this.plantId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Plant>(
      future: fetchPlantDetail(plantId), // API 호출
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: _buildAppBar(context, '로딩 중...'),
            body: const Center(
              child: CircularProgressIndicator(color: Color(0xFF486B48)),
            ),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            appBar: _buildAppBar(context, '오류'),
            body: Center(child: Text('데이터 로드 실패: ${snapshot.error}')),
          );
        } else if (!snapshot.hasData) {
          return Scaffold(
            appBar: _buildAppBar(context, '오류'),
            body: const Center(child: Text('데이터 없음')),
          );
        }

        final plant = snapshot.data!;

        return Scaffold(
          appBar: _buildAppBar(context, plant.nameKo),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 이미지
                Container(
                  margin: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.0),
                    child: Image.network(
                      plant.imageUrl,
                      height: 250,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 250,
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.broken_image,
                            size: 50,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 2. 이름 및 학명
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plant.nameKo,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plant.species,
                        style: TextStyle(
                          fontSize: 17,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 3. 주요 정보 카드
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '주요 정보',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12.0,
                        runSpacing: 12.0,
                        children: [
                          _buildInfoCard(
                            context: context,
                            icon: Icons.thermostat_outlined,
                            label: '난이도',
                            value: plant.difficulty,
                            color: Colors.green,
                          ),
                          _buildInfoCard(
                            context: context,
                            icon: Icons.wb_sunny_outlined,
                            label: '빛 요구',
                            value: plant.lightRequirement,
                            color: Colors.orange,
                          ),
                          _buildInfoCard(
                            context: context,
                            icon: Icons.water_drop_outlined,
                            label: '물주기',
                            value: plant.wateringType,
                            color: Colors.blue,
                          ),
                          _buildInfoCard(
                            context: context,
                            icon: Icons.pets_outlined,
                            label: '반려동물',
                            value: plant.petSafe ? '안전' : '주의',
                            // 🟢 [수정] .shade700 제거하고 기본 색상만 전달
                            color: plant.petSafe ? Colors.cyan : Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 4. 설명
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '식물 설명',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        plant.description.isEmpty
                            ? '설명이 없습니다.'
                            : plant.description,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, String title) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF486B48),
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 1,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  // 🟢 [수정] 간소화된 정보 카드 위젯
  Widget _buildInfoCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color, // MaterialColor 대신 일반 Color로 받음
  }) {
    final cardWidth = (MediaQuery.of(context).size.width / 2) - 16 - 6;

    // 🟢 [핵심 수정] 전달받은 color가 MaterialColor라면 [700]을 쓰고, 아니면 그냥 color를 씀
    Color textColor = color;
    if (color is MaterialColor) {
      textColor = color[700]!; // .shade700 대신 [700] 사용
    }

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor, // 자동으로 계산된 진한 색상 적용
            ),
          ),
        ],
      ),
    );
  }
}
