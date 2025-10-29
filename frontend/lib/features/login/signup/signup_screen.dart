import 'package:flutter/material.dart';
// ⭐️ 이름과 위치 주의!
import '../../../services/api_service.dart';
import '../info/signup_complete_screen.dart';

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

  // void signup() {
  //   setState(() {
  //     if (passwordController.text != confirmPwController.text) {
  //       pwError = "비밀번호가 일치하지 않아요!";
  //     } else {
  //       pwError = null;
  //       // 회원가입 완료 안내 화면으로 이동!
  //       Navigator.pushReplacement(
  //         context,
  //         MaterialPageRoute(builder: (_) => const SignupCompleteScreen()),
  //       );
  //     }
  //   });
  // }

  //   Future<void> signup() async {
  //   // 비밀번호 일치 여부 확인
  //   if (passwordController.text != confirmPwController.text) {
  //     setState(() => pwError = "비밀번호가 일치하지 않아요!");
  //     return;
  //   }
  //   setState(() => pwError = null);

  //   final email = emailController.text.trim();
  //   final password = passwordController.text.trim();

  //   if (email.isEmpty || password.isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('이메일과 비밀번호를 입력하세요.')),
  //     );
  //     return;
  //   }

  //   try {
  //     final res = await ApiService.register(
  //       email: email,
  //       password: password,
  //       nickname: '임시닉네임', // 다음 info_input_screen에서 수정 예정
  //       gender: 'M',
  //       mbti: 'INFJ',
  //     );

  //     print('회원가입 결과: $res');

  //     if (res['ok'] == true) {
  //       if (!mounted) return;
  //         // ✅ 회원가입 성공 시 자동 로그인 (토큰 저장)
  //       try {
  //         final loginRes = await ApiService.login(
  //           email: email,
  //           password: password,
  //         );

  //         print('자동 로그인 결과: $loginRes');

  //         if (loginRes['ok'] == true && loginRes['user']?['token'] != null) {
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             const SnackBar(content: Text('회원가입 + 자동 로그인 성공!')),
  //           );
  //         } else {
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             const SnackBar(content: Text('회원가입은 성공했지만 자동 로그인 실패')),
  //           );
  //         }
  //       } catch (e) {
  //         print('자동 로그인 중 오류: $e');
  //       }

  //       // ✅ 이후 info_input_screen으로 이동
  //       Navigator.pushReplacement(
  //         context,
  //         MaterialPageRoute(builder: (_) => const SignupCompleteScreen()),
  //       );
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('회원가입 실패: ${res['message'] ?? ''}')),
  //       );
  //     }
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('오류 발생: $e')),
  //     );
  //   }
  // }
  Future<void> signup() async {
    // 비밀번호 일치 확인
    if (passwordController.text != confirmPwController.text) {
      setState(() => pwError = "비밀번호가 일치하지 않아요!");
      return;
    }
    setState(() => pwError = null);

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이메일과 비밀번호를 입력하세요.')));
      return;
    }

    try {
      // ✅ 회원가입 요청
      final res = await ApiService.register(
        email: email,
        password: password,
        nickname: '임시닉네임', // info_input_screen에서 수정 예정
        gender: 'M',
        mbti: 'INFJ',
      );

      print('회원가입 결과: $res');

      if (res['ok'] == true) {
        // ✅ 회원가입 성공 후 자동 로그인
        try {
          final loginRes = await ApiService.login(
            email: email,
            password: password,
          );
          print('🔑 자동 로그인 결과: $loginRes');

          if (loginRes['ok'] == true && loginRes['token'] != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('회원가입 + 자동 로그인 성공!')));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('회원가입은 성공했지만 자동 로그인 실패')),
            );
          }
        } catch (e) {
          print('🚨 자동 로그인 중 오류: $e');
        }

        // ✅ 완료 후 다음 화면 이동
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SignupCompleteScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회원가입 실패: ${res['message'] ?? ''}')),
        );
      }
    } catch (e) {
      print('🚨 전체 오류: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('오류 발생: $e')));
    }
  }

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
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {},
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
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
