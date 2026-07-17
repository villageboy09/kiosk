import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cropsync/auth/signup_screen.dart';
import 'package:cropsync/navigation/app_routes.dart';
import 'package:cropsync/screens/home_screen.dart';
import 'package:cropsync/screens/retailer/retailer_dashboard.dart';
import 'package:cropsync/screens/officer/extension_officer_dashboard.dart';
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
  final FocusNode _phoneFocusNode = FocusNode();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  String? _errorMessage;
  Timer? _errorTimer;

  // Selected role: 'farmer', 'retailer', 'officer', or null for role selection landing
  String? _selectedRole;

  @override
  void initState() {
    super.initState();
    _phoneFocusNode.addListener(_onFocusChange);
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

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    _phoneFocusNode.removeListener(_onFocusChange);
    _phoneFocusNode.dispose();
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
                          setState(() {
                            _pinController.text = cleanNum;
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

  Future<void> _login() async {
    final pin = _pinController.text.trim();
    if (pin.length != 10) {
      _showError('login_pin_length_error'.tr());
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Direct login to optimize performance (saves a redundant checkUser network call)
      await AuthService.login(pin, role: _selectedRole);
      if (!mounted) return;

      final loggedInUser = AuthService.currentUser;
      if (loggedInUser?.membershipType == 'Retailer') {
        Navigator.pushReplacement(
          context,
          AppRoutes.fade(const RetailerDashboard()),
        );
      } else if (loggedInUser?.membershipType == 'Officer') {
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
    } catch (error) {
      final errorStr = error.toString().toLowerCase();
      // If user is not registered, redirect to signup
      if (errorStr.contains('not found') || errorStr.contains('register')) {
        _showError('login_user_not_registered_redirect'.tr());
        await Future.delayed(const Duration(milliseconds: 1200));
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          AppRoutes.slideFromRight(
            SignupScreen(initialPhoneNumber: pin),
          ),
        );
      } else {
        _showError(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getRoleThemeColor() {
    switch (_selectedRole) {
      case 'retailer':
        return const Color(0xFF1565C0);
      case 'officer':
        return const Color(0xFF00695C);
      case 'farmer':
      default:
        return const Color(0xFF2E7D32);
    }
  }

  String _getRoleTitle() {
    switch (_selectedRole) {
      case 'retailer':
        return 'role_retailer_title'.tr();
      case 'officer':
        return 'role_officer_title'.tr();
      case 'farmer':
      default:
        return 'role_farmer_title'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedRole != null) {
          HapticFeedback.lightImpact();
          setState(() {
            _selectedRole = null;
            _pinController.clear();
          });
        } else {
          // Go back to SignupScreen
          HapticFeedback.lightImpact();
          Navigator.pushReplacement(
            context,
            AppRoutes.slideFromRight(const SignupScreen()),
          );
        }
      },
      child: Scaffold(
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
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 350),
                                  switchInCurve: Curves.easeInOutCubic,
                                  switchOutCurve: Curves.easeInOutCubic,
                                  transitionBuilder: (Widget child,
                                      Animation<double> animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0.08, 0),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _selectedRole == null
                                      ? KeyedSubtree(
                                          key: const ValueKey(
                                              'RoleSelectionView'),
                                          child: _buildRoleSelectionView(),
                                        )
                                      : KeyedSubtree(
                                          key: const ValueKey('LoginInputView'),
                                          child: _buildLoginInputView(),
                                        ),
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
              if (_selectedRole != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppTheme.textPrimary, size: 24),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedRole = null;
                        _pinController.clear();
                      });
                    },
                  ),
                ),
              AuthAlertBanner(message: _errorMessage),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelectionView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        AuthLogoHeader(
          title: 'login_welcome_back'.tr(),
          subtitle: 'login_select_role_subtitle'.tr(),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // 1. Farmer Card (Prominent green card outline)
        _buildRoleCard(
          role: 'farmer',
          title: 'role_farmer_title'.tr(),
          description: 'role_farmer_desc'.tr(),
          icon: Icons.agriculture_rounded,
          startColor: Colors.transparent,
          endColor: Colors.transparent,
          themeColor: const Color(0xFF2E7D32),
          isPrimary: true,
        ),
        const SizedBox(height: 16),

        // 2. Retailer Card (Blue card outline)
        _buildRoleCard(
          role: 'retailer',
          title: 'role_retailer_title'.tr(),
          description: 'role_retailer_desc'.tr(),
          icon: Icons.storefront_rounded,
          startColor: Colors.transparent,
          endColor: Colors.transparent,
          themeColor: const Color(0xFF1565C0),
          isPrimary: false,
        ),
        const SizedBox(height: 16),

        // 3. Extension Officer Card (Teal card outline)
        _buildRoleCard(
          role: 'officer',
          title: 'role_officer_title'.tr(),
          description: 'role_officer_desc'.tr(),
          icon: Icons.verified_user_rounded,
          startColor: Colors.transparent,
          endColor: Colors.transparent,
          themeColor: const Color(0xFF00695C),
          isPrimary: false,
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String title,
    required String description,
    required IconData icon,
    required Color startColor,
    required Color endColor,
    required Color themeColor,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedRole = role;
          _pinController.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: themeColor.withValues(alpha: isPrimary ? 0.35 : 0.15),
            width: isPrimary ? 2.0 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: themeColor.withValues(alpha: isPrimary ? 0.08 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: isPrimary ? 32 : 28,
                color: themeColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isPrimary ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 4.0),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginInputView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        AuthLogoHeader(
          title: _getRoleTitle(),
          subtitle: 'enter_field'.tr(
            namedArgs: {'field': 'phone_number'.tr()},
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _buildPhoneField(),
        const SizedBox(height: 16),
        _buildHintChip(),
        const SizedBox(height: 24),
        _buildSubmitButton(),
        const SizedBox(height: 20),
        if (_selectedRole == 'farmer') ...[
          _buildSignupLink(),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildPhoneField() {
    final themeColor = _getRoleThemeColor();
    final hasInput = _pinController.text.isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _selectPhoneNumber,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color:
                _phoneFocusNode.hasFocus ? themeColor : const Color(0xFFD1D5DB),
            width: _phoneFocusNode.hasFocus ? 2.0 : 1.5,
          ),
          boxShadow: _phoneFocusNode.hasFocus || hasInput
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 14),
              child: Icon(
                Icons.phone_rounded,
                color: _phoneFocusNode.hasFocus
                    ? themeColor
                    : const Color(0xFF9CA3AF),
                size: 22,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _pinController,
                focusNode: _phoneFocusNode,
                readOnly: true,
                onTap: _selectPhoneNumber,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: (val) {
                  setState(() {});
                },
                style: AppTheme.getTextStyle(
                  context,
                  fontSize: 16,
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'phone_number'.tr(),
                  hintStyle: AppTheme.getTextStyle(
                    context,
                    color: const Color(0xFF9CA3AF),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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
              ),
            ),
            if (hasInput)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: const Icon(
                    Icons.cancel_outlined,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _pinController.clear();
                    });
                  },
                ),
              ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHintChip() {
    String hintText = 'login_hint_farmer'.tr();
    if (_selectedRole == 'retailer') {
      hintText = 'login_hint_retailer'.tr();
    } else if (_selectedRole == 'officer') {
      hintText = 'login_hint_officer'.tr();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(
            hintText,
            textAlign: TextAlign.center,
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
    final canProceed = _pinController.text.length == 10;
    final bool isButtonDisabled = _isLoading || !canProceed;
    final themeColor = _getRoleThemeColor();

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
              isButtonDisabled ? const Color(0xFFD1D5DB) : themeColor,
          minimumSize: const Size(double.infinity, 64),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          elevation: isButtonDisabled ? 0 : 4,
          shadowColor: themeColor.withValues(alpha: 0.3),
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
