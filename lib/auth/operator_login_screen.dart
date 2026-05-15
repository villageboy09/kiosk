import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:cropsync/navigation/app_routes.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:cropsync/widgets/auth/auth_alert_banner.dart';
import 'package:cropsync/widgets/auth/auth_logo_header.dart';

import 'package:cropsync/services/operator_auth_service.dart';
import 'package:cropsync/screens/operator/operator_dashboard.dart';
import 'package:cropsync/auth/signup_screen.dart';

class OperatorLoginScreen extends StatefulWidget {
  const OperatorLoginScreen({super.key});

  @override
  State<OperatorLoginScreen> createState() => _OperatorLoginScreenState();
}

class _OperatorLoginScreenState extends State<OperatorLoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  static const Color _accent = Color(0xFF111827);
  static const Color _surface = Color(0xFFF9FAFB);
  static const Color _border = Color(0xFFD1D5DB);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSub = Color(0xFF4B5563);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _animController,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _animController,
          curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic)),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _errorMessage = msg);
    Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _errorMessage = null);
    });
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (phone.length < 10) {
      _showError('operator_login_error_phone'.tr());
      return;
    }
    if (password.isEmpty) {
      _showError('operator_login_error_password'.tr());
      return;
    }

    setState(() => _isLoading = true);

    try {
      await OperatorAuthService.login(phone, password);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        AppRoutes.fade(const OperatorDashboard()),
      );
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned(
              top: -70,
              right: -90,
              child: _DecorBlob(color: Color(0xFFDCEBFA), size: 210),
            ),
            const Positioned(
              bottom: -90,
              left: -110,
              child: _DecorBlob(color: Color(0xFFEFF6FF), size: 240),
            ),
            Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 20.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.07),
                              blurRadius: 28,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AuthLogoHeader(
                              title: 'operator_login_title'.tr(),
                              subtitle: 'operator_login_subtitle'.tr(),
                              logoHeight: 72,
                            ),
                            const SizedBox(height: 24),
                            _buildOperatorBadge(),
                            const SizedBox(height: 24),
                            _buildPhoneField(),
                            const SizedBox(height: 16),
                            _buildPasswordField(),
                            const SizedBox(height: 28),
                            _buildLoginButton(),
                            const SizedBox(height: 20),
                            _buildBackLink(),
                            const SizedBox(height: 4),
                            Text(
                              'Secure operator access for managed equipment jobs.',
                              textAlign: TextAlign.center,
                              style: AppTheme.getTextStyle(
                                context,
                                fontSize: 12,
                                color: const Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
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
            AuthAlertBanner(message: _errorMessage),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatorBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0FDF4), Color(0xFFEFF6FF)],
        ),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFBAE6FD), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_rounded,
              size: 16, color: Color(0xFF0F172A)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'operator_login_badge'.tr(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.getTextStyle(
                context,
                fontSize: 13,
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        style: AppTheme.getTextStyle(context,
            fontSize: 16, color: _textPrimary, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'operator_phone_hint'.tr(),
          hintStyle: AppTheme.getTextStyle(context,
              color: const Color(0xFF9CA3AF),
              fontSize: 16,
              fontWeight: FontWeight.w500),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 16, right: 12),
            child: Icon(Icons.phone_rounded, color: _accent, size: 22),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 50),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: AppTheme.getTextStyle(context,
            fontSize: 16, color: _textPrimary, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'operator_password_hint'.tr(),
          hintStyle: AppTheme.getTextStyle(context,
              color: const Color(0xFF9CA3AF),
              fontSize: 16,
              fontWeight: FontWeight.w500),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 16, right: 12),
            child: Icon(Icons.lock_rounded, color: _accent, size: 22),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 50),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: const Color(0xFF9CA3AF),
                size: 22,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: _isLoading ? const Color(0xFF94A3B8) : _accent,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _isLoading
            ? []
            : [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _isLoading ? null : _login,
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(
                    'operator_login_button'.tr(),
                    style: AppTheme.getTextStyle(
                      context,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackLink() {
    return TextButton(
      onPressed: () => Navigator.pushReplacement(
        context,
        AppRoutes.slideFromLeft(const SignupScreen()),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFFF8FAFC),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_back_rounded,
              size: 18, color: Color(0xFF4B5563)),
          const SizedBox(width: 8),
          Text(
            'operator_back_to_farmer_login'.tr(),
            style: AppTheme.getTextStyle(
              context,
              fontSize: 15,
              color: _textSub,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _DecorBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
