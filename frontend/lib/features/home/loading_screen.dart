/*
  ✅ loading_screen.dart (Node 중계형 완성 버전, 2025.11.02 수정)
  ----------------------------------------------------------
  ⚙️ 전체 흐름:
   Flutter → Node (/media/upload) → Flask → Node → Flutter
   📦 Node 응답 구조:
     { ok:true, flaskResponse:{ result:{ fused:{...}, text:{...} } } }

  ✅ 주요 기능
  - 영상 업로드 (contentType 자동 판별, fromPath 실패 시 fromBytes 폴백)
  - Flask 감정 분석 요청 후 결과 수신
  - 감정 분포 정규화(0~1 또는 %) 자동 감지 + 한국어 라벨 매핑
  - “분석 중...” 애니메이션 + 랜덤 힐링 문구 표시
  - 결과 데이터(mainEmotion, emotionData, feedback) → AnalysisResultScreen 전달

  ⚠️ 주의
  - CameraScreen에서 push하지 않고 HomeScreen에서 push해야 함
  - LoadingScreen은 반드시 imagePath와 userId를 전달받아야 함
*/

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'analysis_result_screen.dart';

// ======================
// 🌐 서버 주소 자동 분기
// ======================
String getBaseUrl() {
  if (kIsWeb) return 'http://localhost:3000';
  if (Platform.isAndroid) {
    // ✅ 민준 노트북 / EC2 환경 (Wi-Fi 기준)
    return 'http://172.30.75.2:3000';
  }
  return 'http://127.0.0.1:3000';
}

// ======================
// 🎯 라벨 매핑 및 감정 분포 정규화
// ======================
const Map<String, String> _labelEn2Ko = {
  'joy': '기쁨',
  'happy': '기쁨',
  'happiness': '기쁨',
  'sad': '슬픔',
  'sadness': '슬픔',
  'anger': '분노',
  'angry': '분노',
  'neutral': '평온',
  'surprise': '놀람',
  'mixed': '혼합',
  'uncertain': '불확실',
};

String _labelToKo(String? en) =>
    _labelEn2Ko[en?.toLowerCase() ?? ''] ?? '알 수 없음';

// 📊 출력 순서 고정
const List<String> _orderedKo = ['기쁨', '슬픔', '분노', '놀람', '평온'];

// 감정 분포를 0~100(%)로 변환
Map<String, double> _toKoPercent(Map<String, dynamic> dist) {
  final onlyNums = dist.values.whereType<num>().map((e) => e.toDouble().abs());
  final maxVal = onlyNums.isEmpty ? 0.0 : onlyNums.reduce((a, b) => a > b ? a : b);
  final bool alreadyPct = maxVal > 1.001; // 이미 0~100 형태인지 판별

  final Map<String, double> out = {};
  dist.forEach((en, v) {
    final ko = _labelEn2Ko[en.toString().toLowerCase()] ?? en.toString();
    var val = (v is num ? v.toDouble() : 0.0);
    val = alreadyPct ? val : val * 100.0;
    out[ko] = val.clamp(0, 100);
  });

  // 감정 출력 순서 정렬
  final sorted = <String, double>{};
  for (final k in _orderedKo) {
    if (out.containsKey(k)) sorted[k] = out[k]!;
  }
  for (final e in out.entries) {
    if (!sorted.containsKey(e.key)) sorted[e.key] = e.value;
  }
  return sorted;
}

// =====================================================
// 🎬 클래스: LoadingScreen
// =====================================================
class LoadingScreen extends StatefulWidget {
  final String imagePath; // 🎞️ 촬영된 영상 경로
  final int userId;       // 👤 CameraScreen에서 직접 전달받은 userId

