import 'package:flutter/material.dart';

Future<void> showNicknameEditDialog(
  BuildContext context, {
  required String currentNickname,
  required ValueChanged<String> onConfirm,
}) async {
  final controller = TextEditingController();
  String? errorText;
  bool isSuccess = false;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      Center(
                        child: Text(
                          '닉네임 변경',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: InkWell(
                          onTap: () => Navigator.pop(dialogContext),
                          child: Icon(
                            Icons.close,
                            size: 28,
                            color: Colors.black45,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 17),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "현재 닉네임 : $currentNickname",
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: '새 닉네임을 입력해주세요.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  if (isSuccess)
                    Text(
                      '닉네임이 성공적으로 변경되었습니다.',
                      style: TextStyle(fontSize: 14, color: Colors.green[700]),
                    )
                  else if (errorText != null)
                    Text(
                      errorText!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF859A7E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                        textStyle: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        String val = controller.text.trim();
                        if (val.isEmpty) {
                          setState(() {
                            errorText = '닉네임을 입력해 주세요!';
                            isSuccess = false;
                          });
                          return;
                        }
                        setState(() {
                          errorText = null;
                          isSuccess = true;
                        });
                        onConfirm(val);
                        Future.delayed(Duration(milliseconds: 1100), () {
                          Navigator.pop(dialogContext);
                        });
                      },
                      child: Text('변경하기'),
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
