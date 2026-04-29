import 'package:flutter/material.dart';
import 'package:cropsync/theme/app_theme.dart';

class AuthAlertBanner extends StatelessWidget {
  final String? message;
  final bool isError;
  final EdgeInsetsGeometry margin;

  const AuthAlertBanner({
    super.key,
    required this.message,
    this.isError = true,
    this.margin = const EdgeInsets.symmetric(horizontal: 24),
  });

  @override
  Widget build(BuildContext context) {
    final show = message != null;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuart,
      top: show ? MediaQuery.of(context).padding.top + 20 : -120,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isError ? AppTheme.error : AppTheme.success,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (isError ? AppTheme.error : AppTheme.success)
                    .withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  message ?? '',
                  style: const TextStyle(
                    
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

