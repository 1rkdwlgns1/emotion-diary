import 'dart:math';
import 'package:flutter/material.dart';

// lerpDouble 대체
double _lerp(num a, num b, double t) => a + (b - a) * t;

class TrashWriteScreen extends StatefulWidget {
  const TrashWriteScreen({super.key});

  @override
  State<TrashWriteScreen> createState() => _TrashWriteScreenState();
}

class _TrashWriteScreenState extends State<TrashWriteScreen> {
  final _controller = TextEditingController();
  static const mainGreen = Color(0xFF859A7E);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    // TODO: 실제 저장/전송 로직 연결
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('감정을 버렸어요. 잘했어요!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: const BackButton(color: Colors.black87),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, bottom + 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 상단 아이콘
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3F1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF3B82F6), width: 2),
                  ),
                  child: const Icon(Icons.gesture, size: 40, color: Colors.black87),
                ),
              ),
              const SizedBox(height: 16),

              // 테두리
              Expanded(
                child: CustomPaint(
                  painter: _RoughRoundedRectPainter(
                    radius: 18,
                    color: Colors.black54,
                    layers: 3,
                    jitter: 1.6,
                    strokeWidth: 1.7,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: _TrashMultilineField(controller: _controller),
                  ),
                ),
              ),

              const SizedBox(height: 14),
              const Text(
                '버리고자 하는 감정을 마음껏 작성하고 버려 보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),

              // 하단 버튼
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('감정 버리기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrashMultilineField extends StatelessWidget {
  const _TrashMultilineField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      decoration: const InputDecoration(
        hintText: '',
        border: InputBorder.none,
      ),
      style: const TextStyle(fontSize: 16),
    );
  }
}

/// 퍼즐/연필 느낌의 ‘자글자글’ 테두리
class _RoughRoundedRectPainter extends CustomPainter {
  _RoughRoundedRectPainter({
    required this.radius,
    required this.color,
    this.layers = 3,
    this.jitter = 1.6,
    this.strokeWidth = 1.8,
  });

  final double radius;
  final Color color;
  final int layers;
  final double jitter;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rnd = Random(1);

    for (int i = 0; i < layers; i++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color.withOpacity(0.35 + 0.2 * i);

      final r = radius;
      const segments = 46;

      final points = <Offset>[];

      // 상변: (r,0) → (w-r,0)
      for (int s = 0; s <= segments; s++) {
        final t = s / segments;
        final x = _lerp(r, rect.width - r, t);
        const y = 0.0;
        points.add(Offset(
          x + (rnd.nextDouble() * 2 - 1) * jitter,
          y + (rnd.nextDouble() * 2 - 1) * jitter,
        ));
      }
      // 우변: (w,r) → (w,h-r)
      for (int s = 0; s <= segments; s++) {
        final t = s / segments;
        final x = rect.width;
        final y = _lerp(r, rect.height - r, t);
        points.add(Offset(
          x + (rnd.nextDouble() * 2 - 1) * jitter,
          y + (rnd.nextDouble() * 2 - 1) * jitter,
        ));
      }
      // 하변: (w-r,h) → (r,h)
      for (int s = 0; s <= segments; s++) {
        final t = s / segments;
        final x = _lerp(rect.width - r, r, t);
        final y = rect.height;
        points.add(Offset(
          x + (rnd.nextDouble() * 2 - 1) * jitter,
          y + (rnd.nextDouble() * 2 - 1) * jitter,
        ));
      }
      // 좌변: (0,h-r) → (0,r)
      for (int s = 0; s <= segments; s++) {
        final t = s / segments;
        const x = 0.0;
        final y = _lerp(rect.height - r, r, t);
        points.add(Offset(
          x + (rnd.nextDouble() * 2 - 1) * jitter,
          y + (rnd.nextDouble() * 2 - 1) * jitter,
        ));
      }

      if (points.isNotEmpty) {
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (int k = 1; k < points.length; k++) {
          path.lineTo(points[k].dx, points[k].dy);
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoughRoundedRectPainter old) =>
      old.radius != radius ||
          old.color != color ||
          old.layers != layers ||
          old.jitter != jitter ||
          old.strokeWidth != strokeWidth;
}
