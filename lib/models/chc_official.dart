class ChcOfficial {
  final int adminId;
  final String email;
  final String role;
  final String region;
  final List<String> allowedClientCodes;
  final String currentClientCode;

  const ChcOfficial({
    required this.adminId,
    required this.email,
    required this.role,
    required this.region,
    required this.allowedClientCodes,
    required this.currentClientCode,
  });

  factory ChcOfficial.fromJson(Map<String, dynamic> json) {
    final rawCodes = json['allowed_client_codes'];
    List<String> codes = ['ALL'];
    if (rawCodes is List) {
      codes = rawCodes.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      if (!codes.contains('ALL')) {
        codes.insert(0, 'ALL');
      }
    }

    return ChcOfficial(
      adminId: json['admin_id'] is int ? json['admin_id'] as int : int.tryParse(json['admin_id']?.toString() ?? '0') ?? 0,
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'official',
      region: json['region']?.toString() ?? '',
      allowedClientCodes: codes,
      currentClientCode: json['current_client_code']?.toString() ?? (codes.isNotEmpty ? codes[0] : 'ALL'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'admin_id': adminId,
      'email': email,
      'role': role,
      'region': region,
      'allowed_client_codes': allowedClientCodes,
      'current_client_code': currentClientCode,
    };
  }

  ChcOfficial copyWith({
    int? adminId,
    String? email,
    String? role,
    String? region,
    List<String>? allowedClientCodes,
    String? currentClientCode,
  }) {
    return ChcOfficial(
      adminId: adminId ?? this.adminId,
      email: email ?? this.email,
      role: role ?? this.role,
      region: region ?? this.region,
      allowedClientCodes: allowedClientCodes ?? this.allowedClientCodes,
      currentClientCode: currentClientCode ?? this.currentClientCode,
    );
  }
}
