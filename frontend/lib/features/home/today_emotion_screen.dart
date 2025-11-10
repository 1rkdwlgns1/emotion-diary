import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// ==== 서버 환경 ====
const String kBaseUrl = 'http://10.0.2.2:3000'; // ✅ Node 서버 (감정, 피드백 등)
const String kFlaskUrl = 'http://10.0.2.2:5001'; // ✅ Flask 서버 (음악 추천만)

const String kUserId = 'anon';
const Color kMainGreen = Color(0xFF859A7E);

const _keys = ['기쁨', '슬픔', '분노', '평온', '놀람'];

// 감정 칩 색상
const _chipBg = {
  '기쁨': Color(0xFFFFF6D8),
  '슬픔': Color(0xFFEAF4FF),
  '분노': Color(0xFFFFEEF0),
  '평온': Color(0xFFF3FAEE),
  '놀람': Color(0xFFF1EBFF),
};
const _chipBorder = {
  '기쁨': Color(0xFFFFCF66),
  '슬픔': Color(0xFF70B9FF),
  '분노': Color(0xFFFF8AA0),
  '평온': Color(0xFFBDE4B1),
  '놀람': Color(0xFFBBA7FF),
};

String _youtubeSearchUrl(String title, String artist) {
  final q = Uri.encodeComponent('$title $artist official audio');
  return 'https://m.youtube.com/results?search_query=$q';
}

String _normalizeYouTubeLink(String url) {
  final s1 = RegExp(r'youtube\.com/shorts/([A-Za-z0-9_-]{6,})').firstMatch(url);
  if (s1 != null) return 'https://m.youtube.com/watch?v=${s1.group(1)!}';
  final s2 = RegExp(r'youtu\.be/([A-Za-z0-9_-]{6,})').firstMatch(url);
  if (s2 != null) return 'https://m.youtube.com/watch?v=${s2.group(1)!}';
  return url;
}

// ===== 메인 위젯 =====
class TodayEmotionScreen extends StatefulWidget {
  final Map<String, dynamic>? result;
  const TodayEmotionScreen({super.key, this.result});

  @override
  State<TodayEmotionScreen> createState() => _TodayEmotionScreenState();
}

class _TodayEmotionScreenState extends State<TodayEmotionScreen> {
  late Future<_TodayData> _future;
  List<_Song> _songs = [];

  @override
  void initState() {
    super.initState();
    if (widget.result != null) {
      _future = Future.value(_fromAnalysisResult(widget.result!));
    } else {
      _future = _fetchToday();
    }
  }

  _TodayData _fromAnalysisResult(Map<String, dynamic> r) {
    final distRaw = Map<String, dynamic>.from(r['emotionData'] ?? {});
    final dist = {
      '기쁨': ((distRaw['기쁨'] ?? distRaw['joy'] ?? 0) as num).toDouble(),
      '슬픔': ((distRaw['슬픔'] ?? distRaw['sad'] ?? 0) as num).toDouble(),
      '분노': ((distRaw['분노'] ?? distRaw['anger'] ?? 0) as num).toDouble(),
      '평온': ((distRaw['평온'] ?? distRaw['neutral'] ?? 0) as num).toDouble(),
      '놀람': ((distRaw['놀람'] ?? distRaw['surprise'] ?? 0) as num).toDouble(),
    };

    final topKey = _findTopKey(dist);

    final feedback =
        (r['gptFeedback'] ??
                r['feedback'] ??
                r['result']?['gptFeedback'] ??
                r['result']?['feedback'] ??
                '')
            .toString()
            .trim();

    final summary = _shortenTo3Lines(_stripActions(feedback));

    final actionsRaw = r['actions'] ?? r['result']?['actions'] ?? [];
    final actions = (actionsRaw is List && actionsRaw.isNotEmpty)
        ? actionsRaw.map((e) => e.toString()).toList()
        : _extractActions(feedback).isNotEmpty
        ? _extractActions(feedback)
        : _fallbackActions(topKey);

    final musicRaw =
        r['music'] ??
        r['result']?['music'] ??
        r['flaskResponse']?['result']?['music'] ??
        r['flaskResponse']?['music'] ?? // ✅ 이 줄 추가
        [];

    final songs = _parseMusicList(musicRaw);

    return _TodayData(
      dist: dist,
      topKey: topKey,
      summary: summary,
      fullFeedback: feedback,
      songs: songs,
      actions: actions,
    );
  }

  // ✅ Node + Flask 통합
  Future<_TodayData> _fetchToday() async {
    final uri = Uri.parse('$kBaseUrl/results/day?user_id=$kUserId');
    final res = await http.get(uri);
    debugPrint("🎧 Node 응답: ${res.body}");

    if (res.statusCode != 200) throw Exception('서버 오류: ${res.statusCode}');

    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
      if (decoded is String) decoded = jsonDecode(decoded);
    } catch (err) {
      debugPrint("⚠️ JSON decode 오류: $err");
      decoded = {};
    }

