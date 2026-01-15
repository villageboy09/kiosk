class CropProblem {
  final int id;
  final String name;
  final String? category; // 'Fungal Disease', 'Insect Pest', 'Nutrient Deficiency', etc.
  final String? imageUrl1;
  final String? imageUrl2;
  final String? imageUrl3;

  CropProblem({
    required this.id,
    required this.name,
    this.category,
    this.imageUrl1,
    this.imageUrl2,
    this.imageUrl3,
  });

  factory CropProblem.fromJson(Map<String, dynamic> json) {
    return CropProblem(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Unknown',
      category: json['category'] as String?,
      imageUrl1: json['image_url1'] as String?,
      imageUrl2: json['image_url2'] as String?,
      imageUrl3: json['image_url3'] as String?,
    );
  }
}
