import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../user/screens/user_screen.dart';
import '../contents/views/contents_home_views.dart';
import '../calendar/calendar_screen.dart';

const tabIconNames = ['home', 'calendar', 'contents', 'user'];

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});
  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;
  final labels = ['홈', '캘린더', '콘텐츠', '사용자'];
  final List<Widget> _pages = [
    HomeScreen(),
    CalendarScreen(),
    ContentsHomeView(),
    UserScreen(), // 꼭 이렇게!
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 1.2, color: Colors.grey[300]),
            SizedBox(
              height: 65,
              child: Row(
                children:
                    List.generate(4, (idx) {
                      final isSelected = _currentIndex == idx;
                      final assetName =
                          'assets/${tabIconNames[idx]}_${isSelected ? "1" : "0"}.png';
                      return Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _currentIndex = idx),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(assetName, width: 28, height: 28),
                              const SizedBox(height: 3),
                              Text(
                                labels[idx],
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.grey[400],
                                  fontSize: 15,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).asMap().entries.expand((entry) {
                      final idx = entry.key;
                      final widget = entry.value;
                      return idx < 3
                          ? [
                              widget,
                              Container(
                                height: 28,
                                width: 1.2,
                                color: Colors.grey[300],
                                alignment: Alignment.center,
                              ),
                            ]
                          : [widget];
                    }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
