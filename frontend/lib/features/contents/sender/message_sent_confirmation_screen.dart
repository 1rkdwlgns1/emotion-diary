import 'package:flutter/material.dart';
import 'dart:async';
import '../../main_tab/main_tab_screen.dart';

class MessageSentConfirmationScreen extends StatefulWidget {
  const MessageSentConfirmationScreen({super.key});

  @override
  State<MessageSentConfirmationScreen> createState() =>
      _MessageSentConfirmationScreenState();
}

class _MessageSentConfirmationScreenState
    extends State<MessageSentConfirmationScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // 첫 프레임 그려진 뒤 2초 대기 → 루트로 교체(pushAndRemoveUntil)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const MainTabScreen(initialIndex: 2),
          ),
          (route) => false,
        );
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 뒤로가기(제스처/버튼) 완전 비활성화
    return WillPopScope(
      onWillPop: () async => false,
      child: const Scaffold(
        // AppBar 없음: 뒤로가기 아이콘도 없음
        backgroundColor: Colors.white,
        body: SafeArea(child: Center(child: _SuccessBody())),
      ),
    );
  }
}

class _SuccessBody extends StatelessWidget {
  const _SuccessBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 완료 이미지
        Image(
          image: AssetImage('assets/message_3.png'),
          width: 150,
          height: 150,
        ),
        SizedBox(height: 24),
        Text(
          '전달 완료! 누군가 이 메시지에 공감하면 알려드릴게요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.black87),
        ),
        SizedBox(height: 18),
        SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(height: 8),
        Text('2초 후 콘텐츠로 이동합니다…', style: TextStyle(color: Colors.black54)),
      ],
    );
  }
}
