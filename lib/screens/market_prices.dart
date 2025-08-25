// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';

// (MarketPrice class remains the same)
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

  // ♻️ MODIFIED: These are now the master list of all possible commodities
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

  // ✅ NEW: State to hold all prices fetched from the API for the district
  List<MarketPrice> _allPrices = [];
  // ✅ NEW: State to hold prices after applying filters
  List<MarketPrice> _filteredPrices = [];
  // ✅ NEW: State to track which commodity filters are active
  late Set<String> _activeCommodities;

  final String _apiKey =
      "579b464db66ec23bdd000001813d8610f33d417d764c680f21f25387";
  final String _apiUrl =
      "https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070";

  @override
  void initState() {
    super.initState();
    // ✅ NEW: Initialize active commodities to all be selected by default
    _activeCommodities = Set.from(_allCommodities);
    _getCurrentLocation();
  }

  // ✅ NEW: Helper function to get image path for a commodity
  String _getCommodityImagePath(String commodity) {
    // Standardize the commodity name to match file names (lowercase, no spaces)
    final formattedName = commodity.toLowerCase().replaceAll(' ', '');
    return 'assets/images/$formattedName.png';
  }

  // ✅ NEW: Logic to apply the active filters to the list of prices
  void _applyFilters() {
    if (_allPrices.isEmpty) {
      setState(() => _filteredPrices = []);
      return;
    }

    final filtered = _allPrices.where((price) {
      // Check if the price's commodity is in our active filter set.
      // We check against our master list to handle API variations like "Paddy(Dhan)(Common)"
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

  // ♻️ MODIFIED: Now populates _allPrices and then calls _applyFilters
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

        _applyFilters(); // Apply the default filters
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

  // (_getCurrentLocation and _useDefaultLocation methods remain the same)
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Detecting your location...';
    });

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
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? _buildShimmerEffect()
                  : _filteredPrices.isEmpty
                      ? _buildEmptyState()
                      : _buildPriceList(),
            ),
          ],
        ),
      ),
    );
  }

  // ♻️ MODIFIED: Now uses FilterChip for interactive filtering
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.blueAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_currentDistrict, $_currentState',
                  style: GoogleFonts.lexend(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _getCurrentLocation,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Filter by crop:',
            style: GoogleFonts.lexend(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: _allCommodities
                .map((commodity) => FilterChip(
                      label: Text(commodity,
                          style: GoogleFonts.lexend(fontSize: 12)),
                      selected: _activeCommodities.contains(commodity),
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            _activeCommodities.add(commodity);
                          } else {
                            _activeCommodities.remove(commodity);
                          }
                          // Re-apply filters on the existing data without a new API call
                          _applyFilters();
                        });
                      },
                      selectedColor: Colors.green[100],
                      checkmarkColor: Colors.green[800],
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ♻️ MODIFIED: Now builds the list from _filteredPrices
  Widget _buildPriceList() {
    Map<String, List<MarketPrice>> groupedPrices = {};
    for (var price in _filteredPrices) {
      groupedPrices.putIfAbsent(price.commodity, () => []).add(price);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
      itemCount: groupedPrices.length,
      itemBuilder: (context, index) {
        String commodity = groupedPrices.keys.elementAt(index);
        List<MarketPrice> prices = groupedPrices[commodity]!;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ♻️ MODIFIED: Card header now includes an image
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[600],
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white.withValues(alpha: 0.9),
                      // ✅ NEW: Image is displayed here
                      backgroundImage:
                          AssetImage(_getCommodityImagePath(commodity)),
                      onBackgroundImageError:
                          (_, __) {}, // Handles if image is not found
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        commodity,
                        style: GoogleFonts.lexend(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: prices.length,
                itemBuilder: (context, idx) => _buildPriceItem(prices[idx]),
                separatorBuilder: (context, idx) => Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Colors.grey[300]),
              )
            ],
          ),
        );
      },
    );
  }

  // (_buildEmptyState, _buildPriceItem, _buildPriceColumn, _buildShimmerEffect methods remain the same)
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(fontSize: 16, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceItem(MarketPrice price) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            price.market,
            style:
                GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Variety: ${price.variety}  •  Grade: ${price.grade}',
            style: GoogleFonts.lexend(color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Text(
            'Arrival Date: ${price.arrivalDate}',
            style: GoogleFonts.lexend(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPriceColumn('Min Price', price.minPrice),
              _buildPriceColumn('Max Price', price.maxPrice),
              _buildPriceColumn('Modal Price', price.modalPrice, isModal: true),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPriceColumn(String title, String value, {bool isModal = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.lexend(fontSize: 12, color: Colors.grey)),
        Text(
          '₹$value',
          style: GoogleFonts.lexend(
            fontSize: isModal ? 18 : 16,
            fontWeight: isModal ? FontWeight.bold : FontWeight.w500,
            color: isModal ? Colors.green[800] : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerEffect() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: 4,
        itemBuilder: (_, __) => Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 50,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 150, height: 16, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(width: 200, height: 14, color: Colors.white),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(width: 60, height: 24, color: Colors.white),
                        Container(width: 60, height: 24, color: Colors.white),
                        Container(width: 60, height: 24, color: Colors.white),
                      ],
                    ),
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
