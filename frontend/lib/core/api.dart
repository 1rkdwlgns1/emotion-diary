// lib/core/api.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// --- 서버 URL (환경에 맞게 수정)
/// 에뮬레이터: http://10.0.2.2:5001
/// 실기기: http://<PC_IP>:5001
/*const String kBaseUrl = 'http://10.0.2.2:5001';*/
const String kBaseUrl = 'http://10.0.2.2:3000';
const String kUserId = 'anon';

/// 분석 결과 모델
class AnalysisItem {
  final int id;
  final String type;
  final String userId;
  final String? s3Key;
  final Map<String, dynamic> emotion;
  final String? transcript;
  final DateTime createdAt;

  AnalysisItem({
    required this.id,
    required this.type,
    required this.userId,
    this.s3Key,
    required this.emotion,
    this.transcript,
    required this.createdAt,
  });

  factory AnalysisItem.fromJson(Map<String, dynamic> j) => AnalysisItem(
    id: j['id'] as int,
    type: j['type'] as String,
    userId: j['user_id'] ?? 'anon',
    s3Key: j['s3_key'],
    emotion: (j['emotion'] is String)
        ? jsonDecode(j['emotion'])
        : Map<String, dynamic>.from(j['emotion'] ?? {}),
    transcript: j['transcript'],
    createdAt: DateTime.parse(j['created_at'].toString()),
  );
}

/// 서버 통신 API
class AnalysisApi {
  /// 파일 업로드 + 분석
  static Future<Map<String, dynamic>> uploadFile(File file) async {
    final uri = Uri.parse('$kBaseUrl/analysis/file');
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

  /// 하루 조회
  static Future<List<AnalysisItem>> fetchDay(String date) async {
    final url = Uri.parse('$kBaseUrl/results/day?date=$date&user_id=$kUserId');
    final r = await http.get(url);
    if (r.statusCode != 200) throw Exception(r.body);
    final list = jsonDecode(r.body) as List;
    return list.map((e) => AnalysisItem.fromJson(e)).toList();
  }

  /// 기간 조회 (주간)
  static Future<List<AnalysisItem>> fetchRange(String start, String end) async {
    final url = Uri.parse(
      '$kBaseUrl/results/range?start=$start&end=$end&user_id=$kUserId',
    );
    final r = await http.get(url);
    if (r.statusCode != 200) throw Exception(r.body);
    final list = jsonDecode(r.body) as List;
    return list.map((e) => AnalysisItem.fromJson(e)).toList();
  }
}
