import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'dart:async';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  List<CameraDescription>? cameras;
  bool isReady = false;
  bool isRecording = false;
  Timer? _timer;
  int recordingDuration = 0;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    cameras = await availableCameras();
    if (cameras!.isNotEmpty) {
      controller = CameraController(cameras![0], ResolutionPreset.high);
      await controller!.initialize();
      if (mounted) setState(() => isReady = true);
    }
  }

  void startTimer() {
    _timer?.cancel();
    recordingDuration = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => recordingDuration++);
    });
  }

  void stopTimer() {
    _timer?.cancel();
  }

  Future<void> startVideoRecording() async {
    if (controller == null || !controller!.value.isInitialized) return;
    try {
      await controller!.startVideoRecording();
      startTimer();
      setState(() => isRecording = true);
    } catch (e) {
      print('녹화 시작 오류: $e');
    }
  }

  Future<String?> stopVideoRecordingAndReturnPath() async {
    if (controller == null || !controller!.value.isRecordingVideo) return null;
    try {
      final XFile videoFile = await controller!.stopVideoRecording();
      stopTimer();
      setState(() {
        isRecording = false;
        recordingDuration = 0;
      });
      return videoFile.path;
    } catch (e) {
      print('녹화 중지 오류: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    controller?.dispose();
    super.dispose();
  }

  String formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!isReady || controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(controller!)),
          Positioned(
            top: 40,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, size: 30, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
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
                    const Icon(
                      Icons.fiber_manual_record,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formatDuration(recordingDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: isRecording
                    ? () async {
                        final path = await stopVideoRecordingAndReturnPath();
                        if (path != null && context.mounted) {
                          Navigator.pop(context, path);
                        }
                      }
                    : () async {
                        await startVideoRecording();
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
    );
  }
}
