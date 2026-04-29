// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cropsync/services/location_service.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cropsync/theme/app_theme.dart';

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
  String _statusMessage = '';
  String _currentDistrict = '';
  String _currentState = '';

  final List<String> _allCommodities = [
    'rice',
    'cotton',
    'groundnut',
    'chilli',
    'maize',
    'jowar',
    'paddy',
    'wheat'
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
    // Do NOT use context or call _getCurrentLocation() here
  }

  Locale? _lastLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = context.locale;
    if (_lastLocale != currentLocale) {
      _lastLocale = currentLocale;
      _statusMessage = context.tr('detecting_location');
      _getCurrentLocation();
    }
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
        _statusMessage = context
            .tr('no_prices_found', namedArgs: {'district': _currentDistrict});
      }
    });
  }

  Future<void> _fetchPrices() async {
    if (_currentDistrict.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = context
          .tr('fetching_prices', namedArgs: {'district': _currentDistrict});
      _allPrices = [];
      _filteredPrices = [];
    });

    try {
      final encodedDistrict = Uri.encodeComponent(_currentDistrict);
      final url = Uri.parse(
          '$_apiUrl?api-key=$_apiKey&format=json&filters[district]=$encodedDistrict&limit=200');

      final response = await http.get(url).timeout(const Duration(seconds: 12));

      if (!mounted) return;

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
      if (mounted) {
        setState(() {
          _statusMessage = context.tr('failed_fetch');
          _allPrices = [];
          _filteredPrices = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _statusMessage = context.tr('detecting_location');
    });

    if (kIsWeb) {
      _useDefaultLocation(reason: context.tr('web_default'));
      return;
    }

    try {
      // Use LocationService instead of direct Geolocator calls
      final hasPermission = await LocationService.requestPermission()
          .timeout(const Duration(seconds: 8), onTimeout: () => false);
      if (!mounted) return;

      if (!hasPermission) {
        _useDefaultLocation(reason: context.tr('permission_denied'));
        return;
      }

      final position = await LocationService.getCurrentPosition()
          .timeout(const Duration(seconds: 12), onTimeout: () => null);
      if (!mounted) return;

      if (position == null) {
        _useDefaultLocation(reason: context.tr('location_error'));
        return;
      }

      final district = await LocationService.getDistrict().timeout(
        const Duration(seconds: 8),
        onTimeout: () => 'Hyderabad',
      );
      final state = await LocationService.getState().timeout(
        const Duration(seconds: 8),
        onTimeout: () => 'Telangana',
      );

      if (!mounted) return;

      setState(() {
        _currentDistrict = district;
        _currentState = state;
        _statusMessage = context.tr('location_detected',
            namedArgs: {'district': _currentDistrict, 'state': _currentState});
      });
      await _fetchPrices();
    } catch (e) {
      if (mounted) {
        _useDefaultLocation(reason: context.tr('location_error'));
      }
    }
  }

  void _useDefaultLocation({required String reason}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = '$reason ${context.tr('using_default')}.';
      _currentDistrict = 'Hyderabad';
      _currentState = 'Telangana';
    });
    _fetchPrices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('market_prices_title'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                )),
            Text(
              '$_currentDistrict, $_currentState',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
        leading: AppTheme.backButton(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _getCurrentLocation,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _allCommodities.length,
              itemBuilder: (context, index) {
                final commodity = _allCommodities[index];
                final isSelected = _activeCommodities.contains(commodity);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(context.tr(commodity)),
                    selected: isSelected,
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
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                      letterSpacing: 0.2,
                    ),
                    backgroundColor: Colors.white,
                    selectedColor: AppTheme.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                      side: BorderSide(
                        color: isSelected ? AppTheme.textPrimary : const Color(0xFFE5E7EB),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                  ),
                );
              },
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedPrices.length,
      itemBuilder: (context, index) {
        String commodity = groupedPrices.keys.elementAt(index);
        List<MarketPrice> prices = groupedPrices[commodity]!;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildCommodityAvatar(commodity),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr(commodity),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              _currentDistrict,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          context.tr('records_count',
                              namedArgs: {'count': prices.length.toString()}),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ...prices.take(5).map((price) => _buildPriceItem(price)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Text(
                    context.tr('last_updated',
                        namedArgs: {'date': prices.first.arrivalDate}),
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textHint,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPriceItem(MarketPrice price) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.1)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            price.market,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3),
          ),
          const SizedBox(height: 6),
          Text(
            '${context.tr('variety_label')} ${price.variety}',
            style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPriceColumn(
                    context.tr('min_price'), price.minPrice),
              ),
              Expanded(
                child: _buildPriceColumn(
                    context.tr('max_price'), price.maxPrice),
              ),
              Expanded(
                child: _buildPriceColumn(
                    context.tr('modal_price'), price.modalPrice,
                    isModal: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommodityAvatar(String commodity) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          _getCommodityImagePath(commodity),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.agriculture_rounded, size: 28, color: AppTheme.textHint);
          },
        ),
      ),
    );
  }

  Widget _buildPriceColumn(String title, String value,
      {bool isModal = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textHint,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '₹$value',
          style: TextStyle(
            fontSize: isModal ? 18 : 16,
            fontWeight: FontWeight.w900,
            color: isModal ? AppTheme.textPrimary : AppTheme.textPrimary.withValues(alpha: 0.7),
            letterSpacing: -0.5,
          ),
        ),
        Text(
          context.tr('per_quintal'),
          style: const TextStyle(
            fontSize: 9,
            color: AppTheme.textHint,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded, size: 56, color: AppTheme.textHint),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('no_market_prices'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _getCurrentLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.textPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(context.tr('retry'), style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: const Color(0xFFE5E7EB),
        highlightColor: const Color(0xFFF3F4F6),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
