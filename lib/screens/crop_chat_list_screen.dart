// lib/screens/crop_chat_list_screen.dart
// WhatsApp-style crop advisory list

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'crop_conversation_screen.dart';

// ============================================================================
// DESIGN SYSTEM
// ============================================================================
class ChatTheme {
  // WhatsApp-inspired colors
  static const primary = Color(0xFF075E54);
  static const primaryLight = Color(0xFF128C7E);
  static const accent = Color(0xFF25D366);
  static const bg = Color(0xFFECE5DD);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF111B21);
  static const textSecondary = Color(0xFF667781);
  static const unreadBadge = Color(0xFF25D366);
  static const online = Color(0xFF25D366);

  // Spacing
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;

  // Radius
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
}

// ============================================================================
// FARMER CROP MODEL
// ============================================================================
class FarmerCrop {
  final int id;
  final String fieldName;
  final String cropName;
  final String? cropImageUrl;
  final int cropId;
  final int varietyId;
  final DateTime sowingDate;
  final int? currentStageId;
  final String? currentStageName;
  final int problemCount;

  FarmerCrop({
    required this.id,
    required this.fieldName,
    required this.cropName,
    this.cropImageUrl,
    required this.cropId,
    required this.varietyId,
    required this.sowingDate,
    this.currentStageId,
    this.currentStageName,
    this.problemCount = 0,
  });

  int get daysSinceSowing => DateTime.now().difference(sowingDate).inDays;

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(sowingDate).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'yesterday';
    if (diff < 7) return '$diff days ago';
    return DateFormat('dd MMM').format(sowingDate);
  }
}

// ============================================================================
// MAIN SCREEN
// ============================================================================
class CropChatListScreen extends StatefulWidget {
  const CropChatListScreen({super.key});

  @override
  State<CropChatListScreen> createState() => _CropChatListScreenState();
}

