// lib/profile_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/main.dart';
import 'package:cropsync/welcome_screen.dart'; // Assuming this is your splash screen
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _farmerFuture;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditMode = false;

  // Controllers for editable fields
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pincodeController = TextEditingController();
  String? _selectedVillage;
  String? _selectedDistrict;
  XFile? _selectedImage;
  String? _profileImageUrl;

  // Store original values to restore on cancel
  String? _originalName;
  String? _originalPhone;
  String? _originalPincode;
  String? _originalVillage;
  String? _originalDistrict;

  // Dummy data for dropdowns
  final List<String> _districts = ['Wanaparthy', 'Nagarkurnool', 'Mahbubnagar'];
  final List<String> _villages = ['Pami Reddy Pally', 'Kothakota', 'Madanapur'];

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

  Future<Map<String, dynamic>> _fetchAndSetFarmerProfile() async {
    final userId = supabase.auth.currentUser!.id;
    final data =
        await supabase.from('farmers').select().eq('user_id', userId).single();

    // Set controller and state variables from the fetched data
    _nameController.text = data['full_name'] ?? '';
    _phoneController.text = data['phone_number'] ?? '';
    _pincodeController.text = data['pincode'] ?? '';
    _selectedVillage = data['village'];
    _selectedDistrict = data['district'];
    _profileImageUrl = data['profile_image_url'];

    // Also store the original values for the cancel functionality
    _originalName = _nameController.text;
    _originalPhone = _phoneController.text;
    _originalPincode = _pincodeController.text;
    _originalVillage = _selectedVillage;
    _originalDistrict = _selectedDistrict;

    return data;
  }

  Future<void> _pickImage() async {
    if (!_isEditMode) return;
    final ImagePicker picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (!_isEditMode) {
        // Restore original values if cancel is pressed
        _nameController.text = _originalName ?? '';
        _phoneController.text = _originalPhone ?? '';
        _pincodeController.text = _originalPincode ?? '';
        _selectedVillage = _originalVillage;
        _selectedDistrict = _originalDistrict;
        _selectedImage = null;
      }
    });
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });

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
        'village': _selectedVillage,
        'district': _selectedDistrict,
        if (newImageUrl != null) 'profile_image_url': newImageUrl,
      };

      await supabase
          .from('farmers')
          .update(updates)
          .eq('user_id', supabase.auth.currentUser!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // ** THE FIX **: Re-run the future to get fresh data and rebuild the UI
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
            content: Text('Error updating profile: ${error.toString()}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
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
      builder: (context) => AlertDialog(
        title: Text('Logout', style: GoogleFonts.lexend()),
        content: Text('Are you sure you want to logout?',
            style: GoogleFonts.lexend()),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.lexend(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await supabase.auth.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const SplashScreen()),
                  (route) => false,
                );
              }
            },
            child: Text('Logout', style: GoogleFonts.lexend(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Privacy Policy', style: GoogleFonts.lexend()),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Privacy Policy\n\nYour privacy is important to us...\n\n'
              '1. Information We Collect\n'
              '2. How We Use Your Information\n'
              '3. Data Security\n'
              '4. Contact Information\n\n'
              'Last updated: 2025',
              style: GoogleFonts.lexend(fontSize: 14, height: 1.6),
            ),
          ),
        ),
      ),
    );
  }

  void _showContactUs() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact Us',
                style: GoogleFonts.lexend(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.email, color: Colors.green[700]),
              title: Text('support@cropsync.com', style: GoogleFonts.lexend()),
              onTap: () {},
            ),
            ListTile(
              leading: Icon(Icons.phone, color: Colors.green[700]),
              title: Text('+91 9876543210', style: GoogleFonts.lexend()),
              onTap: () {},
            ),
            ListTile(
              leading: Icon(Icons.location_on, color: Colors.green[700]),
              title: Text('Hyderabad, Telangana', style: GoogleFonts.lexend()),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Profile',
            style: GoogleFonts.lexend(
                color: Colors.black87, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.grey[100],
        elevation: 0,
        actions: _buildAppBarActions(),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _farmerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerLoading();
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error loading profile: ${snapshot.error}'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 20),
                  _buildInfoCard(
                    title: 'Personal Information',
                    children: _buildPersonalInfoWidgets(),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoCard(
                    title: 'Support',
                    children: [
                      _buildSettingsTile(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        onTap: _showPrivacyPolicy,
                      ),
                      _buildSettingsTile(
                        icon: Icons.help_outline,
                        title: 'Help & Support',
                        onTap: _showContactUs,
                      ),
                      _buildSettingsTile(
                        icon: Icons.info_outline,
                        title: 'About',
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildLogoutCard(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    if (_isEditMode) {
      return [
        TextButton(
          onPressed: _toggleEditMode,
          child: Text('Cancel',
              style: GoogleFonts.lexend(color: Colors.grey[600])),
        ),
        TextButton(
          onPressed: _isLoading ? null : _updateProfile,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text('Save',
                  style: GoogleFonts.lexend(
                      color: Colors.green[700], fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
      ];
    } else {
      return [
        IconButton(
          onPressed: _toggleEditMode,
          icon: const Icon(Icons.edit_outlined, color: Colors.black87),
        )
      ];
    }
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        _buildProfileImage(),
        if (!_isEditMode) ...[
          const SizedBox(height: 16),
          Text(
            _nameController.text.isEmpty ? 'Your Name' : _nameController.text,
            style: GoogleFonts.lexend(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            supabase.auth.currentUser?.email ?? '',
            style: GoogleFonts.lexend(fontSize: 14, color: Colors.grey[600]),
          ),
        ]
      ],
    );
  }

  List<Widget> _buildPersonalInfoWidgets() {
    if (_isEditMode) {
      return [
        _buildEditableField(
          controller: _nameController,
          label: 'Full Name',
          icon: Icons.person_outline,
        ),
        _buildEditableField(
          controller: _phoneController,
          label: 'Phone Number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        _buildDropdownField(
          value: _selectedDistrict,
          label: 'District',
          icon: Icons.location_city_outlined,
          items: _districts,
          onChanged: (val) => setState(() => _selectedDistrict = val),
        ),
        _buildDropdownField(
          value: _selectedVillage,
          label: 'Village',
          icon: Icons.home_outlined,
          items: _villages,
          onChanged: (val) => setState(() => _selectedVillage = val),
        ),
        _buildEditableField(
          controller: _pincodeController,
          label: 'Pincode',
          icon: Icons.pin_drop_outlined,
          keyboardType: TextInputType.number,
        ),
      ];
    } else {
      return [
        _buildReadOnlyInfoTile(
          icon: Icons.phone_outlined,
          title: 'Phone Number',
          value:
              _phoneController.text.isEmpty ? 'Not set' : _phoneController.text,
        ),
        _buildReadOnlyInfoTile(
          icon: Icons.location_city_outlined,
          title: 'District',
          value: _selectedDistrict ?? 'Not set',
        ),
        _buildReadOnlyInfoTile(
          icon: Icons.home_outlined,
          title: 'Village',
          value: _selectedVillage ?? 'Not set',
        ),
        _buildReadOnlyInfoTile(
          icon: Icons.pin_drop_outlined,
          title: 'Pincode',
          value: _pincodeController.text.isEmpty
              ? 'Not set'
              : _pincodeController.text,
        ),
      ];
    }
  }

  Widget _buildInfoCard(
      {required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: GoogleFonts.lexend(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLogoutCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: Text(
          'Logout',
          style: GoogleFonts.lexend(
            color: Colors.red,
            fontWeight: FontWeight.w500,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: _logout,
      ),
    );
  }

  Widget _buildProfileImage() {
    Widget imageWidget;

    if (_selectedImage != null) {
      imageWidget = ClipOval(
        child: Image.file(
          File(_selectedImage!.path),
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      );
    } else if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      imageWidget = ClipOval(
        child: CachedNetworkImage(
          imageUrl: _profileImageUrl!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 120,
            height: 120,
            color: Colors.grey[200],
            child:
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (context, url, error) => Container(
            width: 120,
            height: 120,
            decoration:
                BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
            child: Icon(Icons.person, size: 60, color: Colors.grey[400]),
          ),
        ),
      );
    } else {
      imageWidget = Container(
        width: 120,
        height: 120,
        decoration:
            BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
        child: Icon(Icons.person, size: 60, color: Colors.grey[400]),
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
                decoration: BoxDecoration(
                  color: Colors.green[700],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child:
                    const Icon(Icons.camera_alt, color: Colors.white, size: 20),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        style: GoogleFonts.lexend(),
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.lexend(color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green[700]!, width: 2),
          ),
        ),
        validator: (value) =>
            value == null || value.isEmpty ? 'Please enter $label' : null,
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        initialValue: value != null && items.contains(value) ? value : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.lexend(color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green[700]!, width: 2),
          ),
        ),
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(item, style: GoogleFonts.lexend()),
                ))
            .toList(),
        onChanged: onChanged,
        validator: (val) => val == null ? 'Please select $label' : null,
      ),
    );
  }

  Widget _buildReadOnlyInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(title,
          style: GoogleFonts.lexend(fontSize: 14, color: Colors.grey[600])),
      subtitle: Text(value,
          style: GoogleFonts.lexend(
              fontSize: 16,
              color: Colors.black87,
              fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(
        title,
        style: GoogleFonts.lexend(
            color: Colors.black87, fontWeight: FontWeight.w400),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            const CircleAvatar(radius: 60),
            const SizedBox(height: 16),
            Container(
                height: 24,
                width: 150,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 8)),
            Container(height: 16, width: 200, color: Colors.white),
            const SizedBox(height: 24),
            Container(
              height: 200,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16)),
            ),
            const SizedBox(height: 20),
            Container(
              height: 150,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16)),
            ),
          ],
        ),
      ),
    );
  }
}
