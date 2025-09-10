import 'package:flutter/material.dart';
import 'settings_screen.dart';

class UserScreen extends StatelessWidget {
  const UserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(16));
    const menuPadding = EdgeInsets.symmetric(vertical: 16, horizontal: 20);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          children: [
            const SizedBox(height: 8),
            // 프로필 박스
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 1.2),
                borderRadius: borderRadius,
                color: Colors.white,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.black12,
                    backgroundImage: const AssetImage(
                      'assets/profile_default.png',
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '홍길동 님',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Divider(
                          color: Colors.grey,
                          thickness: 1,
                          height: 1,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: const [
                            Text(
                              '오늘 하루도 수고했어요!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text('👏', style: TextStyle(fontSize: 17)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // 감정 리포트 확인
            InkWell(
              borderRadius: borderRadius,
              onTap: () {
                // 추후 연결 또는 임시 print
                print('감정 리포트 확인 클릭');
              },
              child: Container(
                padding: menuPadding,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, width: 1.2),
                  borderRadius: borderRadius,
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Image.asset('assets/chart.png', width: 28),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        '감정 리포트 확인',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 감정 패턴
            InkWell(
              borderRadius: borderRadius,
              onTap: () {
                print('감정 패턴 클릭');
              },
              child: Container(
                padding: menuPadding,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, width: 1.2),
                  borderRadius: borderRadius,
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Image.asset('assets/brain.png', width: 28),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        '감정 패턴',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 익명 감정 메시지 관리
            InkWell(
              borderRadius: borderRadius,
              onTap: () {
                print('익명 감정 메시지 관리 클릭');
              },
              child: Container(
                padding: menuPadding,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, width: 1.2),
                  borderRadius: borderRadius,
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Image.asset('assets/envelope.png', width: 28),
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            height: 16,
                            width: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Center(
                              child: Text(
                                '1',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        '익명 감정 메시지 관리',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 설정
            InkWell(
              borderRadius: borderRadius,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              child: Container(
                padding: menuPadding,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, width: 1.2),
                  borderRadius: borderRadius,
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.settings, size: 26, color: Colors.black87),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        '설정',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
