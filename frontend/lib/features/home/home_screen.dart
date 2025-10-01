import 'package:flutter/material.dart';
import '../camera/camera_screen.dart';
import 'dart:io';

// 홈 화면 전체 예시
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? diaryImagePath; // 촬영한 사진 경로(필요시)

  @override
  Widget build(BuildContext context) {
    const mainGreen = Color(0xFF859A7E);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 36),
              const Text(
                '대충그림..',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              // 이미지 프리뷰 or 더미박스
              diaryImagePath == null
                  ? Container(
                      width: 140,
                      height: 110,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[700]!, width: 2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: CustomPaint(painter: XMarkPainter()),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(diaryImagePath!),
                        width: 140,
                        height: 110,
                        fit: BoxFit.cover,
                      ),
                    ),
              const SizedBox(height: 30),
              SizedBox(
                width: 260,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final imagePath = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CameraScreen(),
                      ),
                    );
                    if (imagePath != null) {
                      setState(() {
                        diaryImagePath = imagePath;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: mainGreen,
                          content: const Text('사진이 촬영되었습니다!'),
                        ),
                      );
                      // TODO: 다음 단계(예: 일기 작성 화면 이동 등)로 imagePath 활용
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('일기 촬영'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// X표시 그림 더미
class XMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[700]!
      ..strokeWidth = 2.3;
    canvas.drawLine(Offset(0, 0), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
