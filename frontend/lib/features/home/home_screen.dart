// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import '../camera/camera_screen.dart';
import 'loading_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const mainGreen = Color(0xFF859A7E);

  Future<void> _onCapturePressed() async {
    final String? path = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );

    if (!mounted || path == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LoadingScreen(imagePath: path)),
    );
  }

  /// ✅ 메시지 도착 시 홈 화면 위에 다이얼로그로 띄우는 함수
  void showIncomingMessage(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          '📩 $title',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '대충그림..',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Icon(
                Icons.camera_alt_outlined,
                size: 120,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: 260,
                height: 48,
                child: ElevatedButton(
                  onPressed: _onCapturePressed,
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