    if (decoded == null || decoded['avg_distribution'] == null) {
      throw Exception('결과 없음');
    }

    final distRaw = Map<String, dynamic>.from(
      decoded['avg_distribution'] ?? {},
    );
    final dist = {
      '기쁨': ((distRaw['기쁨'] ?? distRaw['joy'] ?? 0) as num).toDouble(),
      '슬픔': ((distRaw['슬픔'] ?? distRaw['sad'] ?? 0) as num).toDouble(),
      '분노': ((distRaw['분노'] ?? distRaw['anger'] ?? 0) as num).toDouble(),
      '평온': ((distRaw['평온'] ?? distRaw['neutral'] ?? 0) as num).toDouble(),
      '놀람': ((distRaw['놀람'] ?? distRaw['surprise'] ?? 0) as num).toDouble(),
    };

    final topKey = _findTopKey(dist);
    final feedback = (decoded['latest_feedback'] ?? decoded['feedback'] ?? '')
        .toString()
        .trim();
    final summary = _shortenTo3Lines(_stripActions(feedback));

    // ✅ actions 복원
    List<String> actions = [];
    final rawActions = decoded['actions'];
    try {
      if (rawActions is List) {
        actions = rawActions.map((e) => e.toString()).toList();
      } else if (rawActions != null) {
        final parsed = jsonDecode(jsonEncode(rawActions));
        if (parsed is List) actions = parsed.map((e) => e.toString()).toList();
      }
    } catch (err) {
      debugPrint("⚠️ actions 복원 오류: $err");
    }

    if (actions.isEmpty) {
      actions = _extractActions(feedback);
      if (actions.isEmpty) actions = _fallbackActions(topKey);
    }

    // 🎵 Node DB 음악 복원
    final musicRaw = decoded['music'];
    List<_Song> songs = _parseMusicList(musicRaw);

