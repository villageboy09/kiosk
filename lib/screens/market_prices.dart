// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';

// 💡 PRO-TIP: How to get the slide-back animation
// To achieve the slide-back gesture you wanted, you need to use
// CupertinoPageRoute when you navigate TO this screen. It's a simple change
// where you call your navigator.
//
// For example, change this:
// Navigator.push(context, MaterialPageRoute(builder: (context) => const MarketPricesScreen()));
//
// To this:
// import 'package:flutter/cupertino.dart'; // Make sure to import this
// Navigator.push(context, CupertinoPageRoute(builder: (context) => const MarketPricesScreen()));

class MarketPrice {
  final String state;
  final String district;
  final String market;
  final String commodity;
  final String variety;
  final String grade;
  final String arrivalDate;
  final String minPrice;
  final String maxPrice;
  final String modalPrice;

  MarketPrice({
    required this.state,
    required this.district,
    required this.market,
    required this.commodity,
    required this.variety,
    required this.grade,
    required this.arrivalDate,
    required this.minPrice,
    required this.maxPrice,
    required this.modalPrice,
  });

  factory MarketPrice.fromJson(Map<String, dynamic> json) {
    return MarketPrice(
      state: json['state']?.toString() ?? 'N/A',
      district: json['district']?.toString() ?? 'N/A',
      market: json['market']?.toString() ?? 'N/A',
      commodity: json['commodity']?.toString() ?? 'N/A',
      variety: json['variety']?.toString() ?? 'Other',
      grade: json['grade']?.toString() ?? 'N/A',
      arrivalDate: json['arrival_date']?.toString() ?? 'N/A',
      minPrice: json['min_price']?.toString() ?? '0',
      maxPrice: json['max_price']?.toString() ?? '0',
      modalPrice: json['modal_price']?.toString() ?? '0',
    );
  }
}

class MarketPricesScreen extends StatefulWidget {
  const MarketPricesScreen({super.key});

  @override
  State<MarketPricesScreen> createState() => _MarketPricesScreenState();
}

class _MarketPricesScreenState extends State<MarketPricesScreen> {
  bool _isLoading = true;
  String _statusMessage = 'Detecting your location...';
  String _currentDistrict = '';
  String _currentState = '';

  final List<String> _allCommodities = [
    'Rice',
    'Cotton',
    'Groundnut',
    'Chilli',
    'Maize',
    'Jowar',
    'Paddy',
    'Wheat'
  ];

  List<MarketPrice> _allPrices = [];
  List<MarketPrice> _filteredPrices = [];
  late Set<String> _activeCommodities;

  final String _apiKey =
      "579b464db66ec23bdd000001813d8610f33d417d764c680f21f25387";
  final String _apiUrl =
      "https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070";

  @override
  void initState() {
    super.initState();
    _activeCommodities = Set.from(_allCommodities);
    _getCurrentLocation();
  }

  String _getCommodityImagePath(String commodity) {
    final formattedName = commodity.toLowerCase().replaceAll(' ', '');
    return 'assets/images/$formattedName.png';
  }

  void _applyFilters() {
    if (_allPrices.isEmpty) {
      setState(() => _filteredPrices = []);
      return;
    }

    final filtered = _allPrices.where((price) {
      return _activeCommodities.any((active) =>
          price.commodity.toLowerCase().contains(active.toLowerCase()));
    }).toList();

    setState(() {
      _filteredPrices = filtered;
      if (filtered.isEmpty) {
        _statusMessage =
            'No prices found for selected crops in $_currentDistrict.';
      }
    });
  }

  Future<void> _fetchPrices() async {
    if (_currentDistrict.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Fetching prices for $_currentDistrict...';
      _allPrices = [];
      _filteredPrices = [];
    });

