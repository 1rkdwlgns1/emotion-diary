//감정 쓰레기통 .Gif 화면
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:audioplayers/audioplayers.dart';

class TrashGifScreen extends StatefulWidget {
  final String backgroundAsset;
  final String gifAsset;
  final Duration duration;
  final Duration exitDelay;
  final int playNonce;

  const TrashGifScreen({
    super.key,
    this.backgroundAsset = 'assets/back.png',
    this.gifAsset = 'assets/gifs/trash.gif',
    this.duration = const Duration(milliseconds: 2200),
    this.exitDelay = const Duration(milliseconds: 150),
    required this.playNonce,
  });

  @override
  State<TrashGifScreen> createState() => _TrashGifScreenState();
}

class _TrashGifScreenState extends State<TrashGifScreen> {
  Timer? _timer;
  late final AudioPlayer _player;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer(playerId: 'trashPlayer');

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      try {
        // GIF 캐시 초기화 → 항상 첫 프레임부터 재생
        await AssetImage(widget.gifAsset).evict();

        // 효과음 파일 로드 확인
        await rootBundle.load('assets/sounds/paper.mp3');

        // 오디오 세팅

        await _player.setVolume(1.0);
        await _player.setPlaybackRate(1.1);
        await _player.setReleaseMode(ReleaseMode.stop);
        await _player.play(AssetSource('sounds/paper.mp3'));
      } catch (e) {
        debugPrint("오디오 재생 실패: $e");
      }

      // 닫기 타이머 시작
      _timer = Timer(widget.duration + widget.exitDelay, () {
        if (mounted) Navigator.of(context).pop(true);
      });

      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pad = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 배경 이미지
          Image.asset(
            widget.backgroundAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
          ),

          // 중앙 GIF
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: size.width * 0.88,
                maxHeight: size.height * 0.62,
              ),
              child: Image.asset(
                widget.gifAsset,
                key: ValueKey<int>(widget.playNonce),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),

          // 하단 문구
          Positioned(
            left: 0,
            right: 0,
            bottom: pad.bottom + 12,
            child: const Center(
              child: Text(
                '감정을 비우는 중…',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
