import 'package:flutter/material.dart';
import 'id_find_screen.dart';
import '../signup/signup_screen.dart';
import 'password_find_screen.dart'; // 실제 경로와 파일명에 따라 맞게!
import '../../../services/api_service.dart';
import '../../main_tab/main_tab_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool showPassword = false;

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
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () async {
                      final email = emailController.text.trim();
                      final password = passwordController.text.trim();

                      final res = await ApiService.login(
                        email: email,
                        password: password,
                      );
                      print("로그인 결과: $res");

                      if (res['ok'] == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('로그인 성공!')),
                        );

                        // ✅ 메인화면으로 이동 (main_tab_screen.dart)
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

                /// 아이디/비번찾기 + 회원가입 버튼
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const IdFindScreen(),
                          ),
                        );
                      },
                      child: const Text('아이디 찾기'),
                    ),
                    Text('|', style: TextStyle(color: Colors.grey[500])),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PasswordFindScreen(),
                          ),
                        );
                      },
                      child: const Text('비밀번호 찾기'),
                    ),
                    Text('|', style: TextStyle(color: Colors.grey[500])),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignupScreen(),
                          ),
                        );
                      },
                      child: const Text('회원가입'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                /// "또는" Divider
                Row(
                  children: [
                    const Expanded(
                      child: Divider(thickness: 1, color: Colors.grey),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        "또는",
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                    const Expanded(
                      child: Divider(thickness: 1, color: Colors.grey),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                /// ✅ 카카오톡 로그인 버튼 복원
                InkWell(
                  onTap: () {
                    // TODO: 카카오톡 로그인 연동 로직 작성
                  },
                  child: CircleAvatar(
                    backgroundColor: Colors.yellow[700],
                    radius: 20,
                    child: Image.asset(
                      "assets/kakao.png",
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
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
