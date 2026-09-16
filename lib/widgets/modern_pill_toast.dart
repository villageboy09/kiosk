import 'dart:async';
import 'package:flutter/material.dart';

OverlayEntry? _activePillToastEntry;

/// Shows a sleek, pill-shaped notification floating from the top middle of the screen
void showModernPillToast(
  BuildContext context, {
  required String message,
  IconData? icon,
  Color? backgroundColor,
  Color? textColor,
  Color? iconColor,
  bool isSuccess = true,
  Duration duration = const Duration(milliseconds: 2800),
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  // Dismiss any existing active toast to avoid overlapping
  try {
    _activePillToastEntry?.remove();
    _activePillToastEntry = null;
  } catch (_) {}

  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (ctx) => _PillToastWidget(
      message: message,
      icon: icon ?? (isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded),
      backgroundColor: backgroundColor ?? (isSuccess ? const Color(0xFF0F172A) : const Color(0xFF1E293B)),
      textColor: textColor ?? Colors.white,
      iconColor: iconColor ?? (isSuccess ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
      duration: duration,
      onDismissed: () {
        try {
          if (_activePillToastEntry == overlayEntry) {
            _activePillToastEntry = null;
          }
          overlayEntry.remove();
        } catch (_) {}
      },
    ),
  );

  _activePillToastEntry = overlayEntry;
  overlay.insert(overlayEntry);
}

class _PillToastWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;
  final Color iconColor;
  final Duration duration;
  final VoidCallback onDismissed;

  const _PillToastWidget({
    required this.message,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.iconColor,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_PillToastWidget> createState() => _PillToastWidgetState();
}

class _PillToastWidgetState extends State<_PillToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    _dismissTimer = Timer(widget.duration, () {
      _dismiss();
    });
  }

  void _dismiss() {
    if (!mounted) return;
    _dismissTimer?.cancel();
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).viewPadding.top + 14.0;

    return Positioned(
      top: topPadding,
      left: 20.0,
      right: 20.0,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: _dismiss,
                  onVerticalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) < 0) {
                      _dismiss();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      borderRadius: BorderRadius.circular(100.0),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 20.0,
                          offset: const Offset(0, 8),
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: widget.iconColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.iconColor,
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: widget.textColor,
                              fontSize: 13.0,
                              letterSpacing: -0.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
