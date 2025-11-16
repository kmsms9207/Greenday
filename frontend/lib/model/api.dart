// lib/model/api.dart 파일 전체 (최종 수정 및 안정화)

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'plant.dart'; // Plant 모델 정의 파일
import 'chat_model.dart'; // ChatSendResponse, ChatMessage, ThreadInfo 모델 정의 파일
import 'diagnosis_model.dart'; // DiagnosisResponse 모델 정의 파일
import 'remedy_model.dart'; // RemedyAdvice 모델 정의 파일
import 'package:http_parser/http_parser.dart';
import 'dart:async';

// ---------------------- 설정 ----------------------
const String baseUrl =
    "https://feb991a69212.ngrok-free.app"; // 🚨 현재 사용 중인 Base URL
final _storage = const FlutterSecureStorage();

Future<String> _getAccessToken() async {
  final accessToken = await _storage.read(key: 'accessToken');
  if (accessToken == null) {
    throw Exception('로그인 토큰을 찾을 수 없습니다. 다시 로그인해주세요.');
  }
  return accessToken;
}

// ---------------------- 백과사전 ----------------------
Future<List<Plant>> fetchPlantList({
  String? query,
  String? sortBy,
  String order = 'asc', // 기본 오름차순
}) async {
  final queryParams = <String, String>{};

  // 검색어 있으면 검색 API 사용
  late Uri uri;
  if (query != null && query.isNotEmpty) {
    queryParams['q'] = query;
    uri = Uri.parse(
      '$baseUrl/encyclopedia/search',
    ).replace(queryParameters: queryParams);
  }
  // 검색어 없으면 일반 백과사전 API 사용 + 정렬 적용
  else {
    if (sortBy != null && sortBy.isNotEmpty) {
      queryParams['sort_by'] = sortBy;
      queryParams['order'] = order;
    }
    uri = Uri.parse(
      '$baseUrl/encyclopedia/',
    ).replace(queryParameters: queryParams);
  }

  print('📡 요청 URL: $uri');

  final response = await http.get(uri);

  if (response.statusCode == 200) {
    final String responseBody = utf8.decode(response.bodyBytes);
    final List<dynamic> jsonList = jsonDecode(responseBody);
    return jsonList.map((json) => Plant.fromJson(json)).toList();
  } else {
    print('❌ 오류: ${response.body}');
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
// 🚨 중복 정의 문제를 해결하고, 이 코드를 유일한 '내 식물 목록 조회' 함수로 확정합니다.
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

// 🚨 수정 완료: 422 에러 해결을 위해 MultipartRequest 요청으로 복귀
Future<ChatSendResponse> sendChatMessage({
  required String message,
  int? threadId,
}) async {
  final accessToken = await _getAccessToken();
  final url = Uri.parse('$baseUrl/chat/send');

  var request = http.MultipartRequest('POST', url);
  request.headers['Authorization'] = 'Bearer $accessToken';

  // 1. message를 request.fields에 추가
  request.fields['message'] = message;

  // 2. thread_id를 request.fields에 추가
  if (threadId != null) {
    request.fields['thread_id'] = threadId.toString();
  }

  // Timeout 적용
  final streamedResponse = await request.send();
  final response = await http.Response.fromStream(
    streamedResponse,
  ).timeout(const Duration(seconds: 60));

  final responseBody = utf8.decode(response.bodyBytes);

  if (response.statusCode == 200 || response.statusCode == 201) {
    // NOTE: ChatSendResponse는 chat_model.dart에 정의되어 있어야 합니다.
    return ChatSendResponse.fromJson(jsonDecode(responseBody));
  } else {
    throw Exception('챗봇 메시지 전송 실패: ${response.statusCode} - $responseBody');
  }
}

// 기존 getChatHistory 함수는 변경 없음
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
    // NOTE: ChatMessage는 chat_model.dart에 정의되어 있어야 합니다.
    return jsonList.map((json) => ChatMessage.fromJson(json)).toList();
  } else {
    throw Exception('대화 기록 불러오기 실패: ${response.statusCode}');
  }
}

