import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:cropsync/models/user.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/notification_service.dart';
import 'package:cropsync/widgets/language_selector.dart';
import 'package:cropsync/screens/profile_screen.dart';
import 'package:cropsync/screens/reels_screen.dart';
import 'package:cropsync/screens/news/news_feed_screen.dart';
import 'package:cropsync/screens/creator/creator_studio_screen.dart';
import 'package:cropsync/screens/creator/upload_reel_screen.dart';
import 'package:cropsync/screens/creator/upload_news_screen.dart';
import 'package:cropsync/screens/notifications_screen.dart';

/// Dedicated Main Home Screen for Agricultural Content Creators
class CreatorHomeScreen extends StatefulWidget {
  const CreatorHomeScreen({super.key, this.initialIndex = 0});
  final int initialIndex;

  static final ValueNotifier<int> tabNotifier = ValueNotifier<int>(0);
  static bool isMounted = false;

  /// Redirect to the Studio tab from any screen/button
  static void navigateToStudio(BuildContext context) {
    if (isMounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      tabNotifier.value = 0;
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const CreatorHomeScreen(initialIndex: 0)),
        (route) => false,
      );
    }
  }

  @override
  State<CreatorHomeScreen> createState() => _CreatorHomeScreenState();
}

class _CreatorHomeScreenState extends State<CreatorHomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  String _creatorName = 'Agri Creator';
  String? _profileImageUrl;
  bool _isLoading = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    CreatorHomeScreen.isMounted = true;
    _selectedIndex = widget.initialIndex;
    CreatorHomeScreen.tabNotifier.value = _selectedIndex;
    CreatorHomeScreen.tabNotifier.addListener(_onTabNotifierChanged);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _fetchCreatorDetails();
  }

  void _onTabNotifierChanged() {
    if (mounted && _selectedIndex != CreatorHomeScreen.tabNotifier.value) {
      setState(() {
        _selectedIndex = CreatorHomeScreen.tabNotifier.value;
      });
    }
  }

  @override
  void dispose() {
    CreatorHomeScreen.isMounted = false;
    CreatorHomeScreen.tabNotifier.removeListener(_onTabNotifierChanged);
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchCreatorDetails() async {
    try {
      User? user = await AuthService.getCurrentUser();
      user = await AuthService.refreshUserData();

      if (!mounted) return;
      if (user != null) {
        setState(() {
          _creatorName = user!.name;
          _profileImageUrl = user.profileImageUrl;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onNavTap(int index) {
    CreatorHomeScreen.tabNotifier.value = index;
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
    _fetchCreatorDetails();
  }

  void _showCreateActionSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF1B5E20), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Create New Content',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildCreationTile(
                icon: Icons.videocam_rounded,
                iconColor: const Color(0xFF10B981),
                bgColor: const Color(0xFFECFDF5),
                title: 'creator_upload_reel'.tr(),
                subtitle: 'Record or upload a short farming reel for farmers',
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final created = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const UploadReelScreen()),
                  );
                  if (created == true) _fetchCreatorDetails();
                },
              ),
              const SizedBox(height: 12),
              _buildCreationTile(
                icon: Icons.article_rounded,
                iconColor: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
                title: 'creator_upload_news'.tr(),
                subtitle: 'Write an agricultural update, scheme info, or guide',
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final created = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const UploadNewsScreen()),
                  );
                  if (created == true) _fetchCreatorDetails();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreationTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
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
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildCreatorAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'CropSync',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF10B981)],
                  ),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, color: Colors.white, size: 10),
                    SizedBox(width: 3),
                    Text(
                      'CREATOR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Text(
            _creatorName,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
      centerTitle: false,
      backgroundColor: AppTheme.appBarBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      actions: [
        IconButton(
          icon: const Icon(Icons.translate_rounded, color: AppTheme.appBarText, size: 22),
          onPressed: _showLanguageSheet,
          splashRadius: 24,
        ),
        _buildWiggleBell(),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            icon: _buildAvatar(),
            onPressed: _openProfile,
            splashRadius: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildWiggleBell() {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.unreadNotifier,
      builder: (context, unreadCount, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_rounded, color: AppTheme.appBarText, size: 24),
              onPressed: () {
                HapticFeedback.selectionClick();
                NotificationService.unreadNotifier.value = 0;
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
              },
              splashRadius: 24,
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
                  constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAvatar() {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF10B981), width: 1.5),
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
        border: Border.all(color: const Color(0xFF10B981), width: 1.5),
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
                // Tab 0: Creator Studio
                Expanded(
                  child: _CreatorNavItem(
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard_rounded,
                    label: 'Studio',
                    isActive: _selectedIndex == 0,
                    onTap: () => _onNavTap(0),
                    activeColor: const Color(0xFF059669),
                  ),
                ),
                // Tab 1: Reels Feed
                Expanded(
                  child: _CreatorNavItem(
                    icon: Icons.video_library_outlined,
                    activeIcon: Icons.video_library_rounded,
                    label: 'home_bottom_nav_reels'.tr(),
                    isActive: _selectedIndex == 1,
                    onTap: () => _onNavTap(1),
                    activeColor: const Color(0xFF059669),
                  ),
                ),
                // Center Action Tab: Create
                Expanded(
                  child: _AnimatedCreateActionTab(
                    animationController: _pulseController,
                    onTap: _showCreateActionSheet,
                  ),
                ),
                // Tab 2: News Feed
                Expanded(
                  child: _CreatorNavItem(
                    icon: Icons.newspaper_outlined,
                    activeIcon: Icons.newspaper_rounded,
                    label: 'home_bottom_nav_news'.tr(),
                    isActive: _selectedIndex == 2,
                    onTap: () => _onNavTap(2),
                    activeColor: const Color(0xFF059669),
                  ),
                ),
                // Tab 3: Creator Profile
                Expanded(
                  child: _CreatorNavItem(
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: 'profile_title'.tr(),
                    isActive: _selectedIndex == 3,
                    onTap: () => _onNavTap(3),
                    activeColor: const Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const CreatorStudioScreen(key: ValueKey('creator_studio_tab')),
      const ReelsScreen(key: ValueKey('creator_reels_tab')),
      const NewsFeedScreen(key: ValueKey('creator_news_tab')),
      const ProfileScreen(key: ValueKey('creator_profile_tab')),
    ];

    // Hide app bar on full screen Reels tab
    final bool hideAppBar = _selectedIndex == 1;

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: hideAppBar ? null : _buildCreatorAppBar(),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF059669)))
            : IndexedStack(
                index: _selectedIndex,
                children: screens,
              ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }
}

class _CreatorNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeColor;

  const _CreatorNavItem({
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
      splashColor: activeColor.withValues(alpha: 0.1),
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Icon(
                  isActive ? activeIcon : icon,
                  size: 22,
                  color: isActive ? activeColor : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                    color: isActive ? activeColor : const Color(0xFF6B7280),
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

class _AnimatedCreateActionTab extends StatelessWidget {
  final AnimationController animationController;
  final VoidCallback onTap;

  const _AnimatedCreateActionTab({
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
            // Pulse Ring
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
            // Core Create Button
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
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


