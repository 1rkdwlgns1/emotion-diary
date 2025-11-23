//로딩 화면 스크린
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../core/constants.dart';
import 'today_emotion_screen.dart';

class LoadingScreen extends StatefulWidget {
  final String imagePath;
  const LoadingScreen({super.key, required this.imagePath});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  String? _error;
  late final String _tip;
  Timer? _dotTimer;
  int _dotCount = 0;
  String get _dots => '.' * _dotCount;

  static const List<String> _tips = [
    '우울할 땐 울면을 먹어보세요!',
    '기쁠 땐 그 순간을 기록해보세요!',
    '화가 날 땐 잠시 산책을 나가보는 것도 좋아요.',
    '놀랐다면 깊게 숨 한 번 들이쉬고 천천히 내쉬어봐요.',
    '마음이 복잡할 땐 글로 정리해보는 것도 도움이 돼요.',
    '불안할 땐 지금 할 수 있는 “작은 일 하나”에 집중해보세요.',
    '평온함을 느낀다면, 그 순간을 오래 기억해두세요.',
  ];

  static const Map<String, String> _labelEn2Ko = {
    'joy': '기쁨',
    'sad': '슬픔',
    'anger': '분노',
    'neutral': '평온',
    'surprise': '놀람',
    'fear': '두려움',
    'disgust': '혐오',
    'contempt': '경멸',
  };

  @override
  void initState() {
    super.initState();
    _tip = _tips[Random().nextInt(_tips.length)];
    _startDots();
    _startAnalysis();
  }

  @override
  void dispose() {
    _dotTimer?.cancel();
    super.dispose();
  }

  void _startDots() {
    _dotTimer?.cancel();
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() => _dotCount = (_dotCount + 1) % 4);
    });
  }

  Future<http.StreamedResponse> _sendFile(String path) async {
    final uri = Uri.parse('$kBaseUrl/media/upload');
    final req = http.MultipartRequest('POST', uri);

    req.fields['user_id'] = kUserId;
    req.fields['media_type'] = 'video';

    MediaType mediaType;
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp4')) {
      mediaType = MediaType('video', 'mp4');
    } else if (lower.endsWith('.mov')) {
      mediaType = MediaType('video', 'quicktime');
    } else if (lower.endsWith('.mkv')) {
      mediaType = MediaType('video', 'x-matroska');
    } else if (lower.endsWith('.m4a')) {
      mediaType = MediaType('audio', 'm4a');
    } else if (lower.endsWith('.wav')) {
      mediaType = MediaType('audio', 'wav');
    } else if (lower.endsWith('.mp3')) {
      mediaType = MediaType('audio', 'mpeg');
    } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      mediaType = MediaType('image', 'jpeg');
    } else if (lower.endsWith('.png')) {
      mediaType = MediaType('image', 'png');
    } else {
      mediaType = MediaType('application', 'octet-stream');
    }

    final f = File(path);
    if (await f.exists()) {
      req.files.add(
        await http.MultipartFile.fromPath(
          'file',
          f.path,
          contentType: mediaType,
        ),
      );
    }

    print('업로드 요청: user_id=$kUserId, file=$path');
    return req.send();
  }

  Future<void> _startAnalysis() async {
    try {
      final f = File(widget.imagePath);
      if (!await f.exists()) {
        throw Exception('파일을 찾을 수 없습니다: ${widget.imagePath}');
      }
      print('현재 업로드 주소: $kBaseUrl');

      // 파일 업로드
      final streamed = await _sendFile(widget.imagePath);
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }

      final uploadResult = jsonDecode(resp.body);
      if (uploadResult['ok'] != true) {
        throw Exception('업로드 실패: ${uploadResult['error'] ?? 'unknown'}');
      }

      final mediaId = uploadResult['media_id'];
      final s3Key = uploadResult['s3Key'];

      // Node 서버로 분석 요청 (Flask는 Node가 호출함)
      final uriAnalyze = Uri.parse('$kBaseUrl/analysis/analyze');
      final analyzeRes = await http.post(
        uriAnalyze,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': kUserId,
          'media_id': mediaId,
          's3Key': s3Key,
        }),
      );

      if (analyzeRes.statusCode != 200) {
        throw Exception('분석 실패: ${analyzeRes.body}');
      }

      final resultData = jsonDecode(analyzeRes.body);
      if (resultData['ok'] != true) {
        throw Exception('분석 실패: ${resultData['error'] ?? 'unknown'}');
      }

      // Node 결과 파싱
      final nodeRes = resultData['result'] ?? {};
      final dist = Map<String, dynamic>.from(nodeRes['emotionData'] ?? {});
      final gptFeedback = nodeRes['feedback'] ?? '';
      final mainKo = nodeRes['mainEmotion'] ?? '알 수 없음';
      final musicList = nodeRes['music'] ?? [];

      // 퍼센트 변환
      final mapped = _toKoPercent(dist);

      // 결과 전달
      final analysisResult = {
        'mainEmotion': mainKo,
        'emotionData': mapped,
        'gptFeedback': gptFeedback,
        'actions': nodeRes['actions'] ?? [],
        'music': musicList,
        'debug': nodeRes,
      };

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TodayEmotionScreen(result: analysisResult),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Map<String, double> _toKoPercent(Map<String, dynamic> dist) {
    final maxVal = dist.values
        .whereType<num>()
        .map((e) => e.toDouble().abs())
        .fold<double>(0, (a, b) => a > b ? a : b);
    final bool alreadyPct = maxVal > 1.001;
    final out = <String, double>{};
    dist.forEach((en, v) {
      final ko = _labelEn2Ko[en] ?? en;
      var val = (v is num ? v.toDouble() : 0.0);
      val = alreadyPct ? val : val * 100.0;
      out[ko] = val.clamp(0, 100);
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _error == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '분석 중$_dots',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const CircularProgressIndicator(
                    color: Color(0xFF859A7E),
                    strokeWidth: 5.0,
                  ),
                  const SizedBox(height: 36),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      _tip,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  '에러 발생: $_error',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
      ),
    );
  }
}