class _CropChatListScreenState extends State<CropChatListScreen> {
  bool _isLoading = true;
  List<FarmerCrop> _crops = [];
  String? _errorMessage;
  bool _hasLoadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load crops here instead of initState because context.locale
    // is not available until after initState completes
    if (!_hasLoadedOnce) {
      _hasLoadedOnce = true;
      _loadCrops();
    }
  }

  String _getLocale() {
    final code = context.locale.languageCode;
    return code == 'te'
        ? 'te'
        : code == 'hi'
            ? 'hi'
            : 'en';
  }

  Future<void> _loadCrops() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        setState(() {
          _errorMessage = 'Please login to view your crops';
          _isLoading = false;
        });
        return;
      }

      final locale = _getLocale();
      final selectionsData = await ApiService.getUserSelections(
        currentUser.userId,
        lang: locale,
      );

      final List<FarmerCrop> loadedCrops = [];

      for (final s in selectionsData) {
        final cropId = int.tryParse(s['crop_id'].toString()) ?? 1;
        final varietyId = int.tryParse(s['variety_id'].toString()) ?? 1;
        final sowingDate =
            DateTime.tryParse(s['sowing_date'].toString()) ?? DateTime.now();
        final daysSinceSowing = DateTime.now().difference(sowingDate).inDays;

        // Get current stage based on sowing date
        int? currentStageId;
        String? currentStageName;
        int problemCount = 0;

        try {
          final durations =
              await ApiService.getStageDuration(cropId, varietyId: varietyId);
          for (var d in durations) {
            final start = d['start_day_from_sowing'] as int? ?? 0;
            final end = d['end_day_from_sowing'] as int? ?? 999;
            if (daysSinceSowing >= start && daysSinceSowing <= end) {
              currentStageId = d['stage_id'] as int?;
              break;
            }
          }

          // Get stage name and problem count
          if (currentStageId != null) {
            final stages = await ApiService.getCropStages(cropId, lang: locale);
            for (var stage in stages) {
              if (stage['id'] == currentStageId) {
                currentStageName = stage['name'] as String?;
                break;
              }
            }
            final problems = await ApiService.getProblems(
              cropId: cropId,
              stageId: currentStageId,
              lang: locale,
            );
            problemCount = problems.length;
          }
        } catch (e) {
          // Silent error handling for production
        }

        loadedCrops.add(FarmerCrop(
          id: int.tryParse(s['selection_id'].toString()) ?? 0,
          fieldName: s['field_name']?.toString() ?? 'Field',
          cropName: s['crop_name']?.toString() ?? 'Crop',
          cropImageUrl: s['crop_image_url']?.toString(),
          cropId: cropId,
          varietyId: varietyId,
          sowingDate: sowingDate,
          currentStageId: currentStageId,
          currentStageName: currentStageName,
          problemCount: problemCount,
        ));
      }

      if (mounted) {
        setState(() {
          _crops = loadedCrops;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load crops: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _openConversation(FarmerCrop crop) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CropConversationScreen(crop: crop),
      ),
    ).then((_) => _loadCrops()); // Refresh on return
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatTheme.bg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                    ? _buildErrorState()
                    : _crops.isEmpty
                        ? _buildEmptyState()
                        : _buildCropList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        ChatTheme.spacingMd,
        MediaQuery.of(context).padding.top + ChatTheme.spacingMd,
        ChatTheme.spacingMd,
        ChatTheme.spacingMd,
      ),
      decoration: const BoxDecoration(
        color: ChatTheme.primary,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('home_feature_advisory_title'),
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  context.tr('advisories_title'),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadCrops,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(0),
      itemCount: 4,
      itemBuilder: (_, i) => _CropChatTileSkeleton(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ChatTheme.spacingLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: ChatTheme.spacingMd),
            Text(
              _errorMessage!,
              style: GoogleFonts.poppins(color: ChatTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ChatTheme.spacingMd),
            ElevatedButton.icon(
              onPressed: _loadCrops,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ChatTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ChatTheme.spacingLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grass_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: ChatTheme.spacingMd),
            Text(
              context.tr('no_fields_yet'),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: ChatTheme.text,
              ),
            ),
            const SizedBox(height: ChatTheme.spacingSm),
            Text(
              context.tr('add_first_crop'),
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: ChatTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropList() {
    return RefreshIndicator(
      onRefresh: _loadCrops,
      color: ChatTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 0),
        itemCount: _crops.length,
        itemBuilder: (ctx, i) => RepaintBoundary(
          child: _CropChatTile(
            crop: _crops[i],
            onTap: () => _openConversation(_crops[i]),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CROP CHAT TILE (WhatsApp conversation item)
// ============================================================================
class _CropChatTile extends StatelessWidget {
  final FarmerCrop crop;
  final VoidCallback onTap;

  const _CropChatTile({required this.crop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ChatTheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ChatTheme.spacingMd,
            vertical: ChatTheme.spacingSm + 4,
          ),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFE9E9E9), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              // Crop image (circular like WhatsApp)
              _buildCropAvatar(),
              const SizedBox(width: ChatTheme.spacingMd),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: crop name + time
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            crop.cropName,
                            style: GoogleFonts.notoSansTelugu(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: ChatTheme.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          crop.formattedDate,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: crop.problemCount > 0
                                ? ChatTheme.accent
                                : ChatTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Bottom row: field + stage + badge
                    Row(
                      children: [
                        // Field and stage info
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 14, color: ChatTheme.textSecondary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  crop.fieldName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: ChatTheme.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (crop.currentStageName != null) ...[
                                const Text(' • ',
                                    style: TextStyle(
                                        color: ChatTheme.textSecondary)),
                                Flexible(
                                  child: Text(
                                    crop.currentStageName!,
                                    style: GoogleFonts.notoSansTelugu(
                                      fontSize: 12,
                                      color: ChatTheme.primaryLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Problem count badge
                        if (crop.problemCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: ChatTheme.unreadBadge,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              crop.problemCount.toString(),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCropAvatar() {
    final hasImage = crop.cropImageUrl != null &&
        crop.cropImageUrl!.isNotEmpty &&
        crop.cropImageUrl!.startsWith('http');

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: crop.problemCount > 0
              ? ChatTheme.accent
              : ChatTheme.primary.withValues(alpha: 0.3),
          width: crop.problemCount > 0 ? 2 : 1,
        ),
      ),
      child: ClipOval(
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: crop.cropImageUrl!,
                fit: BoxFit.cover,
                memCacheHeight: 112, // Optimized for 56px * 2
                placeholder: (_, __) => Container(
                  color: Colors.grey[100],
                  child: Icon(Icons.grass, color: Colors.grey[400]),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey[100],
                  child: Icon(Icons.grass, color: Colors.grey[400]),
                ),
              )
            : Container(
                color: ChatTheme.primary.withValues(alpha: 0.1),
                child:
                    const Icon(Icons.grass, color: ChatTheme.primary, size: 28),
              ),
      ),
    );
  }
}

// ============================================================================
// SKELETON LOADING
// ============================================================================
class _CropChatTileSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ChatTheme.spacingMd,
        vertical: ChatTheme.spacingMd,
      ),
      color: ChatTheme.surface,
      child: Row(
        children: [
          // Avatar skeleton
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: ChatTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 180,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
