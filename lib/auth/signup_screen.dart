import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cropsync/navigation/app_routes.dart';
import 'package:cropsync/widgets/auth/auth_alert_banner.dart';
import 'package:cropsync/widgets/auth/auth_logo_header.dart';
import 'package:cropsync/screens/home_screen.dart';
import 'package:cropsync/screens/retailer/retailer_dashboard.dart';
import 'package:cropsync/screens/officer/extension_officer_dashboard.dart';
import 'package:cropsync/screens/creator/creator_home_screen.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/auth/login_screen.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:smart_auth/smart_auth.dart';

class SignupScreen extends StatefulWidget {
  final String? initialPhoneNumber;
  const SignupScreen({super.key, this.initialPhoneNumber});

  /// Exposes strict phone validation for direct testing and validation checks
  static String? validatePhoneNumber(String rawPhone) =>
      _SignupScreenState.validatePhoneNumber(rawPhone);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _securityAnswerController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();

  final _phoneFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _securityAnswerFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();

  String _selectedSecurityQuestion = 'security_q1';

  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  String _selectedRole = 'farmer';

  Timer? _errorTimer;
  Timer? _successTimer;
  final smartAuth = SmartAuth.instance;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhoneNumber != null) {
      final digits = widget.initialPhoneNumber!.replaceAll(RegExp(r'\D'), '');
      _phoneController.text = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    }

    _phoneFocusNode.addListener(_onFocusChange);
    _passwordFocusNode.addListener(_onFocusChange);
    _securityAnswerFocusNode.addListener(_onFocusChange);
    _usernameFocusNode.addListener(_onFocusChange);
    _emailFocusNode.addListener(_onFocusChange);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
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
    _phoneController.dispose();
    _passwordController.dispose();
    _securityAnswerController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneFocusNode.removeListener(_onFocusChange);
    _passwordFocusNode.removeListener(_onFocusChange);
    _securityAnswerFocusNode.removeListener(_onFocusChange);
    _usernameFocusNode.removeListener(_onFocusChange);
    _emailFocusNode.removeListener(_onFocusChange);
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _securityAnswerFocusNode.dispose();
    _usernameFocusNode.dispose();
    _emailFocusNode.dispose();
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

  /// Strict phone number validation:
  /// - Exact 10 digits
  /// - Must start with 6, 7, 8, or 9
  /// - Rejects numbers with fewer than 4 unique digits (e.g. 9999999998, 9898989898, 9998887777)
  /// - Rejects runs of 4+ consecutive identical digits (e.g. 9999, 0000, 8888)
  /// - Rejects any single digit appearing 5 or more times throughout the 10 digits
  /// - Rejects sequential runs of 4+ digits (e.g. 1234, 9876, 5432)
  /// - Rejects repeated multi-digit patterns and dummy numbers
  static String? validatePhoneNumber(String rawPhone) {
    final clean = rawPhone.trim().replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) {
      return 'signup_error_phone'.tr();
    }
    if (clean.length != 10) {
      return 'Please enter a valid 10-digit mobile number';
    }
    if (!RegExp(r'^[6-9]').hasMatch(clean)) {
      return 'Mobile number must start with 6, 7, 8, or 9';
    }

    // 1. Check distinct unique digits (real numbers have at least 4 unique digits)
    final uniqueDigits = clean.split('').toSet();
    if (uniqueDigits.length < 4) {
      return 'Invalid mobile number: too few distinct digits';
    }

    // 2. Check consecutive identical digits (e.g., 9999, 8888, 0000)
    if (RegExp(r'(\d)\1{3,}').hasMatch(clean)) {
      return 'Invalid mobile number: consecutive repeating digits';
    }

    // 3. Check max frequency of any single digit (no digit should appear 5+ times)
    final digitCounts = <String, int>{};
    for (var i = 0; i < clean.length; i++) {
      final char = clean[i];
      digitCounts[char] = (digitCounts[char] ?? 0) + 1;
      if (digitCounts[char]! >= 5) {
        return 'Invalid mobile number: digit "$char" repeated too many times';
      }
    }

    // 4. Check sequential 6+ digit ascending/descending patterns or full sequences
    const sequentialPatterns = [
      '0123456789',
      '1234567890',
      '9876543210',
      '8765432109',
      '9123456789',
      '123456',
      '234567',
      '345678',
      '456789',
      '567890',
      '987654',
      '876543',
      '765432',
      '654321',
      '543210',
    ];
    for (final seq in sequentialPatterns) {
      if (clean.contains(seq)) {
        return 'Invalid mobile number: sequential pattern detected';
      }
    }

    // 5. Check repeated 2-digit, 3-digit, or 5-digit chunks
    if (RegExp(r'^(\d{2})\1{3,}$').hasMatch(clean)) {
      return 'Invalid mobile number: repetitive pattern';
    }
    if (RegExp(r'^(\d{3})\1{2}').hasMatch(clean)) {
      return 'Invalid mobile number: repetitive pattern';
    }
    if (RegExp(r'^(\d{5})\1$').hasMatch(clean)) {
      return 'Invalid mobile number: repetitive pattern';
    }

    // 6. Dummy numbers filter
    const dummyNumbers = {
      '9876543210',
      '9876543211',
      '9800000000',
      '9000000000',
      '9123456780',
    };
    if (dummyNumbers.contains(clean)) {
      return 'Invalid mobile number: please enter a real contact number';
    }

    return null;
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
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'We couldn\'t automatically read your SIM details. You can type your number manually.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
                          if (cleanNum.length > 10) {
                            cleanNum = cleanNum.substring(cleanNum.length - 10);
                          }
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
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _registerRole() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final securityAnswer = _securityAnswerController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final name = (_selectedRole == 'content_creator' && username.isNotEmpty)
        ? username
        : _getRoleLabel(_selectedRole);

    if (_selectedRole == 'content_creator') {
      if (username.isEmpty) {
        _showError('Username is required');
        return;
      }
    }

    final phoneError = validatePhoneNumber(phone);
    if (phoneError != null) {
      _showError(phoneError);
      return;
    }

    if (_selectedRole == 'chc_operator' || _selectedRole == 'content_creator') {
      if (password.isEmpty) {
        _showError('Password is required');
        return;
      }
      if (securityAnswer.isEmpty) {
        _showError('Security answer is required');
        return;
      }
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
        'HYD001', // Standard default client code (FPO selection removed)
        role: _selectedRole,
        password: (_selectedRole == 'chc_operator' || _selectedRole == 'content_creator') ? password : null,
        securityQuestion: (_selectedRole == 'chc_operator' || _selectedRole == 'content_creator') ? _selectedSecurityQuestion : null,
        securityAnswer: (_selectedRole == 'chc_operator' || _selectedRole == 'content_creator') ? securityAnswer : null,
        username: _selectedRole == 'content_creator' ? username : null,
        email: _selectedRole == 'content_creator' ? (email.isNotEmpty ? email : null) : null,
      );
      if (regRes['success'] != true) {
        _showError(regRes['error'] ?? 'signup_registration_failed'.tr());
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      await AuthService.login(phone, role: _selectedRole);

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      final user = AuthService.currentUser;
      if (user?.isRetailer == true || user?.membershipType == 'Retailer' || _selectedRole == 'retailer') {
        Navigator.pushReplacement(
          context,
          AppRoutes.fade(const RetailerDashboard()),
        );
      } else if (user?.isOfficer == true || user?.membershipType == 'Officer' || _selectedRole == 'officer') {
        Navigator.pushReplacement(
          context,
          AppRoutes.fade(const ExtensionOfficerDashboard()),
        );
      } else if (user?.isCreator == true || user?.membershipType == 'Creator' || _selectedRole == 'content_creator') {
        Navigator.pushReplacement(
          context,
          AppRoutes.fade(const CreatorHomeScreen()),
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
                final isTablet = constraints.maxWidth >= 600;
                final isShortScreen = constraints.maxHeight < 680;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 32 : 20,
                    vertical: isShortScreen ? 12 : 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - (isShortScreen ? 24 : 48),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isTablet
                              ? min(1120.0, constraints.maxWidth - 48)
                              : 460.0,
                        ),
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: isTablet
                                ? _buildTabletLayout(isShortScreen)
                                : _buildPhoneLayout(isShortScreen),
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

  /// Compact Phone Layout (< 600px width)
  Widget _buildPhoneLayout(bool isShortScreen) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthLogoHeader(
          title: 'signup_title'.tr(),
          subtitle: 'signup_subtitle'.tr(),
          logoHeight: isShortScreen ? 46 : 54,
        ),
        SizedBox(height: isShortScreen ? 14 : 20),
        _buildRoleToggle(compact: isShortScreen),
        SizedBox(height: isShortScreen ? 16 : 22),
        _buildMainFormFields(isShortScreen: isShortScreen),
        SizedBox(height: isShortScreen ? 14 : 18),
        _buildLoginLink(),
        SizedBox(
          height: MediaQuery.of(context).viewInsets.bottom > 0
              ? 16
              : (isShortScreen ? 20 : 36),
        ),
      ],
    );
  }

  /// Spacious Two-Column Tablet / Wide Chrome Layout (>= 600px width)
  Widget _buildTabletLayout(bool isShortScreen) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left Column: Brand Hero & Value Proposition
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.only(right: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo & App Name
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/logo_t.png',
                      height: 56,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.agriculture_rounded,
                        size: 48,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'CropSync',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'signup_title'.tr(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.8,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'signup_subtitle'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                // Feature Value Props
                _buildValuePropTile(
                  icon: Icons.eco_rounded,
                  title: 'Smart Crop Advisory',
                  subtitle: 'Direct personalized recommendations from experts.',
                ),
                const SizedBox(height: 14),
                _buildValuePropTile(
                  icon: Icons.speed_rounded,
                  title: 'Instant Registration',
                  subtitle: 'Quick access via SIM detection or manual entry.',
                ),
                const SizedBox(height: 14),
                _buildValuePropTile(
                  icon: Icons.verified_user_rounded,
                  title: 'Verified Agricultural Network',
                  subtitle: 'Connect seamlessly with CHCs, retailers, and officers.',
                ),

                const SizedBox(height: 28),

                // Role selector
                _buildRoleToggle(compact: false),
              ],
            ),
          ),
        ),

        // Right Column: Elevated Form Card
        Expanded(
          flex: 6,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppTheme.border.withValues(alpha: 0.6),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'signup_title'.tr(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        _getRoleLabel(_selectedRole),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildMainFormFields(isShortScreen: false),
                const SizedBox(height: 16),
                _buildLoginLink(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildValuePropTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF16A34A)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleToggle({bool compact = false}) {
    return GestureDetector(
      onTap: _showRolePicker,
      child: Container(
        height: compact ? 54 : 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: AppTheme.border.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            const Icon(
              Icons.person_pin_rounded,
              size: 22,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _getRoleLabel(_selectedRole),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    bool compact = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => focusNode.requestFocus(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: compact ? 56 : 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: focusNode.hasFocus ? AppTheme.textPrimary : AppTheme.border.withValues(alpha: 0.5),
            width: focusNode.hasFocus ? 2.0 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 12),
              child: AnimatedScale(
                scale: focusNode.hasFocus ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  size: 22,
                  color: focusNode.hasFocus ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: keyboardType,
                obscureText: obscureText,
                decoration: InputDecoration(
                  hintText: hintText,
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
            const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }

  void _showSecurityQuestionBottomSheet() {
    HapticFeedback.selectionClick();
    final questions = ['security_q1', 'security_q2', 'security_q3', 'security_q4'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: const Icon(
                          Icons.security_rounded,
                          color: Color(0xFF16A34A),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'select_security_question'.tr(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'security_question_desc'.tr(),
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: questions.map((q) {
                      final isSelected = _selectedSecurityQuestion == q;
                      return InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedSecurityQuestion = q;
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF0FDF4) : const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF86EFAC) : const Color(0xFFE5E7EB),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  q.tr(),
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? const Color(0xFF15803D) : AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                                color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFD1D5DB),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSecurityQuestionTile({bool compact = false}) {
    return GestureDetector(
      onTap: _showSecurityQuestionBottomSheet,
      child: Container(
        height: compact ? 56 : 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: AppTheme.border.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            const Icon(
              Icons.help_outline_rounded,
              size: 22,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedSecurityQuestion.tr(),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildMainFormFields({required bool isShortScreen}) {
    final showExtraFields = _selectedRole == 'chc_operator' || _selectedRole == 'content_creator';
    final isCreator = _selectedRole == 'content_creator';
    final currentPhone = _phoneController.text.trim();
    final isPhone10Digits = currentPhone.length == 10;
    final phoneError = currentPhone.isNotEmpty ? validatePhoneNumber(currentPhone) : null;
    final isPhoneValid = isPhone10Digits && phoneError == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isCreator) ...[
          _buildCustomTextField(
            controller: _usernameController,
            focusNode: _usernameFocusNode,
            hintText: 'signup_username_hint'.tr(),
            icon: Icons.alternate_email_rounded,
            compact: isShortScreen,
          ),
          SizedBox(height: isShortScreen ? 10 : 14),
        ],

        // Direct Manual & SIM Mobile Input with Strict Formatter
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _phoneFocusNode.requestFocus(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: isShortScreen ? 56 : 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: _phoneFocusNode.hasFocus
                    ? AppTheme.textPrimary
                    : (phoneError != null && currentPhone.length == 10
                        ? Colors.redAccent
                        : AppTheme.border.withValues(alpha: 0.5)),
                width: _phoneFocusNode.hasFocus ? 2.0 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 12),
                  child: AnimatedScale(
                    scale: _phoneFocusNode.hasFocus ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.smartphone_rounded,
                      size: 22,
                      color: _phoneFocusNode.hasFocus ? AppTheme.textPrimary : AppTheme.textSecondary,
                    ),
                  ),
                ),
                // Indian prefix indicator
                Text(
                  '+91 ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _phoneFocusNode.hasFocus ? AppTheme.textPrimary : const Color(0xFF6B7280),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    focusNode: _phoneFocusNode,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    onChanged: (val) {
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: isCreator ? '10-digit number' : 'signup_phone_hint'.tr(),
                      hintStyle: const TextStyle(
                        fontSize: 14,
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
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),

                // Real-time validity badge or Clear button
                if (_phoneController.text.isNotEmpty) ...[
                  if (isPhoneValid)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF16A34A),
                        size: 20,
                      ),
                    )
                  else if (currentPhone.length == 10 && phoneError != null)
                    Tooltip(
                      message: phoneError,
                      child: const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.error_outline_rounded,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.cancel_outlined,
                      color: Color(0xFF9CA3AF),
                      size: 20,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _phoneController.clear();
                      });
                    },
                    tooltip: 'Clear',
                  ),
                ],

                // Auto Detect SIM Button (Primary Action)
                Tooltip(
                  message: 'Detect SIM',
                  child: InkWell(
                    onTap: () {
                      _phoneFocusNode.unfocus();
                      _selectPhoneNumber();
                    },
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sim_card_outlined,
                            color: AppTheme.textPrimary,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'SIM',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (currentPhone.length == 10 && phoneError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 16, right: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    phoneError,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (isCreator) ...[
          SizedBox(height: isShortScreen ? 10 : 14),
          _buildCustomTextField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            hintText: 'signup_email_hint'.tr(),
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            compact: isShortScreen,
          ),
        ],

        if (showExtraFields) ...[
          SizedBox(height: isShortScreen ? 10 : 14),
          _buildCustomTextField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            hintText: 'signup_password_hint'.tr(),
            icon: Icons.lock_outline_rounded,
            obscureText: true,
            compact: isShortScreen,
          ),
          SizedBox(height: isShortScreen ? 10 : 14),
          _buildSecurityQuestionTile(compact: isShortScreen),
          SizedBox(height: isShortScreen ? 10 : 14),
          _buildCustomTextField(
            controller: _securityAnswerController,
            focusNode: _securityAnswerFocusNode,
            hintText: 'signup_security_answer_hint'.tr(),
            icon: Icons.question_answer_outlined,
            compact: isShortScreen,
          ),
        ],

        SizedBox(height: isShortScreen ? 18 : 26),
        _buildSubmitButton(compact: isShortScreen),
      ],
    );
  }

  String _getRoleLabel(String roleKey) {
    switch (roleKey) {
      case 'farmer': return 'role_farmer_title'.tr();
      case 'retailer': return 'role_retailer_title'.tr();
      case 'officer': return 'role_officer_title'.tr();
      case 'chc_operator': return 'role_chc_operator_title'.tr();
      case 'content_creator': return 'role_content_creator_title'.tr();
      default: return roleKey;
    }
  }

  void _showRolePicker() {
    HapticFeedback.selectionClick();
    
    final roles = ['farmer', 'chc_operator', 'retailer', 'officer', 'content_creator'];
    
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
                      child: const Icon(Icons.person_pin_rounded,
                          color: AppTheme.textPrimary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'signup_select_role'.tr(),
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
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'signup_role_warning'.tr(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade900,
                        ),
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
                  itemCount: roles.length,
                  itemBuilder: (context, index) {
                    final role = roles[index];
                    final isSelected = role == _selectedRole;
                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedRole = role;
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
                                _getRoleLabel(role),
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

  Widget _buildSubmitButton({bool compact = false}) {
    final phone = _phoneController.text.trim();
    final bool isPhoneValid = validatePhoneNumber(phone) == null;
    final bool canProceed = isPhoneValid;

    final bool isButtonDisabled = _isLoading || !canProceed;

    return ElevatedButton(
      onPressed: isButtonDisabled
          ? null
          : () {
              HapticFeedback.mediumImpact();
              _registerRole();
            },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isButtonDisabled ? const Color(0xFFD1D5DB) : AppTheme.textPrimary,
        minimumSize: Size(double.infinity, compact ? 56 : 64),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 3),
            )
          : Text(
              'signup_confirm_create'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
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
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.login_rounded, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'signup_already_have_account'.tr(),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}


