/*
  loading_screen.dart (확정 버전)
  - 백엔드 응답의 result.fused.distribution(신규) → fused(구버전) → face/text 순으로 폴백
  - 업로드: contentType 힌트 + fromPath 실패시 fromBytes
  - "분석 중..." 말줄임표 애니메이션
  - 결과로 이미 정규화된 데이터(mainEmotion, emotionData%)를 넘김 → 화면 일관성
*/

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'analysis_result_screen.dart';

/// --- 환경별 서버 주소 ---
/// Android 에뮬: http://10.0.2.2:5001
/// iOS 시뮬:     http://127.0.0.1:5001
/// 실기기:       http://<PC-IP>:5001 (같은 Wi-Fi)
const String kBaseUrl = 'http://10.0.2.2:5001';
/*const String kBaseUrl = 'http://10.11.26.62:5001';*/
// ===== 라벨/정규화 유틸 =====
const Map<String, String> _labelEn2Ko = {
  'joy': '기쁨',
  'sad': '슬픔',
  'anger': '분노',
  'neutral': '평온',
  'surprise': '놀람',
  'mixed': '혼합',
  'uncertain': '불확실',
};
String _labelToKo(String? en) => _labelEn2Ko[en ?? ''] ?? '알 수 없음';

const List<String> _orderedKo = ['기쁨', '슬픔', '분노', '놀람', '평온'];

Map<String, double> _toKoPercent(Map<String, dynamic> dist) {
  // 값이 0~1인지, 이미 %인지 자동 감지
  final maxVal = dist.values
      .whereType<num>()
      .map((e) => e.toDouble().abs())
      .fold<double>(0, (a, b) => a > b ? a : b);
  final bool alreadyPct = maxVal > 1.001;

  final Map<String, double> out = {};
  dist.forEach((en, v) {
    final ko = _labelEn2Ko[en] ?? en;
    var val = (v is num ? v.toDouble() : 0.0);
    val = alreadyPct ? val : val * 100.0;
    out[ko] = val.clamp(0, 100);
  });

  // 보기 좋은 순서 유지
  final sorted = <String, double>{};
  for (final k in _orderedKo) {
    if (out.containsKey(k)) sorted[k] = out[k]!;
  }
  for (final e in out.entries) {
    if (!sorted.containsKey(e.key)) sorted[e.key] = e.value;
  }
  return sorted;
}
// ===========================

class LoadingScreen extends StatefulWidget {
  final String imagePath; // 영상/이미지/오디오 경로
  const LoadingScreen({super.key, required this.imagePath});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  String? _error;
  late final String _tip;

  // "분석 중..." 애니메이션
  Timer? _dotTimer;
  int _dotCount = 0; // 0~3 반복
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
    final uri = Uri.parse('$kBaseUrl/analyze/file');
    final req = http.MultipartRequest('POST', uri);

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
    } else if (lower.endsWith('.bmp')) {
      mediaType = MediaType('image', 'bmp');
    } else {
      mediaType = MediaType('application', 'octet-stream');
    }

    // 일반 경로 업로드
    try {
      final f = File(path);
      if (await f.exists()) {
        req.files.add(
          await http.MultipartFile.fromPath(
            'file',
            f.path,
            contentType: mediaType,
          ),
        );
        return req.send();
      }
    } catch (_) {
      // fall through
    }

    // content:// 등 특수 경로 → fromBytes
    final bytes = await File(path).readAsBytes();
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'upload',
        contentType: mediaType,
      ),
    );
    return req.send();
  }

  Future<void> _startAnalysis() async {
    try {
      final f = File(widget.imagePath);
      if (!await f.exists()) {
        throw Exception('파일을 찾을 수 없습니다: ${widget.imagePath}');
      }

      final streamed = await _sendFile(widget.imagePath);
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }

      // --- 백엔드 JSON 파싱 ---
      final Map<String, dynamic> root = jsonDecode(resp.body);
      if (root['ok'] != true) {
        throw Exception('분석 실패: ${root['error'] ?? 'unknown'}');
      }
      final result = Map<String, dynamic>.from(root['result'] ?? {});
      final fused = Map<String, dynamic>.from(result['fused'] ?? {});

      // ✅ 분포 추출(신규 → 구버전 → 얼굴/텍스트)
      final fusedDist = Map<String, dynamic>.from(
        fused['distribution'] ??
            fused['fused'] ??
            result['face']?['distribution'] ??
            result['text']?['distribution'] ??
            {},
      );
      final finalLabel = fused['final_label']?.toString();

      // 정규화(이미 %로 변환해서 화면에 넘김)
      final mapped = _toKoPercent(fusedDist);
      final mainKo = _labelToKo(finalLabel);

      // 디버그 정보도 같이 넘겨서 화면에서 눈으로 확인 가능
      final dbg = {
        'kind': result['type'],
        'top_label': finalLabel,
        'warnings': (root['warnings'] as List?) ?? const [],
        'has_timeline': result['face']?['timeline'] != null,
        'has_transcript': (result['text']?['transcript'] ?? '')
            .toString()
            .isNotEmpty,
      };

      final analysisResult = {
        'mainEmotion': mainKo,
        'emotionData': mapped,
        'gptFeedback': (result['feedback'] ?? '') as String? ?? '',
        'debug': dbg,
        'raw': root,
      };

      // 콘솔 확인용 (원하면 주석)
      // print('[LOADING] emotionData = $mapped');
      // print('[LOADING] main = $mainKo, debug=$dbg');

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisResultScreen(result: analysisResult),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
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
