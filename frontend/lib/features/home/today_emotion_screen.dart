import 'dart:convert';
import 'dart:io' show HttpDate;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// ==== 서버 환경 ====
const String kBaseUrl = 'http://10.0.2.2:5001';
/*const String kBaseUrl = 'http://10.11.26.62:5001';*/
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

// 감정 칩 컬러(배경/테두리 텍스트)
const _chipBg = {
  'joy': Color(0xFFFFF6D8), // 연노랑
  'sad': Color(0xFFEAF4FF), // 연파랑
  'anger': Color(0xFFFFEEF0), // 연핑크
  'neutral': Color(0xFFF3FAEE), // 연연두
  'surprise': Color(0xFFF1EBFF), // 연보라
};
const _chipBorder = {
  'joy': Color(0xFFFFCF66),
  'sad': Color(0xFF70B9FF),
  'anger': Color(0xFFFF8AA0),
  'neutral': Color(0xFFBDE4B1),
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

class TodayEmotionScreen extends StatefulWidget {
  const TodayEmotionScreen({super.key});

  @override
  State<TodayEmotionScreen> createState() => _TodayEmotionScreenState();
}

class _TodayEmotionScreenState extends State<TodayEmotionScreen> {
  late Future<_TodayData> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchToday();
  }

  // ====== 네트워크 & 가공 ======
  Future<_TodayData> _fetchToday() async {
    String _fmt(DateTime d) =>
        "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    final day = _fmt(DateTime.now());

    // 1) 오늘 분석들 조회
    final uriDay = Uri.parse(
      '$kBaseUrl/results/day?date=$day&user_id=$kUserId',
    );
    final r1 = await http.get(uriDay);
    if (r1.statusCode != 200) {
      throw Exception('HTTP ${r1.statusCode}: ${r1.body}');
    }
    final List raw = jsonDecode(r1.body);
    final items = raw.map((j) => _Item.fromJson(j)).toList();

    // 평균 분포
    Map<String, double> dist = {for (final k in _keys) k: 0.0};
    int n = 0;
    String? latestFeedback;
    for (final it in items) {
      final e = it.emotion;
      final fused =
          (e['fused']?['distribution']) ??
          (e['text']?['distribution']) ??
          (e['face']?['distribution']);
      if (fused is Map) {
        for (final k in _keys) {
          final v = fused[k];
          if (v is num) dist[k] = dist[k]! + v.toDouble();
        }
        n += 1;
      }
      if (e['feedback'] is String &&
          (e['feedback'] as String).trim().isNotEmpty) {
        latestFeedback = e['feedback'];
      }
    }
    if (n > 0) {
      for (final k in _keys) {
        dist[k] = (dist[k]! / n).clamp(0.0, 1.0);
      }
    } else {
      dist['neutral'] = 1.0;
    }

    // 최상위 감정
    String topKey = _keys.first;
    double best = -1;
    for (final k in _keys) {
      if (dist[k]! > best) {
        best = dist[k]!;
        topKey = k;
      }
    }

    // 요약(3줄) + 원문(모달용)
    final hasFeedback =
        (latestFeedback != null &&
        latestFeedback!.toString().trim().isNotEmpty);
    final fullFeedback = hasFeedback
        ? latestFeedback!.toString()
        : _defaultSummary(dist, topKey);
    final summary = _shortenTo3Lines(_stripActions(fullFeedback));

    // 2) 오늘 감정 기반 음악 추천
    final uriMusic = Uri.parse(
      '$kBaseUrl/recommend/music?day=$day&user_id=$kUserId&count=3',
    );
    final r2 = await http.get(uriMusic);
    if (r2.statusCode != 200) {
      throw Exception('음악 추천 실패: HTTP ${r2.statusCode}');
    }
    final m2 = jsonDecode(r2.body) as Map<String, dynamic>;
    final List songs = (m2['items'] ?? []) as List;
    final music = songs
        .map((e) => _Song.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    // 3) 활동 추천: feedback에서 추출 → 없으면 감정별 기본 추천
    var actions = _extractActions(fullFeedback);
    if (actions.isEmpty) {
      actions = _fallbackActions(topKey);
    }

    return _TodayData(
      dist: dist,
      topKey: topKey,
      summary: summary,
      fullFeedback: fullFeedback,
      songs: music,
      actions: actions,
    );
  }

  // 오늘 화면에서는 행동 문장 제거(본문용)
  String _stripActions(String s) {
    if (s.isEmpty) return s;
    final lines = s.split('\n');
    final keep = <String>[];
    for (final ln in lines) {
      final t = ln.trimLeft();
      if (RegExp(
        r'^(행동\s*\d+[:\.]|Action\s*\d+[:\.]|- \[[ xX]\])',
        caseSensitive: false,
      ).hasMatch(t))
        continue;
      if (t.startsWith('행동:') ||
          t.startsWith('추천 행동') ||
          t.startsWith('실천 팁') ||
          t.startsWith('Action:'))
        continue;
      keep.add(ln);
    }
    while (keep.isNotEmpty && keep.last.trim().isEmpty) {
      keep.removeLast();
    }
    return keep.join('\n').trim();
  }

  // 활동 문장만 뽑기
  List<String> _extractActions(String s) {
    if (s.isEmpty) return [];
    final out = <String>[];
    for (final ln in s.split('\n')) {
      final t = ln.trim();
      final m = RegExp(
        r'^(행동\s*\d+[:\.]\s*)(.+)$',
        caseSensitive: false,
      ).firstMatch(t);
      if (m != null) {
        out.add(m.group(2)!.trim());
        continue;
      }
      if (RegExp(r'^(- \[[ xX]\]|•)\s*(.+)$').hasMatch(t)) {
        out.add(t.replaceFirst(RegExp(r'^(- \[[ xX]\]|•)\s*'), '').trim());
      }
    }
    return out;
  }

  // 감정별 기본 액션
  List<String> _fallbackActions(String key) {
    switch (key) {
      case 'joy':
        return ['좋았던 순간을 메모로 남기기', '가벼운 산책하며 기분 유지하기'];
      case 'sad':
        return ['따뜻한 차 마시며 휴식하기', '친한 사람에게 짧은 안부 메시지 보내기'];
      case 'anger':
        return ['5분 복식호흡으로 긴장 풀기', '빠르게 걷기/가벼운 스트레칭 10분'];
      case 'surprise':
        return ['새로운 음악 한 곡 탐색하기', '오늘의 놀란 순간 간단 기록하기'];
      case 'neutral':
      default:
        return ['짧은 스트레칭으로 몸 깨우기', '좋아하는 음악 1곡 듣기'];
    }
  }

  // 기본 요약문 (GPT 피드백이 없을 때)
  String _defaultSummary(Map<String, double> dist, String topKey) {
    const emotionMsg = {
      'joy': '오늘은 기쁨이 두드러진 하루예요. 긍정 에너지를 잘 유지해 보세요.',
      'sad': '슬픔이 느껴지는 날이에요. 스스로를 탓하지 말고 가볍게 쉬어가도 괜찮아요.',
      'anger': '분노가 조금 있는 날이에요. 깊게 숨을 쉬며 긴장을 풀어 보세요.',
      'neutral': '평온한 감정이 가장 강하네요. 안정적인 흐름이 느껴져요.',
      'surprise': '놀람이 보이는 하루였네요. 새로운 경험을 가볍게 기록해보면 좋아요.',
    };
    return emotionMsg[topKey] ?? '오늘의 감정을 분석했어요. 마음을 천천히 돌아보며 편안한 하루를 보내세요.';
  }

  // 3줄로 축약
  String _shortenTo3Lines(String s) {
    final oneLine = s
        .replaceAll('\r', '')
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(' ');
    final words = oneLine.split(RegExp(r'\s+'));
    final buf = <String>[];
    int cnt = 0;
    for (final w in words) {
      buf.add(w);
      cnt++;
      if (cnt >= 45) break; // 대략 3줄
    }
    var out = buf.join(' ');
    if (out.length < oneLine.length) out += '…';
    return out;
  }

  String _pct(num v) => '${(v * 100).toStringAsFixed(0)}%';

  // =========== UI ===========
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TodayData>(
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

        return Scaffold(
          appBar: AppBar(
            title: const Text('오늘의 감정'),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0.5,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 헤더
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '주요 감정 : ${_ko[d.topKey]}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _pct(d.dist[d.topKey]!),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        children: _keys
                            .map(
                              (k) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                margin: const EdgeInsets.only(
                                  right: 8,
                                  bottom: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _chipBg[k],
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: _chipBorder[k]!),
                                ),
                                child: Text('${_ko[k]} ${_pct(d.dist[k]!)}'),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 요약 (3줄 + '자세히')
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          d.summary,
                          style: const TextStyle(
                            color: Colors.black87,
                            height: 1.5,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ===== 추천 음악 (접기/펼치기) =====
                _MusicSection(songs: d.songs),

                const SizedBox(height: 18),

                // ===== 활동 추천 =====
                const Text(
                  '활동 추천',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ..._buildActionList(d.actions),

                const SizedBox(height: 22),

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
        );
      },
    );
  }

  List<Widget> _buildActionList(List<String> actions) {
    if (actions.isEmpty)
      return [const _ActionChip(text: '오늘 실행할 작은 행동을 하나 정해보세요.')];
    final out = <Widget>[];
    for (int i = 0; i < actions.length; i++) {
      out.add(
        _ActionChip(
          text: actions[i],
          highlight: i == 0, // 첫 항목 강추
        ),
      );
    }
    return out;
  }
}

// ===== 음악 섹션(접기/펼치기) =====
class _MusicSection extends StatelessWidget {
  final List<_Song> songs;
  const _MusicSection({required this.songs});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: kMainGreen, width: 1.2), // 버튼색 테두리
          borderRadius: BorderRadius.circular(12),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          title: const Text(
            '추천 음악',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            if (songs.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  '지금은 추천 곡이 없어요. 잠시 후 다시 시도해 주세요.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ...songs.map((s) => _SongTile(song: s)).toList(),
          ],
        ),
      ),
    );
  }
}

