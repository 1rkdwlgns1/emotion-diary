import 'package:flutter/material.dart';
import 'withdraw_complete_dialog.dart'; // 탈퇴 완료 다이얼로그 import (경로 맞게 조정)

Future<void> showWithdrawDialog(
  BuildContext context, {
  required VoidCallback onWithdraw,
}) async {
  final pwController = TextEditingController();
  bool checkConfirmed = false;
  String? pwError;

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
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 350),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 타이틀
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "정말 탈퇴하시겠어요?",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "회원탈퇴 시 모든 데이터는 복구할 수 없습니다. 작성한 감정 기록 및 등록한 정보가 모두 삭제됩니다.",
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 비밀번호 입력
                    TextField(
                      controller: pwController,
                      obscureText: true,
                      style: TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                        hintText: '비밀번호를 입력해주세요.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E5EA),
                            width: 1.3,
                          ),
                        ),
                      ),
                      onChanged: (_) {
                        setState(() {
                          pwError = null;
                        });
                      },
                    ),
                    if (pwError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 2),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            pwError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // 체크박스
                    Row(
                      children: [
                        Checkbox(
                          value: checkConfirmed,
                          activeColor: Colors.black87,
                          onChanged: (v) =>
                              setState(() => checkConfirmed = v ?? false),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        const Flexible(
                          child: Text(
                            "모든 정보가 삭제됨을 확인했습니다.",
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // 탈퇴/취소 버튼
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                checkConfirmed && pwController.text.isNotEmpty
                                ? () async {
                                    if (pwController.text.length < 5) {
                                      setState(
                                        () => pwError = '비밀번호를 다시 확인해주세요.',
                                      );
                                      return;
                                    }
                                    Navigator.pop(dialogContext); // 먼저 닫고
                                    await showWithdrawCompleteDialog(
                                      context,
                                    ); // 완료창
                                    onWithdraw();
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE87A7A),
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 0,
                            ),
                            child: const Text('회원탈퇴'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: const BorderSide(
                            color: Color(0xFFE5E5EA),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text(
                          '취소',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
