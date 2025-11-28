// lib/model/api.dart (최종 수정본)

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
import 'package:dio/dio.dart';
import 'media_model.dart'; // 👈 [신규] MediaUploadResponse 모델 import

// ---------------------- 설정 및 기본 인스턴스 ----------------------
final Dio _dio = Dio();
// 🟢 [수정] baseUrl 공용으로 선언
const String baseUrl =
    "http://3.38.142.173:8000";// 🚨 현재 사용 중인 Base URL
final FlutterSecureStorage _storage = const FlutterSecureStorage();

// 🟢 [통합] 모든 API 호출에 사용할 인증 헤더를 구성하는 함수
Future<Map<String, String>> _getAuthHeaders({bool isJson = true}) async {
  final accessToken = await _storage.read(key: 'accessToken');

  if (accessToken == null) {
    throw Exception('로그인 토큰을 찾을 수 없습니다. 다시 로그인해주세요.');
  }

  final headers = <String, String>{'Authorization': 'Bearer $accessToken'};

  if (isJson) {
    headers['Content-Type'] = 'application/json';
  }

  return headers;
}
// ------------------------------------------------------------------

// 🟢 [추가] 현재 사용자의 프로필 정보를 가져오는 함수 (공식 ID 포함)
Future<Map<String, dynamic>> fetchCurrentUserProfile() async {
  final headers = await _getAuthHeaders(isJson: false);
  final url = Uri.parse('$baseUrl/auth/users/me');

  final response = await http.get(url, headers: headers);

  if (response.statusCode == 200) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data;
  } else {
    throw Exception('사용자 프로필 로드 실패: ${response.statusCode}');
  }
}

// ---------------------- 백과사전 ----------------------
Future<List<Plant>> fetchPlantList({
  String? query,
  String? sortBy,
  String order = 'asc',
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
// 🟢 [수정] _getAuthHeaders로 인증 로직 변경
Future<List<Plant>> fetchMyPlants() async {
  final url = Uri.parse('$baseUrl/plants');

  final response = await http.get(
    url,
    headers: await _getAuthHeaders(isJson: false),
  );

  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((json) => Plant.fromJson(json)).toList();
  } else {
    throw Exception('내 식물 목록 가져오기 실패: ${response.statusCode}');
  }
}

// ---------------------- 내 식물 등록 ----------------------
// 🟢 [수정] _getAuthHeaders로 인증 로직 변경
Future<Plant> savePlantToServer({
  required String nickname,
  required int plantMasterId,
}) async {
  final url = Uri.parse('$baseUrl/plants');

  final response = await http.post(
    url,
    headers: await _getAuthHeaders(),
    body: jsonEncode({'name': nickname, 'plant_master_id': plantMasterId}),
  );

  if (response.statusCode == 201) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return Plant.fromJson(data);
  } else if (response.statusCode == 422) {
    throw Exception('검증 오류: ${response.body}');
  } else {
    throw Exception('식물 등록 실패: ${response.statusCode}');
  }
}

// ---------------------- 내 식물 삭제 ----------------------
// 🟢 [수정] _getAuthHeaders로 인증 로직 변경
Future<void> deleteMyPlant(int plantId) async {
  final url = Uri.parse('$baseUrl/plants/$plantId');

  final response = await http.delete(url, headers: await _getAuthHeaders());

  if (response.statusCode == 200 || response.statusCode == 204) {
    print('식물 삭제 성공: $plantId');
  } else if (response.statusCode == 404) {
    throw Exception('식물을 찾을 수 없거나 권한이 없습니다.');
  } else {
    throw Exception('식물 삭제 실패: ${response.statusCode}');
  }
}

// ---------------------- 푸시 알림 ----------------------
// 🟢 [수정] accessToken 인자 제거 및 _getAuthHeaders 적용
Future<void> registerPushToken(String fcmToken) async {
  final url = Uri.parse('$baseUrl/auth/users/me/push-token');
  final response = await http.post(
    url,
    headers: await _getAuthHeaders(),
    body: jsonEncode({'push_token': fcmToken}),
  );
  if (response.statusCode != 200 && response.statusCode != 201) {
    throw Exception('푸시 토큰 등록 실패: ${response.statusCode}');
  }
}

