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
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('데이터 로드 실패: ${snapshot.error}'));
        } else if (!snapshot.hasData) {
          return const Center(child: Text('데이터 없음'));
        }

        final plant = snapshot.data!;
        return Scaffold(
          appBar: AppBar(
            title: Text(plant.nameKo),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () {
                Navigator.pop(context); // 이전 화면으로 돌아가기
              },
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.network(plant.imageUrl),
                const SizedBox(height: 12),
                Text('학명: ${plant.species}'),
                Text('난이도: ${plant.difficulty}'),
                Text('빛 요구: ${plant.lightRequirement}'),
                Text('물주기: ${plant.wateringType}'), // 핵심 반영
                const SizedBox(height: 12),
                Text(plant.description),
              ],
            ),
          ),
        );
      },
    );
  }
}