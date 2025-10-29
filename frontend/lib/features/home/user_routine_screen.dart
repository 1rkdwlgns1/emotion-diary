/*
  user_routine_screen.dart
  capstone2025-C3
*/
import 'package:flutter/material.dart';

class UserRoutineScreen extends StatelessWidget {
  final String emotion;

  const UserRoutineScreen({super.key, required this.emotion});

  @override
  Widget build(BuildContext context) {
    const mainGreen = Color(0xFF859A7E);
    final BoxDecoration boxDecoration = BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.grey.withOpacity(0.4), width: 1),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 3,
          offset: const Offset(0, 2),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('사용자 루틴 추천'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    const TextSpan(text: '오늘의 주요 감정 : '),
                    TextSpan(
                      text: '$emotion ',
                      style: TextStyle(color: Colors.lightBlue[300]),
                    ),
                    const TextSpan(text: '😌'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: boxDecoration,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '동일한 감정을 느낀 다른 사용자들의 활동 예시:',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 16),
                  _RoutineItem(user: '익명 1', action: '음악을 들었어요.'),
                  _RoutineItem(user: '익명 2', action: '가벼운 달리기를 했어요.'),
                  _RoutineItem(user: '익명 3', action: '따뜻한 차를 마시며 쉬었어요.'),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('확인', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineItem extends StatelessWidget {
  final String user;
  final String action;
  const _RoutineItem({required this.user, required this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6.0, right: 8.0),
            child: Icon(Icons.circle, size: 8, color: Colors.grey),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Colors.black87,
                ),
                children: [
                  TextSpan(
                    text: '$user: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: action),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
