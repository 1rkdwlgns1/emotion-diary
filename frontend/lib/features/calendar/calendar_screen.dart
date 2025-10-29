// lib/features/calendar/calendar_screen.dart
import 'dart:convert';
import 'dart:io' show HttpDate;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';

// ✅ 필요한 화면 클래스만 들여오기 (상수는 가져오지 않음)
import 'day_emotion_screen.dart' show DayEmotionScreen;
import 'week_emotion_report_pro.dart' show WeekEmotionReportProScreen;

// ❌ 이 줄은 삭제 (이미 config.dart 삭제했으므로)
// import '../../config.dart';

// ✅ 여기서만 쓸 상수들을 이 파일 내에서 정의(실서버 IP 반영)
const String kBaseUrl = 'http://10.0.2.2:5001';
/*const String kBaseUrl = 'http://10.11.26.62:5001';*/
const String kUserId = 'anon';
const Color kMainGreen = Color(0xFF859A7E);

// 감정 키/라벨/색상
const _keys = ['joy', 'sad', 'anger', 'neutral', 'surprise'];
const _ko = {
  'joy': '기쁨',
  'sad': '슬픔',
  'anger': '분노',
  'neutral': '평온',
  'surprise': '놀람',
};
const _colors = {
  'joy': Colors.amber,
  'sad': Color(0xFF70B9FF),
  'anger': Colors.redAccent,
  'neutral': Color(0xFF77C066),
  'surprise': Color(0xFFBBA7FF),
};

class _Item {
  final Map<String, dynamic> emotion;
  final DateTime createdAt;
  _Item(this.emotion, this.createdAt);

  static DateTime _safeParse(dynamic v) {
    final s = v?.toString() ?? '';
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso.toLocal();
    try {
      return HttpDate.parse(s).toLocal();
    } catch (_) {}
    return DateTime.now();
  }

  factory _Item.fromJson(Map<String, dynamic> j) {
    final raw = j['emotion'];
    final emo = (raw is String) ? jsonDecode(raw) : (raw ?? {});
    return _Item(Map<String, dynamic>.from(emo), _safeParse(j['created_at']));
  }
}

String _dkey(DateTime d) =>
    "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

