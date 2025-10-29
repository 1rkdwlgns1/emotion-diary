import 'package:flutter/material.dart';
import 'dart:ui';

class TrashWarningScreen extends StatelessWidget {
  const TrashWarningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const mainGreen = Color(0xFF859A7E);

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.5),
      body: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. 경고 문구 박스
              Container(
                width: MediaQuery.of(context).size.width * 0.8,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4D9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '이곳에 남긴 글은 절대 저장되지 않으며,\n복구도 불가능합니다.\n정말로 버리시겠습니까?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                ),
              ),
              const SizedBox(height: 20), // 박스와 버튼 사이 간격

              // 2. 버튼들
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 버리기 버튼
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('버리기'),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainGreen,
                      foregroundColor: Colors.white,
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
    );
  }
}