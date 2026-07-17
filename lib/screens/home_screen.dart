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
import 'package:image_picker/image_picker.dart';
import 'package:cropsync/screens/plant_analysis_screen.dart';
import 'package:cropsync/screens/notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        NotificationService.subscribeToDistrictTopic(currentUser, lang: context.locale.languageCode);
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

  Future<int> _getAvailableRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final times = prefs.getStringList('nvidia_request_timestamps') ?? [];
    
    final validTimes = times.where((t) {
      final dt = DateTime.tryParse(t);
      if (dt == null) return false;
      return now.difference(dt).inSeconds < 60;
    }).toList();
    
    return (40 - validTimes.length).clamp(0, 40).toInt();
  }

  void _showImageSourceSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'diag_select_source'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              FutureBuilder<int>(
                future: _getAvailableRequests(),
                builder: (context, snapshot) {
                  final reqs = snapshot.data ?? 40;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 12),
                    child: Text(
                      'diag_rate_limit'.tr(args: [reqs.toString()]),
                      style: TextStyle(
                        fontSize: 13,
                        color: reqs < 5 ? Colors.red : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.primary),
                title: Text('diag_camera'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppTheme.primary),
                title: Text('diag_gallery'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.eco_rounded, color: AppTheme.primary),
                title: Text('diag_tab_crops'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PlantAnalysisScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    HapticFeedback.mediumImpact();
    final picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (photo != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlantAnalysisScreen(imagePath: photo.path),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error picking image: $e")),
        );
      }
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
        floatingActionButton: _selectedIndex == 0
            ? AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        width: 56 + (_pulseController.value * 28),
                        height: 56 + (_pulseController.value * 28),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF16A34A).withValues(alpha: (1.0 - _pulseController.value) * 0.35),
                          ),
                        ),
                      ),
                      Positioned(
                        width: 56 + (_pulseController.value * 14),
                        height: 56 + (_pulseController.value * 14),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF16A34A).withValues(alpha: (1.0 - _pulseController.value) * 0.65),
                          ),
                        ),
                      ),
                      FloatingActionButton(
                        onPressed: _showImageSourceSheet,
                        backgroundColor: const Color(0xFF16A34A),
                        shape: const CircleBorder(),
                        elevation: 6,
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28),
                      ),
                    ],
                  );
                },
              )
            : null,
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

class WiggleBellButton extends StatefulWidget {
  const WiggleBellButton({super.key});

  @override
  State<WiggleBellButton> createState() => _WiggleBellButtonState();
}

class _WiggleBellButtonState extends State<WiggleBellButton> with SingleTickerProviderStateMixin {
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
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
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

