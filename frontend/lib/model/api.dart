import 'dart:convert';
import 'dart:io'; // 1. 파일(File) 객체 사용을 위해 import
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'plant.dart';
import 'chat_model.dart';
import 'diagnosis_model.dart'; // 2. 진단 모델 import
import 'remedy_model.dart'; // 3. 처방전 모델 import

// 4. 사용자님의 최신 ngrok 주소를 반영합니다.
const String baseUrl = "https://11832cd783df.ngrok-free.app";
final _storage = const FlutterSecureStorage();

Future<String> _getAccessToken() async {
  final accessToken = await _storage.read(key: 'accessToken');
  if (accessToken == null) {
    throw Exception('로그인 토큰을 찾을 수 없습니다. 다시 로그인해주세요.');
  }
  return accessToken;
}

// --- 백과사전 관련 함수들 ---
Future<List<Plant>> fetchPlantList({String? query}) async {
  String url = '$baseUrl/encyclopedia/';
  if (query != null && query.isNotEmpty) {
    final encodedQuery = Uri.encodeComponent(query);
    url += '?search=$encodedQuery';
  }
  print('Requesting URL: $url');
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final String responseBody = utf8.decode(response.bodyBytes);
    final List<dynamic> jsonList = jsonDecode(responseBody);
    return jsonList.map((json) => Plant.fromJson(json)).toList();
  } else {
    print('API 호출 실패 응답: ${response.body}');
    throw Exception('API 호출 실패: ${response.statusCode}');
  }
}

Future<Plant> fetchPlantDetail(int id) async {
  print('Requesting URL: $baseUrl/encyclopedia/$id');
  final response = await http.get(Uri.parse('$baseUrl/encyclopedia/$id'));
  if (response.statusCode == 200) {
    final String responseBody = utf8.decode(response.bodyBytes);
    return Plant.fromJson(jsonDecode(responseBody));
  } else {
    print('API 호출 실패 응답: ${response.body}');
    throw Exception('API 호출 실패: ${response.statusCode}');
  }
}

Future<List<String>> fetchPlantSpecies(String query) async {
  String url = '$baseUrl/encyclopedia/';
  if (query.isNotEmpty) {
    final encodedQuery = Uri.encodeComponent(query);
    url += '?search=$encodedQuery';
  }
  print('Requesting URL: $url');
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final String responseBody = utf8.decode(response.bodyBytes);
    final List<dynamic> jsonList = jsonDecode(responseBody);
    return jsonList.map((json) => json['name_ko'].toString()).toList();
  } else {
    print('API 호출 실패 응답: ${response.body}');
    throw Exception('API 호출 실패: ${response.statusCode}');
  }
}

// --- 서버에 저장된 내 식물 목록 가져오기 ---
Future<List<Plant>> fetchMyPlants() async {
  final accessToken = await _getAccessToken();
  final url = Uri.parse('$baseUrl/plants');
  try {
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
  } catch (e) {
    throw Exception('내 식물 목록 요청 중 오류 발생: $e');
  }
}

// --- 푸시 알림 관련 함수들 ---
Future<void> registerPushToken(String fcmToken, String accessToken) async {
  final url = Uri.parse('$baseUrl/auth/users/me/push-token');
  print('Registering push token to: $url');
  try {
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'push_token': fcmToken}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      print('푸시 토큰 등록 성공');
    } else {
      print('푸시 토큰 등록 실패: ${response.statusCode}, ${response.body}');
      throw Exception('푸시 토큰 등록 실패: ${response.statusCode}');
    }
  } catch (e) {
    print('푸시 토큰 등록 중 네트워크 오류 발생: $e');
    throw Exception('푸시 토큰 등록 중 오류 발생: $e');
  }
}

Future<void> markAsWatered(int plantId, String accessToken) async {
  final url = Uri.parse('$baseUrl/plants/$plantId/water');
  print('Marking as watered: $url');
  try {
    final response = await http.post(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 200) {
      print('물주기 완료 처리 성공 (plantId: $plantId)');
    } else {
      print('물주기 완료 처리 실패: ${response.statusCode}, ${response.body}');
      throw Exception('물주기 완료 처리 실패: ${response.statusCode}');
    }
  } catch (e) {
    print('물주기 완료 처리 중 네트워크 오류 발생: $e');
    throw Exception('물주기 완료 처리 중 오류 발생: $e');
  }
}

Future<void> snoozeWatering(int plantId, String accessToken) async {
  final url = Uri.parse('$baseUrl/plants/$plantId/snooze');
  print('Snoozing watering: $url');
  try {
    final response = await http.post(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 200) {
      print('물주기 하루 미루기 성공 (plantId: $plantId)');
    } else {
      print('물주기 하루 미루기 실패: ${response.statusCode}, ${response.body}');
      throw Exception('물주기 하루 미루기 실패: ${response.statusCode}');
    }
  } catch (e) {
    print('물주기 하루 미루기 중 네트워크 오류 발생: $e');
    throw Exception('물주기 하루 미루기 중 오류 발생: $e');
  }
}

