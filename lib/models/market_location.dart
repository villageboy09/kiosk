enum MarketLocationSource { gps, profile, manual, cached }

enum MarketLocationFailure {
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  timeout,
  geocodeFailed,
  unsupported,
}

class MarketLocation {
  final String state;
  final String district;
  final double? lat;
  final double? lng;
  final MarketLocationSource source;

  const MarketLocation({
    required this.state,
    required this.district,
    this.lat,
    this.lng,
    required this.source,
  });

  /// False when only a district is known (e.g. profile without state); the
  /// UI must ask the user to pick a state.
  bool get hasState => state.isNotEmpty;

  MarketLocation copyWith({
    String? state,
    String? district,
    MarketLocationSource? source,
  }) =>
      MarketLocation(
        state: state ?? this.state,
        district: district ?? this.district,
        lat: lat,
        lng: lng,
        source: source ?? this.source,
      );

  @override
  String toString() => 'MarketLocation($district, $state, ${source.name})';
}

class MarketLocationResult {
  final MarketLocation? location;
  final MarketLocationFailure? failure;

  const MarketLocationResult({this.location, this.failure});

  bool get ok => location != null;
}
