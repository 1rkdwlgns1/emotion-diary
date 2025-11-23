//캘린더 화면
import 'dart:convert';
import 'dart:io' show HttpDate;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import 'day_emotion_screen.dart' show DayEmotionScreen;
import 'week_emotion_report_pro.dart' show WeekEmotionReportProScreen;

const String kBaseUrl = 'http://13.209.65.181:3000';
const String kUserId = 'anon';
const Color kMainGreen = Color(0xFF859A7E);

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
    if (iso != null) return iso;
    try {
      return HttpDate.parse(s);
    } catch (_) {}
    return DateTime.now();
  }

  factory _Item.fromJson(Map<String, dynamic> j) {
    dynamic raw = j['emotion'] ?? j['emotion_detail'];
    if (raw == null || (raw is String && raw.trim().isEmpty)) {
      raw = j['emotion_detail'] ?? j['emotion'];
    }
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        raw = {};
      }
    }
    if (raw is Map && raw.containsKey('joy')) {
      return _Item(Map<String, dynamic>.from(raw), _safeParse(j['created_at']));
    } else {
      final emo = (raw is Map)
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      return _Item(emo, _safeParse(j['created_at']));
    }
  }
}

String _dkey(DateTime d) =>
    "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime? _selected;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  RangeSelectionMode _rangeMode = RangeSelectionMode.toggledOff;

  Map<String, String> _moodByDay = {};
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = DateTime.now();
    _loadMonth(_focused);
  }

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
      if (r.statusCode != 200 || r.body.trim().isEmpty) {
        setState(() {
          _moodByDay = {};
          _loading = false;
        });
        return;
      }

      final List raw = jsonDecode(r.body);
      final items = raw.map((j) => _Item.fromJson(j)).toList();

      final Map<String, Map<String, double>> acc = {};
      Map<String, double>? _extractDist(Map<String, dynamic> emo) {
        if (emo.isEmpty) return null;
        if (emo.keys.toSet().containsAll(_keys)) {
          return emo.map((k, v) => MapEntry(k, (v as num).toDouble()));
        }
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
        final key = _dkey(it.createdAt);
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

      final map = <String, String>{};
      acc.forEach((dateKey, sums) {
        final n = sums['__n__'] ?? 0.0;
        if (n <= 0) return;
        String bestK = _keys.first;
        double bestV = -1;
        for (final k in _keys) {
          final avg = sums[k]! / n;
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
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

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
                      outsideDaysVisible: true,
                      outsideTextStyle: TextStyle(color: Colors.transparent),
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
                      defaultBuilder: (context, day, _) =>
                          _dayCell(context, day),
                      todayBuilder: (context, day, _) =>
                          _dayCell(context, day, isToday: true),
                      selectedBuilder: (context, day, _) =>
                          _dayCell(context, day, isSelected: true),
                    ),
                  ),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),

                // 감정 색상 범례 + 안내문 추가
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // 왼쪽 정렬 유지
                    children: [
                      // 감정 색상 범례
                      Wrap(
                        alignment: WrapAlignment.start, // 가운데(X) → 왼쪽 정렬
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
                              Text(
                                _ko[k]!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),

                      // 안내문 (왼쪽 정렬)
                      const Text(
                        "※ 하루에 여러 영상을 촬영한 경우, 가장 최근 분석된 감정이 반영되고 저장됩니다.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.start, // 왼쪽 정렬
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _rangeStart != null && _rangeEnd != null
                          ? "선택 범위: ${_fmtKo(_rangeStart!)} ~ ${_fmtKo(_rangeEnd!)}"
                          : _rangeStart != null && _rangeEnd == null
                          ? "선택: ${_fmtKo(_rangeStart!)} "
                          : "선택 날짜: ${_fmtKo(_selected ?? DateTime.now())}",
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _onTapWeekly(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kMainGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '기간 리포트 보기',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _onTapDaily(),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 터치 안정화 버전 (점 표시 포함)
  Widget _dayCell(
    BuildContext context,
    DateTime day, {
    bool isOutside = false,
    bool isToday = false,
    bool isSelected = false,
  }) {
    final key = _dkey(day);
    final mood = _moodByDay[key];
    final dotColor = mood != null ? _colors[mood]! : null;

    return GestureDetector(
      onTap: () => _onDayTapped(day, day),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isToday
              ? const Color(0xFFEFF6EE)
              : isSelected
              ? const Color(0xFFDAE6D7)
              : null,
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${day.day}",
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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
      ),
    );
  }

  void _onTapWeekly() {
    final start = _rangeStart ?? _selected ?? DateTime.now();
    final end = _rangeEnd ?? _selected ?? DateTime.now();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WeekEmotionReportProScreen(startDate: start, endDate: end),
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
