import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

// 감정 분석 관련 API
class AnalysisApi {
  // 파일 업로드 + 분석
  static Future<Map<String, dynamic>> uploadFile(File file) async {
    // Node 서버로 전송 (3000 포트)
    final uri = Uri.parse('$kBaseUrl/analysis/file'); // or /analysis/upload
    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', file.path))
      ..fields['user_id'] = kUserId;

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  // 하루 조회 (Node → DB)
  static Future<Map<String, dynamic>> fetchDay(String date) async {
    final url = Uri.parse('$kBaseUrl/results/day?date=$date&user_id=$kUserId');
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // 주간 조회 (Node → Flask 요약)
  static Future<Map<String, dynamic>> fetchWeek(
    String start,
    String end,
  ) async {
    final url = Uri.parse(
      '$kBaseUrl/results/range?start=$start&end=$end&user_id=$kUserId',
    );
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
