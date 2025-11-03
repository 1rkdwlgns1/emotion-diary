import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:capstone/providers/user_provider.dart';
import '../camera/camera_screen.dart';
import 'loading_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const mainGreen = Color(0xFF859A7E);

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId ?? 0;

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
                    // ✅ 카메라 화면으로 이동 → 촬영이 끝나면 path 반환
                    final path = await Navigator.push<String?>(
                      context,
                      MaterialPageRoute(builder: (_) => const CameraScreen()),
                    );

                    // ✅ 반환된 경로로 로딩 화면 진입 (userId 함께 전달)
                    if (path != null && mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LoadingScreen(
                            imagePath: path,
                            userId: userId, // ✅ 필수: 여기서 전달
                          ),
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
