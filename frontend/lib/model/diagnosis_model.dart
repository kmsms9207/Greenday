// POST /diagnose/auto 응답을 위한 데이터 모델
class DiagnosisResponse {
  final String label;
  final String labelKo;
  final double score;
  final String? severity; // 성공 시에만 존재
  final String? imageUrl; // 성공 시에만 존재
  final String? thumbUrl; // 성공 시에만 존재
  final int diagnosisId;
  final String? reasonKo; // 불확실(Unknown) 시에만 존재

  DiagnosisResponse({
    required this.label,
    required this.labelKo,
    required this.score,
    this.severity,
    this.imageUrl,
    this.thumbUrl,
    required this.diagnosisId,
    this.reasonKo,
  });

  // 진단 성공 여부 판단
  bool get isSuccess => label != "Unknown";

  factory DiagnosisResponse.fromJson(Map<String, dynamic> json) {
    return DiagnosisResponse(
      label: json['label'],
      labelKo: json['label_ko'],
      score: (json['score'] as num).toDouble(),
      severity: json['severity'],
      imageUrl: json['image_url'],
      thumbUrl: json['thumb_url'],
      diagnosisId: json['diagnosis_id'],
      reasonKo: json['reason_ko'],
    );
  }
}
