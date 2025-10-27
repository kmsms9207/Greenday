import 'dart:convert';
import 'dart:io'; // File 객체 사용
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'plant.dart';
import 'chat_model.dart';
import 'diagnosis_model.dart';
import 'remedy_model.dart';

// ---------------------- 설정 ----------------------
const String baseUrl = "https://33ec24b88e40.ngrok-free.app";
final _storage = const FlutterSecureStorage();

Future<String> _getAccessToken() async {
  final accessToken = await _storage.read(key: 'accessToken');
  if (accessToken == null) {
    throw Exception('로그인 토큰을 찾을 수 없습니다. 다시 로그인해주세요.');
  }
  return accessToken;
}

// ---------------------- 백과사전 ----------------------
Future<List<Plant>> fetchPlantList({String? query}) async {
  String url = '$baseUrl/encyclopedia/';
  if (query != null && query.isNotEmpty) {
    final encodedQuery = Uri.encodeComponent(query);
    url += '?search=$encodedQuery';
  }
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final String responseBody = utf8.decode(response.bodyBytes);
    final List<dynamic> jsonList = jsonDecode(responseBody);
    return jsonList.map((json) => Plant.fromJson(json)).toList();
  } else {
    throw Exception('API 호출 실패: ${response.statusCode}');
  }
}

Future<Plant> fetchPlantDetail(int id) async {
  final response = await http.get(Uri.parse('$baseUrl/encyclopedia/$id'));
  if (response.statusCode == 200) {
    final String responseBody = utf8.decode(response.bodyBytes);
    return Plant.fromJson(jsonDecode(responseBody));
  } else {
    throw Exception('식물 상세 조회 실패: ${response.statusCode}');
  }
}

Future<List<String>> fetchPlantSpecies(String query) async {
  String url = '$baseUrl/encyclopedia/';
  if (query.isNotEmpty) {
    final encodedQuery = Uri.encodeComponent(query);
    url += '?search=$encodedQuery';
  }
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    final String responseBody = utf8.decode(response.bodyBytes);
    final List<dynamic> jsonList = jsonDecode(responseBody);
    return jsonList.map((json) => json['name_ko'].toString()).toList();
  } else {
    throw Exception('식물 검색 실패: ${response.statusCode}');
  }
}

// ---------------------- 내 식물 목록 ----------------------
Future<List<Plant>> fetchMyPlants() async {
  final accessToken = await _getAccessToken();
  final url = Uri.parse('$baseUrl/plants');

  final response = await http.get(
    url,
    headers: {'Authorization': 'Bearer $accessToken'},
  );

  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((json) => Plant.fromJson(json)).toList();
  } else {
    throw Exception('내 식물 목록 가져오기 실패: ${response.statusCode}');
  }
}

// ---------------------- 내 식물 등록 ----------------------
Future<Plant> savePlantToServer({
  required String nickname,
  required int plantMasterId,
}) async {
  final accessToken = await _getAccessToken();
  final url = Uri.parse('$baseUrl/plants');

  final response = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'name': nickname, // 사용자 지정 별명
      'plant_master_id': plantMasterId, // 서버 식물 ID
    }),
  );

  if (response.statusCode == 201) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return Plant.fromJson(data); // 서버가 반환한 식물 정보를 그대로 사용
  } else if (response.statusCode == 422) {
    throw Exception('검증 오류: ${response.body}');
  } else {
    throw Exception('식물 등록 실패: ${response.statusCode}');
  }
}

// ---------------------- 내 식물 삭제 ----------------------
Future<void> deleteMyPlant(int plantId) async {
  final accessToken = await _getAccessToken();
  final url = Uri.parse('$baseUrl/plants/$plantId');

  final response = await http.delete(
    url,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode == 200 || response.statusCode == 204) {
    print('식물 삭제 성공: $plantId');
  } else if (response.statusCode == 404) {
    throw Exception('식물을 찾을 수 없거나 권한이 없습니다.');
  } else {
    throw Exception('식물 삭제 실패: ${response.statusCode}');
  }
}

// ---------------------- 푸시 알림 ----------------------
Future<void> registerPushToken(String fcmToken, String accessToken) async {
  final url = Uri.parse('$baseUrl/auth/users/me/push-token');
  final response = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'push_token': fcmToken}),
  );
  if (response.statusCode != 200 && response.statusCode != 201) {
    throw Exception('푸시 토큰 등록 실패: ${response.statusCode}');
  }
}

Future<void> markAsWatered(int plantId, String accessToken) async {
  final url = Uri.parse('$baseUrl/plants/$plantId/water');
  final response = await http.post(
    url,
    headers: {'Authorization': 'Bearer $accessToken'},
  );
  if (response.statusCode != 200 && response.statusCode != 204) {
    throw Exception('물주기 완료 처리 실패: ${response.statusCode}');
  }
}

