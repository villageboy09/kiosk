/// User model class representing a farmer/user/creator/retailer/officer from MySQL backend
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
  final String? role;

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
    this.role,
  });

  /// Create a User from JSON response
  factory User.fromJson(Map<String, dynamic> json) {
    final rawRole = json['role']?.toString().toLowerCase().trim();
    final rawMembership = json['membership_type']?.toString();

    // Determine normalized role & membershipType
    String resolvedRole = rawRole ?? 'farmer';
    String resolvedMembership = rawMembership ?? 'Farmer';

    if (resolvedRole == 'content_creator' || resolvedRole == 'creator' ||
        rawMembership?.toLowerCase() == 'creator' || rawMembership?.toLowerCase() == 'content creator') {
      resolvedRole = 'content_creator';
      resolvedMembership = 'Creator';
    } else if (resolvedRole == 'retailer' || rawMembership?.toLowerCase() == 'retailer') {
      resolvedRole = 'retailer';
      resolvedMembership = 'Retailer';
    } else if (resolvedRole == 'officer' || rawMembership?.toLowerCase() == 'officer') {
      resolvedRole = 'officer';
      resolvedMembership = 'Officer';
    } else if (resolvedRole == 'chc_operator' || rawMembership?.toLowerCase() == 'chc operator') {
      resolvedRole = 'chc_operator';
      resolvedMembership = 'CHC Operator';
    }

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
      membershipType: resolvedMembership,
      role: resolvedRole,
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
      'role': role,
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
    String? role,
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
      role: role ?? this.role,
    );
  }

  /// Returns true if user has a creator/content creator role
  bool get isCreator {
    final r = (role ?? '').toLowerCase().trim();
    final type = (membershipType ?? '').toLowerCase().trim();
    return r == 'content_creator' || r == 'creator' || type == 'creator' || type == 'content creator';
  }

  /// Returns true if user has a retailer role
  bool get isRetailer {
    final r = (role ?? '').toLowerCase().trim();
    final type = (membershipType ?? '').toLowerCase().trim();
    return r == 'retailer' || type == 'retailer';
  }

  /// Returns true if user has an extension officer role
  bool get isOfficer {
    final r = (role ?? '').toLowerCase().trim();
    final type = (membershipType ?? '').toLowerCase().trim();
    return r == 'officer' || type == 'officer';
  }

  /// Returns true if user is a CHC operator
  bool get isOperator {
    final r = (role ?? '').toLowerCase().trim();
    final type = (membershipType ?? '').toLowerCase().trim();
    return r == 'chc_operator' || type == 'chc operator';
  }

  /// Returns true if user is a standard farmer
  bool get isFarmer => !isCreator && !isRetailer && !isOfficer && !isOperator;
}
