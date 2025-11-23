// analysis_result_screen.dart
/*
import 'package:flutter/material.dart';
import 'today_emotion_screen.dart';

class AnalysisResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  const AnalysisResultScreen({super.key, required this.result});

  static const mainGreen = Color(0xFF859A7E);

  static const _screenGradients = {
    '기쁨': [Color(0xFFFFF5DA), Colors.white],
    '슬픔': [Color(0xFFE9F1FF), Colors.white],
    '분노': [Color(0xFFFFE0E0), Colors.white],
    '평온': [Color(0xFFE9F7EA), Colors.white],
    '놀람': [Color(0xFFF3EDFF), Colors.white],
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

  static const emotionColors = {
    '기쁨': Color(0xFFFFC135),
    '슬픔': Color(0xFF4BA9FF),
    '분노': Color(0xFFFF6F71),
    '평온': Color(0xFF79C68A),
    '놀람': Color(0xFF9B87FF),
  };

  Color _color(String k) => emotionColors[k] ?? Colors.grey;

  String _emotionKo(dynamic v) {
    switch (v.toString().toLowerCase()) {
      case 'joy':
        return '기쁨';
      case 'sad':
        return '슬픔';
      case 'anger':
        return '분노';
      case 'surprise':
        return '놀람';
      case 'neutral':
        return '평온';
      default:
        return v.toString();
    }
  }

  Widget buildMainEmotionCard(String emotionKo) {
    final iconColor = emotionColors[emotionKo] ?? Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(_emotionIcon(emotionKo), size: 42, color: iconColor),
          const SizedBox(height: 14),
          Text(
            "오늘의 감정은 ‘$emotionKo’ 입니다.",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            _emotionDescription(emotionKo),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.black87.withOpacity(0.75),
            ),
          ),
        ],
      ),
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

  Widget _bar(String label, double v) {
    v = v.clamp(0, 100);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                "${v.toStringAsFixed(0)}%",
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 18, color: Colors.grey.shade200),
                FractionallySizedBox(
                  widthFactor: v / 100,
                  child: Container(height: 18, color: _color(label)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _stripActions(String? raw) {
    if (raw == null) return '';
    final regex = RegExp(r'^행동\s*[1-3]\s*[:：].*$', multiLine: true);
    final cleaned = raw.replaceAll(regex, '');
    return cleaned
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join('\n');
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    if (raw.containsKey('emotionData')) return raw;

    final r = raw['result'] ?? raw;
    final dist =
        r['fused']?['distribution'] ??
        r['face']?['distribution'] ??
        r['text']?['distribution'] ??
        {'joy': 0, 'sad': 0, 'anger': 0, 'neutral': 0, 'surprise': 0};

    final mapped = {
      '기쁨': (dist['joy'] ?? 0) * 100,
      '슬픔': (dist['sad'] ?? 0) * 100,
      '분노': (dist['anger'] ?? 0) * 100,
      '놀람': (dist['surprise'] ?? 0) * 100,
      '평온': (dist['neutral'] ?? 0) * 100,
    };

    final sorted = mapped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'emotionData': mapped,
      'mainEmotion': sorted.first.key,
      'gptFeedback': r['feedback'] ?? '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final norm = _normalize(result);
    final ed = Map<String, double>.from(norm['emotionData']);
    final mainKo = _emotionKo(norm['mainEmotion']);
    final feedback = _stripActions(norm['gptFeedback']);

    final grad = _screenGradients[mainKo] ?? _screenGradients['평온']!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text(
          "분석 결과",
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
            padding: const EdgeInsets.all(16),
            children: [
              buildMainEmotionCard(mainKo),

              const SizedBox(height: 24),
              const Text(
                "감정 비율",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
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

              if (feedback.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  "피드백",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 24,
                        color: emotionColors[mainKo],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          feedback,
                          style: const TextStyle(fontSize: 15.5, height: 1.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () =>
                          Navigator.of(context).popUntil((r) => r.isFirst),
                      child: const Text("다시 찍기"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: mainGreen,
                        side: const BorderSide(color: mainGreen, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TodayEmotionScreen(result: norm),
                          ),
                        );
                      },
                      child: const Text("다음"),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}*/
