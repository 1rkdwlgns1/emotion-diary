import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime focusedDay;
  late DateTime selectedDay;

  @override
  void initState() {
    super.initState();
    focusedDay = DateTime.now();
    selectedDay = DateTime(focusedDay.year, focusedDay.month, focusedDay.day);
  }

  @override
  Widget build(BuildContext context) {
    const mainGreen = Color(0xFF859A7E);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          '캘린더',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false, // 탭 화면은 뒤로가기 제거
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Column(
          children: [
            // 상단 년/월 네비게이션
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 32),
                    onPressed: () {
                      setState(() {
                        focusedDay = DateTime(
                          focusedDay.year,
                          focusedDay.month - 1,
                          1,
                        );
                        selectedDay = DateTime(
                          focusedDay.year,
                          focusedDay.month,
                          1,
                        );
                      });
                    },
                  ),
                  Text(
                    '${focusedDay.year}년 ${focusedDay.month}월',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 19,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 32),
                    onPressed: () {
                      setState(() {
                        focusedDay = DateTime(
                          focusedDay.year,
                          focusedDay.month + 1,
                          1,
                        );
                        selectedDay = DateTime(
                          focusedDay.year,
                          focusedDay.month,
                          1,
                        );
                      });
                    },
                  ),
                ],
              ),
            ),

            // 캘린더 카드
            Card(
              margin: const EdgeInsets.only(bottom: 21),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Colors.grey.shade300), // ← FIX
              ),
              elevation: 0,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 17,
                  horizontal: 7,
                ),
                child: TableCalendar(
                  firstDay: DateTime(2018),
                  lastDay: DateTime(2030),
                  focusedDay: focusedDay,
                  locale: 'ko_KR',
                  headerVisible: false,
                  calendarFormat: CalendarFormat.month,
                  startingDayOfWeek: StartingDayOfWeek.sunday,

                  selectedDayPredicate: (day) => isSameDay(selectedDay, day),

                  onDaySelected: (selDay, focDay) {
                    if (!isSameDay(selectedDay, selDay)) {
                      // ← FIX
                      setState(() {
                        selectedDay = DateTime(
                          selDay.year,
                          selDay.month,
                          selDay.day,
                        );
                        focusedDay = focDay;
                      });
                    }
                  },

                  onPageChanged: (fd) {
                    setState(() {
                      // ← FIX
                      focusedDay = fd;
                    });
                  },

                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 15,
                    ),
                    weekendStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      border: Border.all(color: mainGreen, width: 1.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    selectedDecoration: BoxDecoration(
                      color: mainGreen.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    selectedTextStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ).copyWith(color: mainGreen),
                    defaultTextStyle: const TextStyle(
                      fontSize: 15,
                      color: Colors.black,
                    ),
                    outsideTextStyle: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        elevation: 0,
                      ),
                      child: const Text('주간 리포트 보기'),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        elevation: 0,
                      ),
                      child: const Text('감정 보기'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
