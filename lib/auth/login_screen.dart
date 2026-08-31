import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cropsync/auth/signup_screen.dart';
import 'package:cropsync/navigation/app_routes.dart';
import 'package:cropsync/screens/home_screen.dart';
import 'package:cropsync/screens/retailer/retailer_dashboard.dart';
import 'package:cropsync/screens/officer/extension_officer_dashboard.dart';
import 'package:cropsync/screens/operator/operator_dashboard.dart';
import 'package:cropsync/screens/creator/creator_home_screen.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/operator_auth_service.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:cropsync/widgets/auth/auth_alert_banner.dart';
import 'package:cropsync/widgets/auth/auth_logo_header.dart';

class LoginScreen extends StatefulWidget {
  final String? initialPhoneNumber;

  const LoginScreen({super.key, this.initialPhoneNumber});

  /// Exposes strict phone validation for login
  static String? validatePhoneNumber(String rawPhone) =>
      _LoginScreenState.validatePhoneNumber(rawPhone);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  Timer? _errorTimer;

  // Default active role is 'farmer' (most common user)
  String _selectedRole = 'farmer';

  @override
  void initState() {
    super.initState();
    _phoneFocusNode.addListener(_onFocusChange);
    _passwordFocusNode.addListener(_onFocusChange);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();

    final digits = widget.initialPhoneNumber?.replaceAll(RegExp(r'\D'), '');
    if (digits != null) {
      _phoneController.text =
          digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    }
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    _phoneFocusNode.removeListener(_onFocusChange);
    _passwordFocusNode.removeListener(_onFocusChange);
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    _errorTimer?.cancel();
    if (!mounted) return;
    setState(() => _errorMessage = message);
    _errorTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _errorMessage = null);
      }
    });
  }

  /// Validates standard 10-digit Indian mobile numbers
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
    return null;
  }

  Future<void> _selectPhoneNumber() async {
    HapticFeedback.selectionClick();
    if (!mounted) return;

    List<Map<String, dynamic>> simList = [];
    try {
      final List<dynamic>? rawSims =
          await const MethodChannel('cropsync/sim_info')
              .invokeMethod<List<dynamic>>('getSimInfo');
      if (rawSims != null) {
        simList =
            rawSims.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
                const Icon(Icons.sim_card_alert_rounded,
                    size: 48, color: AppTheme.textSecondary),
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
                  final String displayNum = rawNumber.isNotEmpty
                      ? rawNumber
                      : 'Select Number (Not Available)';

                  return Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                          color: const Color(0xFFE5E7EB), width: 1.5),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 4),
                      leading: const Icon(Icons.sim_card_outlined,
                          color: AppTheme.textSecondary, size: 24),
                      title: Text(
                        displayNum,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppTheme.textPrimary),
                      ),
                      subtitle: Text('SIM Slot $slot - $carrier'),
                      trailing:
                          const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100)),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (rawNumber.isNotEmpty) {
                          String cleanNum =
                              rawNumber.replaceAll(RegExp(r'[^\d+]'), '');
                          if (cleanNum.startsWith('+91')) {
                            cleanNum = cleanNum.substring(3);
                          } else if (cleanNum.startsWith('91') &&
                              cleanNum.length == 12) {
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

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    final phoneError = validatePhoneNumber(phone);
    if (phoneError != null) {
      _showError(phoneError);
      return;
    }

    if (_selectedRole == 'chc_operator') {
      if (password.isEmpty) {
        _showError('Password is required for CHC Operator');
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
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.login(phone, role: _selectedRole);
      if (!mounted) return;

      final loggedInUser = AuthService.currentUser;
      if (loggedInUser?.isRetailer == true || loggedInUser?.membershipType == 'Retailer' || _selectedRole == 'retailer') {
        Navigator.pushReplacement(
          context,
          AppRoutes.fade(const RetailerDashboard()),
        );
      } else if (loggedInUser?.isOfficer == true || loggedInUser?.membershipType == 'Officer' || _selectedRole == 'officer') {
        Navigator.pushReplacement(
          context,
          AppRoutes.fade(const ExtensionOfficerDashboard()),
        );
      } else if (loggedInUser?.isCreator == true || loggedInUser?.membershipType == 'Creator' || _selectedRole == 'content_creator') {
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
    } catch (error) {
      final errorStr = error.toString().toLowerCase();
      // If user is not registered, redirect to signup
      if (errorStr.contains('not found') || errorStr.contains('register')) {
        _showError('No account found with this number. Redirecting to registration...');
        await Future.delayed(const Duration(milliseconds: 1200));
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          AppRoutes.slideFromRight(
            SignupScreen(initialPhoneNumber: phone),
          ),
        );
      } else {
        _showError(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getRoleTitle() {
    switch (_selectedRole) {
      case 'retailer':
        return 'role_retailer_title'.tr();
      case 'officer':
        return 'role_officer_title'.tr();
      case 'chc_operator':
        return 'role_chc_operator_title'.tr();
      case 'content_creator':
        return 'role_content_creator_title'.tr();
      case 'farmer':
      default:
        return 'role_farmer_title'.tr();
    }
  }

  IconData _getRoleIcon() {
    switch (_selectedRole) {
      case 'retailer':
        return Icons.storefront_rounded;
      case 'officer':
        return Icons.verified_user_rounded;
      case 'chc_operator':
        return Icons.agriculture_rounded;
      case 'content_creator':
        return Icons.video_camera_front_rounded;
      case 'farmer':
      default:
        return Icons.eco_rounded;
    }
  }

  void _showRolePicker() {
    HapticFeedback.selectionClick();
    final roles = [
      {'key': 'farmer', 'title': 'role_farmer_title'.tr(), 'desc': 'Access crop advisories & services', 'icon': Icons.eco_rounded},
      {'key': 'chc_operator', 'title': 'role_chc_operator_title'.tr(), 'desc': 'Custom Hiring Center & equipment', 'icon': Icons.agriculture_rounded},
      {'key': 'retailer', 'title': 'role_retailer_title'.tr(), 'desc': 'Fertilizers & seeds retail partner', 'icon': Icons.storefront_rounded},
      {'key': 'officer', 'title': 'role_officer_title'.tr(), 'desc': 'Agricultural Extension Officer', 'icon': Icons.verified_user_rounded},
      {'key': 'content_creator', 'title': 'role_content_creator_title'.tr(), 'desc': 'Farming videos & reels creator', 'icon': Icons.video_camera_front_rounded},
    ];

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
                      'choose_role'.tr(),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: roles.length,
                  itemBuilder: (context, index) {
                    final role = roles[index];
                    final isSelected = _selectedRole == role['key'];

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedRole = role['key'] as String;
                          _passwordController.clear();
                        });
                        Navigator.pop(context);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.textPrimary
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.textPrimary
                                : const Color(0xFFE5E7EB),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.15)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                role['icon'] as IconData,
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textPrimary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    role['title'] as String,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    role['desc'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white70
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_off_rounded,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFFD1D5DB),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
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
                final isShort = constraints.maxHeight < 700;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: isTablet
                            ? _buildTabletLayout(constraints)
                            : _buildPhoneLayout(isShort),
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

  /// Responsive Single-Column Mobile Phone Layout (< 600px)
  Widget _buildPhoneLayout(bool isShort) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: isShort ? 16 : 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AuthLogoHeader(
            title: 'login_welcome_back'.tr(),
            subtitle: 'login_subtitle'.tr(),
            logoHeight: isShort ? 46 : 54,
          ),
          SizedBox(height: isShort ? 18 : 24),
          _buildRoleSelectorPill(isCompact: isShort),
          SizedBox(height: isShort ? 14 : 20),
          _buildPhoneInputField(isCompact: isShort),
          if (_selectedRole == 'chc_operator') ...[
            SizedBox(height: isShort ? 12 : 16),
            _buildPasswordInputField(isCompact: isShort),
          ],
          SizedBox(height: isShort ? 20 : 28),
          _buildSubmitButton(isCompact: isShort),
          SizedBox(height: isShort ? 14 : 20),
          _buildSignupLink(isCompact: isShort),
        ],
      ),
    );
  }

  /// Responsive Two-Column Tablet Layout (>= 600px)
  Widget _buildTabletLayout(BoxConstraints constraints) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1100),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Hero Branding & Value Badges
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.only(right: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/icons/app_icon.png',
                      width: 76,
                      height: 76,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.eco_rounded,
                        size: 76,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'CropSync',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Smart Farming, Simplified.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildTabletValueBadge(
                      icon: Icons.flash_on_rounded,
                      title: '1-Tap SIM Login',
                      subtitle: 'Instant phone number autofill without typing',
                    ),
                    const SizedBox(height: 14),
                    _buildTabletValueBadge(
                      icon: Icons.eco_rounded,
                      title: 'Smart Crop Advisory',
                      subtitle: 'Direct disease detection & spray schedules',
                    ),
                    const SizedBox(height: 14),
                    _buildTabletValueBadge(
                      icon: Icons.groups_rounded,
                      title: 'Connected Community',
                      subtitle: 'Join verified farmers, retailers & officers',
                    ),
                  ],
                ),
              ),
            ),

            // Right Column: Elevated Form Card
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 1.5,
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
                    Text(
                      'login_welcome_back'.tr(),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter your 10-digit mobile number to access your account.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildRoleSelectorPill(isCompact: false),
                    const SizedBox(height: 18),
                    _buildPhoneInputField(isCompact: false),
                    if (_selectedRole == 'chc_operator') ...[
                      const SizedBox(height: 16),
                      _buildPasswordInputField(isCompact: false),
                    ],
                    const SizedBox(height: 24),
                    _buildSubmitButton(isCompact: false),
                    const SizedBox(height: 18),
                    _buildSignupLink(isCompact: false),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletValueBadge({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 20, color: AppTheme.textPrimary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Modern Role Selector Dropdown Pill
  Widget _buildRoleSelectorPill({required bool isCompact}) {
    return GestureDetector(
      onTap: _showRolePicker,
      child: Container(
        height: isCompact ? 54 : 60,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(_getRoleIcon(), size: 20, color: AppTheme.textPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LOGGING IN AS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    _getRoleTitle(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16, color: AppTheme.textPrimary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Direct Manual & SIM Auto-Detect Phone Input Field
  Widget _buildPhoneInputField({required bool isCompact}) {
    final currentPhone = _phoneController.text.trim();
    final isPhone10Digits = currentPhone.length == 10;
    final phoneError =
        currentPhone.isNotEmpty ? validatePhoneNumber(currentPhone) : null;
    final isPhoneValid = isPhone10Digits && phoneError == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _phoneFocusNode.requestFocus(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: isCompact ? 56 : 64,
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
                      color: _phoneFocusNode.hasFocus
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
                // Indian Prefix
                Text(
                  '+91 ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _phoneFocusNode.hasFocus
                        ? AppTheme.textPrimary
                        : const Color(0xFF6B7280),
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
                    decoration: const InputDecoration(
                      hintText: '10-digit mobile number',
                      hintStyle: TextStyle(
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

                // Real-time Validity Icon or Clear Button
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

                // Auto Detect SIM Button (Primary 1-Tap Action)
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
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

        // Inline Error Message
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
      ],
    );
  }

  /// Password field for CHC Operator
  Widget _buildPasswordInputField({required bool isCompact}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _passwordFocusNode.requestFocus(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: isCompact ? 56 : 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: _passwordFocusNode.hasFocus
                ? AppTheme.textPrimary
                : AppTheme.border.withValues(alpha: 0.5),
            width: _passwordFocusNode.hasFocus ? 2.0 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 12),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 22,
                color: _passwordFocusNode.hasFocus
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                obscureText: _obscurePassword,
                decoration: const InputDecoration(
                  hintText: 'Enter Password',
                  hintStyle: TextStyle(
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
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  /// Sign In Action Button
  Widget _buildSubmitButton({required bool isCompact}) {
    final String phone = _phoneController.text.trim();
    final String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final bool canProceed = cleanPhone.length == 10 &&
        (_selectedRole != 'chc_operator' ||
            _passwordController.text.trim().isNotEmpty);
    final bool isButtonDisabled = _isLoading || !canProceed;

    return ElevatedButton(
      onPressed: isButtonDisabled
          ? null
          : () {
              HapticFeedback.mediumImpact();
              _login();
            },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isButtonDisabled ? const Color(0xFFD1D5DB) : AppTheme.textPrimary,
        minimumSize: Size(double.infinity, isCompact ? 56 : 64),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
        elevation: isButtonDisabled ? 0 : 3,
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
                  'login_submit'.tr(),
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
    );
  }

  /// Create Account Outlined Link Button
  Widget _buildSignupLink({required bool isCompact}) {
    return OutlinedButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        Navigator.pushReplacement(
          context,
          AppRoutes.slideFromRight(
            SignupScreen(
              initialPhoneNumber: _phoneController.text.isNotEmpty
                  ? _phoneController.text.trim()
                  : null,
            ),
          ),
        );
      },
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
        minimumSize: Size(double.infinity, isCompact ? 52 : 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_add_outlined,
            size: 18,
            color: AppTheme.textPrimary,
          ),
          SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'New to CropSync? Create Account',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


