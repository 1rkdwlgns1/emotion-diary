import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants.dart';

class PasswordResetScreen extends StatefulWidget {
  final String email;
  const PasswordResetScreen({super.key, required this.email});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final passwordController = TextEditingController();
  final passwordCheckController = TextEditingController();

  String? errorText;

  void _onReset() async {
    final pwd = passwordController.text.trim();
    final check = passwordCheckController.text.trim();

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

    try {
      final res = await http.post(
        Uri.parse('$kBaseUrl/users/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email, 'newPassword': pwd}),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['ok'] == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('비밀번호가 재설정되었습니다.')));
        Navigator.pop(context);
      } else {
        _showDialog(data['message'] ?? '비밀번호 변경 실패');
      }
    } catch (e) {
      _showDialog('서버 연결 실패: $e');
    }
  }

  void _showDialog(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('알림'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
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
              ),
              obscureText: true,
            ),
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
