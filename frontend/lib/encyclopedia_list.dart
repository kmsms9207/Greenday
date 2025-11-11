import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'model/api.dart';
import 'model/plant.dart';
import 'encyclopedia_detail.dart';
import 'dart:async';

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

  // 🔽 정렬 관련 상태
  String _selectedSort = 'name_ko'; // 기본: 이름순
  String _selectedOrder = 'asc'; // 기본: 오름차순

  final Map<String, String> sortOptions = {
    'name_ko': '이름순',
    'difficulty': '난이도순',
    'light_requirement': '햇빛순',
    'watering_type': '물주기순',
    'pet_safe': '반려동물 안전순',
  };

  @override
  void initState() {
    super.initState();
    _fetchPlants();
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
      final newQuery = _searchController.text.trim();
      if (_searchQuery != newQuery) {
        setState(() {
          _searchQuery = newQuery;
        });
        _fetchPlants();
      }
    });
  }

  void _fetchPlants() {
    print('📡 검색: "$_searchQuery", 정렬: $_selectedSort ($_selectedOrder)');
    setState(() {
      _plantListFuture = fetchPlantList(
        query: _searchQuery,
        sortBy: _selectedSort,
        order: _selectedOrder,
      );
    });
  }

  void _onSortChanged(String? newSort) {
    if (newSort != null) {
      setState(() => _selectedSort = newSort);
      _fetchPlants();
    }
  }

  void _toggleOrder() {
    setState(() {
      _selectedOrder = (_selectedOrder == 'asc') ? 'desc' : 'asc';
    });
    _fetchPlants();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '식물 이름, 특징, 초성 등으로 검색...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey[600]),
          ),
          style: const TextStyle(color: Colors.black, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.grey),
            onPressed: () {
              if (_searchController.text.isNotEmpty) {
                _searchController.clear();
                _searchQuery = '';
                _fetchPlants();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔽 정렬 옵션 드롭다운 영역
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedSort,
                    items: sortOptions.entries
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: _onSortChanged,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _selectedOrder == 'asc'
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    color: Colors.green,
                  ),
                  onPressed: _toggleOrder,
                  tooltip: _selectedOrder == 'asc' ? '오름차순' : '내림차순',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 🔽 리스트 뷰
          Expanded(
            child: FutureBuilder<List<Plant>>(
              future: _plantListFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  print('❌ 오류: ${snapshot.error}');
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
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: plant.imageUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.0),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.eco,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      title: Text(
                        plant.nameKo,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '난이도: ${plant.difficulty}',
                        style: const TextStyle(color: Colors.grey),
                      ),
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
          ),
        ],
      ),
    );
  }
}
