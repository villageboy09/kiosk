import 'package:flutter/material.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:cropsync/models/user.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/widgets/language_selector.dart';
import 'package:cropsync/auth/signup_screen.dart';
import 'package:cropsync/widgets/animated_widgets.dart';

class ExtensionOfficerDashboard extends StatefulWidget {
  const ExtensionOfficerDashboard({super.key});

  @override
  State<ExtensionOfficerDashboard> createState() => _ExtensionOfficerDashboardState();
}

class _ExtensionOfficerDashboardState extends State<ExtensionOfficerDashboard> {
  int _currentTab = 0;
  bool _isLoading = true;
  User? _currentUser;
  
  Map<String, dynamic> _dashboardData = {};
  List<Map<String, dynamic>> _outbreaks = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _currentUser = await AuthService.getCurrentUser();
    
    if (_currentUser != null) {
      try {
        final response = await ApiService.getOfficerInfo(_currentUser!.phoneNumber ?? _currentUser!.userId);
        if (response != null && response['success'] == true) {
          final officerId = response['officer_id'] as int;
          final dashboard = await ApiService.getExtensionDashboard(officerId);
          final outbreaks = await ApiService.getActiveOutbreaks(
            district: response['user']['district'],
            mandal: response['user']['mandal'],
          );
          
          _dashboardData = dashboard;
          _outbreaks = outbreaks;
        }
      } catch (e) {
        _loadFallbackData();
      }
    } else {
      _loadFallbackData();
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  void _loadFallbackData() {
    _dashboardData = {
      'officer': {
        'name': 'B. Janardhan Rao',
        'organization': 'Dept of Agriculture',
        'coverage_mandal': 'Narayanraopet',
        'coverage_district': 'Siddipet',
      },
      'total_farmers': 2350,
      'crop_cultivation': [
        {'crop_name': 'Cotton', 'fields_count': 1200, 'total_acreage': 6500.00},
        {'crop_name': 'Maize', 'fields_count': 640, 'total_acreage': 3200.00},
        {'crop_name': 'Paddy', 'fields_count': 450, 'total_acreage': 2250.00},
      ],
      'sowing_progress': [
        {'sowing_date': '2026-06-10', 'count': 150},
        {'sowing_date': '2026-06-15', 'count': 820},
        {'sowing_date': '2026-06-20', 'count': 340},
      ],
      'disease_reports': [
        {'problem_name': 'Fall Armyworm', 'crop_name': 'Maize', 'cases_count': 47},
        {'problem_name': 'Pink Bollworm', 'crop_name': 'Cotton', 'cases_count': 23},
        {'problem_name': 'Blast Disease', 'crop_name': 'Paddy', 'cases_count': 14},
      ]
    };
    
    _outbreaks = [
      {
        'alert_id': 1,
        'crop_name': 'Maize',
        'problem_name': 'Fall Armyworm',
        'district': 'Siddipet',
        'mandal': 'Narayanraopet',
        'reports_count': 15,
        'outbreak_status': 'DETECTED',
        'triggered_at': '2026-06-14 12:00:00'
      }
    ];
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : [
              _buildDashboardTab(),
              _buildOutbreaksTab(),
              _buildProfileTab(),
            ][_currentTab],
      bottomNavigationBar: SalomonBottomBar(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: const Color(0xFF94A3B8),
        items: [
          SalomonBottomBarItem(
            icon: const Icon(Icons.analytics_rounded),
            title: const Text("Mandal Stats"),
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.warning_amber_rounded),
            title: const Text("Outbreaks"),
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.settings_rounded),
            title: const Text("Settings"),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final off = _dashboardData['officer'] ?? {};
    final name = off['name'] ?? 'Extension Officer';
    
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(
            '${off['organization'] ?? ''} | Mandal: ${off['coverage_mandal'] ?? ''}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.translate_rounded),
          onPressed: () => LanguageSelector.show(context),
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent),
          onPressed: _logout,
        ),
      ],
    );
  }

  Widget _buildDashboardTab() {
    final totalFarmers = _dashboardData['total_farmers'] ?? 0;
    final cultivation = _dashboardData['crop_cultivation'] as List<dynamic>? ?? [];
    final diseaseReports = _dashboardData['disease_reports'] as List<dynamic>? ?? [];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FadeInSlideCard(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF065F46), Color(0xFF047857)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Farmers in Coverage",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      AnimatedCountText(
                        targetValue: totalFarmers,
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Icon(Icons.people, color: Colors.white24, size: 48),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          const Text(
            "Cultivation Area Map (Acres)",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          ...cultivation.map((c) {
            double parseDouble(dynamic val) {
              if (val == null) return 0.0;
              if (val is num) return val.toDouble();
              if (val is String) return double.tryParse(val) ?? 0.0;
              return 0.0;
            }
            int parseInt(dynamic val) {
              if (val == null) return 0;
              if (val is num) return val.toInt();
              if (val is String) return int.tryParse(val) ?? 0;
              return 0;
            }

            final double acreage = parseDouble(c['total_acreage']);
            final int fields = parseInt(c['fields_count']);
            final String cropName = c['crop_name'] ?? 'Crop';
            
            double totalAcreageSum = cultivation.fold(0.0, (sum, item) => sum + parseDouble(item['total_acreage']));
            double ratio = totalAcreageSum > 0 ? (acreage / totalAcreageSum) : 0.0;
            
            return FadeInSlideCard(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(cropName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text("$fields Fields / ${acreage.toStringAsFixed(1)} Ac", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AnimatedProgressBar(
                      value: ratio,
                      color: const Color(0xFF059669),
                      backgroundColor: const Color(0xFFE2E8F0),
                      minHeight: 8,
                    ),
                  ],
                ),
              ),
            );
          }),
          
          const SizedBox(height: 24),
          const Text(
            "Mandal Disease & Pest Reports",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          ...diseaseReports.map((d) {
            final int count = (d['cases_count'] as num).toInt();
            final String problem = d['problem_name'] ?? 'Problem';
            final String crop = d['crop_name'] ?? 'Crop';
            
            return FadeInSlideCard(
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(problem, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text("Crop: $crop", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "$count Cases",
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOutbreaksTab() {
    return _outbreaks.isEmpty
        ? const Center(child: Text("No active outbreaks detected in Mandal."))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _outbreaks.length,
            itemBuilder: (context, idx) {
              final outbreak = _outbreaks[idx];
              final count = outbreak['reports_count'] ?? 1;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                            const SizedBox(width: 8),
                            Text(
                              outbreak['problem_name'] ?? 'Outbreak Alert',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFEF4444)),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "$count Reports",
                            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Crop Sync has automatically detected a potential outbreak cluster of ${outbreak['problem_name']} in crop ${outbreak['crop_name']} in ${outbreak['mandal']} Mandal within the last 15 days.",
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Outbreak Status: ${outbreak['outbreak_status']}",
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey),
                    )
                  ],
                ),
              );
            },
          );
  }

  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const CircleAvatar(
          radius: 40,
          backgroundColor: Color(0xFF059669),
          child: Icon(Icons.account_balance_rounded, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _dashboardData['officer']?['name'] ?? 'B. Janardhan Rao',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        Center(
          child: Text(
            "Extension Officer",
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.language_rounded),
          title: const Text("Select Language"),
          onTap: () => LanguageSelector.show(context),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info_outline_rounded),
          title: const Text("Terms & Conditions"),
          onTap: () {},
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          title: const Text("Logout", style: TextStyle(color: Colors.redAccent)),
          onTap: _logout,
        ),
      ],
    );
  }
}
