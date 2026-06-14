import 'package:cropsync/screens/crop_advisory_grid_screen.dart';
import 'package:cropsync/screens/profile_screen.dart';
import 'package:cropsync/screens/settings_screen.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/location_service.dart';
import 'package:cropsync/models/user.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:cropsync/services/notification_service.dart';

import 'package:cropsync/widgets/home_tab.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/widgets/language_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

/// Main home screen - Zepto-inspired clean architecture
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  String _farmerName = 'Farmer';

  bool _isLoading = true;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchFarmerDetails();
    // Request permissions after the home screen is fully rendered.
    // Using a post-frame + 1.5s delay gives the user context before
    // the OS dialogs appear — production pattern (no cold-start lag).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        _requestPermissions();
      });
    });
  }

  Future<void> _requestPermissions() async {
    // Notification permission first
    await NotificationService.requestPermissions();
    // Then location (sequential so dialogs don't stack)
    if (!mounted) return;
    await LocationService.requestPermission();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'home_greeting_morning'.tr();
    if (hour < 17) return 'home_greeting_afternoon'.tr();
    return 'home_greeting_evening'.tr();
  }

  Future<void> _fetchFarmerDetails() async {
    // Small delay to ensure smooth transition
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      User? user = await AuthService.getCurrentUser();
      // Only refresh if we don't have cached data mostly, but here we refresh context
      user = await AuthService.refreshUserData();

      if (!mounted) return;

      if (user != null) {
        final currentUser = user;
        NotificationService.subscribeToDistrictTopic(currentUser);
        setState(() {
          _farmerName = currentUser.name;
          _profileImageUrl = currentUser.profileImageUrl;
        });
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _onNavTap(int index) {
    if (_selectedIndex != index) {
      HapticFeedback.selectionClick();
      setState(() => _selectedIndex = index);
    }
  }

  void _showLanguageSheet() {
    LanguageSelector.show(context);
  }

  Future<void> _openProfile() async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const ProfileScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
    _fetchFarmerDetails();
  }

  @override
  Widget build(BuildContext context) {
    final currentGreeting = _getGreeting();

    final screens = [
      HomeTab(
        key: const ValueKey('home_tab'),
        greeting: currentGreeting,
        farmerName: _farmerName,
        profileImageUrl: _profileImageUrl,
        onTabSelected: _onNavTap,
      ),
      const CropAdvisoryGridScreen(key: ValueKey('advisory_tab')),
      const SettingsScreen(key: ValueKey('settings_tab')),
    ];

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: _selectedIndex == 1 ? null : _buildCurvedAppBar(),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isLoading
              ? const _HomeShimmer(key: ValueKey('shimmer'))
              : IndexedStack(
                  key: const ValueKey('content'),
                  index: _selectedIndex,
                  children: screens,
                ),
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  PreferredSizeWidget _buildCurvedAppBar() {
    return AppBar(
      title: Text(
        'CropSync',
        style: AppTheme.appBarTitle,
      ),
      centerTitle: false,
      backgroundColor: AppTheme.appBarBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      actions: [
        IconButton(
          icon: const Icon(Icons.translate_rounded,
              color: AppTheme.appBarText, size: 24),
          onPressed: _showLanguageSheet,
          splashRadius: 24,
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: _buildAvatar(),
            onPressed: _openProfile,
            splashRadius: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.3), width: 1.5),
        ),
        child: CircleAvatar(
          radius: 15,
          backgroundColor: Colors.white10,
          backgroundImage: CachedNetworkImageProvider(
            _profileImageUrl!,
            maxWidth: 60,
            maxHeight: 60,
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
      ),
      child: const CircleAvatar(
        radius: 15,
        backgroundColor: Colors.white,
        backgroundImage: AssetImage('assets/images/logo.png'),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border:
            const Border(top: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'home_bottom_nav_home'.tr(),
                  isActive: _selectedIndex == 0,
                  onTap: () => _onNavTap(0),
                  activeColor: AppTheme.primary,
                ),
                _NavItem(
                  icon: Icons.eco_outlined,
                  activeIcon: Icons.eco,
                  label: 'home_bottom_nav_advisories'.tr(),
                  isActive: _selectedIndex == 1,
                  onTap: () => _onNavTap(1),
                  activeColor: AppTheme.primary,
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: 'home_bottom_nav_settings'.tr(),
                  isActive: _selectedIndex == 2,
                  onTap: () => _onNavTap(2),
                  activeColor: AppTheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating Nav Item - Modern Icon-Only with Indicator
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeColor;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 24,
              color: isActive ? activeColor : const Color(0xFF9CA3AF),
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: activeColor,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Modern Shimmer loading state
class _HomeShimmer extends StatelessWidget {
  const _HomeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Shimmer.fromColors(
              baseColor: const Color(0xFFE0E0E0),
              highlightColor: const Color(0xFFF5F5F5),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.85,
                ),
                itemCount: 6,
                itemBuilder: (_, __) => Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

