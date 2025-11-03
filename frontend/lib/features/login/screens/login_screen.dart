import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:capstone/providers/user_provider.dart';
import 'package:capstone/services/api_service.dart';
import '../../main_tab/main_tab_screen.dart';
import '../signup/signup_screen.dart';
import 'id_find_screen.dart';
import 'password_find_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool showPassword = false;
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    const mainGreen = Color(0xFF859A7E);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '마음.zip',
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 48),

                  // 이메일 입력
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      hintText: '이메일',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 15, horizontal: 12),
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
                          showPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            showPassword = !showPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 로그인 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final email = emailController.text.trim();
                              final password = passwordController.text.trim();

                              if (email.isEmpty || password.isEmpty) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('이메일과 비밀번호를 입력하세요.')),
                                );
                                return;
                              }

                              setState(() => isLoading = true);
                              final res = await ApiService.login(
                                email: email,
                                password: password,
                              );

                              if (!mounted) return;
                              setState(() => isLoading = false);

                              if (res['ok'] == true) {
                                final user = res['user'];
                                final token = res['token'];

                                if (user == null || token == null) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('서버 응답이 올바르지 않습니다.')),
                                  );
                                  return;
                                }
                                
                                // ✅ 디버그 로그 (여기에 추가)
                                debugPrint(
                                  '✅ 로그인 성공 → user_id=${user['user_id']} token=$token',
                                );

                                // ✅ 로그인 성공 시 Provider에 저장
                                final userProvider = Provider.of<UserProvider>(
                                    context,
                                    listen: false);
                                await userProvider.setUser(
                                  userId: user['user_id'],
                                  email: user['email'] ?? '',
                                  nickname: user['nickname'] ?? '',
                                  token: token,
                                );

                                if (!mounted) return;

                                // ✅ 로그인 성공 메시지 후 메인으로 이동
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('로그인 성공!')),
                                );

                                await Future.delayed(
                                    const Duration(milliseconds: 500));

                                if (mounted) {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const MainTabScreen()),
                                    (route) => false,
                                  );
                                }
                              } else {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '로그인 실패: ${res['message'] ?? '정보를 확인하세요.'}',
                                    ),
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
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('로그인'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 아이디 찾기 / 비밀번호 찾기 / 회원가입
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const IdFindScreen()),
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
                                builder: (_) => const PasswordFindScreen()),
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
                                builder: (_) => const SignupScreen()),
                          );
                        },
                        child: const Text('회원가입'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Divider ("또는")
                  Row(
                    children: const [
                      Expanded(
                        child: Divider(thickness: 1, color: Colors.grey),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          "또는",
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                      Expanded(
                        child: Divider(thickness: 1, color: Colors.grey),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 카카오 로그인 (추후 연동)
                  InkWell(
                    onTap: () {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('카카오 로그인은 추후 지원 예정입니다.')),
                      );
                    },
                    child: CircleAvatar(
                      backgroundColor: Colors.yellow[700],
                      radius: 22,
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
      ),
    );
  }
}
