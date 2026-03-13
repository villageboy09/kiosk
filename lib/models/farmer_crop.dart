import 'package:easy_localization/easy_localization.dart';

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
    if (diff == 0) return 'today'.tr();
    if (diff == 1) return 'yesterday'.tr();
    if (diff < 7) return '$diff ${'days'.tr()} ${'ago'.tr()}';
    return DateFormat('dd MMM').format(sowingDate);
  }
}