String? _topMood(Map<String, dynamic> emo) {
  Map dist =
      (emo['fused']?['distribution']) ??
      (emo['text']?['distribution']) ??
      (emo['face']?['distribution']) ??
      {};
  if (dist is! Map) return null;
  String? bestK;
  double bestV = -1;
  for (final k in _keys) {
    final v = dist[k];
    if (v is num && v.toDouble() > bestV) {
      bestV = v.toDouble();
      bestK = k;
    }
  }
  return bestK;
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused = DateTime.now();

  // 단일/범위 선택 상태
  DateTime? _selected;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  RangeSelectionMode _rangeMode = RangeSelectionMode.toggledOff;

  // 해당 월의 dateKey → topMood
  Map<String, String> _moodByDay = {};

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = DateTime.now();
    _loadMonth(_focused);
  }

  // 기존 _loadMonth 전체를 이 버전으로 교체
  Future<void> _loadMonth(DateTime month) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);

    String fmt(DateTime d) =>
        "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

    final uri = Uri.parse(
      "$kBaseUrl/results/range?start=${fmt(first)}&end=${fmt(last)}&user_id=$kUserId",
    );

    try {
      final r = await http.get(uri);
      if (r.statusCode != 200) {
        throw Exception('HTTP ${r.statusCode}: ${r.body}');
      }

      final List raw = jsonDecode(r.body);
      final items = raw.map((j) => _Item.fromJson(j)).toList();

      // ---- [핵심 변경] 날짜별 분포 누적/평균 → 지배 감정 결정 ----
      // acc[dateKey] = { 'joy': sum, 'sad': sum, ..., '__n__': count }
      final Map<String, Map<String, double>> acc = {};

      Map<String, double>? _extractDist(Map<String, dynamic> emo) {
        final m =
            (emo['fused']?['distribution']) ??
            (emo['text']?['distribution']) ??
            (emo['face']?['distribution']);
        if (m is! Map) return null;
        final out = <String, double>{};
        for (final k in _keys) {
          final v = m[k];
          if (v is num) out[k] = v.toDouble();
        }
        return out.length == _keys.length ? out : null;
      }

      for (final it in items) {
        final key = _dkey(it.createdAt.toLocal());
        final dist = _extractDist(it.emotion);
        if (dist == null) continue;

        acc.putIfAbsent(
          key,
          () => {for (final k in _keys) k: 0.0, '__n__': 0.0},
        );
        for (final k in _keys) {
          acc[key]![k] = acc[key]![k]! + dist[k]!;
        }
        acc[key]!['__n__'] = acc[key]!['__n__']! + 1.0;
      }

      // 평균 내서 지배 감정 뽑기
      final map = <String, String>{}; // dateKey -> topMood
      acc.forEach((dateKey, sums) {
        final n = sums['__n__'] ?? 0.0;
        if (n <= 0) return;
        String bestK = _keys.first;
        double bestV = -1.0;
        for (final k in _keys) {
          final avg = (sums[k]! / n); // 0~1
          if (avg > bestV) {
            bestV = avg;
            bestK = k;
          }
        }
        map[dateKey] = bestK;
      });

      setState(() {
        _moodByDay = map;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // 날짜 탭 → 범위 선택 토글
  void _onDayTapped(DateTime sel, DateTime foc) {
    setState(() {
      _focused = foc;
      if (_rangeMode == RangeSelectionMode.toggledOn) {
        if (_rangeStart != null && _rangeEnd == null) {
          final s = _rangeStart!;
          if (sel.isBefore(s)) {
            _rangeEnd = s;
            _rangeStart = DateTime(sel.year, sel.month, sel.day);
          } else {
            _rangeEnd = DateTime(sel.year, sel.month, sel.day);
          }
          _selected = null;
        } else {
          _rangeStart = DateTime(sel.year, sel.month, sel.day);
          _rangeEnd = null;
        }
      } else {
        _rangeMode = RangeSelectionMode.toggledOn;
        _rangeStart = DateTime(sel.year, sel.month, sel.day);
        _rangeEnd = null;
        _selected = null;
      }
    });
  }

  // 단일 선택으로 전환하고 싶을 때
  void _selectSingle(DateTime sel, DateTime foc) {
    setState(() {
      _rangeMode = RangeSelectionMode.toggledOff;
      _rangeStart = null;
      _rangeEnd = null;
      _selected = DateTime(sel.year, sel.month, sel.day);
      _focused = foc;
    });
  }

  // 주간 범위 얻기
  DateTime _weekStartOf(DateTime d) =>
      d.subtract(Duration(days: d.weekday % 7)); // 일요일 시작
  DateTime _weekEndOf(DateTime d) =>
      _weekStartOf(d).add(const Duration(days: 6));

  (DateTime start, DateTime end) _currentRangeForWeekly() {
    if (_rangeStart != null && _rangeEnd != null) {
      return (_rangeStart!, _rangeEnd!);
    } else {
      final base = _selected ?? DateTime.now();
      return (_weekStartOf(base), _weekEndOf(base));
    }
  }

  String _fmtKo(DateTime d) =>
      "${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    final headerStyle = const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w800,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('캘린더', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TableCalendar(
                    firstDay: DateTime(2023, 1, 1),
                    lastDay: DateTime(2030, 12, 31),
                    focusedDay: _focused,
                    locale: 'ko_KR',
                    headerStyle: HeaderStyle(
                      titleTextFormatter: (date, locale) =>
                          "${date.year}년 ${date.month}월",
                      titleCentered: true,
                      titleTextStyle: headerStyle,
                      formatButtonVisible: false,
                    ),
                    calendarStyle: const CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Color(0xFFEFF6EE),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Color(0xFFDAE6D7),
                        shape: BoxShape.circle,
                      ),
                      rangeHighlightColor: Color(0x2269A36A),
                      withinRangeTextStyle: TextStyle(color: Colors.black87),
                      outsideDaysVisible: false,
                    ),
                    selectedDayPredicate: (d) =>
                        _selected != null &&
                        d.year == _selected!.year &&
                        d.month == _selected!.month &&
                        d.day == _selected!.day,
                    rangeStartDay: _rangeStart,
                    rangeEndDay: _rangeEnd,
                    rangeSelectionMode: _rangeMode,
                    onDaySelected: _onDayTapped,
                    onPageChanged: (foc) {
                      _focused = foc;
                      _loadMonth(foc);
                    },
                    calendarBuilders: CalendarBuilders(
                      dowBuilder: (context, day) {
                        final text = [
                          '일',
                          '월',
                          '화',
                          '수',
                          '목',
                          '금',
                          '토',
                        ][day.weekday % 7];
                        final isSun = day.weekday == DateTime.sunday;
                        final isSat = day.weekday == DateTime.saturday;
                        return Center(
                          child: Text(
                            text,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSun
                                  ? Colors.redAccent
                                  : isSat
                                  ? const Color(0xFF3C6DFF)
                                  : Colors.black87,
                            ),
                          ),
                        );
                      },
                      defaultBuilder: (context, day, focusedDay) =>
                          _dayCell(context, day, isOutside: false),
                      outsideBuilder: (context, day, focusedDay) =>
                          _dayCell(context, day, isOutside: true),
                      todayBuilder: (context, day, _) =>
                          _dayCell(context, day, isToday: true),
                      selectedBuilder: (context, day, _) =>
                          _dayCell(context, day, isSelected: true),
                      rangeStartBuilder: (context, day, _) =>
                          _dayCell(context, day, isRangeEdge: true),
                      rangeEndBuilder: (context, day, _) =>
                          _dayCell(context, day, isRangeEdge: true),
                      withinRangeBuilder: (context, day, _) =>
                          _dayCell(context, day, isWithinRange: true),
                    ),
                  ),
                ),

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '에러: $_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      (_rangeStart != null && _rangeEnd != null)
                          ? "선택 범위: ${_fmtKo(_rangeStart!)} ~ ${_fmtKo(_rangeEnd!)}"
                          : (_rangeStart != null && _rangeEnd == null)
                          ? "범위 시작: ${_fmtKo(_rangeStart!)}  (끝 날짜를 탭하세요)"
                          : "선택 날짜: ${_fmtKo(_selected ?? DateTime.now())}",
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // 색상 범례
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: _keys.map((k) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _colors[k],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(_ko[k]!, style: const TextStyle(fontSize: 12)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 하단 고정 버튼바
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _onTapWeekly, // ✅ 네비 연결
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kMainGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '주간 리포트 보기',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _onTapDaily, // ✅ 네비 연결
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kMainGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '감정 보기',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 날짜 셀
  Widget _dayCell(
    BuildContext context,
    DateTime day, {
    bool isOutside = false,
    bool isToday = false,
    bool isSelected = false,
    bool isRangeEdge = false,
    bool isWithinRange = false,
  }) {
    final key = _dkey(day);
    final mood = _moodByDay[key];
    final dotColor = mood != null ? _colors[mood]! : null;

    final base = Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isWithinRange ? const Color(0x1A69A36A) : null,
        shape: BoxShape.circle,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "${day.day}",
            style: TextStyle(
              fontWeight: (isSelected || isRangeEdge)
                  ? FontWeight.w800
                  : FontWeight.w600,
              color: isOutside ? Colors.black26 : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          if (dotColor != null)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );

    if (isSelected || isRangeEdge) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFFDAE6D7),
          shape: BoxShape.circle,
        ),
        child: base,
      );
    }
    if (isToday) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFFEFF6EE),
          shape: BoxShape.circle,
        ),
        child: base,
      );
    }
    return base;
  }

  // ====== 네비게이션 구현 ======
  void _onTapWeekly() {
    final (start, end) = _currentRangeForWeekly();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WeekEmotionReportProScreen(
          startDate: DateTime(start.year, start.month, start.day),
          endDate: DateTime(end.year, end.month, end.day),
        ),
      ),
    );
  }

  void _onTapDaily() {
    final d = (_rangeStart != null && _rangeEnd == null)
        ? _rangeStart!
        : (_selected ?? DateTime.now());
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DayEmotionScreen(date: DateTime(d.year, d.month, d.day)),
      ),
    );
  }
}
