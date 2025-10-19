import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 1. 패키지를 import 합니다.
import 'model/api.dart';
import 'model/plant.dart';
import 'encyclopedia_detail.dart';

class EncyclopediaListScreen extends StatelessWidget {
  const EncyclopediaListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('식물 백과사전')),
      body: FutureBuilder<List<Plant>>(
        future: fetchPlantList(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('데이터 로드 실패: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('데이터 없음'));
          }

          final plants = snapshot.data!;
          return ListView.builder(
            itemCount: plants.length,
            itemBuilder: (context, index) {
              final plant = plants[index];
              return ListTile(
                // 2. Image.network를 CachedNetworkImage로 교체합니다.
                leading: CachedNetworkImage(
                  imageUrl: plant.imageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  // 이미지를 불러오는 동안 보여줄 임시 위젯 (로딩 스피너)
                  placeholder: (context, url) => const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.0),
                    ),
                  ),
                  // 이미지 로딩 실패 시 보여줄 위젯 (에러 아이콘)
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
                title: Text(plant.nameKo),
                subtitle: Text('물주기: ${plant.wateringType}'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          EncyclopediaDetailScreen(plantId: plant.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
