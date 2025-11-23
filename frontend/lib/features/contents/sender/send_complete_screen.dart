//import 'dart:async';
/*
import 'package:flutter/material.dart';
import '../../main_tab/main_tab_screen.dart'; // 메인탭으로 이동

class SendCompleteScreen extends StatefulWidget {
  const SendCompleteScreen({super.key});

  @override
  State<SendCompleteScreen> createState() => _SendCompleteScreenState();
}

class _SendCompleteScreenState extends State<SendCompleteScreen> {
  Timer? _timer;

  void _goToContentsTab() {
    // 스택 비우고 메인탭의 '콘텐츠'(index: 2)로 진입
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainTabScreen(initialIndex: 2)),
      (route) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    // 첫 프레임 렌더 후 2초 뒤 자동 이동
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        _goToContentsTab();
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
    // 뒤로가기(제스처/버튼) 완전 차단
    return WillPopScope(
      onWillPop: () async => false,
      child: const Scaffold(
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
        Image(
          image: AssetImage('assets/message_0.png'),
          width: 120,
          height: 120,
        ),
        SizedBox(height: 20),
        Text(
          '전달 완료! 누군가 이 메시지에 공감하면 알려드릴게요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 16),
        SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(height: 8),
        Text('2초 후 콘텐츠로 이동합니다…', style: TextStyle(color: Colors.black54)),
      ],
    );
  }
}
*/
