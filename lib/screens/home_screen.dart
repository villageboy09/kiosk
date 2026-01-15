import 'package:cropsync/screens/advisory_screen.dart';
import 'package:cropsync/screens/agri_shop.dart';
import 'package:cropsync/screens/drone_booking.dart';
import 'package:cropsync/screens/market_prices.dart';
import 'package:cropsync/screens/seed_varieties.dart';
import 'package:cropsync/screens/weather.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/advisory_state.dart';
import 'package:cropsync/models/user.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/screens/profile_screen.dart';
import 'package:cropsync/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:lottie/lottie.dart';

// Helper class to draw a dashed line
class DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    const double dashWidth = 4;
    const double dashSpace = 3;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _farmerName = 'Farmer';
  String _greeting = 'home_greeting_welcome'.tr();
  bool _isLoading = true;
  String? _profileImageUrl;

  // Shared advisory state
  final AdvisoryState _advisoryState = AdvisoryState();

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      HomeTab(
        greeting: _greeting,
        farmerName: _farmerName,
        profileImageUrl: _profileImageUrl,
        advisoryState: _advisoryState,
      ),
      const AdvisoriesScreen(),
      SettingsScreen(key: UniqueKey()),
    ];
    _fetchFarmerDetails();
    
    // Listen to advisory state changes
    _advisoryState.addListener(_onAdvisoryStateChanged);
  }

  @override
  void dispose() {
    _advisoryState.removeListener(_onAdvisoryStateChanged);
    super.dispose();
  }

  void _onAdvisoryStateChanged() {
    if (mounted) {
      setState(() {
        // Update HomeTab with new advisory state
        _widgetOptions[0] = HomeTab(
          greeting: _greeting,
          farmerName: _farmerName,
          profileImageUrl: _profileImageUrl,
          advisoryState: _advisoryState,
        );
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'home_greeting_morning'.tr();
    } else if (hour < 17) {
      return 'home_greeting_afternoon'.tr();
    } else {
      return 'home_greeting_evening'.tr();
    }
  }

  String _getLocaleField(String locale) {
    switch (locale) {
      case 'hi':
        return 'hi';
      case 'te':
        return 'te';
      default:
        return 'en';
    }
  }

  Future<void> _fetchFarmerDetails() async {
    // Simulate network delay to see the shimmer effect
    await Future.delayed(const Duration(seconds: 1));

    try {
      // Get user from AuthService instead of Supabase
      User? user = await AuthService.getCurrentUser();
      
      // Optionally refresh user data from server
      user = await AuthService.refreshUserData();

      if (mounted && user != null) {
        setState(() {
          _farmerName = user!.name;
          _profileImageUrl = user.profileImageUrl;
          _greeting = _getGreeting();
          _widgetOptions[0] = HomeTab(
            greeting: _greeting,
            farmerName: _farmerName,
            profileImageUrl: _profileImageUrl,
            advisoryState: _advisoryState,
          );
          _isLoading = false;
        });

        // Initialize advisory state with current locale
        final locale = _getLocaleField(context.locale.languageCode);
        _advisoryState.initializeData(locale: locale);
      } else if (mounted) {
        setState(() {
          _farmerName = 'Farmer';
          _greeting = 'home_greeting_welcome'.tr();
          _widgetOptions[0] = HomeTab(
            greeting: _greeting,
            farmerName: _farmerName,
            profileImageUrl: null,
            advisoryState: _advisoryState,
          );
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _farmerName = 'Farmer';
          _greeting = 'home_greeting_welcome'.tr();
          _widgetOptions[0] = HomeTab(
            greeting: _greeting,
            farmerName: _farmerName,
            profileImageUrl: null,
            advisoryState: _advisoryState,
          );
          _isLoading = false;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('home_fetch_error'.tr()),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Widget _buildProfileAvatar() {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: Colors.white24,
        backgroundImage: CachedNetworkImageProvider(_profileImageUrl!),
      );
    } else {
      return const Icon(Icons.account_circle, color: Colors.white, size: 32);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cropsync',
          style: GoogleFonts.lexend(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: _buildProfileAvatar(),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
              setState(() {
                _isLoading = true;
              });
              _fetchFarmerDetails();
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const HomeTabShimmer()
          : IndexedStack(
              index: _selectedIndex,
              children: _widgetOptions,
            ),
      bottomNavigationBar: SalomonBottomBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        selectedItemColor: Colors.green[800],
        unselectedItemColor: Colors.grey[600],
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        items: [
          SalomonBottomBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            title: Text(
              "home_bottom_nav_home".tr(),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.library_books_outlined),
            activeIcon: const Icon(Icons.library_books),
            title: Text(
              "home_bottom_nav_advisories".tr(),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings),
            title: Text(
              "home_bottom_nav_settings".tr(),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeTabShimmer extends StatelessWidget {
  const HomeTabShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                height: 24,
                width: 150,
                color: Colors.white,
              ),
              const SizedBox(height: 20),
              GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: 6,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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

class HomeTab extends StatelessWidget {
  final String greeting;
  final String farmerName;
  final String? profileImageUrl;
  final AdvisoryState advisoryState;

  const HomeTab({
    super.key,
    required this.greeting,
    required this.farmerName,
    this.profileImageUrl,
    required this.advisoryState,
  });

  static final List<Map<String, dynamic>> features = [
    {
      'title_key': 'home_feature_weather_title',
      'subtitle_key': 'home_feature_weather_subtitle',
      'icon': Icons.wb_cloudy_outlined,
      'lottiePath': 'assets/lottie/Showers.json',
      'color': const Color(0xFF00695C),
      'page': const WeatherScreen()
    },
    {
      'title_key': 'home_feature_advisory_title',
      'subtitle_key': 'home_feature_advisory_subtitle',
      'icon': Icons.agriculture_outlined,
      'color': const Color(0xFF388E3C),
      'page': const AdvisoriesScreen()
    },
    {
      'title_key': 'home_feature_market_title',
      'subtitle_key': 'home_feature_market_subtitle',
      'icon': Icons.trending_up_outlined,
      'color': const Color(0xFFE65100),
      'page': const MarketPricesScreen()
    },
    {
      'title_key': 'home_feature_shop_title',
      'subtitle_key': 'home_feature_shop_subtitle',
      'icon': Icons.storefront_outlined,
      'color': const Color(0xFF5D4037),
      'page': const AgriShopScreen()
    },
    {
      'title_key': 'home_feature_seeds_title',
      'subtitle_key': 'home_feature_seeds_subtitle',
      'icon': Icons.grass_outlined,
      'color': const Color(0xFF1565C0),
      'page': const SeedVarietiesScreen()
    },
    {
      'title_key': 'home_feature_drone_title',
      'subtitle_key': 'home_feature_drone_subtitle',
      'icon': Icons.flight_outlined,
      'color': const Color(0xFF6A1B9A),
      'page': const DroneBookingScreen()
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreetingCard(context),
            const SizedBox(height: 20),
            // Crop Advisory Card - Real-time synced
            _buildCropAdvisoryCard(context),
            const SizedBox(height: 24),
            Text(
              'home_services_title'.tr(),
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 20),
            _buildFeaturesGrid(context),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  farmerName,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'home_welcome_message'.tr(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Lottie.asset(
            'assets/lottie/farmer.json',
            width: 100,
            height: 100,
          ),
        ],
      ),
    );
  }

  /// Build the Crop Advisory Card that shows real-time stage and problem info
  Widget _buildCropAdvisoryCard(BuildContext context) {
    // If no data is loaded yet, show a loading state
    if (advisoryState.isLoading || !advisoryState.isInitialized) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'home_loading_advisory'.tr(),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // If no crops are selected
    if (advisoryState.farmerCrops.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.add_circle_outline, color: Colors.orange[700], size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'home_no_crops_title'.tr(),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[800],
                    ),
                  ),
                  Text(
                    'home_no_crops_subtitle'.tr(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.orange[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Show the crop advisory card with real-time data
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const AdvisoriesScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[50]!, Colors.green[100]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with crop info
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.green[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.agriculture, color: Colors.green[700], size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        advisoryState.currentCropName,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[800],
                        ),
                      ),
                      Text(
                        advisoryState.currentFieldName,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.green[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.green[400], size: 16),
              ],
            ),
            const SizedBox(height: 12),
            // Divider
            Container(
              height: 1,
              color: Colors.green[200],
            ),
            const SizedBox(height: 12),
            // Stage and problems info
            Row(
              children: [
                // Current Stage
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'home_current_stage'.tr(),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.green[600],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        advisoryState.currentStageName.isNotEmpty
                            ? advisoryState.currentStageName
                            : 'home_no_stage'.tr(),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[800],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Problems count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: advisoryState.hasProblems 
                        ? Colors.orange[100] 
                        : Colors.green[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        advisoryState.hasProblems 
                            ? Icons.warning_amber_rounded 
                            : Icons.check_circle,
                        size: 16,
                        color: advisoryState.hasProblems 
                            ? Colors.orange[700] 
                            : Colors.green[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        advisoryState.hasProblems
                            ? '${advisoryState.problemCount} ${'home_problems'.tr()}'
                            : 'home_no_issues'.tr(),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: advisoryState.hasProblems 
                              ? Colors.orange[700] 
                              : Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesGrid(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: features.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final feature = features[index];
        return _buildFeatureCard(
          context,
          feature['title_key'].toString().tr(),
          feature['subtitle_key'].toString().tr(),
          feature['icon'] as IconData,
          feature['color'] as Color,
          feature['page'] as Widget,
          lottiePath: feature['lottiePath'] as String?,
        );
      },
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    Widget page, {
    String? lottiePath,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => page),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: lottiePath != null
                  ? SizedBox(
                      width: 28,
                      height: 28,
                      child: Lottie.asset(lottiePath, fit: BoxFit.contain),
                    )
                  : Icon(icon, color: color, size: 28),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
