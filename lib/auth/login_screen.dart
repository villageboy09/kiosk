import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cropsync/auth/signup_screen.dart';
import 'package:cropsync/navigation/app_routes.dart';
import 'package:cropsync/screens/home_screen.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:cropsync/widgets/auth/auth_alert_banner.dart';
import 'package:cropsync/widgets/auth/auth_logo_header.dart';

class LoginScreen extends StatefulWidget {
  final String? initialPhoneNumber;

  const LoginScreen({super.key, this.initialPhoneNumber});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _pinController = TextEditingController();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  String? _errorMessage;
  String? _pressedButton;
  Timer? _errorTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();

    final digits = widget.initialPhoneNumber?.replaceAll(RegExp(r'\D'), '');
    if (digits != null) {
      _pinController.text =
          digits.length > 10 ? digits.substring(0, 10) : digits;
    }
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    _animController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    _errorTimer?.cancel();
    setState(() => _errorMessage = message);
    _errorTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _errorMessage = null);
      }
    });
  }

  void _appendDigit(String digit) {
    if (_pinController.text.length >= 10) return;
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

  Future<void> _login() async {
    final pin = _pinController.text.trim();
    if (pin.length != 10) {
      _showError('login_pin_length_error'.tr());
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await ApiService.checkUser(pin);
      if (user == null) {
        _showError('login_user_not_registered_redirect'.tr());
        await Future.delayed(const Duration(milliseconds: 1200));
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          AppRoutes.slideFromRight(
            const SignupScreen(),
          ),
        );
        return;
      }

      await AuthService.login(pin);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        AppRoutes.fade(const HomeScreen()),
      );
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight - 48),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 450),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AuthLogoHeader(
                                    title: 'login_welcome_back'.tr(),
                                    subtitle: 'enter_field'.tr(
                                      namedArgs: {'field': 'user_id'.tr()},
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildSingleInputDisplay(),
                                  const SizedBox(height: 16),
                                  _buildHintChip(),
                                  const SizedBox(height: 20),
                                  _buildKeypad(),
                                  const SizedBox(height: 16),
                                  _buildSubmitButton(),
                                  const SizedBox(height: 20),
                                  _buildSignupLink(),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            AuthAlertBanner(message: _errorMessage),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleInputDisplay() {
    final text = _pinController.text;
    final remainingLength = 10 - text.length;
    final hasInput = text.isNotEmpty;
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: hasInput ? AppTheme.textPrimary : const Color(0xFFD1D5DB),
          width: 2,
        ),
        boxShadow: hasInput
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: text),
              TextSpan(
                text: '•' * remainingLength,
                style: TextStyle(
                  color: AppTheme.textPrimary.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
          maxLines: 1,
          style: AppTheme.getTextStyle(context,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 6,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildHintChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(100),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: AppTheme.textSecondary),
          SizedBox(width: 8),
          Text(
            'Your phone number is your login pin',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
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
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
        children: [
          ...List.generate(9, (index) => index + 1)
              .map((number) => _buildKeyButton(number.toString())),
          const SizedBox.shrink(),
          _buildKeyButton('0'),
          _buildDeleteButton(),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final canProceed = _pinController.text.length == 10;
    final bool isButtonDisabled = _isLoading || !canProceed;

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isButtonDisabled
            ? null
            : () {
                HapticFeedback.mediumImpact();
                _login();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isButtonDisabled ? const Color(0xFFD1D5DB) : AppTheme.textPrimary,
          minimumSize: const Size(double.infinity, 64),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          elevation: isButtonDisabled ? 0 : 4,
          shadowColor: AppTheme.textPrimary.withValues(alpha: 0.3),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 3),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'login_submit'.tr() == 'login_submit' ? 'Sign In' : 'login_submit'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ],
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
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isPressed ? const Color(0xFFF3F4F6) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isPressed ? AppTheme.textPrimary : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
          boxShadow: isPressed
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
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
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isPressed ? const Color(0xFFFEF2F2) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                isPressed ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB),
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
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            AppRoutes.slideFromRight(
              const SignupScreen(),
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textSecondary,
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
          minimumSize: const Size(double.infinity, 64),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_add_rounded,
              size: 20,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 10),
            Text(
              'signup_create_account'.tr(),
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
