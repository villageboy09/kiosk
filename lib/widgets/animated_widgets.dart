import 'package:flutter/material.dart';

class FadeInSlideCard extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double delayMilliseconds;

  const FadeInSlideCard({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.delayMilliseconds = 0.0,
  });

  @override
  State<FadeInSlideCard> createState() => _FadeInSlideCardState();
}

class _FadeInSlideCardState extends State<FadeInSlideCard> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: widget.duration,
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 16 * (1.0 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Smooth number incrementor/counter animation
class AnimatedCountText extends StatelessWidget {
  final int targetValue;
  final TextStyle style;
  final Duration duration;

  const AnimatedCountText({
    super.key,
    required this.targetValue,
    required this.style,
    this.duration = const Duration(milliseconds: 1000),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: targetValue.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Text(
          value.toInt().toString(),
          style: style,
        );
      },
    );
  }
}

/// Smooth progress indicator with animation from 0 to target value
class AnimatedProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final Color backgroundColor;
  final double minHeight;
  final Duration duration;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
    this.minHeight = 8.0,
    this.duration = const Duration(milliseconds: 1000),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: val,
            color: color,
            backgroundColor: backgroundColor,
            minHeight: minHeight,
          ),
        );
      },
    );
  }
}
