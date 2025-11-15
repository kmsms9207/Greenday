// model/plant.dart

class Plant {
  final int id;
  final String nameKo;
  final String species;
  final String imageUrl;
  final String description;
  final String difficulty;
  final String lightRequirement;
  final String wateringType;
  final bool petSafe;
  final List<String> tags;

  // 1. 필수 추가: lastWateredAt 필드를 DateTime? 타입으로 추가
  final DateTime? lastWateredAt;

  Plant({
    required this.id,
    required this.nameKo,
    required this.species,
    required this.imageUrl,
    required this.description,
    required this.difficulty,
    required this.lightRequirement,
    required this.wateringType,
    required this.petSafe,
    required this.tags,
    this.lastWateredAt, // 2. 생성자 인수에 추가
  });

  // JSON 데이터를 Plant 객체로 변환해주는 공장
  factory Plant.fromJson(Map<String, dynamic> json) {
    // 3. JSON에서 last_watered_at 값을 파싱
    final String? lastWateredAtString = json['last_watered_at'] as String?;

    return Plant(
      id: json['id'] ?? json['pk'] ?? 0, // id가 없으면 pk, 둘 다 없으면 0
      // [수정됨] /plants/의 'name' 키와 /encyclopedia/의 'name_ko' 키 모두 호환
      nameKo: json['name'] ?? json['name_ko'] ?? '이름 없음',

      species: json['species'] ?? '학명 정보 없음',

      // [수정됨] /plants/의 'master_image_url' 키와 /encyclopedia/의 'image_url' 키 모두 호환
      imageUrl: json['master_image_url'] ?? json['image_url'] ?? '',

      description: json['description'] ?? '설명이 없습니다.',
      difficulty: json['difficulty'] ?? '정보 없음',
      lightRequirement: json['light_requirement'] ?? '정보 없음',
      wateringType: json['watering_type'] ?? "정보 없음",
      petSafe: json['pet_safe'] ?? false,
      tags: List<String>.from(json['tags'] ?? []),

      // 3. 필수 수정: lastWateredAtString이 null이 아닐 경우 DateTime으로 파싱
      lastWateredAt:
          lastWateredAtString != null && lastWateredAtString.isNotEmpty
          ? DateTime.parse(lastWateredAtString)
          : null,
    );
  }
}
