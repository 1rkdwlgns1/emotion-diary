import 'package:flutter/material.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final passwordController = TextEditingController();
  final passwordCheckController = TextEditingController();

  String? errorText;

  void _onReset() {
    final pwd = passwordController.text.trim();
    final check = passwordCheckController.text.trim();

    // 8~16자, 영문+숫자 체크
    if (pwd.length < 8 ||
        pwd.length > 16 ||
        !RegExp(r'[0-9]').hasMatch(pwd) ||
        !RegExp(r'[a-zA-Z]').hasMatch(pwd)) {
      setState(() => errorText = '영문, 숫자 포함 8~16자로 입력하세요.');
      return;
    }
    if (pwd != check) {
      setState(() => errorText = '비밀번호가 일치하지 않아요!');
      return;
    }
    setState(() => errorText = null);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('비밀번호가 재설정되었습니다.')));
    // Navigator.pop(context); // 원한다면 로그인 등으로 이동
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('비밀번호 재설정'),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black87,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: '재설정할 비밀번호를 입력해주세요.',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: passwordCheckController,
              decoration: const InputDecoration(
                labelText: '비밀번호 확인',
                border: OutlineInputBorder(),
                // errorText: 없음!
              ),
              obscureText: true,
            ),
            // ↓ 아래에서 오로지 한 곳만 에러 메시지 출력!
            if (errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _onReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF859A7E),
                  foregroundColor: Colors.white,
                ),
                child: const Text('완료'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
