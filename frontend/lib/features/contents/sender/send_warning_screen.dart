import 'package:flutter/material.dart';
import '../sender/send_complete_screen.dart'; // ✅ 상대경로로 import (같은 sender 폴더 안)

class SendWarningScreen extends StatelessWidget {
  const SendWarningScreen({super.key});

  static const _bgGreen = Color(0xFF859A7E);
  static const _dialogBg = Color(0xFFFFD6C7);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // ⚠️ 경고 팝업
            Center(
              child: Container(
                width: 270,
                decoration: BoxDecoration(
                  color: _dialogBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '누군가 이 글을 익명으로 받게 돼요.\n'
                          '혹시 불편할 수 있는 말은 없었는지,\n'
                          '한 번 더 살펴봐 주세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // ✅ 보내기 버튼 → 전달 완료 화면으로 이동
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SendCompleteScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _bgGreen,
                            minimumSize: const Size(80, 36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('보내기'),
                        ),

                        // ❌ 취소하기 버튼 → 경고창 닫기
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _bgGreen,
                            side: const BorderSide(color: _bgGreen),
                            minimumSize: const Size(80, 36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('취소하기'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
