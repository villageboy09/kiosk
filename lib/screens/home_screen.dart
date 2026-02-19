// ignore_for_file: prefer_const_constructors

import 'package:cropsync/screens/crop_chat_list_screen.dart';
import 'package:cropsync/screens/profile_screen.dart';
import 'package:cropsync/screens/settings_screen.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/models/user.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:cropsync/widgets/home_tab.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
        setState(() {
          _farmerName = user!.name;
          _profileImageUrl = user.profileImageUrl;
        });
      }

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
    HapticFeedback.lightImpact();
    final currentLocale = context.locale;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'language_select_title'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),
              _LanguageTile(
                label: 'English',
                isSelected: currentLocale == const Locale('en'),
                onTap: () => _setLanguage(sheetContext, const Locale('en')),
              ),
              _LanguageTile(
                label: 'हिंदी',
                isSelected: currentLocale == const Locale('hi'),
                onTap: () => _setLanguage(sheetContext, const Locale('hi')),
              ),
              _LanguageTile(
                label: 'తెలుగు',
                isSelected: currentLocale == const Locale('te'),
                onTap: () => _setLanguage(sheetContext, const Locale('te')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setLanguage(BuildContext sheetContext, Locale locale) async {
    Navigator.pop(sheetContext);
    await context.setLocale(locale);
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
      ),
      CropChatListScreen(key: const ValueKey('advisory_tab')),
      SettingsScreen(key: const ValueKey('settings_tab')),
    ];

    return Scaffold(
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
    );
  }

  PreferredSizeWidget _buildCurvedAppBar() {
    return AppBar(
      title: const Text(
        'CropSync',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: false,
      backgroundColor: const Color(0xFF66BB6A), // Light Green (400)
      elevation: 4,
      shadowColor: const Color(0xFF66BB6A).withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      actions: [
        IconButton(
          icon: const Icon(Icons.translate_rounded,
              color: Colors.white, size: 24),
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
      return CircleAvatar(
        radius: 15,
        backgroundColor: Colors.white24,
        backgroundImage: CachedNetworkImageProvider(
          _profileImageUrl!,
          maxWidth: 60,
          maxHeight: 60,
        ),
        onBackgroundImageError: (_, __) {},
        child: null, // Ensure no child obscures the image
      );
    }
    return const CircleAvatar(
      radius: 15,
      backgroundColor: Colors.transparent, // Transparent for logo
      backgroundImage: AssetImage('assets/images/logo.png'),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                  icon: Icons.library_books_outlined,
                  activeIcon: Icons.library_books_rounded,
                  label: 'home_bottom_nav_advisories'.tr(),
                  isActive: _selectedIndex == 1,
                  onTap: () => _onNavTap(1),
                  activeColor: AppTheme.primary,
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
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
      splashColor: activeColor.withValues(alpha: 0.1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? activeColor.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  size: 24,
                  color: isActive ? activeColor : const Color(0xFF9E9E9E),
                ),
                if (isActive) ...[
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: activeColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Language selection tile - Minimalist
class _LanguageTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00695C).withValues(alpha: 0.08)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF00695C)
                    : const Color(0xFF424242),
              ),
            ),
            const Spacer(),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF00695C),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              )
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
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE0E0E0),
      highlightColor: const Color(0xFFF5F5F5),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily Brief Card
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 32),
            // Section Title
            Container(
              height: 24,
              width: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 20),
            // Grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(
                  4,
                  (_) => Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
