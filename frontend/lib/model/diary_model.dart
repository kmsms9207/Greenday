class DiaryEntry {
  final int id;
  final int plantId;
  final DateTime createdAt;
  final String logType; // DIAGNOSIS, WATERING, BIRTHDAY, NOTE, PHOTO
  final String logMessage; // 내용
  final String? title;    // 새로 추가: 제목
  final String? imageUrl;
  final int? referenceId;

  DiaryEntry({
    required this.id,
    required this.plantId,
    required this.createdAt,
    required this.logType,
    required this.logMessage,
    this.title,             // 새로 추가
    this.imageUrl,
    this.referenceId,
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'],
      plantId: json['plant_id'],
      createdAt: DateTime.parse(json['created_at']),
      logType: json['log_type'],
      logMessage: json['log_message'] ?? '',
      title: json['title'],  // 새로 추가
      imageUrl: json['image_url'],
      referenceId: json['reference_id'],
    );
  }
}