// 🟢 [수정] accessToken 인자 제거 및 _getAuthHeaders 적용
Future<void> markAsWatered(int plantId) async {
  final url = Uri.parse('$baseUrl/plants/$plantId/water');
  final response = await http.post(
    url,
    headers: await _getAuthHeaders(isJson: false),
  );
  if (response.statusCode != 200 && response.statusCode != 204) {
    throw Exception('물주기 완료 처리 실패: ${response.statusCode}');
  }
}

// 🟢 [수정] accessToken 인자 제거 및 _getAuthHeaders 적용
Future<void> snoozeWatering(int plantId) async {
  final url = Uri.parse('$baseUrl/plants/$plantId/snooze');
  final response = await http.post(
    url,
    headers: await _getAuthHeaders(isJson: false),
  );
  if (response.statusCode != 200 && response.statusCode != 204) {
    throw Exception('물주기 하루 미루기 실패: ${response.statusCode}');
  }
}

// ---------------------- 회원 탈퇴 ----------------------
// 🟢 [수정] accessToken 인자 제거 및 _getAuthHeaders 적용
Future<void> deleteAccount() async {
  final url = Uri.parse('$baseUrl/auth/users/me');
  final response = await http.delete(
    url,
    headers: await _getAuthHeaders(isJson: false),
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

// 🟢 [수정] _getAuthHeaders 적용 및 Multipart Request 헤더 설정 방식 변경
Future<ChatSendResponse> sendChatMessage({
  required String message,
  int? threadId,
}) async {
  final url = Uri.parse('$baseUrl/chat/send');

  var request = http.MultipartRequest('POST', url);

  // ⭐️ _getAuthHeaders 적용 (Multipart Request는 isJson: false)
  final headers = await _getAuthHeaders(isJson: false);
  request.headers.addAll(headers);

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
    return ChatSendResponse.fromJson(jsonDecode(responseBody));
  } else {
    throw Exception('챗봇 메시지 전송 실패: ${response.statusCode} - $responseBody');
  }
}

// 🟢 [수정] _getAuthHeaders 적용
Future<List<ChatMessage>> getChatHistory(int threadId) async {
  final url = Uri.parse('$baseUrl/chat/threads/$threadId/messages');
  final response = await http.get(
    url,
    headers: await _getAuthHeaders(isJson: false),
  );
  if (response.statusCode == 200) {
    final String responseBody = utf8.decode(response.bodyBytes);
    final List<dynamic> jsonList = jsonDecode(responseBody);
    return jsonList.map((json) => ChatMessage.fromJson(json)).toList();
  } else {
    throw Exception('대화 기록 불러오기 실패: ${response.statusCode}');
  }
}

// 🟢 [수정] _getAuthHeaders 적용
Future<List<ThreadInfo>> fetchChatThreads() async {
  final url = Uri.parse('$baseUrl/chat/threads');

  final response = await http.get(
    url,
    headers: await _getAuthHeaders(isJson: false),
  );

  if (response.statusCode == 200) {
    final String responseBody = utf8.decode(response.bodyBytes);
    final List<dynamic> jsonList = jsonDecode(responseBody);
    return jsonList.map((json) => ThreadInfo.fromJson(json)).toList();
  } else {
    throw Exception('대화방 목록 불러오기 실패: ${response.statusCode}');
  }
}

// 🟢 [신규 추가] 챗봇 대화방(스레드) 삭제 (DELETE /chat/threads/{id})
Future<bool> deleteChatThread(int threadId) async {
  try {
    final response = await _dio.delete(
      '$baseUrl/chat/threads/$threadId', // 🟢 baseUrl 사용
      options: Options(headers: await _getAuthHeaders(isJson: false)),
    );

    // 🟢 204 No Content (성공)
    return response.statusCode == 204 || response.statusCode == 200;
  } on DioError catch (e) {
    print('Error deleting chat thread: $e');
    // 404 (찾을 수 없음) 또는 기타 오류
    return false;
  }
}

// ---------------------- AI 진단 ----------------------

// 🟢 [수정 - 1단계] 미디어 업로드 API (파일 -> URL 반환)
Future<MediaUploadResponse> uploadMedia(File imageFile) async {
  final url = Uri.parse('$baseUrl/media/upload'); // 👈 [신규] 업로드 API 주소

  var request = http.MultipartRequest('POST', url);

  // ⭐️ _getAuthHeaders 적용 (Multipart Request는 isJson: false)
  final headers = await _getAuthHeaders(isJson: false);
  request.headers.addAll(headers);

  request.files.add(
    await http.MultipartFile.fromPath(
      'image',
      imageFile.path,
      // MIME Type 명시 (JPG 파일 기준)
      contentType: MediaType('image', 'jpeg'),
    ),
  );

  print('Requesting POST: $url (Uploading image)');

  try {
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final responseBody = utf8.decode(response.bodyBytes);

    if (response.statusCode == 201) { // 201 Created
      print('이미지 업로드 성공: $responseBody');
      // 👈 [신규] MediaUploadResponse 모델로 파싱
      return MediaUploadResponse.fromJson(jsonDecode(responseBody));
    } else {
      print('이미지 업로드 실패: ${response.statusCode}, $responseBody');
      throw Exception('이미지 업로드 실패: ${response.statusCode}');
    }
  } catch (e) {
    print('이미지 업로드 중 오류 발생: $e');
    throw Exception('이미지 업로드 중 오류 발생: $e');
  }
}

// 🟢 [수정 - 2단계 통합] AI 진단 API (파일 기반 -> URL 기반으로 변경 및 통합)
// 기존 diagnosePlant(File, int) 함수와 diagnosePlantWithImageUrl(int, String, String)을 대체함
Future<DiagnosisResponse> diagnosePlant(int plantId, String imageUrl) async {
  // 👈 [수정] API 주소 변경
  final url = Uri.parse('$baseUrl/plants/$plantId/diagnose-llm');

  print('Requesting POST: $url (Requesting diagnosis)');

  try {
    final response = await http.post(
      url,
      headers: await _getAuthHeaders(), // 👈 [수정] JSON 헤더 사용
      // 👈 [수정] JSON Body 전송
      body: jsonEncode({
        'image_url': imageUrl,
        'prompt_key': 'default'
      }),
    );

    final responseBody = utf8.decode(response.bodyBytes);

    if (response.statusCode == 200) {
      print('진단 성공: $responseBody');
      return DiagnosisResponse.fromJson(jsonDecode(responseBody));
    } else {
      print('진단 실패: ${response.statusCode}, $responseBody');
      throw Exception('진단 실패: ${response.statusCode}');
    }
  } catch (e) {
    print('진단 요청 중 오류 발생: $e');
    throw Exception('진단 요청 중 오류 발생: $e');
  }
}

// ---------------------- AI 처방전 ----------------------
// 🟢 [수정] _getAuthHeaders 적용
Future<RemedyAdvice> fetchRemedy(String diseaseKey) async {
  final url = Uri.parse('$baseUrl/remedy');

  final response = await http.post(
    url,
    headers: await _getAuthHeaders(),
    body: jsonEncode({'disease_key': diseaseKey}),
  );

  final responseBody = utf8.decode(response.bodyBytes);
  if (response.statusCode == 200) {
    return RemedyAdvice.fromJson(jsonDecode(responseBody));
  } else {
    throw Exception('처방전 수신 실패: ${response.statusCode}');
  }
}

// 🟢 [수정] _getAuthHeaders 적용
Future<Plant> fetchMyPlantDetail(int plantId) async {
  final url = Uri.parse('$baseUrl/plants/$plantId');

  final response = await http.get(
    url,
    headers: await _getAuthHeaders(isJson: false),
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
// 🟢 [수정] title, logType 파라미터를 받도록 함수 정의 변경
Future<void> createManualDiary({
  required int plantId,
  String? title, // 🟢 [추가] diary_model.dart와 동기화
  String? logMessage, // 🟢 [수정] 필수가 아닐 수 있으므로 nullable로 변경
  String? imageUrl,
  String logType = 'NOTE', // 🟢 [추가] 기본값을 'NOTE'로 설정
}) async {
  final url = Uri.parse('$baseUrl/diary/$plantId/manual');

  final body = <String, dynamic>{
    'title': title, // 🟢 [추가] body에 title 포함
    'log_message': logMessage ?? '', // 🟢 [수정] null일 경우 빈 문자열 전송
    'log_type': logType, // 🟢 [추가] body에 logType 포함
  };

  // 이미지가 있으면 body에 추가
  if (imageUrl != null) body['image_url'] = imageUrl;

  final response = await http.post(
    url,
    headers: await _getAuthHeaders(),
    body: jsonEncode(body),
  );

  if (response.statusCode == 201) {
    print('성장일지 저장 성공: ${response.body}');
  } else {
    throw Exception('성장일지 저장 실패: ${response.statusCode} - ${response.body}');
  }
}

// ---------------------- 진단 요청 (2단계) ----------------------
// ❌ [삭제] diagnosePlant 함수로 통합되었음
/*
Future<DiagnosisResponse> diagnosePlantWithImageUrl({
  required int plantId,
  required String imageUrl,
  String promptKey = 'default',
}) async {
  final url = Uri.parse('$baseUrl/plants/$plantId/diagnose-llm');

  final response = await http.post(
    url,
    headers: await _getAuthHeaders(),
    body: jsonEncode({'image_url': imageUrl, 'prompt_key': promptKey}),
  );

  final responseBody = utf8.decode(response.bodyBytes);

  if (response.statusCode == 200) {
    return DiagnosisResponse.fromJson(jsonDecode(responseBody));
  } else {
    throw Exception('진단 요청 실패: ${response.statusCode} - $responseBody');
  }
}
*/

// ---------------------- 성장일지 Diary 모델 ----------------------
class DiaryEntry {
  final int id;
  final int plantId;
  final DateTime createdAt;
  final String logType; // DIAGNOSIS, WATERING, BIRTHDAY, NOTE, PHOTO
  final String logMessage;
  final String? title;
  final String? imageUrl;
  final int? referenceId;

  DiaryEntry({
    required this.id,
    required this.plantId,
    required this.createdAt,
    required this.logType,
    required this.logMessage,
    this.title,
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
      title: json['title'],
      imageUrl: json['image_url'],
      referenceId: json['reference_id'],
    );
  }
}

// ---------------------- 성장일지 목록 조회 ----------------------
// 🟢 [수정] _getAuthHeaders 적용
Future<List<DiaryEntry>> fetchDiary(int plantId) async {
  final url = Uri.parse('$baseUrl/diary/$plantId');

  final response = await http.get(
    url,
    headers: await _getAuthHeaders(isJson: false),
  );

  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((json) => DiaryEntry.fromJson(json)).toList();
  } else {
    throw Exception('일지 목록 가져오기 실패: ${response.statusCode}');
  }
}

// ---------------------- 식물 추천 API (Dio 기반) ----------------------
// 🟢 [추가] recommend.dart에서 사용하는 public 함수 (Dio를 내부에서 사용)
Future<Response> sendRecommendationRequest(
    Map<String, dynamic> requestData,
    ) async {
  try {
    // _dio 및 baseUrl, _getAuthHeaders()는 api.dart 내부에 정의되어 있으므로 직접 사용 가능
    final response = await _dio.post(
      '$baseUrl/recommendations/survey', // 🟢 baseUrl 사용
      data: requestData,
      options: Options(headers: await _getAuthHeaders()),
    );
    return response;
  } on DioError {
    rethrow;
  }
}

// --- Community API (Dio 사용) ---

// 1. (GET) 전체 게시글 목록 조회
Future<List<Map<String, dynamic>>?> getCommunityPosts() async {
  try {
    final response = await _dio.get(
      '$baseUrl/community/posts/', // 🟢 baseUrl 사용
      options: Options(headers: await _getAuthHeaders(isJson: false)),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(response.data);
    }
    return null;
  } on DioError catch (e) {
    print('Error getting community posts: $e');
    return null;
  }
}

// 2. (POST) 새 게시글 작성
Future<Map<String, dynamic>?> createCommunityPost(
    String title,
    String content,
    ) async {
  try {
    final response = await _dio.post(
      '$baseUrl/community/posts/', // 🟢 baseUrl 사용
      data: {'title': title, 'content': content},
      options: Options(headers: await _getAuthHeaders()),
    );
    if (response.statusCode == 201) {
      return response.data;
    }
    return null;
  } on DioError catch (e) {
    print('Error creating post: $e');
    return null;
  }
}

// 3. (GET) 특정 게시글 상세 조회 (댓글 포함)
Future<Map<String, dynamic>?> getCommunityPostDetail(int postId) async {
  try {
    final response = await _dio.get(
      '$baseUrl/community/posts/$postId', // 🟢 baseUrl 사용
      options: Options(headers: await _getAuthHeaders(isJson: false)),
    );
    if (response.statusCode == 200) {
      return response.data;
    }
    return null;
  } on DioError catch (e) {
    print('Error getting post detail: $e');
    return null;
  }
}

// 4. (PUT) 게시글 수정
Future<Map<String, dynamic>?> updateCommunityPost(
    int postId,
    String title,
    String content,
    ) async {
  try {
    final response = await _dio.put(
      '$baseUrl/community/posts/$postId', // 🟢 baseUrl 사용
      data: {'title': title, 'content': content},
      options: Options(headers: await _getAuthHeaders()),
    );
    if (response.statusCode == 200) {
      return response.data;
    }
    return null;
  } on DioError catch (e) {
    print('Error updating post: $e');
    return null;
  }
}

// 5. (DELETE) 게시글 삭제
Future<bool> deleteCommunityPost(int postId) async {
  try {
    final response = await _dio.delete(
      '$baseUrl/community/posts/$postId', // 🟢 baseUrl 사용
      options: Options(headers: await _getAuthHeaders(isJson: false)),
    );
    return response.statusCode == 204;
  } on DioError catch (e) {
    print('Error deleting post: $e');
    return false;
  }
}

// 6. (POST) 댓글 작성
Future<Map<String, dynamic>?> createComment(int postId, String content) async {
  try {
    final response = await _dio.post(
      '$baseUrl/community/posts/$postId/comments/', // 🟢 baseUrl 사용
      data: {'content': content},
      options: Options(headers: await _getAuthHeaders()),
    );
    if (response.statusCode == 201) {
      return response.data;
    }
    return null;
  } on DioError catch (e) {
    print('Error creating comment: $e');
    return null;
  }
}

// 7. (PUT) 댓글 수정
Future<Map<String, dynamic>?> updateComment(
    int commentId,
    String content,
    ) async {
  try {
    final response = await _dio.put(
      '$baseUrl/community/comments/$commentId', // 🟢 baseUrl 사용
      data: {'content': content},
      options: Options(headers: await _getAuthHeaders()),
    );
    if (response.statusCode == 200) {
      return response.data;
    }
    return null;
  } on DioError catch (e) {
    print('Error updating comment: $e');
    return null;
  }
}

// 8. (DELETE) 댓글 삭제
Future<bool> deleteComment(int commentId) async {
  try {
    final response = await _dio.delete(
      '$baseUrl/community/comments/$commentId', // 🟢 baseUrl 사용
      options: Options(headers: await _getAuthHeaders(isJson: false)),
    );
    return response.statusCode == 204;
  } on DioError catch (e) {
    print('Error deleting comment: $e');
    return false;
  }
}