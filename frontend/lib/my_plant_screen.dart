import 'package:flutter/material.dart';
import 'plant_form.dart';
import 'plant_info.dart';
import 'model/plant.dart';
import 'model/api.dart';

class MyPlantScreen extends StatefulWidget {
  const MyPlantScreen({super.key});

  @override
  State<MyPlantScreen> createState() => _MyPlantScreenState();
}

class _MyPlantScreenState extends State<MyPlantScreen> {
  List<Plant> _plantsFromServer = [];

  @override
  void initState() {
    super.initState();
    fetchMyPlantsFromServer();
  }

  Future<void> fetchMyPlantsFromServer() async {
    try {
      final plants = await fetchMyPlants();
      setState(() {
        _plantsFromServer = plants;
      });
    } catch (e) {
      print('서버 식물 목록 가져오기 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFA4B6A4);

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: const Text(
          "GREEN DAY",
          style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 4.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // 첫 번째 식물 이미지 (없으면 '+' 아이콘)
                  AspectRatio(
                    aspectRatio: 1,
                    child: InkWell(
                      onTap: () async {
                        if (_plantsFromServer.isEmpty) return;
                        final plant = _plantsFromServer[0];
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlantInfoScreen(plant: plant),
                          ),
                        );
                        if (result == true) {
                          setState(() => _plantsFromServer.removeAt(0));
                        } else if (result == false) {
                          final updatedPlant = await fetchPlantDetail(plant.id);
                          setState(() => _plantsFromServer[0] = updatedPlant);
                        }
                      },
                      borderRadius: BorderRadius.circular(15.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(15.0),
                          image:
                              _plantsFromServer.isNotEmpty &&
                                  _plantsFromServer[0].imageUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(
                                    _plantsFromServer[0].imageUrl,
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child:
                            _plantsFromServer.isEmpty ||
                                _plantsFromServer[0].imageUrl.isEmpty
                            ? const Icon(
                                Icons.eco,
                                size: 40,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 그리드뷰 (첫 번째 식물 제외)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: _plantsFromServer.length + 1, // +1: 플러스 버튼
                    itemBuilder: (context, index) {
                      // + 버튼
                      if (index == 0) {
                        return InkWell(
                          onTap: () async {
                            final newPlant = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PlantFormScreen(),
                              ),
                            );

                            if (newPlant != null && newPlant is Plant) {
                              // 서버에서 다시 fetch하여 순서/이미지 정확히 반영
                              await fetchMyPlantsFromServer();
                            }
                          },
                          borderRadius: BorderRadius.circular(10.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: const Icon(
                              Icons.add,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      }

                      final plant =
                          _plantsFromServer[index - 1]; // index-1로 실제 식물 매핑
                      return InkWell(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlantInfoScreen(plant: plant),
                            ),
                          );
                          if (result == true) {
                            setState(() => _plantsFromServer.remove(plant));
                          } else if (result == false) {
                            final updatedPlant = await fetchPlantDetail(
                              plant.id,
                            );
                            setState(() {
                              final plantIndex = _plantsFromServer.indexWhere(
                                (p) => p.id == plant.id,
                              );
                              if (plantIndex != -1)
                                _plantsFromServer[plantIndex] = updatedPlant;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(10.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(10.0),
                            image: plant.imageUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(plant.imageUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: plant.imageUrl.isEmpty
                              ? const Icon(
                                  Icons.eco,
                                  size: 40,
                                  color: Color(0xFF486B48),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
