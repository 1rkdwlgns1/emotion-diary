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
              Text(label, style: const TextStyle(fontSize: 15)),
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

  /// GPT 피드백에서 행동 문장 제거
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

  /// 서버 응답 데이터 정규화
  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    // ✅ Node 중계형 구조 (Flutter에서 바로 받은 경우)
    if (raw.containsKey('emotionData') && raw.containsKey('mainEmotion')) {
      return {
        'emotionData': Map<String, double>.from(raw['emotionData'] as Map),
        'mainEmotion': (raw['mainEmotion'] as String?) ?? '불확실',
        'gptFeedback': (raw['gptFeedback'] ?? raw['feedback'] ?? '') as String,
        'confidence': (raw['confidence'] as num?)?.toDouble() ?? 0.0,
        'user_id': raw['user_id'],
        'media_id': raw['media_id'],
      };
    }

    // ✅ Flask 원본 구조
    final Map<String, dynamic> r = raw['result'] is Map
        ? Map<String, dynamic>.from(raw['result'])
        : raw;

    final type = (r['type'] ?? '') as String;
    Map<String, dynamic> dist = {};

    if (type == 'video') {
      final fused = (r['fused'] ?? {}) as Map<String, dynamic>;
      dist = (fused['distribution'] ??
              fused['fused'] ??
              r['face']?['distribution'] ??
              r['text']?['distribution'] ??
              {}) as Map<String, dynamic>;
    } else if (type == 'audio') {
      dist = (r['text']?['distribution'] ?? {}) as Map<String, dynamic>;
    } else if (type == 'image') {
      dist = (r['face']?['distribution'] ?? {}) as Map<String, dynamic>;
    }

    double _toPct(num v) =>
        (v.toDouble() <= 1.001 ? v.toDouble() * 100.0 : v.toDouble())
            .clamp(0, 100);
    final Map<String, double> emotionData = {
      '기쁨': _toPct(dist['joy'] ?? 0),
      '슬픔': _toPct(dist['sad'] ?? 0),
      '분노': _toPct(dist['anger'] ?? 0),
      '놀람': _toPct(dist['surprise'] ?? 0),
      '평온': _toPct(dist['neutral'] ?? 0),
    };

    String mainKo = '불확실';
    if (emotionData.values.any((v) => v > 0)) {
      final s = emotionData.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      mainKo = s.first.key;
    }

    return {
      'emotionData': emotionData,
      'mainEmotion': mainKo,
      'gptFeedback': (r['feedback'] ?? '') as String,
      'confidence': (r['fused']?['confidence'] as num?)?.toDouble() ?? 0.0,
      'user_id': raw['context']?['user_id'] ??
          raw['userId'] ??
          r['user_id'] ??
          r['context']?['user_id'],
      'media_id': raw['context']?['media_id'] ??
          raw['mediaId'] ??
          r['media_id'] ??
          r['context']?['media_id'],
    };
  }

  @override
  Widget build(BuildContext context) {
    final norm = _normalize(result);
    final Map<String, double> ed =
        Map<String, double>.from(norm['emotionData'] as Map);
    final mainKo = norm['mainEmotion'] as String;
    final String gptRaw = (norm['gptFeedback'] as String?) ?? '';
    final String gptSummaryOnly = _stripActions(gptRaw);

    final userId = norm['user_id'];
    final mediaId = norm['media_id'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('분석 결과'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ----- 메인 감정 타이틀 -----
          Center(
            child: Text(
              '오늘의 감정: $mainKo',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: mainGreen,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ----- 감정 분포 바 그래프 -----
          const Text(
            '감정 분석 결과',
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

          // ----- GPT 피드백 -----
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
                      gptSummaryOnly,
                      style: const TextStyle(height: 1.6, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ----- 버튼 -----
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
                        builder: (_) => TodayEmotionScreen(
                          userId: userId,
                          mediaId: mediaId,
                          mainEmotion: mainKo,
                          feedback: gptSummaryOnly,
                          emotionDist: {
                            'joy': (ed['기쁨'] ?? 0) / 100.0,
                            'sad': (ed['슬픔'] ?? 0) / 100.0,
                            'anger': (ed['분노'] ?? 0) / 100.0,
                            'surprise': (ed['놀람'] ?? 0) / 100.0,
                            'neutral': (ed['평온'] ?? 0) / 100.0,
                          },
                        ),
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
