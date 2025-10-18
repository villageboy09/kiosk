// lib/screens/home_screen.dart

import 'package:cropsync/screens/advisory_screen.dart';

import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/main.dart';
import 'package:cropsync/screens/profile_screen.dart';
import 'package:cropsync/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

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
  String _greeting = 'Welcome';
  bool _isLoading = true;
  String? _profileImageUrl;

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      HomeTab(
        greeting: _greeting,
        farmerName: _farmerName,
        profileImageUrl: _profileImageUrl, // Pass initial null value
      ),
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
    await Future.delayed(const Duration(seconds: 2));

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
          // UPDATED: Pass profileImageUrl to HomeTab
          _widgetOptions[0] = HomeTab(
            greeting: _greeting,
            farmerName: _farmerName,
            profileImageUrl: _profileImageUrl,
          );
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _farmerName = 'Farmer';
          _greeting = 'Welcome';
          // UPDATED: Pass profileImageUrl to HomeTab even on error
          _widgetOptions[0] = HomeTab(
            greeting: _greeting,
            farmerName: _farmerName,
            profileImageUrl: null,
          );
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
  final String? profileImageUrl; // Added property

  const HomeTab({
    super.key,
    required this.greeting,
    required this.farmerName,
    this.profileImageUrl, // Added to constructor
  });

  @override
  Widget build(BuildContext context) {
    final String currentDate =
        DateFormat('EEEE, d MMMM').format(DateTime.now());
    return Container(
      color: const Color(0xFFF1F8E9),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withAlpha(77),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        farmerName,
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              color: Colors.white70, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            currentDate,
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
                const SizedBox(height: 32),
                Text(
                  'Quick Actions',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 20),
                GridView.builder(
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
                    return _buildFeatureCard(context, feature);
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

  static final List<Map<String, dynamic>> features = [
    // ... (feature list remains the same)
  ];

  // #### ENTIRELY UPDATED WIDGET ####
  Widget _buildFeatureCard(BuildContext context, Map<String, dynamic> feature) {
    Widget iconOrAvatar;

    // Conditional logic for the "Crop Advisory" card
    if (feature['title'] == 'Crop Advisory' &&
        profileImageUrl != null &&
        profileImageUrl!.isNotEmpty) {
      // If it's the advisory card and a profile image exists, show the avatar
      iconOrAvatar = CircleAvatar(
        radius: 22,
        backgroundColor: Colors.grey[200],
        backgroundImage: CachedNetworkImageProvider(profileImageUrl!),
      );
    } else {
      // For all other cards, or if no profile image, show the default decorated icon
      iconOrAvatar = Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (feature['color'] as Color).withAlpha(38), // ~15% opacity
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          feature['icon'] as IconData,
          size: 28,
          color: feature['color'] as Color,
        ),
      );
    }

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withAlpha(26), // ~10% opacity
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          final page = feature['page'] as Widget?;
          if (page != null) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => page),
            );
          } else {
            _showFeatureDialog(context, feature['title'] as String);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              iconOrAvatar, // Use the conditionally built widget here
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full-width dashed line
                  CustomPaint(
                    painter: DashPainter(),
                    child: Container(height: 1), // Provides canvas for painter
                  ),
                  const SizedBox(height: 8),
                  Text(
                    feature['title'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    feature['subtitle'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFeatureDialog(BuildContext context, String featureName) {
    // ... (This function remains unchanged)
  }
}
