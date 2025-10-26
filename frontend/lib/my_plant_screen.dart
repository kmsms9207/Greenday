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
  // 서버에서 가져온 식물 리스트
  List<Plant> _plantsFromServer = [];

  @override
  void initState() {
    super.initState();
    fetchMyPlantsFromServer();
  }

  // 서버에서 내 식물 가져오기
  Future<void> fetchMyPlantsFromServer() async {
    try {
      final plants = await fetchMyPlants(); // api.dart에 구현된 함수 사용
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
                  // 첫 번째 식물 이미지
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(15.0),
                        image: _plantsFromServer.isNotEmpty &&
                                _plantsFromServer[0].imageUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(_plantsFromServer[0].imageUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _plantsFromServer.isEmpty ||
                              _plantsFromServer[0].imageUrl.isEmpty
                          ? const Icon(Icons.eco, size: 40, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 그리드뷰
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _plantsFromServer.length + 1, // +1: 새 식물 버튼
                    itemBuilder: (context, index) {
                      // '+' 버튼
                      if (index == 0) {
                        return InkWell(
                          onTap: () async {
                            final newPlant = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PlantFormScreen(),
                              ),
                            );
                            if (newPlant != null && newPlant is Plant) {
                              setState(() {
                                _plantsFromServer.insert(0, newPlant);
                              });
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

                      final plant = _plantsFromServer[index - 1];
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlantInfoScreen(plant: plant),
                            ),
                          );
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
