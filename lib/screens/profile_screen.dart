import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/main.dart';
import 'package:cropsync/welcome_screen.dart';
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

  // Controllers for editable fields
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pincodeController = TextEditingController();
  String? _selectedVillage;
  String? _selectedDistrict;
  XFile? _selectedImage;
  String? _profileImageUrl;

  // Dummy data for dropdowns - in a real app, this would come from your database
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

    // Populate the controllers with existing data
    _nameController.text = data['full_name'] ?? '';
    _phoneController.text = data['phone_number'] ?? '';
    _pincodeController.text = data['pincode'] ?? '';
    _selectedVillage = data['village'];
    _selectedDistrict = data['district'];
    _profileImageUrl = data['profile_image_url'];

    return data;
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
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
      // 1. Upload new image if one was selected
      if (_selectedImage != null) {
        final imageFile = File(_selectedImage!.path);
        final imageExtension =
            _selectedImage!.path.split('.').last.toLowerCase();
        final userId = supabase.auth.currentUser!.id;
        // CORRECTED: The path now includes the 'profile' folder.
        final imagePath = 'profile/$userId/profile.$imageExtension';

        await supabase.storage.from('farmer_profile').upload(
              imagePath,
              imageFile,
              fileOptions:
                  const FileOptions(cacheControl: '3600', upsert: true),
            );
        newImageUrl =
            supabase.storage.from('farmer_profile').getPublicUrl(imagePath);
      }

      // 2. Update the farmer's record in the database
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
          const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green),
        );
        setState(() {
          if (newImageUrl != null) {
            _profileImageUrl = newImageUrl;
            _selectedImage = null; // Clear selection after upload
          }
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error updating profile: ${error.toString()}'),
              backgroundColor: Colors.redAccent),
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
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const SplashScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile', style: GoogleFonts.lexend()),
        backgroundColor: Colors.white,
        elevation: 1,
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

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                  maxWidth: 600), // For responsiveness on large screens
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildProfileImagePicker(),
                      const SizedBox(height: 32),
                      _buildTextFormField(
                          _nameController, 'Full Name', Icons.person),
                      const SizedBox(height: 16),
                      _buildTextFormField(
                          _phoneController, 'Phone Number', Icons.phone),
                      const SizedBox(height: 16),
                      _buildDropdown(_districts, 'District',
                          (val) => setState(() => _selectedDistrict = val)),
                      const SizedBox(height: 16),
                      _buildDropdown(_villages, 'Village',
                          (val) => setState(() => _selectedVillage = val)),
                      const SizedBox(height: 16),
                      _buildTextFormField(
                          _pincodeController, 'Pincode', Icons.pin_drop),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _updateProfile,
                          icon: _isLoading
                              ? Container()
                              : const Icon(Icons.save, color: Colors.white),
                          label: _isLoading
                              ? const CircularProgressIndicator(
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white))
                              : Text('Update Profile',
                                  style: GoogleFonts.lexend(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, color: Colors.redAccent),
                        label: Text('Logout',
                            style: GoogleFonts.lexend(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Builder Widgets ---

  Widget _buildProfileImagePicker() {
    ImageProvider? backgroundImage;
    if (_selectedImage != null) {
      backgroundImage = FileImage(File(_selectedImage!.path));
    } else if (_profileImageUrl != null) {
      backgroundImage = CachedNetworkImageProvider(_profileImageUrl!);
    }

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.grey[200],
          backgroundImage: backgroundImage,
          child: (backgroundImage == null)
              ? Icon(Icons.person, size: 60, color: Colors.grey[400])
              : null,
        ),
        IconButton(
          onPressed: _pickImage,
          icon: const Icon(Icons.camera_alt),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            shape: const CircleBorder(
                side: BorderSide(color: Colors.grey, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _buildTextFormField(
      TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) =>
          value == null || value.isEmpty ? 'Please enter a $label' : null,
    );
  }

  Widget _buildDropdown(
      List<String> items, String hint, ValueChanged<String?> onChanged) {
    String? initialValue =
        hint == 'District' ? _selectedDistrict : _selectedVillage;
    return DropdownButtonFormField<String>(
      initialValue: items.contains(initialValue) ? initialValue : null,
      decoration: InputDecoration(
        labelText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Please select a $hint' : null,
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircleAvatar(radius: 60),
            const SizedBox(height: 32),
            Container(height: 50, width: double.infinity, color: Colors.white),
            const SizedBox(height: 16),
            Container(height: 50, width: double.infinity, color: Colors.white),
            const SizedBox(height: 16),
            Container(height: 50, width: double.infinity, color: Colors.white),
            const SizedBox(height: 16),
            Container(height: 50, width: double.infinity, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
