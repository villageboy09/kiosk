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
  final String type;
  final String name;
  final String? dose;
  final String? method;
  final String? notes;

  AdvisoryRecommendation({
    required this.type,
    required this.name,
    this.dose,
    this.method,
    this.notes,
  });
}
