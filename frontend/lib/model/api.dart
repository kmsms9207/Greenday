import 'dart:convert';
import 'package:http/http.dart' as http;
import 'plant.dart';

Future<List<Plant>> fetchPlantList() async {
  final response = await http.get(Uri.parse('URL 입력!!'));

  if (response.statusCode == 200) {
    final List<dynamic> jsonList = jsonDecode(response.body);
    return jsonList.map((json) => Plant.fromJson(json)).toList();
  } else {
    throw Exception('API 호출 실패: ${response.statusCode}');
  }
}

Future<Plant> fetchPlantDetail(int id) async {
  final response = await http.get(Uri.parse('URL 입력!!/$id'));
  if (response.statusCode == 200) {
    return Plant.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('API 호출 실패: ${response.statusCode}');
  }
}