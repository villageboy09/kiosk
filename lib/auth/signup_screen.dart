import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:cropsync/navigation/app_routes.dart';
import 'package:cropsync/widgets/auth/auth_alert_banner.dart';
import 'package:cropsync/widgets/auth/auth_logo_header.dart';

import 'package:cropsync/screens/home_screen.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/auth/login_screen.dart';
import 'package:cropsync/services/operator_auth_service.dart';
import 'package:cropsync/screens/operator/operator_dashboard.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:smart_auth/smart_auth.dart';

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
  final _nameFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _fpoDropdownFocusNode = FocusNode();

  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  bool _isOperator = false;
  bool _otpSent = false;
  bool _obscurePassword = true;

  final _operatorPhoneController = TextEditingController();
  final _operatorPasswordController = TextEditingController();

  Timer? _errorTimer;
  Timer? _successTimer;
  final smartAuth = SmartAuth.instance;

  static const List<MapEntry<String, String>> _fpoOptions = [
    MapEntry('signup_fpo_chinna_kodur', 'SDP001'),
    MapEntry('signup_fpo_narayanraopet', 'SDP002'),
    MapEntry('signup_fpo_kattangur', 'NLG001'),
    MapEntry('signup_fpo_tekamal', 'MDK001'),
    MapEntry('signup_fpo_none', 'HYD001'),
  ];

  late String _selectedFpoKey;
  late String _selectedClientCode;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhoneNumber != null) {
      _phoneController.text = widget.initialPhoneNumber!;
    }

    _selectedFpoKey = _fpoOptions.last.key;
    _selectedClientCode = _fpoOptions.last.value;

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
    _errorTimer?.cancel();
    _successTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _fpoDropdownFocusNode.dispose();
    _operatorPhoneController.dispose();
    _operatorPasswordController.dispose();
    _entranceController.dispose();
    smartAuth.removeUserConsentApiListener();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    _errorTimer?.cancel();
    setState(() {
      _errorMessage = msg;
      _successMessage = null;
    });
    _errorTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _errorMessage = null);
    });
  }

  void _listenForSms() async {
    try {
      final res = await smartAuth.getSmsWithUserConsentApi();
      if (res.data?.code != null) {
        if (mounted) {
          setState(() {
            _otpController.text = res.data!.code!;
          });
          // Auto-submit if the code length is exactly 6
          if (_otpController.text.length == 6) {
            FocusScope.of(context).unfocus();
            HapticFeedback.mediumImpact();
            _verifyAndRegister();
          }
        }
      }
    } catch (e) {
      debugPrint('SMS Autofill error: $e');
    }
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    _successTimer?.cancel();
    setState(() {
      _successMessage = msg;
      _errorMessage = null;
    });
    _successTimer = Timer(const Duration(seconds: 4), () {
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
      if (isRegistered != null) {
        _showError('signup_user_exists'.tr());
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          AppRoutes.slideFromLeft(const LoginScreen()),
        );
        return;
      }

      final res = await ApiService.sendOtp(phone);
      if (res['success'] == true) {
        if (mounted) {
          HapticFeedback.mediumImpact();
          setState(() {
            _otpSent = true;
            _isLoading = false;
          });
          _showSuccess('signup_otp_sent'.tr(namedArgs: {'phone': phone}));
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) FocusScope.of(context).requestFocus(_otpFocusNode);
          });
          _listenForSms();
        }
      } else {
        _showError(res['error'] ?? 'signup_unknown_error'.tr());
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

    if (otp.length < 6) {
      _showError('login_pin_length_error'.tr());
      return;
    }

    setState(() => _isLoading = true);

    try {
      final verifyRes = await ApiService.verifyOtp(phone, otp);
      if (verifyRes['success'] != true) {
        _showError(verifyRes['error'] ?? 'signup_invalid_otp'.tr());
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final regRes = await ApiService.registerUser(
        name,
        phone,
        _selectedClientCode,
      );
      if (regRes['success'] != true) {
        _showError(regRes['error'] ?? 'signup_registration_failed'.tr());
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      await AuthService.login(phone);

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      _showError(e.toString());
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginOperator() async {
    final phone = _operatorPhoneController.text.trim();
    final password = _operatorPasswordController.text;

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
      HapticFeedback.heavyImpact();
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
      backgroundColor: AppTheme.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AuthLogoHeader(
                                title: _isOperator
                                    ? 'operator_login_title'.tr()
                                    : 'signup_title'.tr(),
                                subtitle: _isOperator
                                    ? 'operator_login_subtitle'.tr()
                                    : 'signup_subtitle'.tr(),
                              ),
                              const SizedBox(height: 24),
                              _buildRoleToggle(),
                              const SizedBox(height: 26),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0.05, 0),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: _isOperator
                                    ? _buildOperatorCard(
                                        key: const ValueKey('operator'))
                                    : _buildMainCard(
                                        key: const ValueKey('farmer')),
                              ),
                              const SizedBox(height: 18),
                              if (!_isOperator) _buildLoginLink(),
                              const SizedBox(height: 10),
                              SizedBox(
                                  height:
                                      MediaQuery.of(context).viewInsets.bottom >
                                              0
                                          ? 20
                                          : 40),
                            ],
                          ),
                        ),
                      ),
                  ),
                ),
              ),
            ),
            AuthAlertBanner(message: _errorMessage),
            AuthAlertBanner(message: _successMessage, isError: false),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleToggle() {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            alignment:
                _isOperator ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_isOperator) {
                      HapticFeedback.selectionClick();
                      setState(() => _isOperator = false);
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      'farmer'.tr(),
                      style: TextStyle(
                        
                        fontSize: 15,
                        fontWeight:
                            _isOperator ? FontWeight.w500 : FontWeight.w700,
                        color: _isOperator
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (!_isOperator) {
                      HapticFeedback.selectionClick();
                      setState(() => _isOperator = true);
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      'operator'.tr(),
                      style: TextStyle(
                        
                        fontSize: 15,
                        fontWeight:
                            _isOperator ? FontWeight.w700 : FontWeight.w500,
                        color: _isOperator
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          enabled: !_otpSent,
          keyboardType: TextInputType.name,
          decoration: InputDecoration(
            hintText: 'signup_name_hint'.tr(),
            prefixIcon: const Icon(Icons.person_rounded),
          ),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneController,
          focusNode: _phoneFocusNode,
          enabled: !_otpSent,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: InputDecoration(
            hintText: 'signup_phone_hint'.tr(),
            prefixIcon: const Icon(Icons.phone_rounded),
          ),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        _buildClientCodePicker(),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            axis: Axis.vertical,
            axisAlignment: -1.0,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          ),
          child: _otpSent
              ? Column(
                  key: const ValueKey('otp_section'),
                  children: [
                    const SizedBox(height: 24),
                    _buildOtpInputField(),
                    const SizedBox(height: 20),
                    Center(child: _buildHintChip()),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey('no_otp')),
        ),
        const SizedBox(height: 32),
        _buildSubmitButton(),
      ],
    );
  }

  Widget _buildOperatorCard({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _operatorPhoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: InputDecoration(
            hintText: 'operator_phone_hint'.tr(),
            prefixIcon: const Icon(Icons.phone_rounded),
          ),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _operatorPasswordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: 'operator_password_hint'.tr(),
            prefixIcon: const Icon(Icons.lock_rounded),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: AppTheme.textHint,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 32),
        _buildSubmitButton(), // Reuse common submit button style
      ],
    );
  }

  Widget _buildOtpInputField() {
    return AnimatedBuilder(
      animation: Listenable.merge([_otpController, _otpFocusNode]),
      builder: (context, child) {
        final text = _otpController.text;
        final isFocused = _otpFocusNode.hasFocus;

        return Stack(
          alignment: Alignment.center,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                const double boxGap = 8;
                final double maxWidth = constraints.maxWidth;
                final double calculated = (maxWidth - (5 * boxGap)) / 6;
                final double boxSize = calculated.clamp(44.0, 58.0);

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    final hasChar = index < text.length;
                    final char = hasChar ? text[index] : '';
                    final isCurrentFocused = isFocused && index == text.length;

                    return Padding(
                      padding: EdgeInsets.only(right: index == 5 ? 0 : boxGap),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: boxSize,
                        height: boxSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCurrentFocused
                                ? AppTheme.textPrimary
                                : (hasChar
                                    ? AppTheme.textSecondary
                                    : const Color(0xFFE5E7EB)),
                            width: isCurrentFocused ? 2.0 : 1.5,
                          ),
                          boxShadow: isCurrentFocused
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          char,
                          style: const TextStyle(
                            
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
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
                  filled: false,
                  counterText: '',
                ),
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (val) {
                  if (val.length == 6) {
                    FocusScope.of(context).unfocus();
                    HapticFeedback.mediumImpact();
                  }
                  setState(() {}); // Refresh boxes
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFpoPicker() {
    if (_otpSent) return;
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.apartment_rounded,
                          color: AppTheme.textPrimary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'signup_select_fpo'.tr(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 32),
                  itemCount: _fpoOptions.length,
                  itemBuilder: (context, index) {
                    final item = _fpoOptions[index];
                    final isSelected = item.key == _selectedFpoKey;
                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedFpoKey = item.key;
                          _selectedClientCode = item.value;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 20),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFF9FAFB)
                              : Colors.transparent,
                          border: isSelected
                              ? const Border(
                                  left: BorderSide(
                                      color: AppTheme.textPrimary, width: 4))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.key.tr(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppTheme.textPrimary
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded,
                                  color: AppTheme.textPrimary, size: 22),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClientCodePicker() {
    return InkWell(
      onTap: _showFpoPicker,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: _otpSent ? const Color(0xFFF3F4F6) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD9DCE1),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.apartment_rounded,
              size: 22,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _selectedFpoKey.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppTheme.textHint,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHintChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            'signup_otp_hint'.tr(),
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

  Widget _buildSubmitButton() {
    bool canProceed = true;
    if (_otpSent && !_isOperator) {
      canProceed = _otpController.text.length == 6;
    } else if (_isOperator) {
      canProceed = _operatorPhoneController.text.length == 10 &&
          _operatorPasswordController.text.isNotEmpty;
    } else {
      canProceed =
          _phoneController.text.length == 10 && _nameController.text.isNotEmpty;
    }

    final bool isButtonDisabled = _isLoading || !canProceed;

    return ElevatedButton(
      onPressed: isButtonDisabled
          ? null
          : () {
              HapticFeedback.mediumImpact();
              if (_isOperator) {
                _loginOperator();
              } else if (_otpSent) {
                _verifyAndRegister();
              } else {
                _sendOtp();
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isButtonDisabled ? const Color(0xFFD1D5DB) : AppTheme.textPrimary,
        minimumSize: const Size(double.infinity, 64),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 3),
            )
          : Text(
              _isOperator
                  ? 'operator_login_button'.tr()
                  : (_otpSent
                      ? 'signup_confirm_create'.tr()
                      : 'signup_send_otp'.tr()),
            ),
    );
  }

  Widget _buildLoginLink() {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pushReplacement(
          context,
          AppRoutes.noAnimation(const LoginScreen()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.login_rounded,
                size: 20, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            Text(
              'signup_already_have_account'.tr(),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

