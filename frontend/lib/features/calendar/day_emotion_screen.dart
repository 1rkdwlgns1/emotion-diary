// 캘린더 감정 하루보기
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String kBaseUrl = 'http://13.209.65.181:3000';
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

const _screenGradients = {
  'joy': [Color(0xFFFFF5DA), Color(0xFFFFFFFF)],
  'sad': [Color(0xFFE9F1FF), Color(0xFFFFFFFF)],
  'anger': [Color(0xFFFFE0E0), Color(0xFFFFFFFF)],
  'neutral': [Color(0xFFE9F7EA), Color(0xFFFFFFFF)],
  'surprise': [Color(0xFFF3EDFF), Color(0xFFFFFFFF)],
};

class DayEmotionScreen extends StatefulWidget {
  final DateTime date;
  const DayEmotionScreen({super.key, required this.date});

  @override
  State<DayEmotionScreen> createState() => _DayEmotionScreenState();
}

class _DayEmotionScreenState extends State<DayEmotionScreen> {
  late Future<_DayData> _future;
  final _rand = Random();

  bool _editing = false;
  final TextEditingController _memoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _fetchDay(widget.date);
  }

  // 하루 조회
  Future<_DayData> _fetchDay(DateTime day) async {
    String fmt(DateTime d) =>
        "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

    try {
      final res = await http.get(
        Uri.parse("$kBaseUrl/results/day?date=${fmt(day)}&user_id=$kUserId"),
      );
      if (res.statusCode != 200) return _DayData.empty();

      final json = jsonDecode(res.body);
      if (json is! Map || json['ok'] != true) return _DayData.empty();

      final avgRaw = json['avg_distribution'] ?? {};
      final avg = <String, double>{};
      for (final k in _ko.keys) {
        final v = avgRaw[k];
        avg[k] = (v is num) ? v.toDouble() : 0.0;
      }

      String top = 'neutral';
      double best = -1;
      avg.forEach((k, v) {
        if (v > best) {
          best = v;
          top = k;
        }
      });

      final feedback = _randomFeedback(top);

      // 메모 조회
      final memoRes = await http.get(
        Uri.parse("$kBaseUrl/memo/day?date=${fmt(day)}&user_id=$kUserId"),
      );
      String memoText = "";
      if (memoRes.statusCode == 200) {
        final mj = jsonDecode(memoRes.body);
        if (mj['ok'] == true) memoText = mj['memo'] ?? "";
      }

      return _DayData(
        date: day,
        dist: avg,
        topKey: top,
        feedback: feedback,
        memo: memoText,
      );
    } catch (e) {
      debugPrint("_fetchDay 오류: $e");
      return _DayData.empty();
    }
  }

  // 메모 저장
  Future<void> _saveMemo() async {
    final memo = _memoController.text.trim();
    final d = await _future;

    final date = d.date;
    final body = {
      "user_id": kUserId,
      "memo": memo.isEmpty ? "(메모 없음)" : memo,
      "date":
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
    };

    await http.post(
      Uri.parse("$kBaseUrl/memo/save"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    setState(() {
      _editing = false;
      _future = _fetchDay(date);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("메모가 저장되었습니다!")));
  }

  // 랜덤 피드백
  String _randomFeedback(String key) {
    final pool = {
      'joy': ['행복이 전해지는 하루예요.', '웃음이 가득한 하루였네요.'],
      'sad': ['마음이 조금 무거운 하루였죠.', '오늘은 자신을 더 따뜻하게 안아주세요.'],
      'anger': ['잠시 숨 고르기를 해봐요.', '감정을 억누르지 않아도 괜찮아요.'],
      'neutral': ['평온한 하루였네요.', '잔잔한 하루를 보냈군요.'],
      'surprise': ['예상치 못한 일이 있었네요.', '놀라운 하루였어요 ✨'],
    };
    final list = pool[key] ?? pool['neutral']!;
    return list[_rand.nextInt(list.length)];
  }

  IconData _getEmotionIcon(String key) {
    switch (key) {
      case 'joy':
        return Icons.sunny;
      case 'sad':
        return Icons.water_drop_outlined;
      case 'anger':
        return Icons.local_fire_department_rounded;
      case 'neutral':
        return Icons.self_improvement_rounded;
      case 'surprise':
        return Icons.star_border_rounded;
      default:
        return Icons.sentiment_satisfied;
    }
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
        final grad = _screenGradients[d.topKey] ?? _screenGradients['neutral']!;

        if (!_editing) _memoController.text = d.memo;

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: grad,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${d.date.year}년 ${d.date.month}월 ${d.date.day}일",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 상위 감정 카드
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _getEmotionIcon(d.topKey),
                            color: _barColors[d.topKey],
                            size: 40,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "${_ko[d.topKey]} 감정이 주를 이뤘던 하루 🌱",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            d.feedback,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14.5,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    _ResultCard(d: d),

                    const SizedBox(height: 24),

                    _MemoCard(
                      d: d,
                      editing: _editing,
                      controller: _memoController,
                      onEdit: () => setState(() => _editing = true),
                      onSave: _saveMemo,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  final _DayData d;
  const _ResultCard({required this.d});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "감정 분석 결과",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ..._ko.keys.map(
            (k) => _EmotionBar(
              label: _ko[k]!,
              color: _barColors[k]!,
              value: d.dist[k]!,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoCard extends StatelessWidget {
  final _DayData d;
  final bool editing;
  final TextEditingController controller;
  final VoidCallback onEdit;
  final Future<void> Function() onSave;

  const _MemoCard({
    required this.d,
    required this.editing,
    required this.controller,
    required this.onEdit,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.edit_note_rounded, color: kMainGreen),
              SizedBox(width: 6),
              Text(
                '오늘의 메모',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (!editing)
            Text(
              d.memo.isNotEmpty ? d.memo : "오늘은 별다른 메모가 없습니다.",
              style: const TextStyle(
                fontSize: 15.5,
                color: Colors.black87,
                height: 1.6,
              ),
            ),

          if (!editing)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onEdit,
                child: const Text(
                  "수정하기",
                  style: TextStyle(
                    fontSize: 13,
                    color: kMainGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

          if (editing) ...[
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "메모를 수정해보세요",
                filled: true,
                fillColor: const Color(0xFFF7F7F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.black26),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kMainGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(80, 40),
                ),
                child: const Text("저장"),
              ),
            ),
          ],
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
                    color: Colors.grey.shade300,
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
            width: 35,
            child: Text(
              "$pct%",
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
  final String memo;

  const _DayData({
    required this.date,
    required this.dist,
    required this.topKey,
    required this.feedback,
    this.memo = "",
  });

  factory _DayData.empty() => _DayData(
    date: DateTime.now(),
    dist: {for (final k in _ko.keys) k: 0.0},
    topKey: 'neutral',
    feedback: '감정 데이터가 없습니다.',
    memo: '',
  );
}