  const LoadingScreen({
    super.key,
    required this.imagePath,
    required this.userId,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

// =====================================================
// ⚙️ 상태 관리
// =====================================================
class _LoadingScreenState extends State<LoadingScreen> {
  String? _error;         // 에러 메시지
  late final String _tip; // 랜덤 힐링 문구
  late final String _baseUrl;

  Timer? _dotTimer;       // “분석 중…” 점 애니메이션
  int _dotCount = 0;
  String get _dots => '.' * _dotCount;

  // 힐링 문구 모음
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
    _baseUrl = getBaseUrl();
    _tip = _tips[Random().nextInt(_tips.length)];
    _startDots();
    _startAnalysisPipeline(); // 💥 영상 업로드 + 분석 시작
  }

  @override
  void dispose() {
    _dotTimer?.cancel();
    super.dispose();
  }

  // 점 애니메이션 시작
  void _startDots() {
    _dotTimer?.cancel();
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() => _dotCount = (_dotCount + 1) % 4);
    });
  }

  // =====================================================
  // 🧠 메인 분석 파이프라인
  // =====================================================
  Future<void> _startAnalysisPipeline() async {
    try {
      // 🔍 1. 파일 존재 확인
      final f = File(widget.imagePath);
      if (!await f.exists()) {
        throw Exception('파일을 찾을 수 없습니다: ${widget.imagePath}');
      }

      setState(() => _error = '');

      // 📤 2. Node에 업로드 요청
      final uploadResRaw = await _uploadToNode(widget.imagePath);
      final Map<String, dynamic> uploadRes = Map<String, dynamic>.from(uploadResRaw);

      if (uploadRes['ok'] != true) {
        final msg = uploadRes['message']?.toString() ?? '';
        if (msg.contains('user_id 누락됨')) {
          debugPrint('⚠️ 서버에서 user_id 누락됨(무시) → 실제 업로드 성공으로 간주');
        } else {
          throw Exception('업로드 실패: ${uploadRes['message'] ?? uploadRes['error'] ?? 'unknown'}');
        }
      }

      // ✅ s3Key와 media_id 모두 필요
      final s3Key = (uploadRes['s3Key'] ?? uploadRes['key'] ?? '').toString();
      final mediaIdDynamic = uploadRes['media_id'];
      final int? mediaId = mediaIdDynamic is int
          ? mediaIdDynamic
          : (mediaIdDynamic is String ? int.tryParse(mediaIdDynamic) : null);

      if (s3Key.isEmpty || mediaId == null) {
        throw Exception('업로드 성공했지만 s3Key 또는 media_id 누락');
      }

      // 📡 3. Flask 감정 분석 요청
      final analysisResRaw = await _requestNodeAnalysis(s3Key, mediaId);
      final Map<String, dynamic> analysisRes = Map<String, dynamic>.from(analysisResRaw);

      if (analysisRes['ok'] != true) {
        throw Exception('분석 요청 실패: ${analysisRes['message'] ?? 'unknown'}');
      }

      // 📊 4. Flask 응답 정규화
      final dynamic flaskRaw = analysisRes['flaskResponse'] ?? {};
      final Map<String, dynamic> flask = flaskRaw is Map
          ? Map<String, dynamic>.from(flaskRaw)
          : <String, dynamic>{};

      final normalized = _normalizeFlaskResult(flask, s3Key);

      // 🎉 5. 결과 화면으로 이동
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisResultScreen(result: normalized),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  // =====================================================
  // 📤 Node 업로드 (/media/upload)
  // =====================================================
  Future<Map<String, dynamic>> _uploadToNode(String filePath) async {
    final uri = Uri.parse('$_baseUrl/media/upload');
    final request = http.MultipartRequest('POST', uri);

    MediaType type = _detectMediaType(filePath);

    try {
      request.files.add(await http.MultipartFile.fromPath('file', filePath, contentType: type));
    } catch (_) {
      final bytes = await File(filePath).readAsBytes();
      request.files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: 'upload', contentType: type));
    }

    request.fields['user_id'] = widget.userId.toString();
    request.fields['media_type'] = 'video';

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 200) {
      final dynamic decoded = jsonDecode(res.body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return <String, dynamic>{'ok': false, 'error': 'invalid_response'};
    }
    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }

  // =====================================================
  // 📡 Node → Flask 분석 요청 (/analysis/analyze)
  // =====================================================
  Future<Map<String, dynamic>> _requestNodeAnalysis(String s3Key, int mediaId) async {
    final uri = Uri.parse('$_baseUrl/analysis/analyze');
    debugPrint('📡 Node 분석 요청 시작 → userId=${widget.userId}, mediaId=$mediaId, s3Key=$s3Key');

    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        's3Key': s3Key,
        'user_id': widget.userId,
        'media_id': mediaId,
      }),
    );

    if (resp.statusCode == 200) {
      final dynamic decoded = jsonDecode(resp.body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return <String, dynamic>{'ok': false, 'error': 'invalid_response'};
    } else {
      debugPrint('❌ 분석 요청 실패: ${resp.statusCode} ${resp.body}');
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }

  // =====================================================
  // 🧩 Flask 응답 정규화 (Null-safe 개선)
  // =====================================================
  Map<String, dynamic> _normalizeFlaskResult(Map<String, dynamic> flask, String s3Key) {
    final rawResult = flask['result'];
    final result = (rawResult is Map<String, dynamic>) ? rawResult : <String, dynamic>{};

    final rawFused = result['fused'];
    final fused = (rawFused is Map<String, dynamic>) ? rawFused : <String, dynamic>{};

    Map<String, dynamic> distRaw = {};
    final rawDistCandidate =
        fused['distribution'] ??
        fused['fused'] ??
        (result['face'] is Map ? result['face']['distribution'] : null) ??
        (result['text'] is Map ? result['text']['distribution'] : null) ??
        {};

    if (rawDistCandidate is Map<String, dynamic>) {
      distRaw = Map<String, dynamic>.from(rawDistCandidate);
    }

    final finalLabel = (fused['final_label'] ?? result['emotion'] ?? result['top_emotion'])?.toString();

    final mapped = _toKoPercent(distRaw);
    final mainKo = _labelToKo(finalLabel);

    final dbg = {
      'top_label': finalLabel,
      'has_face': result['face'] != null,
      'has_text': result['text'] != null,
      'warnings': (flask['warnings'] is List) ? flask['warnings'] : [],
    };

    return {
      'mainEmotion': mainKo,
      'emotionData': mapped,
      'gptFeedback': (result['feedback'] ?? '') as String? ?? '',
      'debug': dbg,
      's3Key': s3Key,
      'raw': flask,
    };
  }

  // =====================================================
  // 🧾 확장자 기반 Content-Type 감지
  // =====================================================
  MediaType _detectMediaType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp4')) return MediaType('video', 'mp4');
    if (lower.endsWith('.mov')) return MediaType('video', 'quicktime');
    if (lower.endsWith('.mkv')) return MediaType('video', 'x-matroska');
    if (lower.endsWith('.m4a')) return MediaType('audio', 'm4a');
    if (lower.endsWith('.wav')) return MediaType('audio', 'wav');
    if (lower.endsWith('.mp3')) return MediaType('audio', 'mpeg');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg'))
      return MediaType('image', 'jpeg');
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.bmp')) return MediaType('image', 'bmp');
    return MediaType('application', 'octet-stream');
  }

  // =====================================================
  // 🎨 UI 빌드
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _error == null || _error!.isEmpty
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
