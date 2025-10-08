import 'package:flutter/material.dart';
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
        future: fetchPlantList(), // API 호출
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
                leading: Image.network(plant.imageUrl),
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