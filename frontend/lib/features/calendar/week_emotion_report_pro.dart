import 'dart:convert';
import 'dart:io' show HttpDate;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ==== 서버 환경 ====
const String kBaseUrl = 'http://10.0.2.2:3000'; // ✅ Node 서버
const String kUserId = 'anon';
const Color kMainGreen = Color(0xFF859A7E);

// 감정 키/라벨/색
const _keys = ['joy', 'sad', 'anger', 'neutral', 'surprise'];
const _ko = {
  'joy': '기쁨',
  'sad': '슬픔',
  'anger': '분노',
  'neutral': '평온',
  'surprise': '놀람',
};
const _lineColors = {
  'joy': Colors.amber,
  'sad': Color(0xFF70B9FF),
  'anger': Colors.redAccent,
  'neutral': Color(0xFFBDE4B1),
  'surprise': Color(0xFFBBA7FF),
};

// 배경 그라디언트
const _bgGradients = {
  'joy': [Color(0xFFFFF6D8), Colors.white],
  'sad': [Color(0xFFEAF4FF), Colors.white],
  'anger': [Color(0xFFFFEEF0), Colors.white],
  'neutral': [Color(0xFFF3FAEE), Colors.white],
  'surprise': [Color(0xFFF1EBFF), Colors.white],
};

const bool kWeeklyShowFullFeedback = true;

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
    dynamic raw = j['emotion'] ?? j['emotion_detail'];
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        raw = {};
      }
    }
    return _Item(
      Map<String, dynamic>.from(raw ?? {}),
      _safeParse(j['created_at']),
    );
  }
}

class WeekEmotionReportProScreen extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  const WeekEmotionReportProScreen({
    super.key,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<WeekEmotionReportProScreen> createState() =>
      _WeekEmotionReportProScreenState();
}

class _WeekEmotionReportProScreenState
    extends State<WeekEmotionReportProScreen> {
  late Future<_WeekData> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch(widget.startDate, widget.endDate);
  }

  String _fmt(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  String _rangeKo(DateTime s, DateTime e) =>
      "${s.year}년 ${s.month}월 ${s.day}일 ~ ${e.year}년 ${e.month}월 ${e.day}일";

  // ✅ _stripActions 제거 (피드백 삭제 방지)
  Future<_WeekData> _fetch(DateTime s, DateTime e) async {
    try {
      // 1️⃣ 감정 분포 데이터
      final uriRange = Uri.parse(
        '$kBaseUrl/results/range?start=${_fmt(s)}&end=${_fmt(e)}&user_id=$kUserId',
      );
      final r = await http.get(uriRange);
      if (r.statusCode != 200) {
        throw Exception("HTTP ${r.statusCode}: ${r.body}");
      }

      final List raw = jsonDecode(r.body);
      final items = raw.map((j) => _Item.fromJson(j)).toList();

      // 날짜 리스트 생성
      final days = <DateTime>[];
      for (int i = 0; i <= e.difference(s).inDays; i++) {
        days.add(DateTime(s.year, s.month, s.day).add(Duration(days: i)));
      }

      // 날짜별 평균 계산
      Map<String, Map<String, double>> acc = {};
      String dk(DateTime d) =>
          "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

      for (final it in items) {
        final fused =
            (it.emotion['fused']?['distribution']) ??
            (it.emotion['distribution']) ??
            (it.emotion['text']?['distribution']) ??
            (it.emotion['face']?['distribution']) ??
            (it.emotion.containsKey('joy') ? it.emotion : {});
        if (fused is! Map) continue;
        final key = dk(it.createdAt);
        acc.putIfAbsent(
          key,
          () => {for (final k in _keys) k: 0.0, '__n__': 0.0},
        );
        for (final k in _keys) {
          final v = fused[k];
          if (v is num) acc[key]![k] = acc[key]![k]! + v.toDouble();
        }
        acc[key]!['__n__'] = acc[key]!['__n__']! + 1.0;
      }

      final series = <String, List<double>>{
        for (final k in _keys) k: List.filled(days.length, 0.0),
      };
      for (int i = 0; i < days.length; i++) {
        final key = dk(days[i]);
        if (!acc.containsKey(key) || (acc[key]!['__n__'] ?? 0) == 0) continue;
        final n = acc[key]!['__n__']!;
        for (final k in _keys) {
          series[k]![i] = ((acc[key]![k]! / n) * 100).clamp(0.0, 100.0);
        }
      }

      // 2️⃣ ✅ Flask → Node /report/weekly 호출
      final uriWeekly = Uri.parse(
        '$kBaseUrl/results/report/weekly?start=${_fmt(s)}&end=${_fmt(e)}&user_id=$kUserId',
      );

      String summary = "";
      Map<String, double> avg = {for (final k in _keys) k: 0.0};
      String dominant = 'neutral';

      try {
        final rw = await http.get(uriWeekly);
        debugPrint("📩 Weekly response: ${rw.body}"); // 로그 확인용

        if (rw.statusCode == 200) {
          final m = jsonDecode(rw.body) as Map<String, dynamic>;

          // ✅ 피드백 텍스트 직접 읽기
          summary = (m['gpt_feedback'] ?? "").toString().trim();

          // ✅ 평균 감정 분포
          final ad = Map<String, dynamic>.from(m['avg_distribution'] ?? {});
          for (final k in _keys) {
            final v = ad[k];
            if (v is num) avg[k] = v.toDouble();
          }

          dominant = _keys.reduce((a, b) => (avg[a]! >= avg[b]!) ? a : b);
        } else {
          summary = "해당 기간의 감정을 요약했어요. 그래프를 참고해 변화를 살펴보세요.";
        }
      } catch (e) {
        debugPrint("❌ 주간 요약 요청 오류: $e");
        summary = "해당 기간의 감정을 요약했어요. 그래프를 참고해 변화를 살펴보세요.";
      }

      return _WeekData(
        days: days,
        series: series,
        summaryText: summary,
        dominantKey: dominant,
      );
    } catch (err) {
      debugPrint("❌ _fetch 오류: $err");
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_WeekData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: kMainGreen)),
          );
        }
        if (snap.hasError) {
          return Scaffold(body: Center(child: Text('에러: ${snap.error}')));
        }

        final d = snap.data!;
        final grad = _bgGradients[d.dominantKey] ?? _bgGradients['neutral']!;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              '감정 리포트',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0.5,
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: grad,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _rangeKo(widget.startDate, widget.endDate),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ChartCard(days: d.days, series: d.series),
                  const SizedBox(height: 8),
                  _LegendBar(),
                  const SizedBox(height: 12),
                  _SummaryCard(text: d.summaryText),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kMainGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '확인',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ===== 내부 위젯 =====
