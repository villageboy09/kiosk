import 'package:flutter/material.dart';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:cropsync/navigation/app_routes.dart';
import 'package:cropsync/widgets/auth/auth_alert_banner.dart';
import 'package:cropsync/widgets/auth/auth_logo_header.dart';

import 'package:cropsync/screens/home_screen.dart';

import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/auth/signup_screen.dart';
import 'package:cropsync/theme/app_theme.dart';

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
  Timer? _errorTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhoneNumber != null) {
      _pinController.text = widget.initialPhoneNumber!;
    }
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
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
      if (isRegistered == null) {
        _showError('login_user_not_registered_redirect'.tr());
        // Add a slight delay so user can see the message
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => SignupScreen(initialPhoneNumber: pin)),
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
    _errorTimer?.cancel();
    setState(() => _errorMessage = msg);
    _errorTimer = Timer(const Duration(seconds: 4), () {
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
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AuthLogoHeader(
                                title: 'login_welcome_back'.tr(),
                                subtitle: 'enter_field'
                                    .tr(namedArgs: {'field': 'user_id'.tr()}),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),
                              _buildSingleInputDisplay(),
                              const SizedBox(height: 16),
                              _buildHintChip(),
                              const SizedBox(height: 32),
                              _buildKeypad(),
                              const SizedBox(height: 32),
                              _buildSignupLink(),
                              const SizedBox(height: 16),
                            ],
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
    final hasInput = _pinController.text.isNotEmpty;
    final displayText = hasInput ? _pinController.text : '------';
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      width: double.infinity,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasInput ? AppTheme.textPrimary : const Color(0xFFE5E7EB),
          width: 2.0,
        ),
        boxShadow: hasInput ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ] : null,
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          displayText,
          maxLines: 1,
          style: TextStyle(
            
            fontSize: hasInput ? 26 : 32,
            fontWeight: FontWeight.w800,
            letterSpacing: hasInput ? 4 : 8,
            color: hasInput ? AppTheme.textPrimary : AppTheme.textHint,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            'login_pin_hint'.tr(),
            style: const TextStyle(
              
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
        childAspectRatio: 1.2,
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AppTheme.textPrimary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isPressed ? null : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        alignment: Alignment.center,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : const Icon(
                Icons.arrow_forward_rounded,
                size: 32,
                color: Colors.white,
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
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPressed ? AppTheme.textPrimary : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
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
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPressed ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB),
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
    return InkWell(
      onTap: () {
        Navigator.pushReplacement(
          context,
          AppRoutes.slideFromRight(const SignupScreen()),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
                
                fontSize: 16,
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

