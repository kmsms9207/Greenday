// POST /remedy/ 응답을 위한 데이터 모델
class RemedyAdvice {
  final String diseaseKey;
  final String diseaseKo;
  final String titleKo;
  final String? severity;
  final String summaryKo;
  final List<String> immediateActions;
  final List<String> carePlan;
  final List<String> prevention;
  final List<String> caution;
  final List<String> whenToCallPro;

  RemedyAdvice({
    required this.diseaseKey,
    required this.diseaseKo,
    required this.titleKo,
    this.severity,
    required this.summaryKo,
    required this.immediateActions,
    required this.carePlan,
    required this.prevention,
    required this.caution,
    required this.whenToCallPro,
  });

  factory RemedyAdvice.fromJson(Map<String, dynamic> json) {
    // List<dynamic>을 List<String>으로 변환하는 헬퍼
    List<String> _listFromString(List<dynamic>? list) {
      return list?.map((item) => item.toString()).toList() ?? [];
    }

    return RemedyAdvice(
      diseaseKey: json['disease_key'],
      diseaseKo: json['disease_ko'],
      titleKo: json['title_ko'],
      severity: json['severity'],
      summaryKo: json['summary_ko'],
      immediateActions: _listFromString(json['immediate_actions']),
      carePlan: _listFromString(json['care_plan']),
      prevention: _listFromString(json['prevention']),
      caution: _listFromString(json['caution']),
      whenToCallPro: _listFromString(json['when_to_call_pro']),
    );
  }
}
