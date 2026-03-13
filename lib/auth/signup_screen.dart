import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';

import 'package:cropsync/screens/home_screen.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/auth/login_screen.dart';

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

class SignupScreen extends StatefulWidget {
  final String? initialPhoneNumber;
  const SignupScreen({super.key, this.initialPhoneNumber});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();

  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  bool _otpSent = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhoneNumber != null) {
      _phoneController.text = widget.initialPhoneNumber!;
    }

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _errorMessage = msg);
    Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _errorMessage = null);
    });
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    setState(() => _successMessage = msg);
    Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _successMessage = null);
    });
  }

  Future<void> _sendOtp() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      _showError('signup_error_name'.tr());
      return;
    }

    if (phone.length < 10) {
      _showError('signup_error_phone'.tr());
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isRegistered = await ApiService.checkUser(phone);
      if (isRegistered) {
        _showError('signup_user_exists'.tr());
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const LoginScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              const begin = Offset(-1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOutCubic;
              var tween =
                  Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
        return;
      }

      final res = await ApiService.sendOtp(phone);
      if (res['success'] == true) {
        if (mounted) {
          setState(() {
            _otpSent = true;
            _isLoading = false;
          });
          _showSuccess('signup_otp_sent'.tr(namedArgs: {'phone': phone}));
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) FocusScope.of(context).requestFocus(_otpFocusNode);
          });
        }
      } else {
        _showError(res['error'] ?? 'Unknown error occurred');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      _showError(e.toString());
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyAndRegister() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();

    if (otp.length < 4) {
      _showError('login_pin_length_error'.tr());
      return;
    }

    setState(() => _isLoading = true);

    try {
      final verifyRes = await ApiService.verifyOtp(phone, otp);
      if (verifyRes['success'] != true) {
        _showError(verifyRes['error'] ?? 'Invalid OTP');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final regRes = await ApiService.registerUser(name, phone);
      if (regRes['success'] != true) {
        _showError(regRes['error'] ?? 'Registration failed');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      await AuthService.login(phone);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      _showError(e.toString());
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 20.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 32),
                            _buildMainCard(),
                            const SizedBox(height: 32),
                            _buildLoginLink(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _buildTopNotification(_errorMessage, isError: true),
            _buildTopNotification(_successMessage, isError: false),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Image.asset(
          'assets/images/logo_t.png',
          height: 80,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.agriculture_rounded,
            size: 64,
            color: Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'signup_title'.tr(),
          textAlign: TextAlign.center,
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
          'signup_subtitle'.tr(),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(0xFF4B5563),
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildMainCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInputField(
          controller: _nameController,
          hintText: 'signup_name_hint'.tr(),
          icon: Icons.person_rounded,
          keyboardType: TextInputType.name,
          enabled: !_otpSent,
        ),
        const SizedBox(height: 20),
        _buildInputField(
          controller: _phoneController,
          hintText: 'signup_phone_hint'.tr(),
          icon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
          enabled: !_otpSent,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
        ),
        if (_otpSent) ...[
          const SizedBox(height: 28),
          _buildOtpInputField(),
          const SizedBox(height: 16),
          _buildHintChip(),
        ],
        const SizedBox(height: 32),
        _buildSubmitButton(),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required TextInputType keyboardType,
    required bool enabled,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: enabled ? 1.0 : 0.6,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD1D5DB),
            width: 1.5,
          ),
        ),
        child: TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.inter(
              color: const Color(0xFF9CA3AF),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 12),
              child: Icon(icon, color: const Color(0xFF059669), size: 24),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 50),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpInputField() {
    return AnimatedBuilder(
      animation: _otpController,
      builder: (context, child) {
        final text = _otpController.text;
        return Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                final hasChar = index < text.length;
                final char = hasChar ? text[index] : '';
                final isFocused =
                    index == text.length || (text.length == 6 && index == 5);

                return Container(
                  width: 48,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hasChar ? Colors.white : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isFocused
                          ? const Color(0xFF059669)
                          : (hasChar
                              ? const Color(0xFF10B981)
                              : const Color(0xFFD1D5DB)),
                      width: isFocused ? 2.5 : 1.5,
                    ),
                  ),
                  child: Text(
                    char,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                );
              }),
            ),
            Positioned.fill(
              child: TextField(
                controller: _otpController,
                focusNode: _otpFocusNode,
                keyboardType: TextInputType.number,
                cursorColor: Colors.transparent,
                style: const TextStyle(color: Colors.transparent),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: true,
                  fillColor: Colors.transparent,
                  counterText: '',
                ),
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (val) {
                  if (val.length == 6) {
                    FocusScope.of(context).unfocus();
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHintChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: const Color(0xFFA7F3D0),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_rounded,
            size: 16,
            color: Color(0xFF047857),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'signup_otp_hint'.tr(),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF047857),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    bool canProceed = true;
    if (_otpSent) {
      canProceed = _otpController.text.length == 6;
    }

    final bool isButtonDisabled = _isLoading || !canProceed;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: isButtonDisabled ? const Color(0xFF94A3B8) : const Color(0xFF059669),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isButtonDisabled ? null : (_otpSent ? _verifyAndRegister : _sendOtp),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Text(
                    _otpSent
                        ? 'signup_confirm_create'.tr()
                        : 'signup_send_otp'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return TextButton(
      onPressed: () {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const LoginScreen(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFFF8FAFC),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_rounded,
            size: 20,
            color: Color(0xFF4B5563),
          ),
          const SizedBox(width: 8),
          Text(
            'signup_already_have_account'.tr(),
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFF4B5563),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: Color(0xFF4B5563),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNotification(String? message, {required bool isError}) {
    final bool show = message != null;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      top: show ? MediaQuery.of(context).padding.top + 16 : -100,
      left: 24,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: isError ? const Color(0xFFDC2626) : const Color(0xFF059669),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message ?? '',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
