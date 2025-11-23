//오늘의 감정 스크린
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';

const _keys = ['기쁨', '슬픔', '분노', '평온', '놀람'];

const _bgGradient = {
  '기쁨': [Color(0xFFFFF5DA), Colors.white],
  '슬픔': [Color(0xFFE9F1FF), Colors.white],
  '분노': [Color(0xFFFFE0E0), Colors.white],
  '평온': [Color(0xFFE9F7EA), Colors.white],
  '놀람': [Color(0xFFF3EDFF), Colors.white],
};

const _emotionColor = {
  '기쁨': Color(0xFFFFC135),
  '슬픔': Color(0xFF4BA9FF),
  '분노': Color(0xFFFF6F71),
  '평온': Color(0xFF79C68A),
  '놀람': Color(0xFF9B87FF),
};

IconData _emotionIcon(String emo) {
  switch (emo) {
    case '기쁨':
      return Icons.wb_sunny_rounded;
    case '슬픔':
      return Icons.water_drop_rounded;
    case '분노':
      return Icons.local_fire_department_rounded;
    case '놀람':
      return Icons.bolt_rounded;
    case '평온':
      return Icons.self_improvement_rounded;
    default:
      return Icons.circle_outlined;
  }
}

class TodayEmotionScreen extends StatefulWidget {
  final Map<String, dynamic>? result;
  const TodayEmotionScreen({super.key, this.result});

  @override
  State<TodayEmotionScreen> createState() => _TodayEmotionScreenState();
}

