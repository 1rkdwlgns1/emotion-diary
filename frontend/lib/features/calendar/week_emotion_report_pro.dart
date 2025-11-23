//리포트 감정 보기
import 'dart:convert';
import 'dart:io' show HttpDate;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String kBaseUrl = "http://13.209.65.181:3000";
const String kUserId = "anon";
const Color kMainGreen = Color(0xFF859A7E);

const emotionKeys = ["joy", "sad", "anger", "neutral", "surprise"];
const emotionKo = {
  "joy": "기쁨",
  "sad": "슬픔",
  "anger": "분노",
  "neutral": "평온",
  "surprise": "놀람",
};

const emotionColors = {
  "joy": Color(0xFFFBE7C6),
  "sad": Color(0xFFC8D9F0),
  "anger": Color(0xFFF3C7C7),
  "neutral": Color(0xFFDDEECC),
  "surprise": Color(0xFFD9C8F0),
};

final _box = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  boxShadow: [
    BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
  ],
);

const _titleStyle = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w700,
  color: Colors.black87,
);

const _bodyStyle = TextStyle(
  fontSize: 14.5,
  height: 1.6,
  color: Colors.black87,
);

// 공통 Legend (감정 색상 가이드)
Widget _emotionLegend() {
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: emotionKeys.map((k) {
        return Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: emotionColors[k],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              emotionKo[k]!,
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ],
        );
      }).toList(),
    ),
  );
}

// 모델
class _Item {
  final Map<String, dynamic> emotion;
  final DateTime createdAt;

  _Item(this.emotion, this.createdAt);

  static DateTime _safe(dynamic v) {
    final s = v?.toString() ?? '';
    final d = DateTime.tryParse(s);
    if (d != null) return d;
    try {
      return HttpDate.parse(s);
    } catch (_) {}
    return DateTime.now();
  }

  factory _Item.fromJson(Map<String, dynamic> j) {
    dynamic raw = j["emotion"] ?? j["emotion_detail"];
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {}
    }
    return _Item(raw ?? {}, _safe(j["created_at"]));
  }
}

// 주간 데이터
class _WeekData {
  final List<DateTime> days;
  final Map<String, List<double>> series;
  final Map<String, double> avgDist;
  final String insightText;
  final DateTime intenseDay;
  final DateTime stableDay;

  _WeekData({
    required this.days,
    required this.series,
    required this.avgDist,
    required this.insightText,
    required this.intenseDay,
    required this.stableDay,
  });
}

// 화면 시작
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

