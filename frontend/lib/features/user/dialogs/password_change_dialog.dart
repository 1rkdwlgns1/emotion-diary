import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants.dart';

Future<void> showPasswordChangeDialog(
  BuildContext context, {
  required String email,
  required VoidCallback onSuccess,
}) async {
  final oldController = TextEditingController();
  final newController = TextEditingController();
  final confirmController = TextEditingController();

  bool oldObscure = true;
  bool newObscure = true;
  bool confirmObscure = true;

  String? newPwError;
  String? confirmError;
  bool isLoading = false;

  bool validatePw(String pw) {
    final valid = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d\S]{8,16}$');
    return valid.hasMatch(pw);
  }

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> _submitChange() async {
            final oldPw = oldController.text.trim();
            final newPw = newController.text.trim();
            final confirm = confirmController.text.trim();

            // 기본 유효성 검사
            setState(() {
              newPwError = !validatePw(newPw)
                  ? '영문,숫자 포함 8~16자로 입력해 주세요.'
                  : null;
              confirmError = (confirm != newPw) ? '비밀번호가 일치하지 않아요!' : null;
            });
            if (oldPw.isEmpty || newPwError != null || confirmError != null) {
              return;
            }

            setState(() => isLoading = true);

            try {
              // 토큰 불러오기
              final prefs = await SharedPreferences.getInstance();
              final token = prefs.getString('jwt_token');

              if (token == null) {
                throw Exception("로그인 정보가 없습니다. 다시 로그인해주세요.");
              }

              // 서버에 변경 요청 보내기
              final res = await http.post(
                Uri.parse('$kBaseUrl/users/change-password'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: jsonEncode({'oldPassword': oldPw, 'newPassword': newPw}),
              );

              final data = jsonDecode(res.body);
              if (res.statusCode == 200 && data['ok'] == true) {
                Navigator.pop(dialogContext);
                onSuccess();
              } else {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(data['message'] ?? '비밀번호 변경 실패'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            } catch (e) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(
                  content: Text('서버 오류: $e'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            } finally {
              setState(() => isLoading = false);
            }
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.white,
            child: Container(
              width: 340,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      const Center(
                        child: Text(
                          '비밀번호 변경',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(dialogContext),
                          child: const Icon(
                            Icons.close,
                            size: 27,
                            color: Colors.black38,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 23),

                  // 기존 비밀번호
                  TextField(
                    controller: oldController,
                    obscureText: oldObscure,
                    decoration: InputDecoration(
                      hintText: '기존 비밀번호를 입력해 주세요.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => oldObscure = !oldObscure),
                        icon: Icon(
                          oldObscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 새 비밀번호
                  TextField(
                    controller: newController,
                    obscureText: newObscure,
                    decoration: InputDecoration(
                      hintText: '새 비밀번호 입력',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => newObscure = !newObscure),
                        icon: Icon(
                          newObscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    onChanged: (v) => setState(() {
                      newPwError = !validatePw(v)
                          ? '영문,숫자 포함 8~16자로 입력해 주세요.'
                          : null;
                    }),
                  ),
                  if (newPwError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 2),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          newPwError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),

                  // 비밀번호 확인
                  TextField(
                    controller: confirmController,
                    obscureText: confirmObscure,
                    decoration: InputDecoration(
                      hintText: '비밀번호 확인',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => confirmObscure = !confirmObscure),
                        icon: Icon(
                          confirmObscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    onChanged: (v) {
                      setState(() {
                        confirmError = (v != newController.text)
                            ? '비밀번호가 일치하지 않아요!'
                            : null;
                      });
                    },
                  ),
                  if (confirmError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 2),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          confirmError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 26),

                  // 완료 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 41,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _submitChange,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA7BD99),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '완료',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
