/*
  camera_screen.dart (2025.11 완성형)
  ----------------------------------------------------------
  ⚙️ 전체 흐름:
   CameraScreen → 촬영 종료 후 → 파일 경로만 반환
   ⚠️ 업로드 및 분석은 LoadingScreen에서 수행됨

  ✅ 주요 기능
  - 전면 카메라 자동 선택 (enableAudio=true)
  - 녹화 시작/중지 및 시간 표시
  - 파일을 임시 경로로 저장 후 경로 반환
  - 중복 업로드 방지 (CameraScreen에서는 서버 전송 X)
  - 홈 화면에서 LoadingScreen으로 이동 시 파일 경로 전달

  📦 반환 구조:
    Navigator.pop(context, file.path);

  ⚠️ 주의
  - 백그라운드 업로드 코드(_uploadInBackground) 완전히 제거
  - CameraScreen → LoadingScreen 연결은 HomeScreen에서 처리해야 함
  - user_id 누락 문제는 없음 (LoadingScreen에서 처리)
*/

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:capstone/providers/user_provider.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  List<CameraDescription>? cameras;
  bool isReady = false;       // 카메라 초기화 상태
  bool isRecording = false;   // 녹화 여부
  bool isBusy = false;        // 중복 클릭 방지용
  Timer? _timer;              // 녹화 시간 타이머
  int recordingDuration = 0;  // 녹화 경과 시간(초)

  // =====================================================
  // 📸 초기화
  // =====================================================
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      debugPrint('📡 CameraScreen 진입 → userId=${userProvider.userId}, token=${userProvider.token}');
    });
  }

  // 카메라 초기화
  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras == null || cameras!.isEmpty) {
        debugPrint('❌ 사용 가능한 카메라가 없습니다.');
        return;
      }

      final frontCamera = cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras!.first,
      );

      controller = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: true,
      );

      await controller!.initialize();
      if (!mounted) return;
      setState(() => isReady = true);
      debugPrint('✅ 전면 카메라 초기화 완료');
    } catch (e) {
      debugPrint('카메라 초기화 실패: $e');
    }
  }

  // =====================================================
  // ⏱️ 타이머 (녹화 시간 표시)
  // =====================================================
  void _startTimer() {
    _timer?.cancel();
    recordingDuration = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => recordingDuration++);
    });
  }

  void _stopTimer() => _timer?.cancel();

  // =====================================================
  // ▶️ 녹화 시작
  // =====================================================
  Future<void> _startRecording() async {
    if (isBusy) return;
    if (controller == null || !controller!.value.isInitialized) return;

    try {
      await controller!.startVideoRecording();
      _startTimer();
      setState(() => isRecording = true);
      debugPrint('🎬 녹화 시작');
    } catch (e) {
      debugPrint('녹화 시작 오류: $e');
    }
  }

  // =====================================================
  // ⏹️ 녹화 중지 후 임시 파일로 저장
  // =====================================================
  Future<File?> _stopRecordingToTempFile() async {
    if (controller == null || !controller!.value.isRecordingVideo) return null;

    try {
      final XFile x = await controller!.stopVideoRecording();
      _stopTimer();

      if (mounted) {
        setState(() {
          isRecording = false;
          recordingDuration = 0;
        });
      }

      // 임시 디렉토리에 복사
      final dir = await getTemporaryDirectory();
      final newPath = p.join(
        dir.path,
        'emotion_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );

      final f = await File(x.path).copy(newPath);
      debugPrint('🎥 촬영 완료: ${f.path}');
      return f;
    } catch (e) {
      debugPrint('녹화 중지 오류: $e');
      return null;
    }
  }

  // =====================================================
  // 🔙 파일 경로만 반환
  // =====================================================
  Future<void> _stopAndReturnPath() async {
    if (isBusy) return;
    isBusy = true;

    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      final file = await _stopRecordingToTempFile();
      if (file != null) {
        if (mounted) {
          Navigator.pop(context);           // 로딩 닫기
          Navigator.pop(context, file.path); // ✅ 경로 반환 (HomeScreen에서 처리)
        }
      } else {
        if (mounted) Navigator.pop(context); // 로딩 닫기
      }
    } catch (e) {
      debugPrint('❌ 파일 반환 오류: $e');
      if (mounted) Navigator.pop(context);
    } finally {
      try {
        await controller?.dispose();
      } catch (_) {}
      controller = null;
      isBusy = false;
    }
  }

  // =====================================================
  // 🧹 해제
  // =====================================================
  @override
  void dispose() {
    _timer?.cancel();
    try {
      controller?.dispose();
    } catch (_) {}
    super.dispose();
  }

  // =====================================================
  // ⏰ 녹화 시간 표시 포맷 (MM:SS)
  // =====================================================
  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // =====================================================
  // 🎨 UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    if (!isReady || controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return WillPopScope(
      onWillPop: () async => !isBusy,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 🔹 카메라 미리보기
            Positioned.fill(child: CameraPreview(controller!)),

            // 🔹 닫기 버튼 (왼쪽 상단)
            Positioned(
              top: 40,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () async {
                  if (isRecording) {
                    await _stopAndReturnPath();
                  } else {
                    try {
                      await controller?.pausePreview();
                      await controller?.dispose();
                      controller = null;
                    } catch (_) {}
                    if (mounted) Navigator.pop(context);
                  }
                },
              ),
            ),

            // 🔹 녹화 시간 표시 (오른쪽 상단)
            if (isRecording)
              Positioned(
                top: 40,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.fiber_manual_record,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        _formatDuration(recordingDuration),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

            // 🔹 녹화 버튼 (하단 중앙)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () async {
                    if (isBusy) return;
                    if (!isRecording) {
                      await _startRecording();
                    } else {
                      await _stopAndReturnPath(); // ✅ 경로만 반환
                    }
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isRecording ? Colors.red : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey, width: 4),
                    ),
                    child: Icon(
                      isRecording ? Icons.stop : Icons.videocam,
                      color: isRecording ? Colors.white : Colors.black,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
