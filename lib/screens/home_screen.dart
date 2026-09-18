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
import 'package:cropsync/screens/saved_advisories_screen.dart';
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
    ReelsScreen.isTabActive.value = (_selectedIndex == 3);
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
    ReelsScreen.isTabActive.value = false;
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

  Widget _buildSheetActionTile({
    required VoidCallback onTap,
    required IconData icon,
    required Color iconColor,
    Color? iconBgColor,
    Gradient? iconBgGradient,
    required String title,
    required String subtitle,
    String? trailingBadge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                gradient: iconBgGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailingBadge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trailingBadge,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(IconData icon, String text) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showImageSourceSheet() async {
    HapticFeedback.selectionClick();
    final String? action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: const Icon(
                        Icons.psychology_rounded,
                        color: Color(0xFF16A34A),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'diag_sheet_title'.tr(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'diag_sheet_subtitle'.tr(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildSheetActionTile(
                  onTap: () => Navigator.pop(context, 'camera'),
                  icon: Icons.camera_alt_rounded,
                  iconColor: Colors.white,
                  iconBgGradient: const LinearGradient(
                    colors: [Color(0xFF22C55E), Color(0xFF15803D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  title: 'diag_sheet_camera'.tr(),
                  subtitle: 'diag_sheet_camera_desc'.tr(),
                ),
                const SizedBox(height: 10),
                _buildSheetActionTile(
                  onTap: () => Navigator.pop(context, 'gallery'),
                  icon: Icons.photo_library_rounded,
                  iconColor: const Color(0xFF0F766E),
                  iconBgColor: const Color(0xFFCCFBF1),
                  title: 'diag_sheet_gallery'.tr(),
                  subtitle: 'diag_sheet_gallery_desc'.tr(),
                ),
                const SizedBox(height: 10),
                _buildSheetActionTile(
                  onTap: () => Navigator.pop(context, 'saved'),
                  icon: Icons.bookmark_outline_rounded,
                  iconColor: const Color(0xFFB45309),
                  iconBgColor: const Color(0xFFFEF3C7),
                  title: 'diag_sheet_saved'.tr(),
                  subtitle: 'diag_sheet_saved_desc'.tr(),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb_outline_rounded, size: 14, color: Color(0xFFD97706)),
                          const SizedBox(width: 6),
                          Text(
                            'diag_tips_title'.tr(),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildTipItem(Icons.wb_sunny_outlined, 'diag_tip_light'.tr()),
                          _buildTipItem(Icons.center_focus_strong_outlined, 'diag_tip_focus'.tr()),
                          _buildTipItem(Icons.vibration_rounded, 'diag_tip_steady'.tr()),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == null || !mounted) return;

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
    } else if (action == 'saved') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const SavedAdvisoriesScreen(),
        ),
      );
    }
  }



  void _onNavTap(int index) {
    if (_selectedIndex != index) {
      HapticFeedback.selectionClick();
      setState(() => _selectedIndex = index);
      // Notify ReelsScreen about tab visibility (reels is tab index 3)
      ReelsScreen.isTabActive.value = (index == 3);

      // Adapt status bar icons for transparent edge-to-edge
      if (index == 3) {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        );
      } else {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        );
      }
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
      ReelsScreen(
        key: const ValueKey('reels_tab'),
        isTabVisible: _selectedIndex == 3,
      ),
    ];

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedIndex != 0) {
          ReelsScreen.isTabActive.value = false;
          setState(() {
            _selectedIndex = 0;
          });
          SystemChrome.setSystemUIOverlayStyle(
            const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: _selectedIndex == 3 ? Colors.black : AppTheme.background,
        extendBodyBehindAppBar: _selectedIndex == 3,
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


