import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF859A7E),
      unselectedItemColor: Colors.grey,
      items: [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
        BottomNavigationBarItem(
          icon: SizedBox(
            width: 28,
            height: 28,
            child: Image.asset('assets/ai_character.png', fit: BoxFit.contain),
          ),
          label: '마음이',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: '캘린더'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: '사용자'),
      ],
    );
  }
}
