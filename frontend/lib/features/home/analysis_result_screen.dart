// analysis_result_screen.dart
// 감정 분석 결과 화면
import 'package:flutter/material.dart';
import 'today_emotion_screen.dart';

class AnalysisResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  const AnalysisResultScreen({super.key, required this.result});

  static const mainGreen = Color(0xFF859A7E);

  String _pct(double v) => '${v.toStringAsFixed(0)}%';

  Color _color(String k) {
    switch (k) {
      case '기쁨':
        return const Color(0xFFFFD166);
      case '슬픔':
        return const Color(0xFF74C2FF);
      case '분노':
        return const Color(0xFFF6A5B2);
      case '놀람':
        return const Color(0xFFBBA7FF);
      case '평온':
        return const Color(0xFFBDE4B1);
      default:
        return Colors.blueGrey.shade300;
    }
  }

  Widget _bar(String label, double v) {
    v = v.clamp(0, 100);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              Text(label),
              const Spacer(),
              Text(_pct(v), style: const TextStyle(color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 10, color: Colors.grey.shade200),
                FractionallySizedBox(
                  widthFactor: v / 100.0,
                  child: Container(height: 10, color: _color(label)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ 피드백 문장에서 "행동 1~3" 제거
  String _stripActions(String? raw) {
    if (raw == null) return '';
    final regex = RegExp(r'^행동\s*[1-3]\s*[:：].*$', multiLine: true);
    final cleaned = raw.replaceAll(regex, '');
    final lines = cleaned
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return lines.join('\n');
  }

  // ✅ GPT 원문 + 정제본 모두 포함시켜서 다음 화면에 넘김
  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    // Node or Flask의 구조에 맞게 표준화
    if (raw.containsKey('emotionData') && raw.containsKey('mainEmotion')) {
      return {
        'emotionData': Map<String, double>.from(raw['emotionData']),
        'mainEmotion': raw['mainEmotion'] ?? '불확실',
        'gptFeedback': raw['gptFeedback'] ?? '',
        'music': raw['music'] ?? [],
      };
    }

    final r = raw['result'] ?? raw;
    final fused = (r['fused'] ?? {}) as Map<String, dynamic>;
    final dist =
        fused['distribution'] ??
        (r['face']?['distribution'] ??
            r['text']?['distribution'] ??
            {'joy': 0, 'sad': 0, 'anger': 0, 'neutral': 0, 'surprise': 0});

    final Map<String, double> emotionData = {
      '기쁨': (dist['joy'] ?? 0) * 100,
      '슬픔': (dist['sad'] ?? 0) * 100,
      '분노': (dist['anger'] ?? 0) * 100,
      '놀람': (dist['surprise'] ?? 0) * 100,
      '평온': (dist['neutral'] ?? 0) * 100,
    };

    final sorted = emotionData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final mainKo = sorted.first.key;

    final gptFeedback = (r['feedback'] ?? '') as String;
    final music = (r['music'] ?? raw['music'] ?? []) as List;

    return {
      'emotionData': emotionData,
      'mainEmotion': mainKo,
      'gptFeedback': gptFeedback, // 원문 (행동 포함)
      'music': music,
    };
  }

  @override
  Widget build(BuildContext context) {
    final norm = _normalize(result);
    final ed = Map<String, double>.from(norm['emotionData']);
    final mainKo = norm['mainEmotion'];
    final gptRaw = (norm['gptFeedback'] ?? '') as String;
    final gptSummaryOnly = _stripActions(gptRaw); // 피드백 요약만

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('분석 완료'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '감정 분석 결과',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // 감정 분포 바 그래프
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                _bar('기쁨', ed['기쁨'] ?? 0),
                _bar('슬픔', ed['슬픔'] ?? 0),
                _bar('분노', ed['분노'] ?? 0),
                _bar('놀람', ed['놀람'] ?? 0),
                _bar('평온', ed['평온'] ?? 0),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ✅ 피드백 (행동 제외)
          if (gptSummaryOnly.isNotEmpty) ...[
            const Text(
              '피드백',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.chat_bubble_outline, color: Colors.black87),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      gptSummaryOnly, // ✅ 행동 제거된 요약만 출력
                      style: const TextStyle(height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 버튼 2개 (다시 찍기 / 다음)
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('다시 찍기'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TodayEmotionScreen(result: norm), // ✅ 원본 전달
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: mainGreen,
                    side: const BorderSide(color: mainGreen, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('다음'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