// 대화방 목록 가져오기 함수 (ThreadInfo 모델이 정의되어 있어야 함)
Future<List<ThreadInfo>> fetchChatThreads() async {
  final accessToken = await _getAccessToken();
  final url = Uri.parse('$baseUrl/chat/threads');

  final response = await http.get(
    url,
    headers: {'Authorization': 'Bearer $accessToken'},
  );

  if (response.statusCode == 200) {
    final String responseBody = utf8.decode(response.bodyBytes);
    final List<dynamic> jsonList = jsonDecode(responseBody);
    // NOTE: ThreadInfo는 chat_model.dart에 정의되어 있어야 합니다.
    return jsonList.map((json) => ThreadInfo.fromJson(json)).toList();
  } else {
    throw Exception('대화방 목록 불러오기 실패: ${response.statusCode}');
  }
}

// ---------------------- AI 진단 ----------------------
Future<DiagnosisResponse> diagnosePlant(File imageFile, int plantId) async {
  final accessToken = await _getAccessToken();
  final url = Uri.parse('$baseUrl/diagnose/auto');

  var request = http.MultipartRequest('POST', url);
  request.headers['Authorization'] = 'Bearer $accessToken';

  // MIME Type을 명시적으로 'image/jpeg'로 지정
  request.files.add(
    await http.MultipartFile.fromPath(
      'image', // 서버가 요구하는 필드 이름
      imageFile.path,
      // MIME Type 명시 (JPG 파일 기준)
      contentType: MediaType('image', 'jpeg'),
    ),
  );

  // plantId 필드 추가
  request.fields['plant_id'] = plantId.toString();

  final streamedResponse = await request.send();
  final response = await http.Response.fromStream(streamedResponse);
  final responseBody = utf8.decode(response.bodyBytes);

  if (response.statusCode == 200 || response.statusCode == 201) {
    // NOTE: DiagnosisResponse는 diagnosis_model.dart에 정의되어 있어야 합니다.
    return DiagnosisResponse.fromJson(jsonDecode(responseBody));
  } else {
    // 진단 실패 시 서버 응답 본문을 포함하여 에러 메시지 출력
    throw Exception('진단 실패: ${response.statusCode} - $responseBody');
  }
}

// ---------------------- AI 처방전 ----------------------
Future<RemedyAdvice> fetchRemedy(String diseaseKey) async {
  final accessToken = await _getAccessToken();
  final url = Uri.parse('$baseUrl/remedy');

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
    // NOTE: RemedyAdvice는 remedy_model.dart에 정의되어 있어야 합니다.
    return RemedyAdvice.fromJson(jsonDecode(responseBody));
  } else {
    throw Exception('처방전 수신 실패: ${response.statusCode}');
  }
}

Future<Plant> fetchMyPlantDetail(int plantId) async {
  final accessToken = await _getAccessToken();
  final url = Uri.parse('$baseUrl/plants/$plantId');

  final response = await http.get(
    url,
    headers: {'Authorization': 'Bearer $accessToken'},
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return Plant.fromJson(data);
  } else if (response.statusCode == 404) {
    throw Exception('식물을 찾을 수 없거나 권한이 없습니다.');
  } else {
    throw Exception('내 식물 상세 정보 가져오기 실패: ${response.statusCode}');
  }
}

// ---------------------- 성장 일지 ----------------------
// NOTE/PHOTO 자동 구분: log_message만 있으면 NOTE, image_url 있으면 PHOTO
Future<void> createManualDiary({
  required int plantId,
  required String logMessage,
  String? imageUrl,
}) async {
  final accessToken = await _getAccessToken();
  final url = Uri.parse('$baseUrl/diary/$plantId/manual');

  final body = <String, dynamic>{'log_message': logMessage};
  if (imageUrl != null) body['image_url'] = imageUrl;

  final response = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(body),
  );

  // 🚨 원래 상태로 복구: 응답 본문을 디코딩하지 않고 바로 사용 (한글 깨짐 위험은 있음)
  // final responseBody = utf8.decode(response.bodyBytes); // 이 라인이 제거됨

  if (response.statusCode == 201) {
    print('성장일지 저장 성공: ${response.body}'); // 🚨 복구: response.body 사용
  } else {
    // 🚨 복구: response.body 사용
    throw Exception('성장일지 저장 실패: ${response.statusCode} - ${response.body}');
  }
}