    // 🎵 Flask 음악 추천 (보조용)
    if (songs.isEmpty) {
      try {
        final flaskRes = await http.post(
          Uri.parse('$kFlaskUrl/recommend/music'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'distribution': distRaw}),
        );
        if (flaskRes.statusCode == 200) {
          final decoded = jsonDecode(flaskRes.body);
          if (decoded['ok'] == true && decoded['music'] != null) {
            songs = _parseMusicList(decoded['music']);
            debugPrint("🎵 Flask 추천 ${songs.length}곡 수신 완료");
          }
        }
      } catch (err) {
        debugPrint("⚠️ Flask 음악 추천 실패: $err");
      }
    }

    //setState(() {
    //_songs = songs;
    // });
    debugPrint("📦 최종 songs count(setState 후): ${songs.length}");

    return _TodayData(
      dist: dist,
      topKey: topKey,
      summary: summary,
      fullFeedback: feedback,
      songs: songs,
      actions: actions,
    );
  }

  // ✅ music 파싱
  List<_Song> _parseMusicList(dynamic musicRaw) {
    try {
      if (musicRaw == null) return [];

      // ✅ 1. 문자열(JSON-like) 형태인 경우
      if (musicRaw is String && musicRaw.trim().isNotEmpty) {
        var txt = musicRaw.trim();

        // ``` 제거
        txt = txt
            .replaceAll(RegExp(r'```[a-zA-Z]*'), '')
            .replaceAll('```', '')
            .trim();

        // ✅ JSON 배열이 아니면 강제로 배열로 감싸기
        if (!txt.startsWith('[')) txt = '[$txt]';

        // ✅ 작은따옴표(') → 큰따옴표(") 치환
        txt = txt.replaceAll("'", '"');

        debugPrint('🧩 musicRaw (fixed JSON): $txt');
        final parsed = jsonDecode(txt);

        if (parsed is List) {
          return parsed
              .map<_Song>((e) {
                final map = Map<String, dynamic>.from(e);
                return _Song.fromMap(map);
              })
              .where((s) => s.title.isNotEmpty && s.artist.isNotEmpty)
              .toList();
        }
      }

      // ✅ 2. 이미 List<Map> 형태인 경우
      if (musicRaw is List) {
        return musicRaw
            .map<_Song>((e) {
              final map = Map<String, dynamic>.from(jsonDecode(jsonEncode(e)));
              return _Song.fromMap(map);
            })
            .where((s) => s.title.isNotEmpty && s.artist.isNotEmpty)
            .toList();
      }
    } catch (err) {
      debugPrint('💥 music 파싱 오류: $err');
    }
    return [];
  }

  // ===== 유틸 =====
  String _findTopKey(Map<String, double> dist) {
    String best = '평온';
    double maxVal = -1;
    dist.forEach((k, v) {
      if (v > maxVal) {
        maxVal = v;
        best = k;
      }
    });
    return best;
  }

  String _shortenTo3Lines(String s) {
    final oneLine = s
        .replaceAll('\r', '')
        .split('\n')
        .map((e) => e.trim())
        .join(' ');
    if (oneLine.length <= 80) return oneLine;
    return '${oneLine.substring(0, 80)}...';
  }

  String _stripActions(String s) {
    if (s.isEmpty) return s;
    final lines = s.split('\n');
    final keep = <String>[];
    for (final ln in lines) {
      if (RegExp(r'^(행동|Action)\s*\d+', caseSensitive: false).hasMatch(ln))
        continue;
      keep.add(ln);
    }
    return keep.join('\n').trim();
  }

  List<String> _extractActions(String s) {
    if (s.isEmpty) return [];
    final out = <String>[];
    for (final ln in s.split('\n')) {
      final m = RegExp(
        r'^(행동\s*\d+[:\.]\s*)(.+)$',
        caseSensitive: false,
      ).firstMatch(ln);
      if (m != null) out.add(m.group(2)!.trim());
    }
    return out;
  }

  List<String> _fallbackActions(String key) {
    switch (key) {
      case '기쁨':
        return ['좋았던 순간 기록하기', '가벼운 산책하기', '친구에게 감사 인사하기'];
      case '슬픔':
        return ['따뜻한 차 마시며 휴식하기', '좋은 기억 떠올리기', '일기를 써보기'];
      case '분노':
        return ['복식호흡으로 진정하기', '스트레칭 10분', '산책하며 생각 정리하기'];
      case '놀람':
        return ['오늘의 놀람 기록하기', '새로운 음악 듣기', '편하게 휴식하기'];
      default:
        return ['심호흡하기', '좋아하는 음악 듣기', '짧은 산책하기'];
    }
  }

  String _pct(num v) {
    if (v > 1) return '${v.toStringAsFixed(0)}%';
    return '${(v * 100).toStringAsFixed(0)}%';
  }

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
        debugPrint("📦 최종 songs count: ${d.songs.length}");

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
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '주요 감정 : ${d.topKey}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _pct(d.dist[d.topKey] ?? 0),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        children: _keys.map((k) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            margin: const EdgeInsets.only(right: 8, bottom: 6),
                            decoration: BoxDecoration(
                              color: _chipBg[k],
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: _chipBorder[k]!),
                            ),
                            child: Text('$k ${_pct(d.dist[k] ?? 0)}'),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Text(
                    d.summary,
                    style: const TextStyle(color: Colors.black87, height: 1.5),
                  ),
                ),
                const SizedBox(height: 14),
                _MusicSection(songs: d.songs),
                const SizedBox(height: 18),
                const Text(
                  '활동 추천',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ..._buildActionList(d.actions),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildActionList(List<String> actions) {
    if (actions.isEmpty) {
      return [const _ActionChip(text: '오늘 실행할 작은 행동을 정해보세요.')];
    }
    final fixed = List<String>.from(actions);
    while (fixed.length < 3) {
      fixed.add('감정에 맞는 활동을 추가해보세요.');
    }
    return [
      _ActionChip(text: fixed[0], highlight: true),
      _ActionChip(text: fixed[1]),
      _ActionChip(text: fixed[2]),
    ];
  }
}

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
          border: Border.all(color: kMainGreen, width: 1.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ExpansionTile(
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

// ===== 곡 타일 =====
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
        border: Border.all(color: kMainGreen, width: 1.2),
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
                if ((song.reason ?? '').isNotEmpty)
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
                String url = (song.link ?? '').trim();
                if (url.isNotEmpty) url = _normalizeYouTubeLink(url);
                Uri target = url.isEmpty
                    ? Uri.parse(_youtubeSearchUrl(song.title, song.artist))
                    : Uri.parse(url);
                if (await canLaunchUrl(target)) {
                  await launchUrl(target, mode: LaunchMode.externalApplication);
                } else {
                  await launchUrl(
                    Uri.parse(_youtubeSearchUrl(song.title, song.artist)),
                    mode: LaunchMode.externalApplication,
                  );
                }
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

// ===== 행동칩 (추천 행동) =====
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
      ),
      child: Row(
        children: [
          if (highlight)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: kMainGreen.withOpacity(.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: kMainGreen),
              ),
              child: const Text(
                '강추',
                style: TextStyle(
                  color: kMainGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            )
          else
            const Icon(
              Icons.check_circle_outline,
              color: Colors.black54,
              size: 20,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.black87, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== 데이터 모델 =====
class _TodayData {
  final Map<String, double> dist;
  final String topKey;
  final String summary;
  final String fullFeedback;
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
