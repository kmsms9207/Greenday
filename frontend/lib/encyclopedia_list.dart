import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'model/api.dart';
import 'model/plant.dart';
import 'encyclopedia_detail.dart';
import 'dart:async'; // Timer를 사용하기 위해 import

class EncyclopediaListScreen extends StatefulWidget {
  const EncyclopediaListScreen({super.key});

  @override
  State<EncyclopediaListScreen> createState() => _EncyclopediaListScreenState();
}

class _EncyclopediaListScreenState extends State<EncyclopediaListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  Future<List<Plant>>? _plantListFuture;

  @override
  void initState() {
    super.initState();
    _plantListFuture = fetchPlantList();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final newQuery = _searchController.text;
      // 1. 디버깅 로그 추가: 검색어가 변경될 때마다 로그 출력
      print('Search query changed: $newQuery');
      if (_searchQuery != newQuery) {
        setState(() {
          _searchQuery = newQuery;
          // 2. 디버깅 로그 추가: API 호출 직전 로그 출력
          print('Calling fetchPlantList with query: $_searchQuery');
          _plantListFuture = fetchPlantList(query: _searchQuery);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '식물 이름 검색...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey[600]),
          ),
          style: const TextStyle(color: Colors.black, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.grey),
            onPressed: () {
              _searchController.clear();
              if (_searchQuery.isNotEmpty) {
                setState(() {
                  _searchQuery = '';
                  _plantListFuture = fetchPlantList();
                });
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Plant>>(
        future: _plantListFuture,
        builder: (context, snapshot) {
          // 3. 디버깅 로그 추가: FutureBuilder가 다시 빌드될 때 로그 출력
          print(
            'FutureBuilder rebuilding with connection state: ${snapshot.connectionState}',
          );
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('데이터 로드 실패: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                _searchQuery.isEmpty ? '표시할 식물이 없습니다.' : '검색 결과가 없습니다.',
              ),
            );
          }

          final plants = snapshot.data!;
          return ListView.builder(
            itemCount: plants.length,
            itemBuilder: (context, index) {
              final plant = plants[index];
              return ListTile(
                leading: CachedNetworkImage(
                  imageUrl: plant.imageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.0),
                    ),
                  ),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.eco, size: 40, color: Colors.grey),
                ),
                title: Text(plant.nameKo),
                subtitle: Text('난이도: ${plant.difficulty}'),
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
