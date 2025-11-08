import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String kBaseUrl = 'http://10.0.2.2:3000'; // ✅ Node 서버
const String kUserId = 'anon';
const Color kMainGreen = Color(0xFF859A7E);

const _ko = {
  'joy': '기쁨',
  'sad': '슬픔',
  'anger': '분노',
  'neutral': '평온',
  'surprise': '놀람',
};
const _barColors = {
  'joy': Color(0xFFFFCF66),
  'sad': Color(0xFF70B9FF),
  'anger': Color(0xFFFF8AA0),
  'neutral': Color(0xFFBDE4B1),
  'surprise': Color(0xFFBBA7FF),
};
const _bgGradients = {
  'joy': [Color(0xFFFFF6D8), Colors.white],
  'sad': [Color(0xFFEAF4FF), Colors.white],
  'anger': [Color(0xFFFFEEF0), Colors.white],
  'neutral': [Color(0xFFF3FAEE), Colors.white],
  'surprise': [Color(0xFFF1EBFF), Colors.white],
};

class DayEmotionScreen extends StatefulWidget {
  final DateTime date;
  const DayEmotionScreen({super.key, required this.date});

  @override
  State<DayEmotionScreen> createState() => _DayEmotionScreenState();
}

class _DayEmotionScreenState extends State<DayEmotionScreen> {
  late Future<_DayData> _future;
  final _memoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _fetchDay(widget.date);
  }

  Future<_DayData> _fetchDay(DateTime day) async {
    String fmt(DateTime d) =>
        "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

    final uri = Uri.parse(
      "$kBaseUrl/results/day?date=${fmt(day)}&user_id=$kUserId",
    );

    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) return _DayData.empty();

      final json = jsonDecode(res.body);
      if (json is! Map || json['ok'] != true) return _DayData.empty();

      // ✅ Node는 영어 key로 반환하므로 영어로 매핑
      final avgRaw = json['avg_distribution'] ?? {};
      final avg = <String, double>{};
      for (final k in _ko.keys) {
        final v = avgRaw[k];
        avg[k] = (v is num) ? v.toDouble() : 0.0;
      }

      // ✅ 대표 감정 찾기
      String top = 'neutral';
      double best = -1;
      avg.forEach((k, v) {
        if (v > best) {
          best = v;
          top = k;
        }
      });

      final fb = (json['latest_feedback'] ?? '').toString().trim();
      final summary = fb.isNotEmpty ? fb : _defaultSummary(top);

      return _DayData(date: day, dist: avg, topKey: top, feedback: summary);
    } catch (e) {
      debugPrint("❌ _fetchDay 오류: $e");
      return _DayData.empty();
    }
  }

  String _defaultSummary(String key) {
    const msg = {
      'joy': '기쁨이 가득한 하루였어요. 밝은 에너지가 주변에도 전해졌겠어요.',
      'sad': '조금 슬픔이 느껴졌지만 괜찮아요. 오늘을 잘 견뎌낸 것만으로도 충분해요.',
      'anger': '분노의 감정이 보이네요. 깊게 숨을 쉬고 마음을 진정시켜보세요.',
      'neutral': '평온한 하루였어요. 균형 잡힌 감정이 느껴져요.',
      'surprise': '놀람이 있었던 하루네요. 새로운 경험이 당신을 성장시켜요.',
    };
    return msg[key] ?? '오늘의 감정을 차분히 돌아보며 마무리해요.';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DayData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: kMainGreen)),
          );
        }

        final d = snap.data ?? _DayData.empty();
        final grad = _bgGradients[d.topKey] ?? _bgGradients['neutral']!;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              "${d.date.year}년 ${d.date.month}월 ${d.date.day}일",
              style: const TextStyle(fontWeight: FontWeight.bold),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FeedbackCard(d: d),
                  const SizedBox(height: 24),
                  const Text(
                    '감정 분석 결과',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  ..._ko.keys.map(
                    (k) => _EmotionBar(
                      label: _ko[k]!,
                      color: _barColors[k]!,
                      value: d.dist[k]!,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    '오늘의 한 줄 메모',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _memoCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: '오늘의 감정을 간단히 기록해보세요.',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black12),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('감정 일기가 저장되었어요.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        Navigator.pop(context);
                      },
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

class _FeedbackCard extends StatelessWidget {
  final _DayData d;
  const _FeedbackCard({required this.d});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Text(
            "${_ko[d.topKey]} 감정이 중심이 된 하루예요 🌿",
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 10),
          Text(
            d.feedback,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmotionBar extends StatelessWidget {
  final String label;
  final Color color;
  final double value;
  const _EmotionBar({
    required this.label,
    required this.color,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 50, child: Text(label)),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 30,
            child: Text(
              '$pct%',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayData {
  final DateTime date;
  final Map<String, double> dist;
  final String topKey;
  final String feedback;
  const _DayData({
    required this.date,
    required this.dist,
    required this.topKey,
    required this.feedback,
  });

  factory _DayData.empty() => _DayData(
    date: DateTime.now(),
    dist: {for (final k in _ko.keys) k: 0.0},
    topKey: 'neutral',
    feedback: '감정 데이터가 없습니다.',
  );
}
