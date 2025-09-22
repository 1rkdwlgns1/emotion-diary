import 'package:flutter/material.dart';

Future<void> showPasswordChangeDialog(
  BuildContext context, {
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
                  // 타이틀 + X
                  Stack(
                    children: [
                      Center(
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
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 13,
                      ),
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
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40), // << 여기만 40으로!
                  // 새 비밀번호
                  TextField(
                    controller: newController,
                    obscureText: newObscure,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 13,
                      ),
                      hintText: '재설정할 비밀번호를 입력해 주세요.',
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
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                    onChanged: (v) {
                      setState(() {
                        newPwError = !validatePw(v)
                            ? '영문,숫자 포함 8~16자로 입력해 주세요.'
                            : null;
                        confirmError =
                            (confirmController.text.isNotEmpty &&
                                confirmController.text != v)
                            ? '비밀번호가 일치하지 않아요!'
                            : null;
                      });
                    },
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
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 13,
                      ),
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
                          color: Colors.grey[500],
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
                      onPressed: () {
                        final oldPw = oldController.text.trim();
                        final newPw = newController.text.trim();
                        final confirm = confirmController.text.trim();
                        setState(() {
                          newPwError = !validatePw(newPw)
                              ? '영문,숫자 포함 8~16자로 입력해 주세요.'
                              : null;
                          confirmError = (confirm != newPw)
                              ? '비밀번호가 일치하지 않아요!'
                              : null;
                        });
                        if (oldPw.isEmpty ||
                            newPwError != null ||
                            confirmError != null ||
                            newPw.isEmpty ||
                            confirm.isEmpty) {
                          return;
                        }
                        onSuccess();
                        Navigator.pop(dialogContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA7BD99),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
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
