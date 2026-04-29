import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cropsync/theme/app_theme.dart';

void showModernErrorToast(BuildContext context, String message) {
  // Get the overlay state
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => _ToastWidget(
      message: message,
      onDismissed: () {
        // Check if entry is still mounted before removing
        try {
          overlayEntry.remove();
        } catch (e) {
          // It might have been removed already, ignore.
        }
      },
    ),
  );

  // Insert the toast into the overlay
  overlay.insert(overlayEntry);
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDismissed;

  const _ToastWidget({
    required this.message,
    required this.onDismissed,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Animate the toast in
    _controller.forward();

    // Set a timer to dismiss the toast
    _dismissTimer = Timer(const Duration(seconds: 4), () {
      _controller.reverse().then((_) {
        widget.onDismissed();
      });
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
    // Using MediaQuery to position the toast safely below the status bar
    final topPadding = MediaQuery.of(context).viewPadding.top + 16.0;

    return Positioned(
      top: topPadding,
      left: 20.0,
      right: 20.0,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            decoration: BoxDecoration(
              color: AppTheme.error,
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.error.withValues(alpha: 0.3),
                  blurRadius: 24.0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontSize: 14,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

