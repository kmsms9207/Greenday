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
  });

  // JSON 데이터를 Plant 객체로 변환해주는 공장
  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      id: json['id'] ?? json['pk'] ?? 0, // id가 없으면 pk, 둘 다 없으면 0
      nameKo: json['name_ko'] ?? '이름 없음',
      species: json['species'] ?? '학명 정보 없음',
      imageUrl: json['image_url'] ?? '', // 이미지 URL이 없으면 빈 문자열
      description: json['description'] ?? '설명이 없습니다.',
      difficulty: json['difficulty'] ?? '정보 없음',
      lightRequirement: json['light_requirement'] ?? '정보 없음',
      wateringType: json['watering_type'] ?? "정보 없음",
      petSafe: json['pet_safe'] ?? false,
      tags: List<String>.from(json['tags'] ?? []),
    );
  }
}
