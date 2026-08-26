import 'package:cropsync/screens/crop_advisory_grid_screen.dart';
import 'package:cropsync/screens/profile_screen.dart';
import 'package:cropsync/screens/news/news_feed_screen.dart';
import 'package:cropsync/screens/reels_screen.dart';
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
import 'package:image_picker/image_picker.dart';
import 'package:cropsync/screens/plant_analysis_screen.dart';
import 'package:cropsync/screens/notifications_screen.dart';

/// Main home screen - Zepto-inspired clean architecture
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  String _farmerName = 'Farmer';
  String? _clientCode;

  bool _isLoading = true;
  String? _profileImageUrl;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
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

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
        NotificationService.subscribeToDistrictTopic(currentUser,
            lang: context.locale.languageCode);
        setState(() {
          _farmerName = currentUser.name;
          _profileImageUrl = currentUser.profileImageUrl;
          _clientCode = currentUser.clientCode;
        });
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Widget _buildGridButton({
    required BuildContext context,
    required VoidCallback onTap,
    required Gradient gradient,
    required IconData icon,
    required Color shadowColor,
  }) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Center(
            child: Icon(
              icon,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
      ),
    );
  }

  void _showImageSourceSheet() async {
    HapticFeedback.selectionClick();
    final String? action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Choose Action",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Select a source to diagnose your crop's health",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildGridButton(
                      context: context,
                      onTap: () => Navigator.pop(context, 'camera'),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      icon: Icons.camera_alt_rounded,
                      shadowColor: const Color(0xFFD97706).withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 32),
                    _buildGridButton(
                      context: context,
                      onTap: () => Navigator.pop(context, 'gallery'),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF34D399), Color(0xFF047857)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      icon: Icons.image_rounded,
                      shadowColor: const Color(0xFF047857).withValues(alpha: 0.3),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );

    if (action == null || !mounted) return;

    // Small delay to ensure the bottom sheet slide down completes cleanly
    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;

    if (action == 'camera') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const PlantAnalysisScreen(initialSource: ImageSource.camera),
        ),
      );
    } else if (action == 'gallery') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const PlantAnalysisScreen(initialSource: ImageSource.gallery),
        ),
      );
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
        clientCode: _clientCode,
        onTabSelected: _onNavTap,
      ),
      const CropAdvisoryGridScreen(key: ValueKey('advisory_tab')),
      const NewsFeedScreen(key: ValueKey('news_tab')),
      const ReelsScreen(key: ValueKey('reels_tab')),
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
        appBar: (_selectedIndex == 1 || _selectedIndex == 2 || _selectedIndex == 3) ? null : _buildCurvedAppBar(),
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
        const WiggleBellButton(),
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
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
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
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: _NavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: 'home_bottom_nav_home'.tr(),
                    isActive: _selectedIndex == 0,
                    onTap: () => _onNavTap(0),
                    activeColor: AppTheme.primary,
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.eco_outlined,
                    activeIcon: Icons.eco,
                    label: 'home_bottom_nav_advisories'.tr(),
                    isActive: _selectedIndex == 1,
                    onTap: () => _onNavTap(1),
                    activeColor: AppTheme.primary,
                  ),
                ),
                Expanded(
                  child: _AnimatedCameraTab(
                    animationController: _pulseController,
                    onTap: _showImageSourceSheet,
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.newspaper_outlined,
                    activeIcon: Icons.newspaper_rounded,
                    label: 'home_bottom_nav_news'.tr(),
                    isActive: _selectedIndex == 2,
                    onTap: () => _onNavTap(2),
                    activeColor: AppTheme.primary,
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.video_library_outlined,
                    activeIcon: Icons.video_library_rounded,
                    label: 'home_bottom_nav_reels'.tr(),
                    isActive: _selectedIndex == 3,
                    onTap: () => _onNavTap(3),
                    activeColor: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                size: 24,
                color: isActive ? activeColor : const Color(0xFF9CA3AF),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? activeColor : const Color(0xFF9CA3AF),
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
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

class WiggleBellButton extends StatefulWidget {
  const WiggleBellButton({super.key});

  @override
  State<WiggleBellButton> createState() => _WiggleBellButtonState();
}

class _WiggleBellButtonState extends State<WiggleBellButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.04), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.04, end: 0.04), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.04, end: -0.03), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.03, end: 0.03), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.03, end: -0.02), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.02, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    NotificationService.onNotificationReceived = () {
      if (mounted && !_controller.isAnimating) {
        _controller.forward(from: 0.0);
        HapticFeedback.vibrate();
      }
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.unreadNotifier,
      builder: (context, unreadCount, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            RotationTransition(
              turns: _animation,
              child: IconButton(
                icon: const Icon(
                  Icons.notifications_rounded,
                  color: AppTheme.appBarText,
                  size: 26,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  NotificationService.unreadNotifier.value = 0;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const NotificationsScreen()),
                  );
                },
                splashRadius: 24,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 14,
                    minHeight: 14,
                  ),
                  child: Text(
                    unreadCount > 9 ? "9+" : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AnimatedCameraTab extends StatelessWidget {
  final AnimationController animationController;
  final VoidCallback onTap;

  const _AnimatedCameraTab({
    required this.animationController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Pulse Ring 1 (Fades out as it grows)
            AnimatedBuilder(
              animation: animationController,
              builder: (context, child) {
                return Container(
                  width: 42 + (animationController.value * 18),
                  height: 42 + (animationController.value * 18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981).withValues(
                      alpha: (1.0 - animationController.value) * 0.45,
                    ),
                  ),
                );
              },
            ),
            // Pulse Ring 2 (Alternating pulse ripple)
            AnimatedBuilder(
              animation: animationController,
              builder: (context, child) {
                final double val = (animationController.value + 0.5) % 1.0;
                return Container(
                  width: 42 + (val * 12),
                  height: 42 + (val * 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981).withValues(
                      alpha: (1.0 - val) * 0.6,
                    ),
                  ),
                );
              },
            ),
            // Core Static Button
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF34D399), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x3310B981),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
