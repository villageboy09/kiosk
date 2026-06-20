import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:cropsync/navigation/app_routes.dart';
import 'package:cropsync/widgets/auth/auth_alert_banner.dart';
import 'package:cropsync/widgets/auth/auth_logo_header.dart';

import 'package:cropsync/screens/home_screen.dart';
import 'package:cropsync/screens/retailer/retailer_dashboard.dart';
import 'package:cropsync/screens/officer/extension_officer_dashboard.dart';
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
  final _nameFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _fpoDropdownFocusNode = FocusNode();
  final _operatorPhoneFocusNode = FocusNode();
  final _operatorPasswordFocusNode = FocusNode();

  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  bool _isOperator = false;
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

    _nameFocusNode.addListener(_onFocusChange);
    _phoneFocusNode.addListener(_onFocusChange);
    _fpoDropdownFocusNode.addListener(_onFocusChange);
    _operatorPhoneFocusNode.addListener(_onFocusChange);
    _operatorPasswordFocusNode.addListener(_onFocusChange);

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

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    _successTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _nameFocusNode.removeListener(_onFocusChange);
    _phoneFocusNode.removeListener(_onFocusChange);
    _fpoDropdownFocusNode.removeListener(_onFocusChange);
    _operatorPhoneFocusNode.removeListener(_onFocusChange);
    _operatorPasswordFocusNode.removeListener(_onFocusChange);
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _fpoDropdownFocusNode.dispose();
    _operatorPhoneFocusNode.dispose();
    _operatorPasswordFocusNode.dispose();
    _operatorPhoneController.dispose();
    _operatorPasswordController.dispose();
    _entranceController.dispose();
    try {
      smartAuth.removeUserConsentApiListener();
    } catch (e) {
      debugPrint('Error removing SMS listener: $e');
    }
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

  Future<void> _selectPhoneNumber() async {
    HapticFeedback.selectionClick();
    if (!mounted) return;

    List<Map<String, dynamic>> simList = [];
    try {
      final List<dynamic>? rawSims = await const MethodChannel('cropsync/sim_info')
          .invokeMethod<List<dynamic>>('getSimInfo');
      if (rawSims != null) {
        simList = rawSims.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching SIM details from channel: $e');
    }

    if (!mounted) return;

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
                      child: const Icon(Icons.sim_card_rounded,
                          color: AppTheme.textPrimary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Select Mobile Number',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (simList.isEmpty) ...[
                const SizedBox(height: 16),
                const Icon(Icons.sim_card_alert_rounded, size: 48, color: AppTheme.textSecondary),
                const SizedBox(height: 12),
                const Text(
                  'No SIM Card Detected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'We couldn\'t automatically read your SIM details.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                ...simList.map((sim) {
                  final int slot = sim['slot'] as int? ?? 1;
                  final String carrier = sim['carrier'] as String? ?? 'Carrier';
                  final String rawNumber = sim['number'] as String? ?? '';
                  final String displayNum = rawNumber.isNotEmpty ? rawNumber : 'Select Number (Not Available)';

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      leading: const Icon(Icons.sim_card_outlined, color: AppTheme.textSecondary, size: 24),
                      title: Text(
                        displayNum,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16, color: AppTheme.textPrimary),
                      ),
                      subtitle: Text('SIM Slot $slot - $carrier'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (rawNumber.isNotEmpty) {
                          String cleanNum = rawNumber.replaceAll(RegExp(r'[^\d+]'), '');
                          if (cleanNum.startsWith('+91')) {
                            cleanNum = cleanNum.substring(3);
                          } else if (cleanNum.startsWith('91') && cleanNum.length == 12) {
                            cleanNum = cleanNum.substring(2);
                          }
                          cleanNum = cleanNum.replaceAll(RegExp(r'\D'), '');
                          setState(() {
                            _phoneController.text = cleanNum;
                          });
                        }
                        Navigator.pop(context);
                      },
                    ),
                  );
                }),
              ],
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }



  Future<void> _registerFarmer() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      _showError('signup_error_name'.tr());
      return;
    }

    if (phone.isEmpty) {
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
      final user = AuthService.currentUser;
      if (user?.membershipType == 'Retailer') {
        Navigator.pushReplacement(
          context,
          AppRoutes.fade(const RetailerDashboard()),
        );
      } else if (user?.membershipType == 'Officer') {
        Navigator.pushReplacement(
          context,
          AppRoutes.fade(const ExtensionOfficerDashboard()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          AppRoutes.fade(const HomeScreen()),
        );
      }
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
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
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
                                AnimatedCrossFade(
                                  firstChild: _buildMainCard(
                                    key: const ValueKey('farmer'),
                                  ),
                                  secondChild: _buildOperatorCard(
                                    key: const ValueKey('operator'),
                                  ),
                                  crossFadeState: _isOperator
                                      ? CrossFadeState.showSecond
                                      : CrossFadeState.showFirst,
                                  duration: const Duration(milliseconds: 350),
                                  firstCurve: Curves.easeInOutCubic,
                                  secondCurve: Curves.easeInOutCubic,
                                  sizeCurve: Curves.easeInOutCubic,
                                ),
                                const SizedBox(height: 18),
                                if (!_isOperator) _buildLoginLink(),
                                const SizedBox(height: 10),
                                SizedBox(
                                    height:
                                        MediaQuery.of(context).viewInsets.bottom > 0
                                            ? 20
                                            : 40),
                              ],
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
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _nameFocusNode.requestFocus(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: _nameFocusNode.hasFocus ? AppTheme.textPrimary : AppTheme.border.withValues(alpha: 0.5),
                width: _nameFocusNode.hasFocus ? 2.0 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 24, right: 14),
                  child: AnimatedScale(
                    scale: _nameFocusNode.hasFocus ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 22,
                      color: _nameFocusNode.hasFocus ? AppTheme.textPrimary : AppTheme.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    keyboardType: TextInputType.name,
                    decoration: InputDecoration(
                      hintText: 'signup_name_hint'.tr(),
                      hintStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textHint,
                      ),
                      border: InputBorder.none,
                      filled: false,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Focus(
          focusNode: _phoneFocusNode,
          child: InkWell(
            onTap: () {
              _phoneFocusNode.requestFocus();
              _selectPhoneNumber();
            },
            borderRadius: BorderRadius.circular(100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: _phoneFocusNode.hasFocus ? AppTheme.textPrimary : AppTheme.border.withValues(alpha: 0.5),
                  width: _phoneFocusNode.hasFocus ? 2.0 : 1.5,
                ),
              ),
              child: Row(
                children: [
                  AnimatedScale(
                    scale: _phoneFocusNode.hasFocus ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.smartphone_rounded,
                      size: 22,
                      color: _phoneFocusNode.hasFocus ? AppTheme.textPrimary : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _phoneController.text.isEmpty
                          ? 'signup_phone_hint'.tr()
                          : _phoneController.text,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _phoneController.text.isEmpty
                            ? AppTheme.textHint
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (_phoneController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.cancel_outlined,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _phoneController.clear();
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildClientCodePicker(),
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
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _operatorPhoneFocusNode.requestFocus(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: _operatorPhoneFocusNode.hasFocus ? AppTheme.textPrimary : AppTheme.border.withValues(alpha: 0.5),
                width: _operatorPhoneFocusNode.hasFocus ? 2.0 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 24, right: 14),
                  child: Icon(
                    Icons.smartphone_rounded,
                    size: 22,
                    color: _operatorPhoneFocusNode.hasFocus ? AppTheme.textPrimary : AppTheme.textSecondary,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _operatorPhoneController,
                    focusNode: _operatorPhoneFocusNode,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: InputDecoration(
                      hintText: 'operator_phone_hint'.tr(),
                      hintStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textHint,
                      ),
                      border: InputBorder.none,
                      filled: false,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _operatorPasswordFocusNode.requestFocus(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: _operatorPasswordFocusNode.hasFocus ? AppTheme.textPrimary : AppTheme.border.withValues(alpha: 0.5),
                width: _operatorPasswordFocusNode.hasFocus ? 2.0 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 24, right: 14),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 22,
                    color: _operatorPasswordFocusNode.hasFocus ? AppTheme.textPrimary : AppTheme.textSecondary,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _operatorPasswordController,
                    focusNode: _operatorPasswordFocusNode,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'operator_password_hint'.tr(),
                      hintStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textHint,
                      ),
                      border: InputBorder.none,
                      filled: false,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: AppTheme.textHint,
                      size: 22,
                    ),
                    splashRadius: 24,
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        _buildSubmitButton(),
      ],
    );
  }



  void _showFpoPicker() {
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
                        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.textPrimary : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: isSelected ? AppTheme.textPrimary : const Color(0xFFE5E7EB),
                            width: 1.5,
                          ),
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
                                      ? Colors.white
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                              color: isSelected ? Colors.white : AppTheme.textHint,
                              size: 20,
                            ),
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
    return Focus(
      focusNode: _fpoDropdownFocusNode,
      child: InkWell(
        onTap: () {
          _fpoDropdownFocusNode.requestFocus();
          _showFpoPicker();
        },
        borderRadius: BorderRadius.circular(100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: _fpoDropdownFocusNode.hasFocus ? AppTheme.textPrimary : AppTheme.border.withValues(alpha: 0.5),
              width: _fpoDropdownFocusNode.hasFocus ? 2.0 : 1.5,
            ),
          ),
          child: Row(
            children: [
              AnimatedScale(
                scale: _fpoDropdownFocusNode.hasFocus ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.business_outlined,
                  size: 22,
                  color: _fpoDropdownFocusNode.hasFocus ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _selectedFpoKey.tr(),
                  style: const TextStyle(
                    fontSize: 15,
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
      ),
    );
  }



  Widget _buildSubmitButton() {
    bool canProceed = true;
    if (_isOperator) {
      canProceed = _operatorPhoneController.text.length == 10 &&
          _operatorPasswordController.text.isNotEmpty;
    } else {
      canProceed =
          _phoneController.text.isNotEmpty && _nameController.text.isNotEmpty;
    }

    final bool isButtonDisabled = _isLoading || !canProceed;

    return ElevatedButton(
      onPressed: isButtonDisabled
          ? null
          : () {
              HapticFeedback.mediumImpact();
              if (_isOperator) {
                _loginOperator();
              } else {
                _registerFarmer();
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
                  : 'signup_confirm_create'.tr(),
            ),
    );
  }

  Widget _buildLoginLink() {
    return OutlinedButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        Navigator.pushReplacement(
          context,
          AppRoutes.slideFromLeft(const LoginScreen()),
        );
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.textSecondary,
        side: BorderSide(color: AppTheme.border.withValues(alpha: 0.5), width: 1.5),
        minimumSize: const Size(double.infinity, 64),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.login_rounded, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(
            'signup_already_have_account'.tr(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
