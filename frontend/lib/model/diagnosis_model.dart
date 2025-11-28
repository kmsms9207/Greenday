// lib/model/diagnosis_model.dart (최종 수정본)
import 'remedy_model.dart'; // 👈 처방전 모델 import

class DiagnosisResponse {
  // --- ⬇️ [핵심 수정] 백엔드 응답과 필드명 일치 ⬇️ ---
  final String diseaseKey;
  final String diseaseKo;
  final String? reasonKo; // reasonKo는 null 가능성이 있으므로 nullable로 유지
  final double score;
  final String? severity; // severity도 null 가능성이 있으므로 nullable로 유지
  final RemedyAdvice? guide;
  // --- ⬆️ [핵심 수정 완료] ⬆️ ---

  DiagnosisResponse({
    required this.diseaseKey,
    required this.diseaseKo,
    this.reasonKo, // nullable
    required this.score,
    this.severity, // nullable
    this.guide,
  });

  // 진단 성공 여부 판단 (diseaseKey가 'unknown'이 아닐 때 성공)
  bool get isSuccess => diseaseKey != "unknown";

  factory DiagnosisResponse.fromJson(Map<String, dynamic> json) {
    return DiagnosisResponse(
      // 👈 [수정] 백엔드 키(disease_key)로 파싱
      diseaseKey: json['disease_key'],
      // 👈 [수정] 백엔드 키(disease_ko)로 파싱
      diseaseKo: json['disease_ko'],
      // reason_ko는 백엔드에서 null을 보낼 수 있으므로 안전하게 처리
      reasonKo: json['reason_ko'],
      score: (json['score'] as num).toDouble(),
      // severity는 백엔드에서 null을 보낼 수 있으므로 안전하게 처리
      severity: json['severity'],
      // 👈 'guide' 객체가 null이 아닐 때만 파싱
      guide: json['guide'] != null ? RemedyAdvice.fromJson(json['guide']) : null,
    );
  }
}