// 메인 상태
class _WeekEmotionReportProScreenState
    extends State<WeekEmotionReportProScreen> {
  late Future<_WeekData> _future;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _future = _fetch(widget.startDate, widget.endDate);
  }

  String _fmt(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  Future<_WeekData> _fetch(DateTime s, DateTime e) async {
    // 날짜별 최신 데이터 로드
    final r = await http.get(
      Uri.parse(
        "$kBaseUrl/results/range?start=${_fmt(s)}&end=${_fmt(e)}&user_id=$kUserId",
      ),
    );

    final List raw = jsonDecode(r.body);
    final items = raw.map((j) => _Item.fromJson(j)).toList();

    // 전체 날짜 목록
    final days = [
      for (int i = 0; i <= e.difference(s).inDays; i++)
        DateTime(s.year, s.month, s.day).add(Duration(days: i)),
    ];

    Map<String, Map<String, double>> acc = {};
    String dk(DateTime d) =>
        "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

    for (final it in items) {
      final dist =
          it.emotion["fused"]?["distribution"] ??
          it.emotion["distribution"] ??
          it.emotion["text"]?["distribution"] ??
          it.emotion["face"]?["distribution"] ??
          {};

      final key = dk(it.createdAt);

      acc.putIfAbsent(
        key,
        () => {for (final k in emotionKeys) k: 0.0, "__n__": 0.0},
      );

      for (final k in emotionKeys) {
        final v = dist[k];
        if (v is num) acc[key]![k] = acc[key]![k]! + v.toDouble();
      }

      acc[key]!["__n__"] = acc[key]!["__n__"]! + 1;
    }

    // 데이터 없는 날짜 제외
    final validDays = days.where((d) {
      final key = dk(d);
      return acc.containsKey(key) && acc[key]!["__n__"]! > 0;
    }).toList();

    // series를 validDays 기준으로 생성
    final series = {
      for (final k in emotionKeys)
        k: List<double>.filled(validDays.length, 0.0),
    };

    for (int i = 0; i < validDays.length; i++) {
      final key = dk(validDays[i]);
      final n = acc[key]!["__n__"]!;
      for (final k in emotionKeys) {
        series[k]![i] = (acc[key]![k]! / n) * 100;
      }
    }

    // GPT 인사이트 생성 (Node → Flask)
    final rw = await http.get(
      Uri.parse(
        "$kBaseUrl/results/report/weekly?start=${_fmt(s)}&end=${_fmt(e)}&user_id=$kUserId",
      ),
    );

    Map<String, double> avg = {for (final k in emotionKeys) k: 0.0};
    if (rw.statusCode == 200) {
      final m = jsonDecode(rw.body);
      final ad = m["avg_distribution"] ?? {};
      for (final k in emotionKeys) {
        final v = ad[k];
        if (v is num) avg[k] = v.toDouble();
      }
    }

    // 흔들린 날 / 안정된 날 계산
    double maxChange = -999;
    double minChange = 999;
    int maxIndex = 0;
    int minIndex = 0;

    for (int i = 1; i < validDays.length; i++) {
      double sum = 0;
      for (final k in emotionKeys) {
        sum += (series[k]![i] - series[k]![i - 1]).abs();
      }
      if (sum > maxChange) {
        maxChange = sum;
        maxIndex = i;
      }
      if (sum < minChange) {
        minChange = sum;
        minIndex = i;
      }
    }

    final intense = validDays[maxIndex];
    final stable = validDays[minIndex];

    // Flask 인사이트 호출
    final ins = await http.post(
      Uri.parse("$kBaseUrl/results/report/weekly-insight"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_id": kUserId,
        "intense_date": _fmt(intense),
        "stable_date": _fmt(stable),
        "start": _fmt(s),
        "end": _fmt(e),
      }),
    );

    String insightTxt = "";
    if (ins.statusCode == 200) {
      final m = jsonDecode(ins.body);
      insightTxt = (m["insight"] ?? "").toString();
    }

    return _WeekData(
      days: validDays,
      series: series,
      avgDist: avg,
      insightText: insightTxt,
      intenseDay: intense,
      stableDay: stable,
    );
  }

  // 빌드
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_WeekData>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: kMainGreen)),
          );
        }

        final d = snap.data!;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            title: const Text(
              "기간 리포트 보기",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            foregroundColor: Colors.black,
          ),

          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
            child: Column(
              children: [
                _InsightCard(text: d.insightText),
                const SizedBox(height: 20),

                _SummaryBar(d.series, widget.startDate, widget.endDate),

                const SizedBox(height: 20),

                _ChartCard(days: d.days, series: d.series),
                const SizedBox(height: 20),

                // 자세히 보기
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _expanded ? "접기 ▲" : "자세히 보기 ▼",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kMainGreen,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_expanded) ...[
                  const SizedBox(height: 20),
                  _PatternCard(series: d.series, days: d.days),

                  const SizedBox(height: 20),
                  _DonutCard(
                    avg: d.avgDist,
                    start: widget.startDate,
                    end: widget.endDate,
                  ),

                  const SizedBox(height: 20),
                  _BalanceCard(avg: d.avgDist),
                  const SizedBox(height: 20),
                  _StressCard(avg: d.avgDist),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // 인사이트
  Widget _InsightCard({required String text}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _box,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.orange, size: 26),
              SizedBox(width: 8),
              Text("해당 기간 인사이트", style: _titleStyle),
            ],
          ),
          const SizedBox(height: 12),
          Text(text.isNotEmpty ? text : "인사이트를 불러올 수 없어요.", style: _bodyStyle),
        ],
      ),
    );
  }

  // 주간 평균 변화 방식
  Widget _SummaryBar(
    Map<String, List<double>> series,
    DateTime startDate,
    DateTime endDate,
  ) {
    // 주간 평균 값 계산
    Map<String, double> weeklyAvg = {};
    for (final k in emotionKeys) {
      final list = series[k]!;
      final sum = list.fold<double>(0.0, (a, b) => a + b);
      weeklyAvg[k] = sum / list.length;
    }

    // 마지막 날 변화 계산
    Map<String, double> diff = {};
    for (final k in emotionKeys) {
      final last = series[k]!.last;
      diff[k] = last - weeklyAvg[k]!;
    }

    String arrowText(double v) {
      if (v > 0.01) return "▲ ${v.toStringAsFixed(1)}%";
      if (v < -0.01) return "▼ ${v.abs().toStringAsFixed(1)}%";
      return "— 0%";
    }

    Color arrowColor(double v) {
      if (v > 0) return Colors.redAccent;
      if (v < 0) return Colors.blueAccent;
      return Colors.grey;
    }

    return Column(
      children: [
        // 카드 전체
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: _box,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: emotionKeys.map((k) {
              final d = diff[k]!;
              return Column(
                children: [
                  Text(
                    emotionKo[k]!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    arrowText(d),
                    style: TextStyle(fontSize: 12, color: arrowColor(d)),
                  ),
                ],
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),

        // 설명 문구
        const Text(
          "이번 기간 날, 감정이 얼마나 오르내렸는지 보여드려요.",
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }

  // 차트
  Widget _ChartCard({
    required List<DateTime> days,
    required Map<String, List<double>> series,
  }) {
    List<FlSpot> _s(List<double> a) =>
        List.generate(a.length, (i) => FlSpot(i.toDouble(), a[i]));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _box,
      child: Column(
        children: [
          SizedBox(
            height: 240,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                minX: 0,
                maxX: (days.length - 1).toDouble(),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (v) =>
                      const FlLine(strokeWidth: .4, color: Colors.black12),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (v, m) {
                        final i = v.toInt();
                        if (i < 0 || i >= days.length) return const SizedBox();
                        return Text(
                          "${days[i].month}.${days[i].day}",
                          style: const TextStyle(fontSize: 11),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      getTitlesWidget: (v, m) => Text(
                        "${v.toInt()}%",
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: emotionKeys.map((k) {
                  return LineChartBarData(
                    spots: _s(series[k]!),
                    color: emotionColors[k],
                    isCurved: true,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          emotionColors[k]!.withOpacity(0.25),
                          emotionColors[k]!.withOpacity(0.07),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          _emotionLegend(),
        ],
      ),
    );
  }

  // 패턴
  Widget _PatternCard({
    required Map<String, List<double>> series,
    required List<DateTime> days,
  }) {
    // 날짜 범위 생성
    final start = days.first;
    final end = days.last;

    String _fmt(DateTime d) => "${d.month}.${d.day.toString().padLeft(2, '0')}";

    final rangeText = "${_fmt(start)} ~ ${_fmt(end)} 기간에는";

    // 가장 많이 변화한 감정 찾기
    String best = "neutral";
    double bestVal = -999;

    for (final k in emotionKeys) {
      final diff = series[k]!.last - series[k]!.first;
      if (diff > bestVal) {
        bestVal = diff;
        best = k;
      }
    }

    // 메시지 생성
    final msg = {
      "joy": "기쁨이 조금씩 늘어났어요. 작은 좋은 순간들이 이어진 흐름이에요. 😊",
      "sad": "슬픔이 조금 더 높게 나타났어요. 마음이 지치는 날이 있었던 것 같아요.",
      "anger": "예민함이 느껴지는 흐름이에요. 감정이 조금 날카로웠던 시기였을 수 있어요.",
      "surprise": "놀람이 증가했어요. 예상치 못한 일들이 있었던 것 같아요.",
      "neutral": " 전반적으로 평온한 흐름이 유지됐어요. 감정을 잘 관리하고 있었어요. 😊",
    }[best]!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _box,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.show_chart, size: 24),
              SizedBox(width: 8),
              Text("감정 패턴 분석", style: _titleStyle),
            ],
          ),
          const SizedBox(height: 12),
          Text(msg, style: _bodyStyle),
        ],
      ),
    );
  }

  // 도넛
  Widget _DonutCard({
    required Map<String, double> avg,
    required DateTime start,
    required DateTime end,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _box,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("감정 분포", style: _titleStyle),
          const SizedBox(height: 4),

          // 설명문
          Text(
            "${start.month}.${start.day} ~ ${end.month}.${end.day} 기간 동안 기록된 감정 비율이에요.",
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 240,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 60,
                sections: emotionKeys.map((k) {
                  return PieChartSectionData(
                    value: avg[k],
                    title: "",
                    color: emotionColors[k],
                  );
                }).toList(),
              ),
            ),
          ),

          _emotionLegend(),
        ],
      ),
    );
  }

  // 밸런스
  Widget _BalanceCard({required Map<String, double> avg}) {
    final pos = avg["joy"]! + avg["surprise"]!;
    final neg = avg["sad"]! + avg["anger"]!;
    final neu = avg["neutral"]!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _box,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart, size: 24),
              SizedBox(width: 8),
              Text("감정 균형 상태", style: _titleStyle),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "🙂 긍정 ${pos.toStringAsFixed(1)}%   "
            "😐 중립 ${neu.toStringAsFixed(1)}%   "
            "😢 부정 ${neg.toStringAsFixed(1)}%",
            style: _bodyStyle,
          ),
        ],
      ),
    );
  }

  // 스트레스
  Widget _StressCard({required Map<String, double> avg}) {
    // 스트레스 계산: 분노(0.7) + 슬픔(0.3)
    final stress = avg["anger"]! * 0.7 + avg["sad"]! * 0.3;

    String msg;
    if (stress < 15) {
      msg = "이번 기간은 마음이 아주 편안했어요. 좋은 흐름을 잘 유지하고 있어요 😊";
    } else if (stress < 30) {
      msg = "약간의 긴장감은 있었지만 전체적으로는 안정적인 한 주였어요.";
    } else if (stress < 50) {
      msg = "스트레스가 조금씩 쌓이는 흐름이 보여요. 잠깐의 휴식이 도움이 될 거예요.";
    } else if (stress < 70) {
      msg = "이번 기간은 스트레스가 다소 높았어요. 스스로를 돌보는 시간이 필요해요.";
    } else {
      msg = "스트레스가 많이 누적된 상태예요. 충분한 휴식과 마음 챙김이 꼭 필요해요.";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _box,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 24), // 온도계 아이콘
              SizedBox(width: 8),
              Text("스트레스 지수", style: _titleStyle),
            ],
          ),
          const SizedBox(height: 12),

          // 스트레스 지수 표시
          Text("🌡️ 스트레스 지수: ${stress.toStringAsFixed(1)}%", style: _bodyStyle),

          const SizedBox(height: 8),

          // 단계별 멘트
          Text(msg, style: _bodyStyle),
        ],
      ),
    );
  }
}
