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

  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      id: json['id'],
      nameKo: json['name_ko'],
      species: json['species'],
      imageUrl: json['image_url'],
      description: json['description'],
      difficulty: json['difficulty'],
      lightRequirement: json['light_requirement'],
      wateringType: json['watering_type'] ?? "정보 없음",
      petSafe: json['pet_safe'] ?? false,
      tags: List<String>.from(json['tags'] ?? []),
    );
  }
}