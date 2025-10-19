class CropProblem {
  final int id;
  final String name;
  final String? imageUrl1;
  final String? imageUrl2;
  final String? imageUrl3;

  CropProblem({
    required this.id,
    required this.name,
    this.imageUrl1,
    this.imageUrl2,
    this.imageUrl3,
  });
}
