import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedAuthBackground extends StatefulWidget {
  final Widget? child;

  const AnimatedAuthBackground({super.key, this.child});

  @override
  State<AnimatedAuthBackground> createState() => _AnimatedAuthBackgroundState();
}

class _AnimatedAuthBackgroundState extends State<AnimatedAuthBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Solid base background
        Container(
          color: const Color(0xFFF1F8E9),
        ),
        // Animated geometric sky shapes
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _SkyShapesPainter(_controller.value),
              size: Size.infinite,
            );
          },
        ),
        // Animated grass
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _GrassPainter(_controller.value),
              size: Size.infinite,
            );
          },
        ),
        // Backdrop blur to soften the grass and sky
        // This gives the "fluid motion" but keeps the UI clean
        Positioned.fill(
          child: Container(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        // The actual content (Login/Signup form)
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _SkyShapesPainter extends CustomPainter {
  final double progress;

  _SkyShapesPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = const Color(0xFFE8F5E9).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    
    final paint2 = Paint()
      ..color = const Color(0xFFE3F2FD).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Slowly rotating top-left shape
    canvas.save();
    canvas.translate(0, 0);
    canvas.rotate(progress * 2 * math.pi * 0.2);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.1), size.width * 0.6, paint1);
    canvas.restore();

    // Slowly rotating bottom-right shape
    canvas.save();
    canvas.translate(size.width, size.height);
    canvas.rotate(-progress * 2 * math.pi * 0.15);
    canvas.drawCircle(Offset(-size.width * 0.2, -size.height * 0.1), size.width * 0.7, paint2);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SkyShapesPainter oldDelegate) => true;
}

class _GrassPainter extends CustomPainter {
  final double progress;
  _GrassPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    const bladeCount = 60;
    final bladeWidth = size.width / bladeCount;

    for (int i = 0; i < bladeCount; i++) {
      // Create some variance between blades
      final randomHeightMod = math.sin(i * 123.45) * 0.3 + 0.7; // 0.4 to 1.0 variation
      final colorVar = (math.sin(i * 789.12) * 20).toInt();
      paint.color = Color.fromARGB(255, 100 + colorVar, 180 + colorVar, 100 + colorVar).withValues(alpha: 0.4);

      final xOffset = i * bladeWidth;
      final bladeHeight = size.height * 0.15 * randomHeightMod;
      
      // Wind effect
      final sway = math.sin(progress * 2 * math.pi + i * 0.2) * 20.0;

      final path = Path();
      path.moveTo(xOffset, size.height); // Bottom left
      path.quadraticBezierTo(
        xOffset + sway / 2, size.height - bladeHeight / 2, // Control point
        xOffset + sway, size.height - bladeHeight // Tip
      );
      path.quadraticBezierTo(
        xOffset + bladeWidth + sway / 2, size.height - bladeHeight / 2, // Control point
        xOffset + bladeWidth, size.height // Bottom right
      );
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrassPainter oldDelegate) => true;
}
