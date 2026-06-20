import 'package:flutter/material.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:cropsync/models/user.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/widgets/language_selector.dart';
import 'package:cropsync/auth/signup_screen.dart';
import 'package:flutter/services.dart';
import 'package:cropsync/widgets/animated_widgets.dart';
import 'package:cropsync/screens/retailer/lead_detail_screen.dart';

class RetailerDashboard extends StatefulWidget {
  const RetailerDashboard({super.key});

  @override
  State<RetailerDashboard> createState() => _RetailerDashboardState();
}

class _RetailerDashboardState extends State<RetailerDashboard> {
  int _currentTab = 0;
  bool _isLoading = true;
  User? _currentUser;
  
  Map<String, dynamic> _dashboardData = {};
  List<Map<String, dynamic>> _leads = [];

  @override
  void initState() {
    super.initState();
  }

  String? _lastLanguageCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newLang = context.locale.languageCode;
    if (_lastLanguageCode != newLang) {
      _lastLanguageCode = newLang;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final String langCode = context.locale.languageCode;
    setState(() => _isLoading = true);
    _currentUser = await AuthService.getCurrentUser();
    
    if (_currentUser != null) {
      try {
        // Since we stored the retailer id in user's profile metadata or can check by phone,
        // let's fetch it via API. For demo/prototype, let's assume retailer ID is 1 or matches user profile.
        // We will make a call to our new PHP endpoints.
        
        // We fetch retailer dashboard info using referred_by_retailer_id or hardcoded ID.
        // We can pass user's phone to identify the retailer id.
        final response = await ApiService.getRetailerInfo(_currentUser!.phoneNumber ?? _currentUser!.userId);
        if (response != null && response['success'] == true) {
          final retailerId = response['retailer_id'] as int;
          final dashboard = await ApiService.getRetailerDashboard(retailerId, lang: langCode);
          final leads = await ApiService.getRetailerLeads(retailerId, lang: langCode);
          
          if (mounted) {
            setState(() {
              _dashboardData = dashboard;
              _leads = leads;
            });
          }
        }
      } catch (e) {
        // Fallback demo data
        _loadFallbackData();
      }
    } else {
      _loadFallbackData();
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  void _loadFallbackData() {
    _dashboardData = {
      'retailer': {
        'shop_name': 'Sri Lakshmi Agro Agencies',
        'owner_name': 'Dhanunjay Reddy',
        'referral_code': 'SLAGRO500',
        'tier': 'GOLD',
        'mandal': 'Narayanraopet',
        'district': 'Siddipet',
      },
      'referred_farmers_count': 142,
      'area_farmers_count': 580,
      'cultivation_intelligence': [
        {'crop_name': 'Cotton', 'fields_count': 85, 'total_acreage': 850.50},
        {'crop_name': 'Maize', 'fields_count': 42, 'total_acreage': 420.00},
        {'crop_name': 'Paddy', 'fields_count': 30, 'total_acreage': 300.25},
      ],
      'sowing_timeline': [
        {'sowing_date': '2026-06-10', 'sowing_count': 12},
        {'sowing_date': '2026-06-15', 'sowing_count': 48},
        {'sowing_date': '2026-06-20', 'sowing_count': 32},
      ]
    };
    
    _leads = [
      {
        'lead_id': 1,
        'farmer_name': 'M. Lingaiah',
        'farmer_phone': '9848012345',
        'village': 'Narayanraopet',
        'crop_name': 'Cotton',
        'problem_name': 'Pink Bollworm',
        'lead_status': 'NEW',
        'reported_at': '2026-06-14 09:30:00'
      },
      {
        'lead_id': 2,
        'farmer_name': 'K. Ramulu',
        'farmer_phone': '9908812345',
        'village': 'Jakkapur',
        'crop_name': 'Paddy',
        'problem_name': 'Stem Borer',
        'lead_status': 'CONTACTED',
        'reported_at': '2026-06-12 11:15:00'
      }
    ];
  }

  Future<void> _updateLead(dynamic leadId, String newStatus, String notes) async {
    try {
      final res = await ApiService.updateLeadStatus(leadId: leadId, status: newStatus, notes: notes);
      if (res['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('lead_status_updated'.tr()), backgroundColor: const Color(0xFF059669)),
        );
        _loadData();
      }
    } catch (e) {
      // Local updates for fallback/prototype
      setState(() {
        final idx = _leads.indexWhere((l) => l['lead_id'] == leadId);
        if (idx != -1) {
          _leads[idx]['lead_status'] = newStatus;
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local status updated (Prototype Mode)')),
      );
    }
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
              _buildLeadsTab(),
              _buildProfileTab(),
            ][_currentTab],
      bottomNavigationBar: SalomonBottomBar(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: const Color(0xFF94A3B8),
        items: [
          SalomonBottomBarItem(
            icon: const Icon(Icons.dashboard_rounded),
            title: Text("dashboard_title".tr()),
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.people_rounded),
            title: Text("leads".tr()),
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.settings_rounded),
            title: Text("settings".tr()),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final ret = _dashboardData['retailer'] ?? {};
    final shopName = ret['shop_name'] ?? 'partner_retailer'.tr();
    final tier = ret['tier'] ?? 'BRONZE';
    
    Color tierColor;
    switch (tier) {
      case 'PLATINUM':
        tierColor = const Color(0xFFE2E8F0);
        break;
      case 'GOLD':
        tierColor = const Color(0xFFF59E0B);
        break;
      case 'SILVER':
        tierColor = const Color(0xFF94A3B8);
        break;
      default:
        tierColor = const Color(0xFFB45309);
    }

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(shopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tier,
                  style: TextStyle(color: tierColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${ret['mandal'] ?? ''}, ${ret['district'] ?? ''}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
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
    final referred = _dashboardData['referred_farmers_count'] ?? 0;
    final area = _dashboardData['area_farmers_count'] ?? 0;
    final cultivation = _dashboardData['cultivation_intelligence'] as List<dynamic>? ?? [];
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stat cards
          FadeInSlideCard(
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    "referred_farmers".tr(), 
                    referred.toString(), 
                    Icons.person_pin_circle_rounded, 
                    const Color(0xFF059669)
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    "total_farmers".tr(), 
                    area.toString(), 
                    Icons.map_rounded, 
                    const Color(0xFF2563EB)
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Referral code box
          FadeInSlideCard(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
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
                      Text(
                        "referral_code_title".tr(),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dashboardData['retailer']?['referral_code'] ?? 'SLAGRO500',
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 22, 
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _dashboardData['retailer']?['referral_code'] ?? 'SLAGRO500'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('referral_code_copied'.tr())),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text("copy".tr()),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Cultivation intelligence
          Text(
            "cultivation_intelligence".tr(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
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
            
            // Calculate a ratio for progress bar
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
                        Text("$fields ${'fields_count_label'.tr()} / ${acreage.toStringAsFixed(1)} ${'acres_label'.tr()}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AnimatedProgressBar(
                      value: ratio,
                      color: AppTheme.primary,
                      backgroundColor: const Color(0xFFE2E8F0),
                      minHeight: 8,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    final int count = int.tryParse(value) ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          AnimatedCountText(
            targetValue: count,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLeadsTab() {
    return _leads.isEmpty
        ? Center(child: Text("no_leads_assigned".tr()))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _leads.length,
            itemBuilder: (context, idx) {
              final lead = _leads[idx];
              final status = lead['lead_status'] ?? 'NEW';
              
              Color statusColor;
              switch (status) {
                case 'NEW':
                  statusColor = Colors.blue;
                  break;
                case 'CONTACTED':
                  statusColor = Colors.orange;
                  break;
                case 'RESOLVED':
                  statusColor = Colors.green;
                  break;
                default:
                  statusColor = Colors.grey;
              }

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LeadDetailScreen(
                        lead: lead,
                        onUpdateStatus: (leadId, status, notes) async {
                          await _updateLead(leadId, status, notes);
                        },
                      ),
                    ),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              lead['farmer_name'] ?? 'Farmer',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text("${'crop_label'.tr()}: ${lead['crop_name'] ?? ''} | ${'issue_label'.tr()}: ${lead['problem_name'] ?? ''}"),
                        Text("${'village_label'.tr()}: ${lead['village'] ?? ''}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LeadDetailScreen(
                                      lead: lead,
                                      onUpdateStatus: (leadId, status, notes) async {
                                        await _updateLead(leadId, status, notes);
                                      },
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.visibility_outlined, size: 16),
                              label: Text("view_details".tr()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
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
          backgroundColor: AppTheme.primary,
          child: Icon(Icons.store_rounded, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _dashboardData['retailer']?['owner_name'] ?? 'Dhanunjay Reddy',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        Center(
          child: Text(
            "retailer_partner".tr(),
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.language_rounded),
          title: Text("select_language".tr()),
          onTap: () => LanguageSelector.show(context),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info_outline_rounded),
          title: Text("terms_conditions".tr()),
          onTap: () {},
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          title: Text("logout".tr(), style: const TextStyle(color: Colors.redAccent)),
          onTap: _logout,
        ),
      ],
    );
  }
}
