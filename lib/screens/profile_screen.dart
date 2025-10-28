// lib/profile_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/main.dart';
import 'package:cropsync/welcome_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  // How to use the new smooth navigation:
  // Instead of MaterialPageRoute, push the route like this:
  // Navigator.of(context).push(ProfileScreen.route());
  static Route<void> route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const ProfileScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _farmerFuture;
  late Future<List<Map<String, dynamic>>> _problemsFuture;
  late Future<List<Map<String, dynamic>>> _bookingsFuture;
  // Removed 'late' and made _appConfigFuture a getter to avoid LateInitializationError
  String? farmerId;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditMode = false;

  // Controllers for editable fields
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pincodeController = TextEditingController();
  XFile? _selectedImage;
  String? _profileImageUrl;

  // Store original values to restore on cancel
  String? _originalName;
  String? _originalPhone;
  String? _originalPincode;

  // Getter for app config to avoid late initialization issues
  Future<Map<String, String>> get _appConfigFuture => _fetchAppConfig();

  @override
  void initState() {
    super.initState();
    _farmerFuture = _fetchAndSetFarmerProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _fetchAppConfig() async {
    final response = await supabase.from('app_config').select('key, value');
    return {
      for (var item in response) item['key'] as String: item['value'] as String
    };
  }

  Future<Map<String, dynamic>> _fetchAndSetFarmerProfile() async {
    final userId = supabase.auth.currentUser!.id;
    final data =
        await supabase.from('farmers').select().eq('user_id', userId).single();

    _nameController.text = data['full_name'] ?? '';
    _phoneController.text = data['phone_number'] ?? '';
    _pincodeController.text = data['pincode'] ?? '';
    _profileImageUrl = data['profile_image_url'];

    _originalName = _nameController.text;
    _originalPhone = _phoneController.text;
    _originalPincode = _pincodeController.text;

    farmerId = data['id'];
    // Fixed: Use correct farmerId for queries
    _problemsFuture = _fetchProblems(farmerId!);
    _bookingsFuture = _fetchBookings();

    return data;
  }

  Future<List<Map<String, dynamic>>> _fetchProblems(String farmerId) async {
    return await supabase
        .from('farmer_identified_problems')
        .select()
        .eq('farmer_id', farmerId)
        .order('identified_at', ascending: false);
  }

  Future<List<Map<String, dynamic>>> _fetchBookings() async {
    if (farmerId == null) return [];
    return await supabase
        .from('drone_service_bookings')
        .select()
        .eq('farmer_id', farmerId!)
        .order('created_at', ascending: false);
  }

  Future<void> _pickImage() async {
    if (!_isEditMode) return;
    final ImagePicker picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) {
      if (mounted) {
        setState(() {
          _selectedImage = image;
        });
      }
    }
  }

  void _toggleEditMode() {
    if (mounted) {
      setState(() {
        _isEditMode = !_isEditMode;
        if (!_isEditMode) {
          _nameController.text = _originalName ?? '';
          _phoneController.text = _originalPhone ?? '';
          _pincodeController.text = _originalPincode ?? '';
          _selectedImage = null;
        }
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      String? newImageUrl;
      if (_selectedImage != null) {
        final imageFile = File(_selectedImage!.path);
        final imageExtension =
            _selectedImage!.path.split('.').last.toLowerCase();
        final userId = supabase.auth.currentUser!.id;
        final imagePath = 'profile/$userId/profile.$imageExtension';

        await supabase.storage.from('farmer_profile').upload(
              imagePath,
              imageFile,
              fileOptions:
                  const FileOptions(cacheControl: '3600', upsert: true),
            );

        final publicUrl =
            supabase.storage.from('farmer_profile').getPublicUrl(imagePath);
        newImageUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      }

      final updates = {
        'full_name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        if (newImageUrl != null) 'profile_image_url': newImageUrl,
      };

      await supabase
          .from('farmers')
          .update(updates)
          .eq('user_id', supabase.auth.currentUser!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('profile_updated')),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        setState(() {
          _farmerFuture = _fetchAndSetFarmerProfile();
          _isEditMode = false;
          _selectedImage = null;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('update_profile_error',
                namedArgs: {'error': error.toString()})),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('logout_title'),
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF282C3F),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('logout_message'),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: const Color(0xFF7E808C),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        context.tr('cancel'),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF282C3F),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await supabase.auth.signOut();
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (context) => const SplashScreen()),
                            (route) => false,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFFFC8019),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        context.tr('logout'),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Future<void> _showPrivacyPolicy() async {
    final config = await _appConfigFuture;
    final url =
        config['privacyPolicyUrl'] ?? 'https://cropsync.in/privacy.html';
    if (mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      context.tr('privacy_policy_title'),
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF282C3F),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Color(0xFF93959F)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('privacy_matters_title'),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF282C3F),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.tr('privacy_description'),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF7E808C),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('full_policy_teaser'),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF60B246),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PrivacyPolicyScreen(url: url),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF60B246),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      context.tr('view_full_policy'),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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

  void _showContactUs() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FutureBuilder<Map<String, String>>(
        future: _appConfigFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              height: 200,
              padding: const EdgeInsets.all(20),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          final config = snapshot.data ?? {};
          final email = config['supportEmail'] ?? 'support@cropsync.com';
          final phone = config['supportPhone'] ?? '+91 9876543210';
          final location =
              config['headquartersAddress'] ?? 'Hyderabad, Telangana';
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        context.tr('contact_us_title'),
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF282C3F),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Color(0xFF93959F)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildContactTile(
                    icon: Icons.email_outlined,
                    title: email,
                    subtitle: context.tr('send_email'),
                  ),
                  const SizedBox(height: 12),
                  _buildContactTile(
                    icon: Icons.phone_outlined,
                    title: phone,
                    subtitle: context.tr('call_us'),
                  ),
                  const SizedBox(height: 12),
                  _buildContactTile(
                    icon: Icons.location_on_outlined,
                    title: location,
                    subtitle: context.tr('headquarters'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // This method is no longer called from the UI but is kept for reference.

  Widget _buildProblemCard(Map<String, dynamic> problem) {
    final identifiedAt = DateTime.parse(problem['identified_at']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.warning_amber_outlined,
                  color: Color(0xFFF57C00),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('problem_id',
                          namedArgs: {'id': problem['problem_id'].toString()}),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF282C3F),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MMM dd, yyyy').format(identifiedAt),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF7E808C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final serviceDate = DateTime.parse('${booking['service_date']}T00:00:00');
    final cost = booking['total_cost']?.toString() ?? '0';
    final bookingIdText = booking['booking_id_text'] ?? 'N/A';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.airport_shuttle,
                  color: Color(0xFF60B246),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookingIdText,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF282C3F),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('booking_details', namedArgs: {
                        'crop': booking['crop_type'],
                        'acres': booking['acres'].toString()
                      }),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF7E808C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          context.tr('total_cost', namedArgs: {'cost': cost}),
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF60B246),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(booking['booking_status']),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            booking['booking_status'] ?? context.tr('pending'),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('service_date', namedArgs: {
                        'date': DateFormat('MMM dd, yyyy').format(serviceDate)
                      }),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF7E808C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return const Color(0xFF4CAF50);
      case 'cancelled':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFFFF9800);
    }
  }

  Widget _buildContactTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF60B246), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF282C3F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF7E808C),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF93959F), size: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _farmerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildShimmerLoading();
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Color(0xFF93959F)),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('error_loading_profile'),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: const Color(0xFF7E808C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF93959F),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 240,
                  pinned: true,
                  backgroundColor: const Color(0xFF60B246),
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  leading: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildGradientHeader(),
                  ),
                  actions: _buildAppBarActions(),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildPersonalInfoCard(),
                          const SizedBox(height: 12),
                          _buildActivityHistoryCard(), // New Activity Card
                          const SizedBox(height: 12),
                          _buildMenuCard(),
                          const SizedBox(height: 12),
                          _buildLogoutCard(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    if (_isEditMode) {
      return [
        TextButton(
          onPressed: _toggleEditMode,
          child: Text(
            context.tr('cancel'),
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
        TextButton(
          onPressed: _isLoading ? null : _updateProfile,
          style: TextButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF60B246)),
                  ),
                )
              : Text(
                  context.tr('save'),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF60B246),
                  ),
                ),
        ),
        const SizedBox(width: 8),
      ];
    } else {
      return [
        IconButton(
          onPressed: _toggleEditMode,
          icon: const Icon(Icons.edit_outlined, color: Colors.white),
          tooltip: context.tr('edit_profile'),
        ),
        const SizedBox(width: 4),
      ];
    }
  }

  /// New widget to display farmer's activity history in expandable cards.
  Widget _buildActivityHistoryCard() {
    return Container(
      clipBehavior: Clip.antiAlias, // Ensures content respects rounded corners
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              iconColor: const Color(0xFF282C3F),
              collapsedIconColor: const Color(0xFF282C3F),
              leading: const Icon(Icons.bug_report_outlined,
                  color: Color(0xFFF57C00)),
              title: Text(
                context.tr('identified_problems'),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF282C3F),
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _problemsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 100,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            context.tr('error', namedArgs: {
                              'error': snapshot.error.toString()
                            }),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: const Color(0xFF93959F),
                            ),
                          ),
                        );
                      }
                      final problems = snapshot.data ?? [];
                      if (problems.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            context.tr('no_problems'),
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: const Color(0xFF7E808C),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return Column(
                        children: problems
                            .map((problem) => _buildProblemCard(problem))
                            .toList(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const DashedDivider(indent: 20, endIndent: 20),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              iconColor: const Color(0xFF282C3F),
              collapsedIconColor: const Color(0xFF282C3F),
              leading: const Icon(Icons.rocket_launch_outlined,
                  color: Color(0xFF60B246)),
              title: Text(
                context.tr('drone_bookings'),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF282C3F),
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _bookingsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 100,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            context.tr('error', namedArgs: {
                              'error': snapshot.error.toString()
                            }),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: const Color(0xFF93959F),
                            ),
                          ),
                        );
                      }
                      final bookings = snapshot.data ?? [];
                      if (bookings.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            context.tr('no_bookings'),
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: const Color(0xFF7E808C),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return Column(
                        children: bookings
                            .map((booking) => _buildBookingCard(booking))
                            .toList(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF60B246),
            Color(0xFF4A9635),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildProfileImage(),
              const SizedBox(height: 16),
              Text(
                _nameController.text.isEmpty
                    ? context.tr('your_name')
                    : _nameController.text,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                supabase.auth.currentUser?.email ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8), // Adjusted padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isEditMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  _buildEditableField(
                    controller: _nameController,
                    label: context.tr('full_name'),
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildEditableField(
                    controller: _phoneController,
                    label: context.tr('phone_number'),
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildEditableField(
                    controller: _pincodeController,
                    label: context.tr('pincode'),
                    icon: Icons.pin_drop_outlined,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            )
          else ...[
            _buildInfoRow(
              icon: Icons.phone_outlined,
              label: context.tr('phone'),
              value: _phoneController.text.isEmpty
                  ? context.tr('not_set')
                  : _phoneController.text,
            ),
            const DashedDivider(indent: 20, endIndent: 20),
            _buildInfoRow(
              icon: Icons.pin_drop_outlined,
              label: context.tr('pincode'),
              value: _pincodeController.text.isEmpty
                  ? context.tr('not_set')
                  : _pincodeController.text,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.credit_card_outlined,
            title: context.tr('payment_methods'),
            onTap: () {},
          ),
          const DashedDivider(indent: 20, endIndent: 20),
          _buildMenuItem(
            icon: Icons.privacy_tip_outlined,
            title: context.tr('privacy_policy'),
            onTap: _showPrivacyPolicy,
          ),
          const DashedDivider(indent: 20, endIndent: 20),
          _buildMenuItem(
            icon: Icons.help_outline,
            title: context.tr('help_support'),
            onTap: _showContactUs,
          ),
          const DashedDivider(indent: 20, endIndent: 20),
          _buildMenuItem(
            icon: Icons.info_outline,
            title: context.tr('about'),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF282C3F), size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF282C3F),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF93959F), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutCard() {
    return InkWell(
      onTap: _logout,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.logout, color: Color(0xFFFC8019), size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                context.tr('logout'),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF282C3F),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF93959F), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    Widget imageWidget;

    if (_selectedImage != null) {
      imageWidget = ClipOval(
        child: Image.file(
          File(_selectedImage!.path),
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
      );
    } else if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      imageWidget = ClipOval(
        child: CachedNetworkImage(
          imageUrl: _profileImageUrl!,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
          errorWidget: (context, url, error) => Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, size: 50, color: Color(0xFF93959F)),
          ),
        ),
      );
    } else {
      imageWidget = Container(
        width: 100,
        height: 100,
        decoration: const BoxDecoration(
          color: Color(0xFFF8F9FA),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person, size: 50, color: Color(0xFF93959F)),
      );
    }

    return Stack(
      children: [
        imageWidget,
        if (_isEditMode)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF60B246),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child:
                    const Icon(Icons.camera_alt, color: Colors.white, size: 16),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEditableField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF7E808C),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF282C3F),
          ),
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF93959F), size: 20),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE9EBED), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFF60B246), width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE9EBED), width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            isDense: true,
          ),
          validator: (value) => value == null || value.isEmpty
              ? context
                  .tr('enter_field', namedArgs: {'field': label.toLowerCase()})
              : null,
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF93959F), size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF7E808C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF282C3F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE9EBED),
      highlightColor: Colors.white,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: const Color(0xFF60B246),
            automaticallyImplyLeading: false,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF60B246),
                      Color(0xFF4A9635),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 28,
                          width: 200,
                          decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 15,
                          width: 150,
                          decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: List.generate(
                        2,
                        (index) => Padding(
                          padding: EdgeInsets.only(bottom: index == 1 ? 0 : 16),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFF8F9FA),
                                    borderRadius: BorderRadius.circular(4)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      height: 13,
                                      width: 80,
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFF8F9FA),
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 15,
                                      width: 120,
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFF8F9FA),
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: List.generate(
                        4,
                        (index) => Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: index == 0 ? 0 : 16),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFF8F9FA),
                                    borderRadius: BorderRadius.circular(4)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  height: 15,
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFF8F9FA),
                                      borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFF8F9FA),
                                    borderRadius: BorderRadius.circular(4)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatefulWidget {
  final String url;
  const PrivacyPolicyScreen(
      {super.key, this.url = 'https://cropsync.in/privacy.html'});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  late final WebViewController controller;
  bool _supportsWebView = false;

  @override
  void initState() {
    super.initState();
    // Only initialize WebViewController if on supported platform to avoid assertion error
    _supportsWebView = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    if (_supportsWebView) {
      controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              // Update loading bar.
            },
            onPageStarted: (String url) {},
            onPageFinished: (String url) {},
            onWebResourceError: (WebResourceError error) {},
          ),
        )
        ..loadRequest(Uri.parse(widget.url));
    }
  }

  Future<void> _launchPrivacyPolicy() async {
    final url = Uri.parse(widget.url);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            context.tr('privacy_policy_title'),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF282C3F),
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: const Color(0xFF282C3F),
        ),
        body: _supportsWebView
            ? WebViewWidget(controller: controller)
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        context.tr('privacy_policy_title'),
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF282C3F),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('visit_in_browser'),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: const Color(0xFF7E808C),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _launchPrivacyPolicy,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF60B246),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          context.tr('open_privacy_policy'),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
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

class DashedDivider extends StatelessWidget {
  const DashedDivider({
    super.key,
    this.height = 1,
    this.color,
    this.indent = 0,
    this.endIndent = 0,
  });

  final double height;
  final Color? color;
  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent, right: endIndent),
      child: CustomPaint(
        painter: _DashedLinePainter(
          color: color ?? Colors.grey.shade200,
        ),
        size: Size(double.infinity, height),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 4, dashSpace = 4, startX = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
