class Advisory {
  final String title;
  final String symptoms;
  final String? notes;
  final List<AdvisoryRecommendation> recommendations;

  Advisory({
    required this.title,
    required this.symptoms,
    this.notes,
    required this.recommendations,
  });
}

class AdvisoryRecommendation {
  final String type; // 'Chemical' or 'Biological'
  final String name; // Component name
  final String? altName; // Alternative/brand name
  final String? dose;
  final String? method;
  final String? notes;
  final String? stageScope; // 'All Stages', 'Nursery', 'Vegetative', etc.
  final String? imageUrl;

  AdvisoryRecommendation({
    required this.type,
    required this.name,
    this.altName,
    this.dose,
    this.method,
    this.notes,
    this.stageScope,
    this.imageUrl,
  });

  factory AdvisoryRecommendation.fromJson(Map<String, dynamic> json) {
    return AdvisoryRecommendation(
      type: json['component_type']?.toString() ?? 'General',
      name: json['component_name']?.toString() ?? 'N/A',
      altName: json['alt_component_name']?.toString(),
      dose: json['dose']?.toString(),
      method: json['application_method']?.toString(),
      notes: json['notes']?.toString(),
      stageScope: json['stage_scope']?.toString(),
      imageUrl: json['image_url']?.toString(),
    );
  }
}