class _TodayEmotionScreenState extends State<TodayEmotionScreen> {
  late Future<_TodayData> _future;
  final TextEditingController _memoController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.result != null) {
      _future = Future.value(_fromAnalysisResult(widget.result!));
    } else {
      _future = _fetchToday();
    }
  }

  // 단어 감지
  List<String> _extractKeywords(String text) {
    if (text.isEmpty) return [];
    final patterns = [
      '피곤',
      '힘들',
      '불안',
      '기대',
      '화가',
      '짜증',
      '행복',
      '우울',
      '걱정',
      '긴장',
      '슬픔',
      '기쁨',
      '놀람',
      '분노',
    ];
    return patterns.where((p) => text.contains(p)).toList();
  }

  String _buildKeywordInsight(List<String> words) {
    if (words.isEmpty) return "";
    final counter = <String, int>{};
    for (var w in words) {
      counter[w] = (counter[w] ?? 0) + 1;
    }
    final sorted = counter.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sorted.first.value == 1) {
      return "감정 관련 단어가 고르게 분포되어 있었어요.";
    }
    return "반복적으로 등장한 감정 단어는 ‘${sorted.first.key}’ 입니다.";
  }

  // Node 분석결과 → 하루데이터 변환
  _TodayData _fromAnalysisResult(Map<String, dynamic> r) {
    final distRaw = Map<String, dynamic>.from(r['emotionData'] ?? {});

    final dist = <String, double>{
      '기쁨': (distRaw['기쁨'] ?? distRaw['joy'] ?? 0).toDouble(),
      '슬픔': (distRaw['슬픔'] ?? distRaw['sad'] ?? 0).toDouble(),
      '분노': (distRaw['분노'] ?? distRaw['anger'] ?? 0).toDouble(),
      '평온': (distRaw['평온'] ?? distRaw['neutral'] ?? 0).toDouble(),
      '놀람': (distRaw['놀람'] ?? distRaw['surprise'] ?? 0).toDouble(),
    };

    final topKey = _findTopKey(dist);
    final feedback = (r['gptFeedback'] ?? r['feedback'] ?? '')
        .toString()
        .trim();

    List<String> actions = [];
    if (r['actions'] is List) {
      actions = (r['actions'] as List).map((e) => e.toString()).toList();
    } else if (r['actions'] is String) {
      actions = r['actions']
          .toString()
          .split("\n")
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return _TodayData(
      dist: dist,
      topKey: topKey,
      summary: feedback,
      fullFeedback: feedback,
      actions: actions,
    );
  }

  // 오늘자 조회
  Future<_TodayData> _fetchToday() async {
    final res = await http.get(
      Uri.parse('$kBaseUrl/results/day?user_id=$kUserId'),
    );

    final decoded = jsonDecode(res.body);

    final distRaw = Map<String, dynamic>.from(
      decoded['avg_distribution'] ?? {},
    );

    final dist = <String, double>{
      '기쁨': (distRaw['기쁨'] ?? distRaw['joy'] ?? 0).toDouble(),
      '슬픔': (distRaw['슬픔'] ?? distRaw['sad'] ?? 0).toDouble(),
      '분노': (distRaw['분노'] ?? distRaw['anger'] ?? 0).toDouble(),
      '평온': (distRaw['평온'] ?? distRaw['neutral'] ?? 0).toDouble(),
      '놀람': (distRaw['놀람'] ?? distRaw['surprise'] ?? 0).toDouble(),
    };

    final topKey = _findTopKey(dist);
    final feedback = (decoded['feedback'] ?? '').toString().trim();

    List<String> actions = [];
    if (decoded['actions'] is List) {
      actions = (decoded['actions'] as List).map((e) => e.toString()).toList();
    } else if (decoded['actions'] is String) {
      actions = decoded['actions']
          .toString()
          .split("\n")
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return _TodayData(
      dist: dist,
      topKey: topKey,
      summary: feedback,
      fullFeedback: feedback,
      actions: actions,
    );
  }

  // 유틸
  String _findTopKey(Map<String, double> dist) =>
      dist.entries.reduce((a, b) => a.value > b.value ? a : b).key;

  // 추천 액션 UI
  List<Widget> _buildActionList(List<String> actions) {
    if (actions.isEmpty) {
      return [
        const Text(
          "GPT가 활동 추천을 생성하지 않았습니다.",
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
      ];
    }

    final a = List<String>.from(actions);

    while (a.length < 3) {
      a.add("추천 데이터를 불러오는 중...");
    }

    return [
      _ActionItem(text: a[0], highlight: true),
      const SizedBox(height: 12),
      _ActionItem(text: a[1]),
      const SizedBox(height: 12),
      _ActionItem(text: a[2]),
    ];
  }

  // UI
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TodayData>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: kMainGreen)),
          );
        }

        final d = snap.data!;
        final words = _extractKeywords(d.fullFeedback);
        final insight = _buildKeywordInsight(words);
        final grad = _bgGradient[d.topKey] ?? _bgGradient['평온']!;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.black87,
            title: const Text(
              "분석 완료",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: grad,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
                children: [
                  // 메인 감정 카드
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 28,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _emotionIcon(d.topKey),
                          size: 44,
                          color: _emotionColor[d.topKey],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          "오늘의 감정은 ‘${d.topKey}’ 입니다.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _emotionDescription(d.topKey),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: Colors.black87.withOpacity(0.75),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 감정 비율
                  const Text(
                    "감정 비율",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: _keys.map((k) {
                        final v = (d.dist[k] ?? 0).clamp(0, 100);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text(
                                    k,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    "${v.toStringAsFixed(0)}%",
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 16,
                                      color: Colors.grey.shade200,
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: v / 100,
                                      child: Container(
                                        height: 16,
                                        color: _emotionColor[k],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 전체 피드백
                  const Text(
                    "오늘의 감정 요약",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Text(
                      d.summary,
                      style: const TextStyle(fontSize: 15.5, height: 1.6),
                    ),
                  ),

                  // 단어 키워드
                  if (words.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const Text(
                      "단어 키워드",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "당신의 말에서 감지된 주요 감정 단어 👇",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: words
                                .map(
                                  (e) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kMainGreen.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      e,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          if (insight.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              "📌 $insight",
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),

                  // 활동 추천
                  const Text(
                    "활동 추천",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  ..._buildActionList(d.actions),

                  const SizedBox(height: 30),

                  // 메모
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '오늘의 메모',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _memoController,
                          maxLines: 4,
                          cursorColor: kMainGreen,
                          decoration: InputDecoration(
                            hintText: '오늘 하루를 기록해보세요. 캘린더에 저장돼요! ✏️',
                            filled: true,
                            fillColor: const Color(0xFFF9FAF9),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFC8D3C1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: kMainGreen,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: SizedBox(
                            width: 160,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveMemo,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kMainGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.3,
                                      ),
                                    )
                                  : const Text(
                                      '저장하기',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
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

  String _emotionDescription(String emo) {
    switch (emo) {
      case '기쁨':
        return "따뜻한 기분이 느껴지는 하루였어요.";
      case '슬픔':
        return "마음이 조금 무거운 하루였네요.";
      case '분노':
        return "감정이 예민했던 순간이 있었어요.";
      case '평온':
        return "잔잔하고 안정된 하루였어요.";
      case '놀람':
        return "뜻밖의 일이 있었던 하루였어요.";
      default:
        return "다양한 감정이 함께한 하루였어요.";
    }
  }

  Future<void> _saveMemo() async {
    setState(() => _isSaving = true);

    final memo = _memoController.text.trim();

    // 오늘 날짜 yyyy-MM-dd (캘린더와 완전 동일 형식)
    final now = DateTime.now();
    final dateStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    await http.post(
      Uri.parse('$kBaseUrl/memo/save'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': kUserId,
        'memo': memo.isEmpty ? "(메모 없음)" : memo,
        'date': dateStr,
      }),
    );

    setState(() => _isSaving = false);
    Navigator.pop(context);
  }
}

// 추천 액션 카드
class _ActionItem extends StatelessWidget {
  final String text;
  final bool highlight;

  const _ActionItem({required this.text, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? kMainGreen : Colors.black12,
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (highlight)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: kMainGreen.withOpacity(.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: kMainGreen),
              ),
              child: const Text(
                '추천',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: kMainGreen,
                ),
              ),
            )
          else
            const Icon(
              Icons.check_circle_outline,
              color: Colors.black45,
              size: 20,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 데이터 모델
class _TodayData {
  final Map<String, double> dist;
  final String topKey;
  final String summary;
  final String fullFeedback;
  final List<String> actions;

  _TodayData({
    required this.dist,
    required this.topKey,
    required this.summary,
    required this.fullFeedback,
    required this.actions,
  });
}
