import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedAdvisory {
  final String id;
  final DateTime createdAt;
  final String? cropName;
  final String problemName;
  final String healthStatus;
  final int confidence;
  final String? imagePath;
  final String summary;
  final String? weatherImpact;
  final List<String> chemicalControls;
  final List<String> biologicalControls;
  final List<String> preventativeControls;
  final List<String> symptoms;
  final List<String> recoveryTips;
  final int? matchedProblemId;

  SavedAdvisory({
    required this.id,
    required this.createdAt,
    this.cropName,
    required this.problemName,
    required this.healthStatus,
    required this.confidence,
    this.imagePath,
    required this.summary,
    this.weatherImpact,
    this.chemicalControls = const [],
    this.biologicalControls = const [],
    this.preventativeControls = const [],
    this.symptoms = const [],
    this.recoveryTips = const [],
    this.matchedProblemId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'cropName': cropName,
        'problemName': problemName,
        'healthStatus': healthStatus,
        'confidence': confidence,
        'imagePath': imagePath,
        'summary': summary,
        'weatherImpact': weatherImpact,
        'chemicalControls': chemicalControls,
        'biologicalControls': biologicalControls,
        'preventativeControls': preventativeControls,
        'symptoms': symptoms,
        'recoveryTips': recoveryTips,
        'matchedProblemId': matchedProblemId,
      };

  factory SavedAdvisory.fromJson(Map<String, dynamic> json) {
    return SavedAdvisory(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      cropName: json['cropName']?.toString(),
      problemName: json['problemName']?.toString() ?? 'Unknown Issue',
      healthStatus: json['healthStatus']?.toString() ?? 'healthy',
      confidence: (json['confidence'] as num?)?.toInt() ?? 88,
      imagePath: json['imagePath']?.toString(),
      summary: json['summary']?.toString() ?? '',
      weatherImpact: json['weatherImpact']?.toString(),
      chemicalControls: json['chemicalControls'] is List
          ? List<String>.from(json['chemicalControls'])
          : const [],
      biologicalControls: json['biologicalControls'] is List
          ? List<String>.from(json['biologicalControls'])
          : const [],
      preventativeControls: json['preventativeControls'] is List
          ? List<String>.from(json['preventativeControls'])
          : const [],
      symptoms: json['symptoms'] is List
          ? List<String>.from(json['symptoms'])
          : const [],
      recoveryTips: json['recoveryTips'] is List
          ? List<String>.from(json['recoveryTips'])
          : const [],
      matchedProblemId: json['matchedProblemId'] != null
          ? int.tryParse(json['matchedProblemId'].toString())
          : null,
    );
  }
}

class SavedAdvisoriesService {
  static const String _storageKey = 'cropsync_saved_plant_advisories_v1';

  /// Fetch all saved advisories, sorted by newest first
  static Future<List<SavedAdvisory>> getSavedAdvisories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_storageKey) ?? [];
      final List<SavedAdvisory> results = [];

      for (final raw in rawList) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          results.add(SavedAdvisory.fromJson(map));
        } catch (e) {
          debugPrint("Error parsing saved advisory: $e");
        }
      }

      // Sort newest first
      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return results;
    } catch (e) {
      debugPrint("Error reading saved advisories: $e");
      return [];
    }
  }

  /// Save a new plant doctor advisory. Copies source image to permanent directory.
  static Future<SavedAdvisory> saveAdvisory({
    String? cropName,
    required String problemName,
    required String healthStatus,
    required int confidence,
    String? sourceImagePath,
    required String summary,
    String? weatherImpact,
    List<String> chemicalControls = const [],
    List<String> biologicalControls = const [],
    List<String> preventativeControls = const [],
    List<String> symptoms = const [],
    List<String> recoveryTips = const [],
    int? matchedProblemId,
  }) async {
    String? permanentImagePath = sourceImagePath;

    // Archive image permanently if available
    if (sourceImagePath != null && sourceImagePath.isNotEmpty) {
      try {
        final srcFile = File(sourceImagePath);
        if (await srcFile.exists()) {
          final appDocDir = await getApplicationDocumentsDirectory();
          final saveDir = Directory('${appDocDir.path}/saved_plant_advisories');
          if (!await saveDir.exists()) {
            await saveDir.create(recursive: true);
          }
          final ext = sourceImagePath.contains('.')
              ? sourceImagePath.substring(sourceImagePath.lastIndexOf('.'))
              : '.jpg';
          final targetPath =
              '${saveDir.path}/advisory_${DateTime.now().millisecondsSinceEpoch}$ext';
          final savedFile = await srcFile.copy(targetPath);
          permanentImagePath = savedFile.path;
        }
      } catch (e) {
        debugPrint("Error archiving advisory image: $e");
      }
    }

    final advisory = SavedAdvisory(
      id: 'adv_${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
      cropName: cropName,
      problemName: problemName,
      healthStatus: healthStatus,
      confidence: confidence,
      imagePath: permanentImagePath,
      summary: summary,
      weatherImpact: weatherImpact,
      chemicalControls: chemicalControls,
      biologicalControls: biologicalControls,
      preventativeControls: preventativeControls,
      symptoms: symptoms,
      recoveryTips: recoveryTips,
      matchedProblemId: matchedProblemId,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_storageKey) ?? [];
      rawList.insert(0, jsonEncode(advisory.toJson()));
      await prefs.setStringList(_storageKey, rawList);
    } catch (e) {
      debugPrint("Error storing saved advisory: $e");
    }

    return advisory;
  }

  /// Check if a problem is already saved
  static Future<bool> isAdvisorySaved(String problemName, {String? cropName}) async {
    final list = await getSavedAdvisories();
    return list.any((item) =>
        item.problemName.trim().toLowerCase() == problemName.trim().toLowerCase() &&
        (cropName == null ||
            item.cropName?.trim().toLowerCase() == cropName.trim().toLowerCase()));
  }

  /// Delete a saved advisory by ID
  static Future<bool> deleteAdvisory(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_storageKey) ?? [];
      final updated = <String>[];

      for (final raw in rawList) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          if (map['id']?.toString() == id) {
            // Also attempt to delete archived image file if exists
            final img = map['imagePath']?.toString();
            if (img != null && img.contains('saved_plant_advisories')) {
              final f = File(img);
              if (await f.exists()) {
                await f.delete();
              }
            }
            continue;
          }
          updated.add(raw);
        } catch (_) {
          updated.add(raw);
        }
      }

      return await prefs.setStringList(_storageKey, updated);
    } catch (e) {
      debugPrint("Error deleting saved advisory: $e");
      return false;
    }
  }
}
