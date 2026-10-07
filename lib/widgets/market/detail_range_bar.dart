import 'package:flutter/material.dart';

/// Min-max price bar with a tick for the modal price. Purely decorative: the
/// numbers are shown as text beside it.
class DetailRangeBar extends StatelessWidget {
  final double min;
  final double max;
  final double modal;
  final Color color;

  const DetailRangeBar({
    super.key,
    required this.min,
    required this.max,
    required this.modal,
    this.color = const Color(0xFF15803D),
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 16,
        width: double.infinity,
        child: CustomPaint(
          painter: _RangePainter(min, max, modal, color),
        ),
      ),
    );
  }
}

class _RangePainter extends CustomPainter {
  final double min, max, modal;
  final Color color;
  _RangePainter(this.min, this.max, this.modal, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    const r = 3.0;
    final track = RRect.fromLTRBR(
        0, cy - r, size.width, cy + r, const Radius.circular(r));
    canvas.drawRRect(
      track,
      Paint()
        ..shader = LinearGradient(colors: [
          color.withValues(alpha: 0.18),
          color.withValues(alpha: 0.45),
        ]).createShader(Offset.zero & size),
    );
    final span = max - min;
    final t = span <= 0 ? 0.5 : ((modal - min) / span).clamp(0.0, 1.0);
    final x = (size.width * t).clamp(6.0, size.width - 6.0);
    canvas.drawCircle(Offset(x, cy), 7.5, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(x, cy), 5.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RangePainter o) =>
      o.min != min || o.max != max || o.modal != modal || o.color != color;
}
