import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';

import 'package:cropsync/screens/home_screen.dart';

import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/auth/signup_screen.dart';

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
  final String? initialPhoneNumber;
  const LoginScreen({super.key, this.initialPhoneNumber});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _pressedButton;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhoneNumber != null) {
      _pinController.text = widget.initialPhoneNumber!;
    }
  }

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
      final isRegistered = await ApiService.checkUser(pin);
      if (!isRegistered) {
        _showError('User not registered. Redirecting to Signup...');
        // Add a slight delay so user can see the message
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SignupScreen(initialPhoneNumber: pin)),
        );
        return;
      }

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
      return;
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
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false, // Prevent keyboard from jumping view
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),
                      _buildBranding(),
                      const Spacer(flex: 1),
                      _buildSingleInputDisplay(),
                      const SizedBox(height: 12),
                      _buildHintChip(),
                      const SizedBox(height: 24),
                      _buildKeypad(),
                      const Spacer(flex: 1),
                      _buildSignupLink(),
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
            ),
            if (_errorMessage != null)
              Positioned(
                top: 16,
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
        Image.asset(
          'assets/images/logo_t.png',
          height: 80,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.agriculture_rounded,
            size: 64,
            color: Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'login_welcome_back'.tr(),
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'enter_field'.tr(namedArgs: {'field': 'user_id'.tr()}),
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: const Color(0xFF4B5563),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSingleInputDisplay() {
    final hasInput = _pinController.text.isNotEmpty;
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasInput
              ? const Color(0xFF059669)
              : const Color(0xFFD1D5DB),
          width: 2.0,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        hasInput ? _pinController.text : '------',
        style: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: 8,
          color: hasInput
              ? const Color(0xFF111827)
              : const Color(0xFF9CA3AF), 
        ),
      ),
    );
  }

  Widget _buildHintChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFC8E6C9),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: Color(0xFF388E3C),
          ),
          const SizedBox(width: 8),
          Text(
            'login_pin_hint'.tr(),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF388E3C),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.25,
        children: [
          ...List.generate(9, (i) => i + 1)
              .map((number) => _buildKeyButton(number.toString())),
          _buildSubmitButton(),
          _buildKeyButton('0'),
          _buildDeleteButton(),
        ],
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
        scale: isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF059669),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Icon(
                  Icons.arrow_forward_rounded,
                  size: 32,
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: isPressed ? const Color(0xFFE5E7EB) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1F2937),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: isPressed ? const Color(0xFFFEE2E2) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFCA5A5),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.backspace_rounded,
          size: 28,
          color: Color(0xFFEF4444),
        ),
      ),
    );
  }

  Widget _buildSignupLink() {
    return TextButton(
      onPressed: () {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const SignupScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOutCubic;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFFF0FDF4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_add_alt_1_rounded,
            size: 20,
            color: Color(0xFF047857),
          ),
          const SizedBox(width: 8),
          Text(
            'signup_create_account'.tr(),
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: const Color(0xFF047857),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: Color(0xFF047857),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorNotification() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      tween: Tween(begin: -100, end: 0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, value),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 22),
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
