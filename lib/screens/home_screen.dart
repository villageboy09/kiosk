// lib/screens/home_screen.dart
import 'package:cropsync/screens/advisory_screen.dart';
import 'package:cropsync/screens/agri_shop.dart';
import 'package:cropsync/screens/drone_booking.dart';
import 'package:cropsync/screens/market_prices.dart';
import 'package:cropsync/screens/seed_varieties.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/main.dart';
import 'package:cropsync/screens/profile_screen.dart';
import 'package:cropsync/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _farmerName = 'Farmer';
  String _greeting = 'Welcome';
  bool _isLoading = true;
  String? _profileImageUrl;

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      HomeTab(greeting: _greeting, farmerName: _farmerName),
      const AdvisoriesScreen(),
      SettingsScreen(key: UniqueKey()),
    ];
    _fetchFarmerDetails();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  Future<void> _fetchFarmerDetails() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('farmers')
          .select('full_name, profile_image_url')
          .eq('user_id', userId)
          .single();

      if (mounted) {
        setState(() {
          _farmerName = response['full_name'] as String? ?? 'Farmer';
          _profileImageUrl = response['profile_image_url'] as String?;
          _greeting = _getGreeting();
          _widgetOptions[0] =
              HomeTab(greeting: _greeting, farmerName: _farmerName);
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _farmerName = 'Farmer';
          _greeting = 'Welcome';
          _widgetOptions[0] =
              HomeTab(greeting: _greeting, farmerName: _farmerName);
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not fetch farmer details.'),
            backgroundColor: Colors.redAccent,
          ),
        );
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
              fontWeight: FontWeight.bold, color: Colors.white),
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
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
              _fetchFarmerDetails();
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? _buildLoadingShimmer()
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
            title: const Text("Home"),
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.library_books_outlined),
            activeIcon: const Icon(Icons.library_books),
            title: const Text("Advisories"),
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings),
            title: const Text("Settings"),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
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
            LayoutBuilder(builder: (context, constraints) {
              int crossAxisCount = 2;
              if (constraints.maxWidth > 600) crossAxisCount = 3;
              if (constraints.maxWidth > 900) crossAxisCount = 4;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
                children: List.generate(
                    6,
                    (index) => Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        )),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// HomeTab Widget with your beautiful animations
class HomeTab extends StatefulWidget {
  final String greeting;
  final String farmerName;

  const HomeTab({super.key, required this.greeting, required this.farmerName});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with TickerProviderStateMixin {
  late AnimationController _greetingController;
  late AnimationController _cardsController;
  late Animation<double> _greetingAnimation;
  late Animation<double> _cardsAnimation;

  @override
  void initState() {
    super.initState();
    _greetingController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _cardsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _greetingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _greetingController,
      curve: Curves.easeOutBack,
    ));

    _cardsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardsController,
      curve: Curves.elasticOut,
    ));

    _greetingController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _cardsController.forward();
      }
    });
  }

  @override
  void dispose() {
    _greetingController.dispose();
    _cardsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE8F5E8), Color(0xFFF1F8E9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting Section
                AnimatedBuilder(
                  animation: _greetingAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, 30 * (1 - _greetingAnimation.value)),
                      child: Opacity(
                        opacity:
                            _greetingAnimation.value.clamp(0.0, 1.0), // ✅ Fixed
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.greeting,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.farmerName,
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.wb_sunny,
                                    color: Colors.yellow[300],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Have a productive day!',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Quick Actions Title
                AnimatedBuilder(
                  animation: _cardsAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _cardsAnimation.value.clamp(0.0, 1.0), // ✅ Fixed
                      child: Text(
                        'Quick Actions',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Feature Cards Grid
                AnimatedBuilder(
                  animation: _cardsAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _cardsAnimation.value.clamp(0.0, 1.0), // ✅ Fixed
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount = 2;
                          if (constraints.maxWidth > 600) crossAxisCount = 3;
                          if (constraints.maxWidth > 900) crossAxisCount = 4;

                          return GridView.count(
                            crossAxisCount: crossAxisCount,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.85,
                            children: _buildFeatureCards(context),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFeatureCards(BuildContext context) {
    final features = [
      {
        'title': 'Weather',
        'subtitle': 'Live Updates',
        'icon': Icons.wb_cloudy,
        'gradient': [const Color(0xFF64B5F6), const Color(0xFF1976D2)],
        'delay': 100
      },
      {
        'title': 'Crop Advisory',
        'subtitle': 'Expert Tips',
        'icon': Icons.agriculture,
        'gradient': [const Color(0xFF81C784), const Color(0xFF388E3C)],
        'delay': 200,
        'screen': const AdvisoriesScreen()
      },
      {
        'title': 'Market Prices',
        'subtitle': 'Real-time',
        'icon': Icons.trending_up,
        'gradient': [const Color(0xFFFFB74D), const Color(0xFFF57C00)],
        'delay': 300,
        'screen': const MarketPricesScreen()
      },
      {
        'title': 'Drone Booking',
        'subtitle': 'Schedule Now',
        'icon': Icons.flight_takeoff,
        'gradient': [const Color(0xFFBA68C8), const Color(0xFF7B1FA2)],
        'delay': 400,
        'drone': const DroneBookingScreen()
      },
      {
        'title': 'Agri Shop',
        'subtitle': 'Equipment',
        'icon': Icons.store,
        'gradient': [const Color(0xFFE57373), const Color(0xFFD32F2F)],
        'delay': 500,
        'shop': const AgriShopScreen()
      },
      {
        'title': 'Seed Varieties',
        'subtitle': 'Catalog',
        'icon': Icons.eco,
        'gradient': [const Color(0xFF4DB6AC), const Color(0xFF00695C)],
        'delay': 600,
        'seeds': const SeedVarietiesScreen()
      },
    ];
    return features
        .map((feature) => _buildFeatureCard(context, feature))
        .toList();
  }

  Widget _buildFeatureCard(BuildContext context, Map<String, dynamic> feature) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 500 + (feature['delay'] as int)),
      curve: Curves.easeOutBack,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0), // ✅ Already fixed
            child: child,
          ),
        );
      },
      child: InkWell(
        onTap: () {
          if (feature['screen'] != null) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => feature['screen']),
            );
          }
          // Navigate to DroneBookingScreen
          else if (feature['drone'] != null) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => feature['drone']),
            );
          }
          // Navigate to AgriShopScreen
          else if (feature['shop'] != null) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => feature['shop']),
            );
          } else if (feature['seeds'] != null) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => feature['seeds']),
            );
          } else {
            _showFeatureDialog(context, feature['title'] as String);
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: feature['gradient'] as List<Color>,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (feature['gradient'] as List<Color>)[0]
                    .withValues(alpha: 0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(feature['icon'] as IconData,
                      size: 32, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  feature['title'] as String,
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  feature['subtitle'] as String,
                  style:
                      GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFeatureDialog(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('$featureName Feature',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text(
              'This will navigate to the $featureName screen. Implementation coming soon!',
              style: GoogleFonts.poppins()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.poppins(
                    color: const Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
