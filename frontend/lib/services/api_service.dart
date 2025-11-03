import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // 🔗 환경에 따라 자동 분기
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000';
     // ✅ Node 서버 접근용 IP
    return 'http://172.30.75.2:3000';
  }

  static Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
      };

  /// ✅ 안전한 JSON 파싱
  static Map<String, dynamic> safeJsonDecode(http.Response res) {
    try {
      return jsonDecode(utf8.decode(res.bodyBytes))
          as Map<String, dynamic>;
    } catch (_) {
      print('⚠️ JSON 파싱 실패: ${utf8.decode(res.bodyBytes)}');
      return {
        'ok': false,
        'message': '서버 응답이 올바른 JSON 형식이 아닙니다.',
        'raw': utf8.decode(res.bodyBytes),
        'status': res.statusCode,
      };
    }
  }

  /// ✅ 회원가입
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String nickname,
    required String gender,
    required String mbti,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/users/register'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'email': email,
        'password': password,
        'nickname': nickname,
        'gender': gender,
        'mbti': mbti,
      }),
    );
    return safeJsonDecode(res);
  }

  /// ✅ 로그인
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/users/login'),
      headers: _jsonHeaders,
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = safeJsonDecode(res);

    // ✅ 로그인 성공 시 JWT 저장
    if (res.statusCode == 200 &&
        data['ok'] == true &&
        data['token'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      print('✅ JWT 토큰 저장 완료');
    }

    return data;
  }

  /// ✅ 인증 헤더
  static Future<Map<String, String>> authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// ✅ 로그아웃
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    print('🧹 JWT 토큰 삭제 완료');
  }

  /// ✅ 프로필 업데이트
  static Future<Map<String, dynamic>> updateProfile({
    required String nickname,
    required String gender,
    required int age,
    required String mbti,
  }) async {
    final headers = await authHeaders();
    final res = await http.put(
      Uri.parse('$baseUrl/users/me'),
      headers: headers,
      body: jsonEncode({
        'nickname': nickname,
        'gender': gender,
        'age': age,
        'mbti': mbti,
      }),
    );
    print('📡 프로필 응답 코드: ${res.statusCode}');
    return safeJsonDecode(res);
  }

  /// ✅ 관심사 저장
  static Future<Map<String, dynamic>> saveInterests(
    List<String> interests,
  ) async {
    final headers = await authHeaders();
    final res = await http.post(
      Uri.parse('$baseUrl/users/interests'),
      headers: headers,
      body: jsonEncode({'interests': interests}),
    );
    print('📡 관심사 응답 코드: ${res.statusCode}');
    return safeJsonDecode(res);
  }

  /// ✅ 내 정보 조회
  static Future<Map<String, dynamic>> me() async {
    final headers = await authHeaders();
    final res = await http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: headers,
    );
    return safeJsonDecode(res);
  }

  /// ✅ 서버 상태 확인
  static Future<Map<String, dynamic>> ping() async {
    final res = await http.get(Uri.parse('$baseUrl/'));
    return safeJsonDecode(res);
  }
}
