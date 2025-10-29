import 'package:flutter/material.dart';
import '../camera/camera_screen.dart';
import 'loading_screen.dart';
// home_screen.dart

// 홈 화면 전체 예시
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
                  onPressed: () async {
                    final path = await Navigator.push<String?>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CameraScreen(),
                      ),
                    );

                    if (path != null && mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LoadingScreen(imagePath: path),
                        ),
                      );
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
