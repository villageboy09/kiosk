import 'package:cropsync/utils/safe_parser.dart';

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
      id: SafeParser.toInt(json['id']),
      name: SafeParser.toStringVal(json['name'], 'Unknown'),
      category: json['category']?.toString(),
      imageUrl1: json['image_url1']?.toString(),
      imageUrl2: json['image_url2']?.toString(),
      imageUrl3: json['image_url3']?.toString(),
    );
  }
}
