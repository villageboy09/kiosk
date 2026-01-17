/// User model class representing a farmer/user from the MySQL database
class User {
  final String userId;
  final String name;
  final String? phoneNumber;
  final String? district;
  final String? village;
  final String? mandal;
  final String? region;
  final String? clientCode;
  final String? cardUid;
  final String? profileImageUrl;
  final String? membershipType;

  User({
    required this.userId,
    required this.name,
    this.phoneNumber,
    this.district,
    this.village,
    this.mandal,
    this.region,
    this.clientCode,
    this.cardUid,
    this.profileImageUrl,
    this.membershipType,
  });

  /// Create a User from JSON response
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      phoneNumber: json['phone_number']?.toString(),
      district: json['district']?.toString(),
      village: json['village']?.toString(),
      mandal: json['mandal']?.toString(),
      region: json['region']?.toString(),
      clientCode: json['client_code']?.toString(),
      cardUid: json['card_uid']?.toString(),
      profileImageUrl: json['profile_image_url']?.toString(),
      membershipType: json['membership_type']?.toString(),
    );
  }

  /// Convert User to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'phone_number': phoneNumber,
      'district': district,
      'village': village,
      'mandal': mandal,
      'region': region,
      'client_code': clientCode,
      'card_uid': cardUid,
      'profile_image_url': profileImageUrl,
      'membership_type': membershipType,
    };
  }

  /// Create a copy of User with updated fields
  User copyWith({
    String? userId,
    String? name,
    String? phoneNumber,
    String? district,
    String? village,
    String? mandal,
    String? region,
    String? clientCode,
    String? cardUid,
    String? profileImageUrl,
    String? membershipType,
  }) {
    return User(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      district: district ?? this.district,
      village: village ?? this.village,
      mandal: mandal ?? this.mandal,
      region: region ?? this.region,
      clientCode: clientCode ?? this.clientCode,
      cardUid: cardUid ?? this.cardUid,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      membershipType: membershipType ?? this.membershipType,
    );
  }
}