// ---------------------- 성장 일지 삭제 ----------------------
Future<void> deleteManualDiary(int diaryId) async {
  final accessToken = await _getAccessToken();
  // 명세: DELETE /diary/{diary_id}/manual
  final url = Uri.parse('$baseUrl/diary/$diaryId/manual');

  final response = await http.delete( // 👈 DELETE 메소드 사용
    url,
    headers: {
      'Authorization': 'Bearer $accessToken',
    },
  );

  // 200 OK 또는 204 No Content 모두 성공으로 처리
  if (response.statusCode == 200 || response.statusCode == 204) {
    print('일지 삭제 성공: $diaryId');
  } else {
    throw Exception('일지 삭제 실패: ${response.statusCode}');
  }
}

// ---------------------- 미디어 업로드 (1단계) ----------------------
// 사진 파일을 서버에 업로드하여 image_url을 받아옵니다.
Future<String> uploadMedia(File imageFile) async {
  final accessToken = await _getAccessToken();
  final url = Uri.parse('$baseUrl/media/upload');

  var request = http.MultipartRequest('POST', url);
  request.headers['Authorization'] = 'Bearer $accessToken';
  request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

  final streamedResponse = await request.send();
  final response = await http.Response.fromStream(streamedResponse);
  final responseBody = utf8.decode(response.bodyBytes);

  if (response.statusCode == 201) {
    final Map<String, dynamic> json = jsonDecode(responseBody);
    return json['image_url']; // 예: "/media/1/orig"
  } else {
    throw Exception('미디어 업로드 실패: ${response.statusCode} - $responseBody');
  }
}

// ---------------------- 진단 요청 (2단계) ----------------------
Future<DiagnosisResponse> diagnosePlantWithImageUrl({
  required int plantId,
  required String imageUrl,
  String promptKey = 'default',
}) async {
  final accessToken = await _getAccessToken();
  final url = Uri.parse('$baseUrl/plants/$plantId/diagnose-llm');

  final response = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'image_url': imageUrl, 'prompt_key': promptKey}),
  );

  final responseBody = utf8.decode(response.bodyBytes);

  if (response.statusCode == 200) {
    return DiagnosisResponse.fromJson(jsonDecode(responseBody));
  } else {
    throw Exception('진단 요청 실패: ${response.statusCode} - $responseBody');
  }
}

// ---------------------- 성장일지 Diary 모델 ----------------------
class DiaryEntry {
  final int id;
  final int plantId;
  final DateTime createdAt;
  final String logType; // DIAGNOSIS, WATERING, BIRTHDAY, NOTE, PHOTO
  final String logMessage;
  final String? imageUrl;
  final int? referenceId;

  DiaryEntry({
    required this.id,
    required this.plantId,
    required this.createdAt,
    required this.logType,
    required this.logMessage,
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
      imageUrl: json['image_url'],
      referenceId: json['reference_id'],
    );
  }
}

// ---------------------- 성장일지 목록 조회 ----------------------
Future<List<DiaryEntry>> fetchDiary(int plantId) async {
  final accessToken = await _getAccessToken();
  final url = Uri.parse('$baseUrl/diary/$plantId');

  final response = await http.get(
    url,
    headers: {'Authorization': 'Bearer $accessToken'},
  );

  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((json) => DiaryEntry.fromJson(json)).toList();
  } else {
    throw Exception('일지 목록 가져오기 실패: ${response.statusCode}');
  }
}
