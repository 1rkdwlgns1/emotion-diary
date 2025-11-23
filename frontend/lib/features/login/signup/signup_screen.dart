//회원가입 스크린
import 'package:flutter/material.dart';
import '../../../../core/user_api.dart';
import '../info/signup_complete_screen.dart';
import '../../main_tab/main_tab_screen.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as Kakao;
import 'package:shared_preferences/shared_preferences.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPwController = TextEditingController();

  bool showPassword = false;
  bool showConfirmPassword = false;
  String? pwError;

  // 약관 체크박스 상태
  bool agreeAll = false;
  bool agreeService = false;
  bool agreePrivacy = false;
  bool agreeAge = false;
  bool agreeMarketing = false;

  // 전체 동의 토글
  void _toggleAll(bool? val) {
    setState(() {
      agreeAll = val ?? false;
      agreeService = agreeAll;
      agreePrivacy = agreeAll;
      agreeAge = agreeAll;
      agreeMarketing = agreeAll;
    });
  }

  // 개별 체크 시 전체 체크 여부 업데이트
  void _updateAllState() {
    setState(() {
      agreeAll = agreeService && agreePrivacy && agreeAge && agreeMarketing;
    });
  }

  // 회원가입
  Future<void> signup() async {
    print('회원가입 버튼 눌림');

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirm = confirmPwController.text.trim();

    // 비밀번호 불일치가 가장 먼저
    if (password != confirm) {
      setState(() => pwError = "비밀번호가 일치하지 않아요!");
      return;
    }

    // pwError 초기화
    setState(() => pwError = null);

    // 필드 비어있는지 확인
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이메일과 비밀번호를 입력하세요.')));
      return;
    }

    // 약관 필수 체크 확인
    if (!agreeService || !agreePrivacy || !agreeAge) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('필수 약관에 모두 동의해주세요.')));
      return;
    }

    // 회원가입 API 요청
    try {
      final res = await UserApi.register(
        email: email,
        password: password,
        nickname: "임시닉네임",
      );

      print('회원가입 결과: $res');

      if (res["ok"] == true) {
        final loginRes = await UserApi.login(email: email, password: password);

        print('자동 로그인 결과: $loginRes');

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SignupCompleteScreen()),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("회원가입 실패: ${res['message']}")));
      }
    } catch (e) {
      print("에러: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("오류 발생: $e")));
    }
  }

  // 카카오 로그인
  Future<void> signupWithKakao() async {
    try {
      final bool installed = await Kakao.isKakaoTalkInstalled();
      Kakao.OAuthToken token;

      try {
        if (installed) {
          token = await Kakao.UserApi.instance.loginWithKakaoTalk();
        } else {
          token = await Kakao.UserApi.instance.loginWithKakaoAccount();
        }
      } catch (_) {
        // fallback
        token = await Kakao.UserApi.instance.loginWithKakaoAccount();
      }

      // 사용자 정보 조회
      final user = await Kakao.UserApi.instance.me();
      final kakaoId = user.id?.toString() ?? "";
      final email = user.kakaoAccount?.email ?? "";
      final nickname = user.kakaoAccount?.profile?.nickname ?? "카카오사용자";

      print("카카오 회원가입 → 서버 전달");
      print("kakao_id: $kakaoId");
      print("email: $email");
      print("nickname: $nickname");

      // 서버 전송
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

        if (res["isNew"] == true) {
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

      // 서버 오류 메시지 출력
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("카카오 회원가입 실패: ${res['message'] ?? ''}")),
      );
    } catch (e) {
      print("카카오 회원가입 오류: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("카카오 로그인 오류: $e")));
    }
  }

  // UI
  @override
  Widget build(BuildContext context) {
    const mainGreen = Color(0xFF859A7E);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                "회원가입",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                "가입하실 이메일과 비밀번호를 입력해 주세요.",
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 26),

              // 이메일
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '이메일 주소를 입력해 주세요.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 16,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 비밀번호
              TextFormField(
                controller: passwordController,
                obscureText: !showPassword,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '영문, 숫자 포함 8~16자로 입력해 주세요.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 16,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      showPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => showPassword = !showPassword),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 비밀번호 확인
              TextFormField(
                controller: confirmPwController,
                obscureText: !showConfirmPassword,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '비밀번호 확인',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 16,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      showConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () => setState(
                      () => showConfirmPassword = !showConfirmPassword,
                    ),
                  ),
                ),
              ),

              // 비밀번호 오류 문구
              if (pwError != null) ...[
                const SizedBox(height: 4),
                Text(
                  pwError ?? "",
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 22),

              // 회원가입 버튼
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: signup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('회원가입'),
                ),
              ),
              const SizedBox(height: 11),

              // 카카오 버튼
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: signupWithKakao,
                  icon: Image.asset('assets/kakao.png', width: 40, height: 40),
                  label: const Text(
                    "카카오톡으로 시작하기",
                    style: TextStyle(
                      color: Color(0xFF2D2D2D),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFE812),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                    side: const BorderSide(color: Color(0xFFFFE812)),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Container(
                height: 1,
                color: Colors.grey.shade300,
                width: double.infinity,
              ),
              const SizedBox(height: 18),

              const Text(
                "약관 동의",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),

              _agreeTile("전체 동의", agreeAll, (v) => _toggleAll(v), bold: true),
              _agreeTile("[필수] 서비스 이용약관 동의", agreeService, (v) {
                agreeService = v ?? false;
                _updateAllState();
              }),
              _agreeTile("[필수] 개인정보 수집 및 이용 동의", agreePrivacy, (v) {
                agreePrivacy = v ?? false;
                _updateAllState();
              }),
              _agreeTile("[필수] 만 14세 이상입니다", agreeAge, (v) {
                agreeAge = v ?? false;
                _updateAllState();
              }),
              _agreeTile("[선택] 마케팅 정보 수신 동의", agreeMarketing, (v) {
                agreeMarketing = v ?? false;
                _updateAllState();
              }),

              const SizedBox(height: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _agreeTile(
    String text,
    bool value,
    Function(bool?) onChanged, {
    bool bold = false,
  }) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF859A7E),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
