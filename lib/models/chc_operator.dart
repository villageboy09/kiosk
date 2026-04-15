/// CHC Operator model representing a row from the chc_operators table
class ChcOperator {
  final String operatorId;
  final String name;
  final String phoneNumber;
  final String? zone;
  final String? rating;
  final String? baseVillage;
  final String? profileImage;
  final String? equipmentType;
  final String? clientCode;

  ChcOperator({
    required this.operatorId,
    required this.name,
    required this.phoneNumber,
    this.zone,
    this.rating,
    this.baseVillage,
    this.profileImage,
    this.equipmentType,
    this.clientCode,
  });

  factory ChcOperator.fromJson(Map<String, dynamic> json) {
    return ChcOperator(
      operatorId: json['operator_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Operator',
      phoneNumber: json['phone_number']?.toString() ?? '',
      zone: json['zone']?.toString(),
      rating: json['rating']?.toString(),
      baseVillage: json['base_village']?.toString(),
      profileImage: json['profile_image']?.toString(),
      equipmentType: json['equipment_type']?.toString(),
      clientCode: json['client_code']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'operator_id': operatorId,
      'name': name,
      'phone_number': phoneNumber,
      'zone': zone,
      'rating': rating,
      'base_village': baseVillage,
      'profile_image': profileImage,
      'equipment_type': equipmentType,
      'client_code': clientCode,
    };
  }

  /// Display name for zone/location badge shown in dashboard top bar
  String get zoneDisplay => zone ?? baseVillage ?? 'Zone N/A';

  /// First letter of name for avatar circle
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : 'O';
}
