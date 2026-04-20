import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:cropsync/navigation/app_routes.dart';
import 'package:cropsync/widgets/auth/auth_alert_banner.dart';
import 'package:cropsync/widgets/auth/auth_logo_header.dart';

import 'package:cropsync/screens/home_screen.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/auth/login_screen.dart';
import 'package:cropsync/auth/operator_login_screen.dart';

class SignupScreen extends StatefulWidget {
  final String? initialPhoneNumber;
  const SignupScreen({super.key, this.initialPhoneNumber});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  static const Color _pageBackground = Color(0xFFEFF1F4);
  static const Color _fieldBackground = Color(0xFFF7F7F8);
  static const Color _fieldBorder = Color(0xFFD9DCE1);
  static const Color _primaryText = Color(0xFF15171A);
  static const Color _secondaryText = Color(0xFF6B7280);
  static const Color _accentText = Color(0xFF1F2937);
  static const Color _buttonColor = Color(0xFF111111);
  static const Color _buttonDisabled = Color(0xFFB8BDC7);

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

  bool _otpSent = false;
  Timer? _errorTimer;
  Timer? _successTimer;

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
    _entranceController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: Stack(
          children: [
            AnimatedPadding(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom * 0.5,
              ),
              child: SingleChildScrollView(
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
                                title: 'signup_title'.tr(),
                                subtitle: 'signup_subtitle'.tr(),
                              ),
                              const SizedBox(height: 26),
                              _buildMainCard(),
                              const SizedBox(height: 18),
                              _buildLoginLink(),
                              const SizedBox(height: 10),
                              _buildOperatorLink(),
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
            ),
            AuthAlertBanner(message: _errorMessage),
            AuthAlertBanner(message: _successMessage, isError: false),
          ],
        ),
      ),
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
          focusNode: _nameFocusNode,
        ),
        const SizedBox(height: 20),
        _buildInputField(
          controller: _phoneController,
          hintText: 'signup_phone_hint'.tr(),
          icon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
          enabled: !_otpSent,
          focusNode: _phoneFocusNode,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
        ),
        const SizedBox(height: 20),
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
                    const SizedBox(height: 28),
                    _buildOtpInputField(),
                    const SizedBox(height: 16),
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required TextInputType keyboardType,
    required bool enabled,
    List<TextInputFormatter>? inputFormatters,
    FocusNode? focusNode,
  }) {
    return AnimatedBuilder(
      animation: focusNode ?? const AlwaysStoppedAnimation(0),
      builder: (context, child) {
        final isFocused = focusNode?.hasFocus ?? false;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: enabled ? _fieldBackground : const Color(0xFFF1F3F6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isFocused ? const Color(0xFF1F2430) : const Color(0xFFC7CDD6),
              width: isFocused ? 1.6 : 1.1,
            ),
            boxShadow: isFocused
                ? [
                    const BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ]
                : [
                    const BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: true,
            readOnly: !enabled,
            canRequestFocus: enabled,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: _primaryText,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: GoogleFonts.inter(
                color: _secondaryText,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.only(left: 16, right: 10),
                child: Icon(
                  icon,
                  color: isFocused
                      ? _buttonColor
                      : (enabled
                          ? const Color(0xFF9AA1AB)
                          : const Color(0xFFB1B7C1)),
                  size: 22,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 50),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 20),
            ),
          ),
        );
      },
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
                const double boxGap = 6;
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
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        width: boxSize,
                        height: boxSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: hasChar ? Colors.white : _fieldBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrentFocused
                                ? _buttonColor
                                : (hasChar
                                    ? const Color(0xFF4B5563)
                                    : _fieldBorder),
                            width: isCurrentFocused ? 2.0 : 1.2,
                          ),
                          boxShadow: isCurrentFocused
                              ? [
                                  const BoxShadow(
                                    color: Color(0x18000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 130),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(
                            scale: animation,
                            child: child,
                          ),
                          child: Text(
                            char,
                            key: ValueKey('otp_char_$index$char'),
                            style: GoogleFonts.poppins(
                              fontSize: boxSize * 0.42,
                              fontWeight: FontWeight.w700,
                              color: _primaryText,
                            ),
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
                  filled: true,
                  fillColor: Colors.transparent,
                  counterText: '',
                ),
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (val) {
                  if (val.length == 6) {
                    FocusScope.of(context).unfocus();
                    HapticFeedback.mediumImpact();
                  }
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(Icons.apartment_rounded,
                          color: Color(0xFF111827), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'signup_select_fpo'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _primaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 24),
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
                            horizontal: 24, vertical: 16),
                        color: isSelected ? const Color(0xFFF8FAFC) : Colors.transparent,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.key.tr(),
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? _primaryText : _secondaryText,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF111827), size: 20),
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
        decoration: BoxDecoration(
          color: _otpSent ? const Color(0xFFF1F3F6) : _fieldBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFC7CDD6),
            width: 1.1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.apartment_rounded,
                size: 20,
                color: _otpSent
                    ? const Color(0xFFB1B7C1)
                    : const Color(0xFF808894),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _selectedFpoKey.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _primaryText,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _otpSent
                    ? const Color(0xFFB1B7C1)
                    : const Color(0xFF8A909A),
              ),
            ],
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
        border: Border.all(
          color: const Color(0xFFD1D5DB),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_rounded,
            size: 16,
            color: Color(0xFF4B5563),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'signup_otp_hint'.tr(),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _accentText,
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      height: 64,
      decoration: BoxDecoration(
        color: isButtonDisabled ? _buttonDisabled : _buttonColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isButtonDisabled
            ? null
            : [
                const BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          onTap: isButtonDisabled
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  if (_otpSent) {
                    _verifyAndRegister();
                  } else {
                    _sendOtp();
                  }
                },
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isLoading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Text(
                      key: ValueKey(_otpSent ? 'verify' : 'send'),
                      _otpSent
                          ? 'signup_confirm_create'.tr()
                          : 'signup_send_otp'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        splashColor: const Color(0x14000000),
        highlightColor: const Color(0x08000000),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pushReplacement(
            context,
            AppRoutes.noAnimation(const LoginScreen()),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6F8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD8DCE3)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_rounded,
                size: 20,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'signup_already_have_account'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: _accentText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: Color(0xFF6B7280),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOperatorLink() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        splashColor: const Color(0x14000000),
        highlightColor: const Color(0x08000000),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pushReplacement(
            context,
            AppRoutes.noAnimation(const OperatorLoginScreen()),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6F8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFD4D8DF),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _buttonColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.agriculture_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'signup_operator_signin'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _accentText,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