class _ChartCard extends StatelessWidget {
  final List<DateTime> days;
  final Map<String, List<double>> series;
  const _ChartCard({required this.days, required this.series});

  @override
  Widget build(BuildContext context) {
    List<FlSpot> _spots(List<double> a) =>
        List.generate(a.length, (i) => FlSpot(i.toDouble(), a[i]));

    String _tick(int i) =>
        (i < 0 || i >= days.length) ? '' : '${days[i].month}.${days[i].day}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        height: 260,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 100,
            minX: 0,
            maxX: (days.length - 1).toDouble(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 20,
              getDrawingHorizontalLine: (v) =>
                  const FlLine(strokeWidth: .5, color: Colors.black12),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: 20,
                  getTitlesWidget: (v, _) => Text(
                    '${v.toInt()}%',
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (v, _) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _tick(v.toInt()),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: true),
            lineBarsData: _keys
                .map((k) => _line(_spots(series[k] ?? []), _lineColors[k]!))
                .toList(),
          ),
        ),
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      color: color,
      isCurved: true,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [color.withOpacity(.10), color.withOpacity(.10)],
        ),
      ),
    );
  }
}

class _LegendBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Wrap(
          spacing: 12,
          children: _keys.map((k) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _lineColors[k],
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
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String text;
  const _SummaryCard({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.account_circle_outlined,
            size: 36,
            color: Colors.black87,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text.isNotEmpty ? text : "이번 주 감정 데이터를 불러오지 못했습니다.",
              style: const TextStyle(fontSize: 14.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekData {
  final List<DateTime> days;
  final Map<String, List<double>> series;
  final String summaryText;
  final String dominantKey;
  _WeekData({
    required this.days,
    required this.series,
    required this.summaryText,
    required this.dominantKey,
  });
}
