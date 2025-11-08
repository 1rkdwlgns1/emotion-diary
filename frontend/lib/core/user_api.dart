// lib/core/user_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ 에뮬레이터용 서버 주소 (Node.js 서버 실행 중이어야 함)
const String kBaseUrl = 'http://10.0.2.2:3000';

class UserApi {
  // 공통 JSON 헤더
  static Map<String, String> get _jsonHeaders => {
    'Content-Type': 'application/json; charset=utf-8',
  };

  // JSON 파싱 안정화
  static Map<String, dynamic> safeJsonDecode(http.Response res) {
    try {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      debugPrint(
        '⚠️ JSON 파싱 실패 (${res.statusCode}): ${utf8.decode(res.bodyBytes)}',
      );
      return {
        'ok': false,
        'status': res.statusCode,
        'message': 'JSON 파싱 실패',
        'raw': utf8.decode(res.bodyBytes),
      };
    }
  }

  // ✅ 회원가입
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final uri = Uri.parse('$kBaseUrl/users/register');
    try {
      final res = await http.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({
          'email': email,
          'password': password,
          'nickname': nickname,
        }),
      );
      debugPrint('📡 회원가입 응답 코드: ${res.statusCode}');
      debugPrint('📡 회원가입 응답 본문: ${utf8.decode(res.bodyBytes)}');
      return safeJsonDecode(res);
    } catch (e) {
      debugPrint('🚨 회원가입 중 오류: $e');
      return {'ok': false, 'message': e.toString()};
    }
  }

  // ✅ 로그인
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$kBaseUrl/users/login');
    try {
      final res = await http.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = safeJsonDecode(res);

      if (res.statusCode == 200 && data['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['token']);
        debugPrint('✅ JWT 저장 완료');
        return {'ok': true, 'token': data['token']};
      }

      return {'ok': false, 'message': data['message'] ?? '로그인 실패'};
    } catch (e) {
      debugPrint('🚨 로그인 중 오류: $e');
      return {'ok': false, 'message': e.toString()};
    }
  }

  // ✅ 인증 헤더
  static Future<Map<String, String>> authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return {
      'Content-Type': 'application/json; charset=utf-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ✅ 프로필 업데이트
  static Future<Map<String, dynamic>> updateProfile({
    required String nickname,
    required String gender,
    required int age,
    required String mbti,
  }) async {
    final headers = await authHeaders();
    final uri = Uri.parse('$kBaseUrl/users/me');

    try {
      final res = await http.put(
        uri,
        headers: headers,
        body: jsonEncode({
          'nickname': nickname,
          'gender': gender,
          'age': age,
          'mbti': mbti,
        }),
      );

      debugPrint('📡 프로필 업데이트 응답 코드: ${res.statusCode}');
      debugPrint('📡 응답 본문: ${utf8.decode(res.bodyBytes)}');

      return safeJsonDecode(res);
    } catch (e) {
      debugPrint('🚨 프로필 업데이트 오류: $e');
      return {'ok': false, 'message': e.toString()};
    }
  }

  // ✅ 관심사 저장
  static Future<Map<String, dynamic>> saveInterests(
    List<String> interests,
  ) async {
    final headers = await authHeaders();
    final uri = Uri.parse('$kBaseUrl/users/interests');

    try {
      debugPrint('🧩 headers: $headers');
      debugPrint('🧩 payload: ${jsonEncode({'interests': interests})}');
      final res = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({'interests': interests}),
      );
      debugPrint('📡 관심사 저장 응답 코드: ${res.statusCode}');
      debugPrint('📡 응답 본문: ${utf8.decode(res.bodyBytes)}');
      return safeJsonDecode(res);
    } catch (e) {
      debugPrint('🚨 관심사 저장 오류: $e');
      return {'ok': false, 'message': e.toString()};
    }
  }
}
