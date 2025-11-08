import 'package:flutter/material.dart';
import 'dart:ui';
import 'trash_gif_screen.dart';

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
            children: [
              // 경고 박스
              Container(
                width: MediaQuery.of(context).size.width * 0.8,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4D9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '이곳에 남긴 글은 절대 저장되지 않으며,\n복구도 불가능합니다.\n정말로 버리시겠습니까?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 버리기
                  ElevatedButton(
                    onPressed: () async {
                      final played = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => TrashGifScreen(
                            backgroundAsset: 'assets/back.png',
                            gifAsset: 'assets/gifs/trash.gif',
                            // 화면 머무는 시간은 필요 시 조정 (GIF 길이에 맞춰 2000~2600ms 권장)
                            duration: const Duration(milliseconds: 2200),
                            playNonce: DateTime.now().microsecondsSinceEpoch,
                          ),
                        ),
                      );
                      if (played == true && context.mounted) {
                        Navigator.of(context).pop(true); // 경고창 닫기
                      }
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

                  // 취소
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(false),
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
