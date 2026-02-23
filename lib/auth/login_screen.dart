import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';

import 'package:cropsync/screens/home_screen.dart';
import 'package:cropsync/services/auth_service.dart';

extension ColorExtension on Color {
  Color withValues({double? alpha, int? red, int? green, int? blue}) {
    return Color.fromARGB(
      alpha != null ? (alpha * 255).round() : (a * 255.0).round().clamp(0, 255),
      red ?? (r * 255.0).round().clamp(0, 255),
      green ?? (g * 255.0).round().clamp(0, 255),
      blue ?? (b * 255.0).round().clamp(0, 255),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _pressedButton;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      _showError('login_pin_length_error'.tr());
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.login(pin);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    setState(() => _errorMessage = msg);
    Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _errorMessage = null);
    });
  }

  void _appendDigit(String digit) {
    if (_pinController.text.length >= 10) {
      return; // Limit to 10 digits as requested
    }
    setState(() {
      _pinController.text += digit;
    });
  }

  void _deleteDigit() {
    if (_pinController.text.isEmpty) return;
    setState(() {
      _pinController.text =
          _pinController.text.substring(0, _pinController.text.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Soft gradient background like the reference image
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE3F2FD), // Light Blue 50
              Color(0xFFFFFFFF), // White
              Color(0xFFE8F5E9), // Light Green 50 (subtle brand touch)
              Color(0xFFE3F2FD), // Light Blue 50
            ],
            stops: [0.0, 0.4, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            _buildBranding(),
                            const SizedBox(height: 40),
                            _buildSingleInputDisplay(),
                            const SizedBox(height: 10),
                            _buildHintChip(),
                            const SizedBox(height: 30),
                            _buildKeypad(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_errorMessage != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 24,
                right: 24,
                child: _buildErrorNotification(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranding() {
    return Column(
      children: [
        Container(
          width: 140, // Increased from 100
          height: 140, // Increased from 100
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B5E20)
                    .withValues(alpha: 0.15), // Brand green shadow
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24), // Increased padding
          child: Image.asset(
            'assets/images/logo_t.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.agriculture_rounded,
              size: 70, // Increased from 50
              color: Color(0xFF1B5E20),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'login_welcome_back'.tr(),
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A1A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'enter_field'.tr(namedArgs: {'field': 'user_id'.tr()}),
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF757575),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildSingleInputDisplay() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F9FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF2196F3).withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2196F3).withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          _pinController.text.isEmpty ? '------' : _pinController.text,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: 4,
            color: _pinController.text.isEmpty
                ? Colors.grey.withValues(alpha: 0.5)
                : const Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }

  // ── Hint chip below the PIN input ──
  Widget _buildHintChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            size: 15,
            color: Color(0xFF388E3C),
          ),
          const SizedBox(width: 6),
          Text(
            'login_pin_hint'.tr(),
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF388E3C),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            ...List.generate(9, (i) => i + 1)
                .map((number) => _buildKeyButton(number.toString())),
            _buildSubmitButton(), // Submit button left of 0
            _buildKeyButton('0'),
            _buildDeleteButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final isPressed = _pressedButton == 'submit';
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressedButton = 'submit'),
      onTapUp: (_) {
        setState(() => _pressedButton = null);
        if (!_isLoading) _login();
      },
      onTapCancel: () => setState(() => _pressedButton = null),
      child: AnimatedScale(
        scale: isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons.arrow_forward_rounded,
                  size: 28,
                  color: Colors.white,
                ),
        ),
      ),
    );
  }

  Widget _buildKeyButton(String label) {
    final isPressed = _pressedButton == label;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressedButton = label),
      onTapUp: (_) {
        setState(() => _pressedButton = null);
        _appendDigit(label);
      },
      onTapCancel: () => setState(() => _pressedButton = null),
      child: AnimatedScale(
        scale: isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: isPressed
                ? const Color(0xFFE8F5E9) // Subtle green tint on press
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPressed
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
                  : const Color(0xFFE0E0E0),
              width: 1,
            ),
            boxShadow: isPressed
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A1A1A),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    final isPressed = _pressedButton == 'delete';
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressedButton = 'delete'),
      onTapUp: (_) {
        setState(() => _pressedButton = null);
        _deleteDigit();
      },
      onTapCancel: () => setState(() => _pressedButton = null),
      child: AnimatedScale(
        scale: isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.backspace_outlined,
            size: 24,
            color:
                isPressed ? const Color(0xFFE53935) : const Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorNotification() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      tween: Tween(begin: -100, end: 0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, value),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE53935).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage ?? '',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