    try {
      final encodedDistrict = Uri.encodeComponent(_currentDistrict);
      final url = Uri.parse(
          '$_apiUrl?api-key=$_apiKey&format=json&filters[district]=$encodedDistrict&limit=1000');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'] as List?;

        if (records == null || records.isEmpty) {
          throw Exception('No records found for the specified district.');
        }

        final allFetchedPrices = records
            .whereType<Map<String, dynamic>>()
            .map((record) => MarketPrice.fromJson(record))
            .toList();

        allFetchedPrices.sort((a, b) {
          int dateCompare = b.arrivalDate.compareTo(a.arrivalDate);
          if (dateCompare != 0) return dateCompare;
          return a.commodity.compareTo(b.commodity);
        });

        setState(() {
          _allPrices = allFetchedPrices;
        });

        _applyFilters();
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to fetch market prices. Please try again.';
        _allPrices = [];
        _filteredPrices = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Detecting your location...';
    });

    if (kIsWeb) {
      _useDefaultLocation(
          reason: 'Web platform detected. Using default location for prices.');
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _useDefaultLocation(reason: 'Please enable location services.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _useDefaultLocation(reason: 'Location permission was denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _useDefaultLocation(
            reason:
                'Location permission is permanently denied. You can change this in your device settings.');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _currentDistrict =
              (place.subAdministrativeArea ?? 'Hyderabad').trim();
          _currentState = (place.administrativeArea ?? 'Telangana').trim();
          _statusMessage = 'Location: $_currentDistrict, $_currentState';
        });
        await _fetchPrices();
      } else {
        _useDefaultLocation(
            reason: 'Could not determine location from coordinates.');
      }
    } catch (e) {
      print('Error getting location: $e');
      _useDefaultLocation(reason: 'An error occurred while fetching location.');
    }
  }

  void _useDefaultLocation({required String reason}) {
    setState(() {
      _statusMessage = '$reason Using default location.';
      _currentDistrict = 'Hyderabad';
      _currentState = 'Telangana';
    });
    _fetchPrices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.grey.withValues(alpha: 0.1),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Market Prices',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              '$_currentDistrict, $_currentState',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.grey),
            onPressed: _getCurrentLocation,
          ),
          const SizedBox(width: 8), // Small padding for edge
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _allCommodities
                    .map((commodity) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              commodity,
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _activeCommodities.contains(commodity)
                                      ? Colors.green[800]
                                      : Colors.black54),
                            ),
                            selected: _activeCommodities.contains(commodity),
                            onSelected: (bool selected) {
                              setState(() {
                                if (selected) {
                                  _activeCommodities.add(commodity);
                                } else {
                                  _activeCommodities.remove(commodity);
                                }
                                _applyFilters();
                              });
                            },
                            selectedColor: Colors.green[100],
                            checkmarkColor: Colors.green[800],
                            backgroundColor: Colors.grey[100],
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: _activeCommodities.contains(commodity)
                                  ? BorderSide(color: Colors.green[200]!)
                                  : BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildShimmerEffect()
            : _filteredPrices.isEmpty
                ? _buildEmptyState()
                : _buildPriceList(),
      ),
    );
  }

  Widget _buildPriceList() {
    Map<String, List<MarketPrice>> groupedPrices = {};
    for (var price in _filteredPrices) {
      groupedPrices.putIfAbsent(price.commodity, () => []).add(price);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: groupedPrices.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        String commodity = groupedPrices.keys.elementAt(index);
        List<MarketPrice> prices = groupedPrices[commodity]!;

        return Card(
          elevation: 2,
          shadowColor: Colors.grey.withValues(alpha: 0.1),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
          clipBehavior:
              Clip.antiAlias, // Ensures children respect the border radius
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildCommodityAvatar(commodity),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            commodity,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            _currentDistrict,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${prices.length} Records',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              // List of Price Items
              ...prices.map((price) => _buildPriceItem(price)),
              // Card Footer
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                color: Colors.white,
                child: Text(
                  'Last updated: ${prices.first.arrivalDate}',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey[500]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriceItem(MarketPrice price) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            price.market,
            style:
                GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            'Variety: ${price.variety}',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPriceColumn('Min', price.minPrice,
                    color: Colors.orange[800]!),
              ),
              Expanded(
                child: _buildPriceColumn('Max', price.maxPrice,
                    color: Colors.red[700]!),
              ),
              Expanded(
                child: _buildPriceColumn('Modal', price.modalPrice,
                    isModal: true, color: Colors.green[700]!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommodityAvatar(String commodity) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        _getCommodityImagePath(commodity),
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.agriculture, size: 28, color: Colors.grey[500]),
          );
        },
      ),
    );
  }

  Widget _buildPriceColumn(String title, String value,
      {bool isModal = false, required Color color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '₹$value /qt',
          style: GoogleFonts.poppins(
            fontSize: isModal ? 15 : 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            Text(
              'No market prices available',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(width: 50, height: 50, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              width: 120, height: 18, color: Colors.white),
                          const SizedBox(height: 6),
                          Container(
                              width: 140, height: 14, color: Colors.white),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 200, height: 16, color: Colors.white),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(width: 70, height: 20, color: Colors.white),
                        const SizedBox(width: 20),
                        Container(width: 70, height: 20, color: Colors.white),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
