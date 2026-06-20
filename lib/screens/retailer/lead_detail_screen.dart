import 'package:flutter/material.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/widgets/animated_widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class LeadDetailScreen extends StatefulWidget {
  final Map<String, dynamic> lead;
  final Future<void> Function(dynamic leadId, String status, String notes) onUpdateStatus;

  const LeadDetailScreen({
    super.key,
    required this.lead,
    required this.onUpdateStatus,
  });

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  bool _isLoadingAdvisory = true;
  List<Map<String, dynamic>> _recommendations = [];
  late String _currentStatus;
  late String _currentNotes;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.lead['lead_status'] ?? 'NEW';
    _currentNotes = widget.lead['retailer_notes'] ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _loadAdvisoryData();
      _isInitialized = true;
    }
  }

  Future<void> _loadAdvisoryData() async {
    final problemId = widget.lead['problem_id'];
    if (problemId == null) {
      if (mounted) setState(() => _isLoadingAdvisory = false);
      return;
    }

    try {
      final String langCode = context.locale.languageCode;
      final advisoryData = await ApiService.getAdvisories(problemId, lang: langCode);
      if (advisoryData != null) {
        final advisoryId = advisoryData['id'] as int?;
        if (advisoryId != null) {
          final components = await ApiService.getAdvisoryComponents(advisoryId, lang: langCode);
          if (mounted) {
            setState(() {
              _recommendations = List<Map<String, dynamic>>.from(components);
            });
          }
        }
      }
    } catch (e) {
      // Fail silently
    } finally {
      if (mounted) {
        setState(() => _isLoadingAdvisory = false);
      }
    }
  }

  void _showUpdateBottomSheet() {
    String selectedStatus = _currentStatus;
    final notesController = TextEditingController(text: _currentNotes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final statuses = [
              {
                'status': 'NEW',
                'label': 'NEW',
                'icon': Icons.fiber_new_rounded,
                'color': const Color(0xFF3B82F6),
              },
              {
                'status': 'CONTACTED',
                'label': 'CONTACTED',
                'icon': Icons.phone_in_talk_rounded,
                'color': const Color(0xFFF59E0B),
              },
              {
                'status': 'VISITED',
                'label': 'VISITED',
                'icon': Icons.location_on_rounded,
                'color': const Color(0xFF6366F1),
              },
              {
                'status': 'RESOLVED',
                'label': 'RESOLVED',
                'icon': Icons.check_circle_rounded,
                'color': const Color(0xFF10B981),
              },
              {
                'status': 'CLOSED',
                'label': 'CLOSED',
                'icon': Icons.lock_rounded,
                'color': const Color(0xFF6B7280),
              },
            ];

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                top: 8,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 4, bottom: 16),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        "update_lead_status".tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...statuses.map((s) {
                        final bool isSelected = selectedStatus == s['status'];
                        final Color color = s['color'] as Color;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedStatus = s['status'] as String),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? color.withValues(alpha: 0.08) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? color : const Color(0xFFE2E8F0),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  s['icon'] as IconData,
                                  color: isSelected ? color : const Color(0xFF94A3B8),
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  (s['status'] as String).tr(),
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? color : const Color(0xFF475569),
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: color,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      TextField(
                        controller: notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: "retailer_notes".tr(),
                          alignLabelWithHint: true,
                          hintText: "Enter follow-up comments, recommendations, etc.",
                          fillColor: const Color(0xFFF8FAFC),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                foregroundColor: const Color(0xFF475569),
                              ),
                              child: Text("cancel".tr()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                final oldStatus = _currentStatus;
                                final oldNotes = _currentNotes;
                                
                                setState(() {
                                  _currentStatus = selectedStatus;
                                  _currentNotes = notesController.text;
                                });

                                try {
                                  await widget.onUpdateStatus(
                                    widget.lead['lead_id'],
                                    selectedStatus,
                                    notesController.text,
                                  );
                                } catch (e) {
                                  // Revert status if update fails
                                  setState(() {
                                    _currentStatus = oldStatus;
                                    _currentNotes = oldNotes;
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: Text("save_status".tr()),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> images = [
      widget.lead['image_url1'],
      widget.lead['image_url2'],
      widget.lead['image_url3'],
    ].where((url) => url != null && url.toString().isNotEmpty).map((e) => e.toString()).toList();

    Color statusColor;
    switch (_currentStatus) {
      case 'NEW':
        statusColor = const Color(0xFF3B82F6);
        break;
      case 'CONTACTED':
        statusColor = const Color(0xFFF59E0B);
        break;
      case 'RESOLVED':
        statusColor = const Color(0xFF10B981);
        break;
      default:
        statusColor = const Color(0xFF6B7280);
    }

    final farmerInitial = (widget.lead['farmer_name'] ?? 'F').toString().substring(0, 1).toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          "lead_details".tr(),
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFE2E8F0),
            height: 1,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Premium Farmer Card
                FadeInSlideCard(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: AppTheme.primary,
                              child: Text(
                                farmerInitial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.lead['farmer_name'] ?? 'Farmer',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${widget.lead['village'] ?? ''}, ${widget.lead['mandal'] ?? ''}",
                                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_currentNotes.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF1F5F9)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "retailer_notes".tr(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Colors.grey,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currentNotes,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => url_launcher.launchUrl(Uri.parse("tel:${widget.lead['farmer_phone']}")),
                                icon: const Icon(Icons.phone_rounded, size: 18),
                                label: Text("call_farmer".tr()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Diagnostic Summary Banner Card
                FadeInSlideCard(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.grass_rounded, color: Color(0xFF059669), size: 24),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "diagnosed_crop".tr(),
                                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.lead['crop_name'] ?? 'Crop',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: const Color(0xFFFEE2E2)),
                          ),
                          child: Text(
                            widget.lead['problem_name'] ?? 'Problem Diagnosis',
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Problem Diagnosis Images List
                if (images.isNotEmpty) ...[
                  Text(
                    "reported_incident_photos".tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 240,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: CachedNetworkImage(
                              imageUrl: images[index],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[50],
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[50],
                                child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Recommended Treatments Title
                Text(
                  "scientific_treatment_suggestions".tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 10),
                if (_isLoadingAdvisory)
                  const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()))
                else if (_recommendations.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 36, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          "no_treatment_records_found".tr(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                else
                  ..._recommendations.map((rec) {
                    final type = rec['component_type'] ?? 'Chemical';
                    final isChemical = type.toString().toLowerCase() == 'chemical';
                    
                    String getString(String primaryKey, String fallbackKey1, String fallbackKey2, String defaultVal) {
                      final val = rec[primaryKey]?.toString();
                      if (val != null && val.trim().isNotEmpty) return val;
                      final fb1 = rec[fallbackKey1]?.toString();
                      if (fb1 != null && fb1.trim().isNotEmpty) return fb1;
                      final fb2 = rec[fallbackKey2]?.toString();
                      if (fb2 != null && fb2.trim().isNotEmpty) return fb2;
                      return defaultVal;
                    }

                    final name = getString('component_name', 'component_name_te', 'component_name_en', 'Treatment Suggestion');
                    final dose = getString('dose', 'dose_te', 'dose_en', '');
                    final method = getString('application_method', 'application_method_te', 'application_method_en', '');
                    
                    return FadeInSlideCard(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (isChemical ? const Color(0xFF3B82F6) : const Color(0xFF10B981)).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    type,
                                    style: TextStyle(
                                      color: isChemical ? const Color(0xFF1D4ED8) : const Color(0xFF047857),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (dose.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Icon(Icons.science_outlined, size: 16, color: Color(0xFF64748B)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "${'dose_title'.tr()}: $dose",
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (method.isNotEmpty)
                              Row(
                                children: [
                                  const Icon(Icons.waves_rounded, size: 16, color: Color(0xFF64748B)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "${'method_title'.tr()}: $method",
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),

          // Expert Sticky Bottom Action Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "current_status".tr(),
                          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _currentStatus.tr(),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _showUpdateBottomSheet,
                      icon: const Icon(Icons.edit_note_rounded, size: 20),
                      label: Text("update_status".tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
