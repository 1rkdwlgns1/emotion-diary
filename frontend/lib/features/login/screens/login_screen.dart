import 'package:flutter/material.dart';
import 'id_find_screen.dart';
import '../signup/signup_screen.dart';
import 'password_find_screen.dart';
import '../../../../core/user_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main_tab/main_tab_screen.dart';
import '../info/signup_complete_screen.dart';

import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool showPassword = false;

  // 카카오 로그인 함수
  Future<void> _kakaoLogin() async {
    try {
      // 카카오톡 설치 여부 확인
      final bool installed = await kakao.isKakaoTalkInstalled();
      kakao.OAuthToken token;

      try {
        if (installed) {
          token = await kakao.UserApi.instance.loginWithKakaoTalk();
        } else {
          token = await kakao.UserApi.instance.loginWithKakaoAccount();
        }
      } catch (_) {
        // 카카오톡 로그인 실패 → 웹 계정 로그인으로 자동 fallback
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      // 카카오 사용자 정보 가져오기
      final user = await kakao.UserApi.instance.me();

      final kakaoId = user.id?.toString() ?? "";
      final email = user.kakaoAccount?.email ?? "";
      final nickname = user.kakaoAccount?.profile?.nickname ?? "카카오사용자";

      print("카카오 로그인 성공 → 서버 전송");
      print("kakao_id: $kakaoId");
      print("email: $email");
      print("nickname: $nickname");

      // 백엔드로 카카오 로그인 요청
      final res = await UserApi.kakaoLogin(
        kakaoId: kakaoId,
        email: email,
        nickname: nickname,
      );

      print("서버 응답: $res");

      if (res["ok"] == true && res["token"] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("access_token", res["token"]);

        if (!mounted) return;

        // 여기서 신규/기존 분기
        if (res["isNew"] == true) {
          // 신규 카카오 회원 → 기존 회원가입 흐름 동일하게
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SignupCompleteScreen()),
          );
        } else {
          // 기존 카카오 회원 → 바로 메인
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainTabScreen()),
          );
        }

        return;
      }

      // 서버 에러
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("카카오 로그인 실패: ${res['message'] ?? ''}")),
      );
    } catch (e) {
      print("카카오 로그인 오류: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("카카오 로그인 오류: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    const mainGreen = Color(0xFF859A7E);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '마음.zip',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 48),

                // 이메일 입력
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    hintText: '이메일',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 비밀번호 입력
                TextFormField(
                  controller: passwordController,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    hintText: '비밀번호',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 12,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showPassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          showPassword = !showPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 로그인 버튼
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () async {
                      final email = emailController.text.trim();
                      final password = passwordController.text.trim();

                      final res = await UserApi.login(
                        email: email,
                        password: password,
                      );

                      print("로그인 결과: $res");

                      if (res['ok'] == true) {
                        if (res['token'] != null) {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('access_token', res['token']);
                        }

                        if (!mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MainTabScreen(),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('로그인 실패: ${res['message'] ?? ''}'),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      elevation: 0,
                    ),
                    child: const Text('로그인'),
                  ),
                ),
                const SizedBox(height: 12),

                // 아이디/비번찾기/회원가입
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      child: const Text('아이디 찾기'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const IdFindScreen(),
                          ),
                        );
                      },
                    ),
                    Text('|', style: TextStyle(color: Colors.grey[500])),
                    TextButton(
                      child: const Text('비밀번호 찾기'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PasswordFindScreen(),
                          ),
                        );
                      },
                    ),
                    Text('|', style: TextStyle(color: Colors.grey[500])),
                    TextButton(
                      child: const Text('회원가입'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignupScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                /// “또는”
                Row(
                  children: const [
                    Expanded(child: Divider(thickness: 1, color: Colors.grey)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        "또는",
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                    Expanded(child: Divider(thickness: 1, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 12),

                // 카카오 로그인 버튼
                InkWell(
                  onTap: _kakaoLogin,
                  child: CircleAvatar(
                    backgroundColor: Colors.yellow,
                    radius: 20,
                    child: Image.asset(
                      "assets/kakao.png",
                      width: 40,
                      height: 40,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
