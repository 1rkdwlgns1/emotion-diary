import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kBaseUrl = 'http://13.209.65.181:3000';

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
      debugPrint("JSON 파싱 오류: $e");
      return {
        'ok': false,
        'status': res.statusCode,
        'message': 'JSON 파싱 실패',
        'raw': utf8.decode(res.bodyBytes),
      };
    }
  }

  // JWT 인증 헤더
  static Future<Map<String, String>> authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    return {
      'Content-Type': 'application/json; charset=utf-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // 회원가입
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

      return safeJsonDecode(res);
    } catch (e) {
      return {'ok': false, 'message': e.toString()};
    }
  }

  // 이메일 로그인
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

      // JWT 저장
      if (data['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['token']);
      }

      return data;
    } catch (e) {
      return {'ok': false, 'message': e.toString()};
    }
  }

  // 카카오 로그인 API
  static Future<Map<String, dynamic>> kakaoLogin({
    required String kakaoId,
    required String email,
    required String nickname,
  }) async {
    final uri = Uri.parse("$kBaseUrl/users/kakao-login");

    try {
      final res = await http.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({
          "kakao_id": kakaoId,
          "email": email,
          "nickname": nickname,
        }),
      );

      final data = safeJsonDecode(res);

      if (data["ok"] == true && data["token"] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("access_token", data["token"]);
      }

      return data;
    } catch (e) {
      debugPrint("카카오 로그인 오류: $e");
      return {"ok": false, "message": e.toString()};
    }
  }

  // 프로필 업데이트
  static Future<Map<String, dynamic>> updateProfile({
    required String nickname,
    required String gender,
    required int age,
    required String mbti,
  }) async {
    final uri = Uri.parse('$kBaseUrl/users/me');
    final headers = await authHeaders();

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

      return safeJsonDecode(res);
    } catch (e) {
      return {'ok': false, 'message': e.toString()};
    }
  }

  // 관심사 저장
  static Future<Map<String, dynamic>> saveInterests(
    List<String> interests,
  ) async {
    final uri = Uri.parse('$kBaseUrl/users/interests');
    final headers = await authHeaders();

    try {
      final res = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({'interests': interests}),
      );

      return safeJsonDecode(res);
    } catch (e) {
      return {'ok': false, 'message': e.toString()};
    }
  }

  // 로그인 상태 비밀번호 변경 (JWT 필요)
  static Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final uri = Uri.parse('$kBaseUrl/users/change-password');
    final headers = await authHeaders();

    try {
      final res = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        }),
      );

      return safeJsonDecode(res);
    } catch (e) {
      return {'ok': false, 'message': e.toString()};
    }
  }

  // 이메일 기반 비밀번호 재설정 (로그인 필요 없음)
  static Future<Map<String, dynamic>> resetPasswordViaEmail({
    required String email,
    required String newPassword,
  }) async {
    final uri = Uri.parse('$kBaseUrl/users/reset-password');

    try {
      final res = await http.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({'email': email, 'newPassword': newPassword}),
      );

      return safeJsonDecode(res);
    } catch (e) {
      return {'ok': false, 'message': e.toString()};
    }
  }
}