Future<void> snoozeWatering(int plantId, String accessToken) async {
  final url = Uri.parse('$baseUrl/plants/$plantId/snooze');
  final response = await http.post(
    url,
    headers: {'Authorization': 'Bearer $accessToken'},
  );
  if (response.statusCode != 200 && response.statusCode != 204) {
    throw Exception('물주기 하루 미루기 실패: ${response.statusCode}');
  }
}

// ---------------------- 회원 탈퇴 ----------------------
Future<void> deleteAccount(String accessToken) async {
  final url = Uri.parse('$baseUrl/auth/users/me');
  final response = await http.delete(
    url,
    headers: {'Authorization': 'Bearer $accessToken'},
  );

  if (response.statusCode == 200 || response.statusCode == 204) {
    print('회원 탈퇴 성공');
  } else {
    throw Exception('회원 탈퇴 실패: ${response.statusCode}');
  }
}

// ---------------------- 이메일 인증 ----------------------
Future<Map<String, dynamic>> verifyEmailCode(String email, String code) async {
  final url = Uri.parse('$baseUrl/auth/verify-code');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'code': code}),
  );
  final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
  if (response.statusCode == 200) {
    return responseBody;
  } else {
    throw Exception(responseBody['detail'] ?? '인증 실패: ${response.statusCode}');
  }
}

// ---------------------- 챗봇 ----------------------
Future<List<ChatMessage>> getChatHistory(int threadId) async {
  final accessToken = await _getAccessToken();
  final url = Uri.parse('$baseUrl/chat/threads/$threadId/messages');
  final response = await http.get(
    url,
    headers: {'Authorization': 'Bearer $accessToken'},
  );
  if (response.statusCode == 200) {
    final String responseBody = utf8.decode(response.bodyBytes);
    final List<dynamic> jsonList = jsonDecode(responseBody);
    return jsonList.map((json) => ChatMessage.fromJson(json)).toList();
  } else {
    throw Exception('대화 기록 불러오기 실패: ${response.statusCode}');
  }
}

Future<ChatSendResponse> sendChatMessage({
  required String message,
  int? threadId,
  String? imageUrl,
}) async {
  final accessToken = await _getAccessToken();
  final url = Uri.parse('$baseUrl/chat/send');
  Map<String, dynamic> requestBody = {'message': message};
  if (threadId != null) requestBody['thread_id'] = threadId;
  if (imageUrl != null) requestBody['image_url'] = imageUrl;

  final response = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(requestBody),
  );

  if (response.statusCode == 200 || response.statusCode == 201) {
    final String responseBody = utf8.decode(response.bodyBytes);
    return ChatSendResponse.fromJson(jsonDecode(responseBody));
  } else {
    throw Exception('챗봇 메시지 전송 실패: ${response.statusCode}');
  }
}

// ---------------------- AI 진단 ----------------------
Future<DiagnosisResponse> diagnosePlant(File imageFile) async {
  final accessToken = await _getAccessToken();
  final url = Uri.parse('$baseUrl/diagnose/auto');

  var request = http.MultipartRequest('POST', url);
  request.headers['Authorization'] = 'Bearer $accessToken';
  request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

  final streamedResponse = await request.send();
  final response = await http.Response.fromStream(streamedResponse);
  final responseBody = utf8.decode(response.bodyBytes);

  if (response.statusCode == 200 || response.statusCode == 201) {
    return DiagnosisResponse.fromJson(jsonDecode(responseBody));
  } else {
    throw Exception('진단 실패: ${response.statusCode}');
  }
}

// ---------------------- AI 처방전 ----------------------
Future<RemedyAdvice> fetchRemedy(String diseaseKey) async {
  final accessToken = await _getAccessToken();
  final url = Uri.parse('$baseUrl/remedy/');

  final response = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'disease_key': diseaseKey}),
  );

  final responseBody = utf8.decode(response.bodyBytes);
  if (response.statusCode == 200) {
    return RemedyAdvice.fromJson(jsonDecode(responseBody));
  } else {
    throw Exception('처방전 수신 실패: ${response.statusCode}');
  }
}

Future<Plant> fetchMyPlantDetail(int plantId) async {
  final accessToken = await _getAccessToken();
  // ★★★ 작업 지시서 3번 항목: GET /plants/{plant_id} ★★★
  final url = Uri.parse('$baseUrl/plants/$plantId');

  final response = await http.get(
    url,
    headers: {'Authorization': 'Bearer $accessToken'},
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    // ★★★ 이전에 수정한 Plant.fromJson을 그대로 사용합니다 ★★★
    return Plant.fromJson(data);
  } else if (response.statusCode == 404) {
    throw Exception('식물을 찾을 수 없거나 권한이 없습니다.');
  } else {
    throw Exception('내 식물 상세 정보 가져오기 실패: ${response.statusCode}');
  }
}
