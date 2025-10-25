import 'dart:convert';
import 'package:http/http.dart' as http;
import 'plant.dart';

// 1. 사용자님의 최신 ngrok 주소를 반영합니다.
const String baseUrl = "https://54c80334e045.ngrok-free.app";

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

// --- 푸시 알림 관련 함수들 ---
Future<void> registerPushToken(String fcmToken) async {
  const String accessToken = 'YOUR_ACCESS_TOKEN'; // TODO: 실제 토큰으로 교체
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

Future<void> markAsWatered(int plantId) async {
  const String accessToken = 'YOUR_ACCESS_TOKEN'; // TODO: 실제 토큰으로 교체
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

Future<void> snoozeWatering(int plantId) async {
  const String accessToken = 'YOUR_ACCESS_TOKEN'; // TODO: 실제 토큰으로 교체
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
Future<Map<String, dynamic>> deleteAccount() async {
  const String accessToken = 'YOUR_ACCESS_TOKEN'; // TODO: 실제 토큰으로 교체
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
// 2. 이 함수를 새로 추가했습니다.
Future<Map<String, dynamic>> verifyEmailCode(String email, String code) async {
  final url = Uri.parse('$baseUrl/auth/verify-code');
  print('Verifying email code for: $email with code: $code'); // 디버깅 로그 강화

  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );

    final responseBody = jsonDecode(
      utf8.decode(response.bodyBytes),
    ); // 응답 본문은 항상 디코딩 시도 (UTF-8)

    if (response.statusCode == 200) {
      print('이메일 인증 성공: ${response.body}');
      return responseBody; // 성공 메시지 반환
    } else {
      print('이메일 인증 실패: ${response.statusCode}, ${response.body}');
      // 실패 시, 응답 본문에 있는 detail 메시지를 에러로 던져줌
      throw Exception(
        responseBody['detail'] ?? '인증 실패: ${response.statusCode}',
      );
    }
  } catch (e) {
    print('이메일 인증 중 오류 발생: $e');
    throw Exception('이메일 인증 중 오류 발생: $e');
  }
}