// ===== 내부 위젯들 =====
class _Song {
  final String title;
  final String artist;
  final String? link;
  final String? reason;
  _Song({required this.title, required this.artist, this.link, this.reason});
  factory _Song.fromMap(Map<String, dynamic> m) => _Song(
    title: (m['title'] ?? '').toString(),
    artist: (m['artist'] ?? '').toString(),
    link: (m['link'] ?? '').toString(),
    reason: (m['reason'] ?? '').toString(),
  );
}

class _SongTile extends StatelessWidget {
  final _Song song;
  const _SongTile({required this.song});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kMainGreen, width: 1.2), // 버튼색과 동일
      ),
      child: Row(
        children: [
          const Icon(Icons.music_note, size: 24, color: Colors.black87),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${song.title} - ${song.artist}",
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (song.reason != null && song.reason!.isNotEmpty)
                  Text(
                    song.reason!,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 34,
            child: OutlinedButton(
              onPressed: () async {
                if (song.link == null || song.link!.isEmpty) return;
                final uri = Uri.parse(song.link!);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kMainGreen, width: 1.2),
                foregroundColor: kMainGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('듣기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String text;
  final bool highlight;
  const _ActionChip({required this.text, this.highlight = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? kMainGreen : Colors.black12,
          width: 1.2,
        ),
        boxShadow: highlight
            ? const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (highlight)
            Container(
              margin: const EdgeInsets.only(right: 8, top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: kMainGreen.withOpacity(.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: kMainGreen, width: 1.0),
              ),
              child: const Text(
                '강추',
                style: TextStyle(
                  color: kMainGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            )
          else
            const Icon(Icons.check_circle_outline, color: Colors.black87),
          if (!highlight) const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _TodayData {
  final Map<String, double> dist;
  final String topKey;
  final String summary; // 3줄 축약
  final String fullFeedback; // 원문(모달용)
  final List<_Song> songs;
  final List<String> actions;
  _TodayData({
    required this.dist,
    required this.topKey,
    required this.summary,
    required this.fullFeedback,
    required this.songs,
    required this.actions,
  });
}
