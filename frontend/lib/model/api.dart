import 'dart:convert';
import 'package:http/http.dart' as http;
import 'plant.dart';

// 1. 사용자님의 최신 ngrok 주소를 반영합니다.
const String baseUrl = "https://6860a10b6227.ngrok-free.app";

// --- 백과사전 관련 함수들 ---
Future<List<Plant>> fetchPlantList({String? query}) async {
  // TODO: 인증 토큰 추가
  // const String accessToken = 'YOUR_ACCESS_TOKEN';

  String url = '$baseUrl/encyclopedia/';
  // 2. 검색어가 있으면 URL에 ?search= 파라미터를 추가 (서버 검색)
  if (query != null && query.isNotEmpty) {
    // URL 인코딩 추가: 검색어에 한글이나 특수문자가 포함될 경우를 대비
    final encodedQuery = Uri.encodeComponent(query);
    url += '?search=$encodedQuery';
  }

  print('Requesting URL: $url'); // 디버깅용 로그

  final response = await http.get(
    Uri.parse(url),
    // headers: {'Authorization': 'Bearer $accessToken'},
  );

  if (response.statusCode == 200) {
    final String responseBody = utf8.decode(response.bodyBytes);
    final List<dynamic> jsonList = jsonDecode(responseBody);
    return jsonList.map((json) => Plant.fromJson(json)).toList();
  } else {
    print('API 호출 실패 응답: ${response.body}'); // 실패 시 응답 내용 확인
    throw Exception('API 호출 실패: ${response.statusCode}');
  }
}

Future<Plant> fetchPlantDetail(int id) async {
  print('Requesting URL: $baseUrl/encyclopedia/$id'); // 디버깅용 로그
  final response = await http.get(Uri.parse('$baseUrl/encyclopedia/$id'));
  if (response.statusCode == 200) {
    final String responseBody = utf8.decode(response.bodyBytes);
    return Plant.fromJson(jsonDecode(responseBody));
  } else {
    print('API 호출 실패 응답: ${response.body}'); // 실패 시 응답 내용 확인
    throw Exception('API 호출 실패: ${response.statusCode}');
  }
}

Future<List<String>> fetchPlantSpecies(String query) async {
  String url = '$baseUrl/encyclopedia/'; // 기본 URL
  if (query.isNotEmpty) {
    final encodedQuery = Uri.encodeComponent(query);
    url += '?search=$encodedQuery'; // 검색어가 있으면 추가
  }
  print('Requesting URL: $url'); // 디버깅용 로그

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final String responseBody = utf8.decode(response.bodyBytes);
    final List<dynamic> jsonList = jsonDecode(responseBody);
    // 서버에서 필터링된 결과의 이름만 추출
    return jsonList.map((json) => json['name_ko'].toString()).toList();
  } else {
    print('API 호출 실패 응답: ${response.body}'); // 실패 시 응답 내용 확인
    throw Exception('API 호출 실패: ${response.statusCode}');
  }
}

// --- 푸시 알림 관련 함수들 ---

// A. FCM 푸시 토큰을 서버에 등록하는 함수
Future<void> registerPushToken(String fcmToken) async {
  // TODO: 로그인 성공 시 저장해 둔 실제 accessToken으로 교체해야 합니다.
  const String accessToken = 'YOUR_ACCESS_TOKEN';

  final url = Uri.parse('$baseUrl/auth/users/me/push-token');
  print('Registering push token to: $url'); // 디버깅용 로그

  try {
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json', // 요청 본문이 JSON임을 명시
      },
      body: jsonEncode({
        // 데이터를 JSON 형식으로 변환하여 전송
        'push_token': fcmToken,
      }),
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

// B. "물 줬어요" API 호출 함수
Future<void> markAsWatered(int plantId) async {
  // TODO: 로그인 성공 시 저장해 둔 실제 accessToken으로 교체해야 합니다.
  const String accessToken = 'YOUR_ACCESS_TOKEN';
  final url = Uri.parse('$baseUrl/plants/$plantId/water');
  print('Marking as watered: $url'); // 디버깅용 로그

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

// C. "하루 미루기" API 호출 함수
Future<void> snoozeWatering(int plantId) async {
  // TODO: 로그인 성공 시 저장해 둔 실제 accessToken으로 교체해야 합니다.
  const String accessToken = 'YOUR_ACCESS_TOKEN';
  final url = Uri.parse('$baseUrl/plants/$plantId/snooze');
  print('Snoozing watering: $url'); // 디버깅용 로그

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
