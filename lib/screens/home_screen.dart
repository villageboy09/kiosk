import 'package:cropsync/main.dart';
import 'package:cropsync/screens/profile_screen.dart';
import 'package:cropsync/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // UPDATED: The third widget is now the interactive SettingsScreen
  static const List<Widget> _widgetOptions = <Widget>[
    HomeTab(
        greeting: '', farmerName: ''), // This will be updated with real data
    Center(child: Text('Advisories Page', style: TextStyle(fontSize: 24))),
    SettingsScreen(), // Correctly navigates to your new settings screen
  ];

  @override
  void initState() {
    super.initState();
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
    setState(() {
      _isLoading = true;
    });
    try {
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('farmers')
          .select('full_name')
          .eq('user_id', userId)
          .single();

      if (mounted) {
        setState(() {
          _farmerName = response['full_name'] as String? ?? 'Farmer';
          _greeting = _getGreeting();
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _farmerName = 'Farmer';
          _greeting = 'Welcome';
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
            icon:
                const Icon(Icons.account_circle, color: Colors.white, size: 32),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : IndexedStack(
              index: _selectedIndex,
              children: [
                HomeTab(greeting: _greeting, farmerName: _farmerName),
                _widgetOptions[1],
                _widgetOptions[2],
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books_outlined),
            activeIcon: Icon(Icons.library_books),
            label: 'Advisories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green[800],
        unselectedItemColor: Colors.grey[600],
        onTap: _onItemTapped,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

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
      _cardsController.forward();
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
                        opacity: _greetingAnimation.value,
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
                      opacity: _cardsAnimation.value,
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
                      scale: _cardsAnimation.value,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Responsive grid based on screen width
                          int crossAxisCount = 2;
                          if (constraints.maxWidth > 600) {
                            crossAxisCount = 3;
                          }
                          if (constraints.maxWidth > 900) {
                            crossAxisCount = 4;
                          }

                          return GridView.count(
                            crossAxisCount: crossAxisCount,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.85,
                            children: _buildFeatureCards(),
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

  List<Widget> _buildFeatureCards() {
    final features = [
      {
        'title': 'Weather',
        'subtitle': 'Live Updates',
        'icon': Icons.wb_cloudy,
        'gradient': [const Color(0xFF64B5F6), const Color(0xFF1976D2)],
        'delay': 100,
      },
      {
        'title': 'Crop Advisory',
        'subtitle': 'Expert Tips',
        'icon': Icons.agriculture,
        'gradient': [const Color(0xFF81C784), const Color(0xFF388E3C)],
        'delay': 200,
      },
      {
        'title': 'Market Prices',
        'subtitle': 'Real-time',
        'icon': Icons.trending_up,
        'gradient': [const Color(0xFFFFB74D), const Color(0xFFF57C00)],
        'delay': 300,
      },
      {
        'title': 'Drone Booking',
        'subtitle': 'Schedule Now',
        'icon': Icons.flight_takeoff,
        'gradient': [const Color(0xFFBA68C8), const Color(0xFF7B1FA2)],
        'delay': 400,
      },
      {
        'title': 'Agri Shop',
        'subtitle': 'Equipment',
        'icon': Icons.store,
        'gradient': [const Color(0xFFE57373), const Color(0xFFD32F2F)],
        'delay': 500,
      },
      {
        'title': 'Seed Varieties',
        'subtitle': 'Catalog',
        'icon': Icons.eco,
        'gradient': [const Color(0xFF4DB6AC), const Color(0xFF00695C)],
        'delay': 600,
      },
    ];

    return features.map((feature) => _buildFeatureCard(feature)).toList();
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 800 + feature['delay'] as int),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: InkWell(
              onTap: () {
                // Add navigation logic here
                _showFeatureDialog(feature['title'] as String);
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
                        child: Icon(
                          feature['icon'] as IconData,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        feature['title'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        feature['subtitle'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFeatureDialog(String featureName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            '$featureName Feature',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'This will navigate to the $featureName screen. Implementation coming soon!',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
