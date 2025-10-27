import 'package:flutter/material.dart';
import 'model/api.dart';
import 'model/remedy_model.dart';

class RemedyScreen extends StatefulWidget {
  final String diseaseKey; // 진단 화면에서 전달받은 질병 키 (예: "powdery_mildew")

  const RemedyScreen({super.key, required this.diseaseKey});

  @override
  State<RemedyScreen> createState() => _RemedyScreenState();
}

class _RemedyScreenState extends State<RemedyScreen> {
  late Future<RemedyAdvice> _remedyFuture;

  @override
  void initState() {
    super.initState();
    // 화면이 로드될 때 처방전 API를 호출합니다.
    _remedyFuture = fetchRemedy(widget.diseaseKey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 처방전')),
      body: FutureBuilder<RemedyAdvice>(
        future: _remedyFuture,
        builder: (context, snapshot) {
          // 1. 로딩 중
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // 2. 에러 발생
          if (snapshot.hasError) {
            return Center(child: Text('처방전을 불러오는 데 실패했습니다: ${snapshot.error}'));
          }
          // 3. 데이터 없음
          if (!snapshot.hasData) {
            return const Center(child: Text('처방전 데이터가 없습니다.'));
          }

          // 4. 성공
          final remedy = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  remedy.titleKo, // "흰가루병 해결 가이드"
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  remedy.summaryKo, // "요약..."
                  style: const TextStyle(fontSize: 16, color: Colors.blueGrey),
                ),
                const SizedBox(height: 24),
                _buildSection(
                  context,
                  title: '🚨 즉시 할 일',
                  items: remedy.immediateActions,
                  icon: Icons.warning_amber_rounded,
                  color: Colors.red.shade100,
                ),
                _buildSection(
                  context,
                  title: '🌿 관리 계획',
                  items: remedy.carePlan,
                  icon: Icons.healing,
                  color: Colors.green.shade100,
                ),
                _buildSection(
                  context,
                  title: '🛡️ 예방',
                  items: remedy.prevention,
                  icon: Icons.shield_outlined,
                  color: Colors.blue.shade100,
                ),
                _buildSection(
                  context,
                  title: '⚠️ 주의사항',
                  items: remedy.caution,
                  icon: Icons.gpp_good_outlined,
                  color: Colors.yellow.shade100,
                ),
                _buildSection(
                  context,
                  title: '👨‍⚕️ 전문가 도움이 필요할 때',
                  items: remedy.whenToCallPro,
                  icon: Icons.medical_services_outlined,
                  color: Colors.grey.shade200,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 처방전의 각 섹션을 그리는 헬퍼 위젯
  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<String> items,
    required IconData icon,
    required Color color,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: color,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.black54),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 각 항목을 리스트로 표시
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Text(item, style: const TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
