import 'package:flutter/material.dart';
import 'model/plant.dart';
import 'plant_form.dart';
import 'plant_info.dart';

// 임시 저장용 리스트 (앱 종료 시 초기화됨)
List<Plant> myPlants = [];

class MyPlantScreen extends StatefulWidget {
  const MyPlantScreen({super.key});

  @override
  State<MyPlantScreen> createState() => _MyPlantScreenState();
}

class _MyPlantScreenState extends State<MyPlantScreen> {

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
      // 화면 오버플로우를 방지하기 위해 스크롤 기능을 추가합니다.
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
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(15.0),
                        image: myPlants.isNotEmpty && myPlants[0].imageUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(myPlants[0].imageUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: myPlants.isEmpty || myPlants[0].imageUrl.isEmpty
                          ? const Icon(Icons.eco, size: 40, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  GridView.builder(
                    shrinkWrap: true, // GridView가 콘텐츠 크기만큼만 공간을 차지하도록 설정
                    physics:
                      const NeverScrollableScrollPhysics(), // GridView 자체 스크롤 비활성화
                    gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                       itemCount: myPlants.length + 1, // +1: ‘+’ 버튼
                        itemBuilder: (context, index) {
                      // '+' 아이콘 버튼
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
                                myPlants.insert(0, newPlant); // 새 식물을 맨 앞에 추가
                              }); // 새 식물 추가 후 화면 갱신
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

                      final plant = myPlants[index - 1]; // index 0은 + 버튼이므로 -1
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
                                    image: NetworkImage(plant.imageUrl), // 서버 이미지
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
