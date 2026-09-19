import 'dart:io';
import 'package:cropsync/screens/plant_doctor_screen.dart';
import 'package:cropsync/services/saved_advisories_service.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

class SavedAdvisoriesScreen extends StatefulWidget {
  const SavedAdvisoriesScreen({super.key});

  @override
  State<SavedAdvisoriesScreen> createState() => _SavedAdvisoriesScreenState();
}

class _SavedAdvisoriesScreenState extends State<SavedAdvisoriesScreen> {
  List<SavedAdvisory> _advisories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    setState(() => _isLoading = true);
    final list = await SavedAdvisoriesService.getSavedAdvisories();
    if (mounted) {
      setState(() {
        _advisories = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAdvisory(SavedAdvisory item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'diag_delete_confirm'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('diag_cancel'.tr(), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('diag_delete'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      HapticFeedback.mediumImpact();
      await SavedAdvisoriesService.deleteAdvisory(item.id);
      _loadSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('diag_saved_removed'.tr()),
            backgroundColor: const Color(0xFF334155),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _shareAdvisory(SavedAdvisory item) {
    HapticFeedback.selectionClick();
    final buffer = StringBuffer();
    buffer.writeln("🌿 CropSync Plant Doctor Advisory");
    if (item.cropName != null && item.cropName!.isNotEmpty) {
      buffer.writeln("🌾 Crop: ${item.cropName}");
    }
    buffer.writeln("⚠️ Issue: ${item.problemName} (${item.confidence}% Match)");
    if (item.summary.isNotEmpty) {
      buffer.writeln("\n📋 Diagnosis:\n${item.summary}");
    }
    if (item.chemicalControls.isNotEmpty) {
      buffer.writeln("\n🧪 Chemical Sprays (Per Acre):");
      for (final s in item.chemicalControls) {
        buffer.writeln("• $s");
      }
    }
    if (item.biologicalControls.isNotEmpty) {
      buffer.writeln("\n🌱 Biological & Organic Remedy:");
      for (final b in item.biologicalControls) {
        buffer.writeln("• $b");
      }
    }
    if (item.weatherImpact != null && item.weatherImpact!.trim().isNotEmpty) {
      buffer.writeln("\n🌦️ Weather Spray Advice:\n${item.weatherImpact}");
    }
    buffer.writeln("\n📲 Diagnosed via CropSync App • Smart Farming Partner");

    final text = buffer.toString();
    if (item.imagePath != null && File(item.imagePath!).existsSync()) {
      SharePlus.instance.share(
        ShareParams(
          files: [XFile(item.imagePath!)],
          text: text,
          subject: "CropSync: ${item.problemName}",
        ),
      );
    } else {
      SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: "CropSync: ${item.problemName}",
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'healthy':
        return const Color(0xFF16A34A);
      case 'diseased':
        return const Color(0xFFDC2626);
      case 'deficiency':
        return const Color(0xFFD97706);
      case 'pest_infestation':
        return const Color(0xFFEA580C);
      case 'physical_damage':
        return const Color(0xFF475569);
      default:
        return const Color(0xFF16A34A);
    }
  }

  String _getStatusKey(String status) {
    switch (status.toLowerCase()) {
      case 'healthy':
        return 'diag_status_healthy';
      case 'diseased':
        return 'diag_status_diseased';
      case 'deficiency':
        return 'diag_status_deficiency';
      case 'pest_infestation':
        return 'diag_status_pest';
      case 'physical_damage':
        return 'diag_status_physical';
      default:
        return 'diag_status_healthy';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('diag_saved_advisories'.tr(), style: AppTheme.appBarTitle),
        backgroundColor: Colors.white,
        leading: AppTheme.backButton(context, color: AppTheme.appBarText),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _advisories.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _loadSaved,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: _advisories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _advisories[index];
                      return _buildAdvisoryCard(item);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Icon(
                Icons.bookmark_outline_rounded,
                size: 44,
                color: Color(0xFF16A34A),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'diag_no_saved'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'diag_no_saved_desc'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PlantDoctorScreen(initialSource: ImageSource.camera),
                  ),
                );
              },
              icon: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
              label: Text(
                'diag_sheet_camera'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvisoryCard(SavedAdvisory item) {
    final statusColor = _getStatusColor(item.healthStatus);
    final statusText = _getStatusKey(item.healthStatus).tr();
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(item.createdAt);
    final hasImage = item.imagePath != null && File(item.imagePath!).existsSync();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          // Open diagnosis in PlantAnalysisScreen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlantDoctorScreen(
                imagePath: item.imagePath,
                preloadedResult: {
                  'is_plant': true,
                  'health_status': item.healthStatus,
                  'detected_crop_name': item.cropName,
                  'matched_problem_name': item.problemName,
                  'confidence': item.confidence / 100.0,
                  'ai_analysis': item.summary,
                  'weather_impact': item.weatherImpact,
                  'ai_control_measures': {
                    'chemical': item.chemicalControls,
                    'biological': item.biologicalControls,
                    'preventative': item.preventativeControls,
                  },
                  'observed_symptoms': item.symptoms,
                  'recovery_recommendations': item.recoveryTips,
                  'matched_problem_id': item.matchedProblemId,
                },
              ),
            ),
          ).then((_) => _loadSaved());
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Thumbnail or placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 76,
                  height: 76,
                  color: const Color(0xFFF1F5F9),
                  child: hasImage
                      ? Image.file(
                          File(item.imagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.eco_rounded,
                            color: Color(0xFF16A34A),
                            size: 32,
                          ),
                        )
                      : const Icon(
                          Icons.eco_rounded,
                          color: Color(0xFF16A34A),
                          size: 32,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "${item.confidence}% Match",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.problemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (item.cropName != null && item.cropName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.cropName!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D9488),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 11, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        // Quick Action Buttons
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.share_rounded, size: 18, color: Color(0xFF16A34A)),
                          onPressed: () => _shareAdvisory(item),
                          tooltip: 'diag_share'.tr(),
                        ),
                        const SizedBox(width: 14),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(Icons.delete_outline_rounded,
                              size: 18, color: Colors.red.shade400),
                          onPressed: () => _deleteAdvisory(item),
                          tooltip: 'diag_delete'.tr(),
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
}
