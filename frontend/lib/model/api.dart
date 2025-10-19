import 'dart:convert';
import 'package:http/http.dart' as http;
import 'plant.dart';

// 1. URL을 한 곳에서 관리하여 변경이 쉽도록 baseUrl을 만듭니다.
// TODO: 이 URL을 백엔드 팀이 제공하는 최신 ngrok 주소로 항상 업데이트해야 합니다.
const String baseUrl = "https://7b2e1bfc4d32.ngrok-free.app";

// 백과사전 식물 목록 전체를 가져오는 함수
Future<List<Plant>> fetchPlantList() async {
  // TODO: 로그인 시 발급받은 실제 accessToken을 사용해야 합니다.
  // const String accessToken = 'YOUR_ACCESS_TOKEN';

  // 2. 백엔드 팀과 약속된 정확한 경로인지 다시 한번 확인해야 합니다. (404 에러의 주된 원인)
  final response = await http.get(
    Uri.parse('$baseUrl/encyclopedia/'),
    // headers: {'Authorization': 'Bearer $accessToken'}, // 인증이 필요할 경우
  );

  if (response.statusCode == 200) {
    // 3. 한글 데이터가 깨지지 않도록 UTF-8로 디코딩합니다.
    final String responseBody = utf8.decode(response.bodyBytes);
    final List<dynamic> jsonList = jsonDecode(responseBody);
    return jsonList.map((json) => Plant.fromJson(json)).toList();
  } else {
    throw Exception('API 호출 실패: ${response.statusCode}');
  }
}

// 특정 식물 하나의 상세 정보를 가져오는 함수
Future<Plant> fetchPlantDetail(int id) async {
  final response = await http.get(Uri.parse('$baseUrl/encyclopedia/$id'));

  if (response.statusCode == 200) {
    final String responseBody = utf8.decode(response.bodyBytes);
    return Plant.fromJson(jsonDecode(responseBody));
  } else {
    throw Exception('API 호출 실패: ${response.statusCode}');
  }
}

// 식물 종류를 검색하는 함수 (사용자 코드 기반)
Future<List<String>> fetchPlantSpecies(String query) async {
  final response = await http.get(
    Uri.parse('$baseUrl/encyclopedia?search=$query'),
  );

  if (response.statusCode == 200) {
    final String responseBody = utf8.decode(response.bodyBytes);
    final List<dynamic> jsonList = jsonDecode(responseBody);
    return jsonList.map((json) => json['name'].toString()).toList();
  } else {
    throw Exception('API 호출 실패: ${response.statusCode}');
  }
}