// --- 회원 탈퇴 함수 ---
Future<Map<String, dynamic>> deleteAccount(String accessToken) async {
  final url = Uri.parse('$baseUrl/auth/users/me');
  print('Requesting DELETE: $url');
  try {
    final response = await http.delete(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 200) {
      print('회원 탈퇴 성공');
      return {'message': '회원 탈퇴가 성공적으로 처리되었습니다.'};
    } else {
      print('회원 탈퇴 실패: ${response.statusCode}, ${response.body}');
      String detail = '회원 탈퇴 실패: ${response.statusCode}';
      try {
        final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
        if (decodedBody is Map && decodedBody.containsKey('detail')) {
          detail = decodedBody['detail'];
        }
      } catch (_) {}
      throw Exception(detail);
    }
  } catch (e) {
    print('회원 탈퇴 중 네트워크 오류 발생: $e');
    throw Exception('회원 탈퇴 중 오류 발생: $e');
  }
}

// --- 새로운 이메일 인증번호 검증 함수 ---
Future<Map<String, dynamic>> verifyEmailCode(String email, String code) async {
  final url = Uri.parse('$baseUrl/auth/verify-code');
  print('Verifying email code for: $email with code: $code');
  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) {
      print('이메일 인증 성공: ${response.body}');
      return responseBody;
    } else {
      print('이메일 인증 실패: ${response.statusCode}, ${response.body}');
      throw Exception(
        responseBody['detail'] ?? '인증 실패: ${response.statusCode}',
      );
    }
  } catch (e) {
    print('이메일 인증 중 오류 발생: $e');
    throw Exception('이메일 인증 중 오류 발생: $e');
  }
}

// --- 챗봇 관련 함수들 ---
Future<List<ChatMessage>> getChatHistory(int threadId) async {
  final accessToken = await _getAccessToken();
  final url = Uri.parse('$baseUrl/chat/threads/$threadId/messages');
  print('Requesting GET: $url');
  try {
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 200) {
      final String responseBody = utf8.decode(response.bodyBytes);
      final List<dynamic> jsonList = jsonDecode(responseBody);
      return jsonList.map((json) => ChatMessage.fromJson(json)).toList();
    } else {
      print('대화 기록 불러오기 실패: ${response.statusCode}, ${response.body}');
      throw Exception('대화 기록 불러오기 실패: ${response.statusCode}');
    }
  } catch (e) {
    print('대화 기록 요청 중 오류 발생: $e');
    throw Exception('대화 기록 요청 중 오류 발생: $e');
  }
}

Future<ChatSendResponse> sendChatMessage({
  required String message,
  int? threadId,
  String? imageUrl,
}) async {
  final accessToken = await _getAccessToken();
  final url = Uri.parse('$baseUrl/chat/send');
  print('Requesting POST: $url');
  Map<String, dynamic> requestBody = {'message': message};
  if (threadId != null) {
    requestBody['thread_id'] = threadId;
  }
  if (imageUrl != null) {
    requestBody['image_url'] = imageUrl;
  }
  try {
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
      final jsonResponse = jsonDecode(responseBody);
      return ChatSendResponse.fromJson(jsonResponse);
    } else {
      print('챗봇 메시지 전송 실패: ${response.statusCode}, ${response.body}');
      throw Exception('챗봇 메시지 전송 실패: ${response.statusCode}');
    }
  } catch (e) {
    print('챗봇 메시지 전송 중 오류 발생: $e');
    throw Exception('챗봇 메시지 전송 중 오류 발생: $e');
  }
}

// --- AI 진단 및 처방 관련 함수들 (새로 추가) ---

// 1. AI 식물 진단 API (POST /diagnose/auto)
Future<DiagnosisResponse> diagnosePlant(File imageFile) async {
  final accessToken = await _getAccessToken();
  final url = Uri.parse('$baseUrl/diagnose/auto');
  print('Requesting POST: $url');

  // 1-1. Multipart 요청 생성
  var request = http.MultipartRequest('POST', url);

  // 1-2. 헤더 추가 (인증)
  request.headers['Authorization'] = 'Bearer $accessToken';

  // 1-3. 이미지 파일 추가
  request.files.add(
    await http.MultipartFile.fromPath(
      'image', // 백엔드에서 요구하는 필드 이름
      imageFile.path,
    ),
  );

  try {
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final responseBody = utf8.decode(response.bodyBytes);

    if (response.statusCode == 200 || response.statusCode == 201) {
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

// 2. 처방전(해결 방법) API (POST /remedy/)
Future<RemedyAdvice> fetchRemedy(String diseaseKey) async {
  final accessToken = await _getAccessToken();
  final url = Uri.parse('$baseUrl/remedy/');
  print('Requesting POST: $url');

  try {
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'disease_key': diseaseKey}),
    );

    if (response.statusCode == 200) {
      final responseBody = utf8.decode(response.bodyBytes);
      print('처방전 수신 성공: $responseBody');
      return RemedyAdvice.fromJson(jsonDecode(responseBody));
    } else {
      print('처방전 수신 실패: ${response.statusCode}, ${response.body}');
      throw Exception('처방전 수신 실패: ${response.statusCode}');
    }
  } catch (e) {
    print('처방전 요청 중 오류 발생: $e');
    throw Exception('처방전 요청 중 오류 발생: $e');
  }
}
