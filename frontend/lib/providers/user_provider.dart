import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider with ChangeNotifier {
  int? _userId;
  String? _email;
  String? _nickname;
  String? _token;

  int? get userId => _userId;
  String? get email => _email;
  String? get nickname => _nickname;
  String? get token => _token;
  bool get isLoggedIn => _userId != null && _token != null;

  /// ✅ 로그인 시 사용자 저장 + 로컬 저장
  Future<void> setUser({
    required int userId,
    required String email,
    required String nickname,
    required String token,
  }) async {
    _userId = userId;
    _email = email;
    _nickname = nickname;
    _token = token;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', userId);
    await prefs.setString('email', email);
    await prefs.setString('nickname', nickname);
    await prefs.setString('token', token);

    debugPrint('📦 User 저장됨 → id:$userId, email:$email');
  }

  /// ✅ 앱 시작 시 자동 로그인 복원
  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('user_id');
    final email = prefs.getString('email');
    final nick = prefs.getString('nickname');
    final token = prefs.getString('token');

    if (id != null && token != null) {
      _userId = id;
      _email = email;
      _nickname = nick;
      _token = token;
      notifyListeners();
      debugPrint('🔁 자동 로그인 복원 성공 → id:$id');
    } else {
      debugPrint('🚫 자동 로그인 복원 실패 (저장된 정보 없음)');
    }
  }

  /// ✅ 로그아웃 (메모리 + 로컬 저장소 초기화)
  Future<void> clearUser() async {
    _userId = null;
    _email = null;
    _nickname = null;
    _token = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('email');
    await prefs.remove('nickname');
    await prefs.remove('token');

    debugPrint('👋 로그아웃 완료 (SharedPreferences 초기화)');
  }
}
