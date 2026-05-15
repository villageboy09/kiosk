import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cropsync/services/location_service.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';

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
  String _latestDate = '';

  List<MarketPrice> _allPrices = [];

  @override
  void initState() {
    super.initState();
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
    return 'http://kiosk.cropsync.in/api/commodity/$formattedName.png';
  }

  Future<void> _fetchPrices() async {
    if (_currentState.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = context.tr('fetching_state_prices');
      _allPrices = [];
    });

    try {
      final response = await ApiService.getStateMarketPrices(_currentState);

      if (!mounted) return;

      if (response['success'] == true) {
        final records = response['records'] as List?;
        _latestDate = response['date']?.toString() ?? '';

        if (records == null || records.isEmpty) {
          setState(() {
            _allPrices = [];
            _statusMessage = context
                .tr('no_prices_for_state', namedArgs: {'state': _currentState});
          });
          return;
        }

        final allFetchedPrices = records
            .whereType<Map<String, dynamic>>()
            .map((record) => MarketPrice.fromJson(record))
            .toList();

        setState(() {
          _allPrices = allFetchedPrices;
        });
      } else {
        setState(() {
          _statusMessage = response['error'] ?? context.tr('failed_fetch');
          _allPrices = [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = context.tr('error_fetching_prices');
          _allPrices = [];
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

  void _openCommodityDetails(String commodity) {
    // Filter prices for this commodity
    final commodityPrices =
        _allPrices.where((p) => p.commodity == commodity).toList();

    // Sort so local district is first
    commodityPrices.sort((a, b) {
      bool aIsLocal =
          a.district.toLowerCase() == _currentDistrict.toLowerCase();
      bool bIsLocal =
          b.district.toLowerCase() == _currentDistrict.toLowerCase();
      if (aIsLocal && !bIsLocal) return -1;
      if (!aIsLocal && bIsLocal) return 1;
      return a.district.compareTo(b.district);
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommodityDetailScreen(
          commodity: commodity,
          prices: commodityPrices,
          currentDistrict: _currentDistrict,
          imagePath: _getCommodityImagePath(commodity),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
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
        ],
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchPrices,
          child: _isLoading
              ? _buildShimmerEffect()
              : _allPrices.isEmpty
                  ? _buildEmptyState()
                  : _buildCommodityGrid(),
        ),
      ),
    );
  }

  Widget _buildCommodityGrid() {
    // Extract unique commodities and find best price to show on card
    Map<String, MarketPrice> uniqueCommodities = {};
    for (var p in _allPrices) {
      if (!uniqueCommodities.containsKey(p.commodity)) {
        uniqueCommodities[p.commodity] = p;
      } else {
        // If we find a local district price, prefer it for the card summary
        if (p.district.toLowerCase() == _currentDistrict.toLowerCase()) {
          uniqueCommodities[p.commodity] = p;
        }
      }
    }

    List<MarketPrice> displayList = uniqueCommodities.values.toList();
    displayList.sort((a, b) => a.commodity.compareTo(b.commodity));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('commodities_in_state'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  context.tr('last_updated', namedArgs: {'date': _latestDate}),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final price = displayList[index];
                final isLocalPrice = price.district.toLowerCase() ==
                    _currentDistrict.toLowerCase();

                return GestureDetector(
                  onTap: () => _openCommodityDetails(price.commodity),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        _buildCommodityAvatar(price.commodity),
                        const SizedBox(height: 12),
                        Text(
                          price.commodity,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            isLocalPrice
                                ? price.district
                                : context.tr('avg_across_state'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isLocalPrice
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                              fontWeight: isLocalPrice
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.05),
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(16)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '₹${price.modalPrice}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const Text(
                                '/ quintal',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: displayList.length,
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }

  Widget _buildCommodityAvatar(String commodity) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            spreadRadius: 1,
          )
        ],
      ),
      child: ClipOval(
        child: Image.network(
          _getCommodityImagePath(commodity),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              'assets/images/logo_t.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.grass_rounded,
                    size: 30, color: AppTheme.textHint);
              },
            );
          },
        ),
      ),
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
              child: const Icon(Icons.search_off_rounded,
                  size: 56, color: AppTheme.textHint),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('no_market_prices'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(context.tr('retry'),
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: const Color(0xFFE5E7EB),
        highlightColor: const Color(0xFFF3F4F6),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class CommodityDetailScreen extends StatefulWidget {
  final String commodity;
  final List<MarketPrice> prices;
  final String currentDistrict;
  final String imagePath;

  const CommodityDetailScreen({
    super.key,
    required this.commodity,
    required this.prices,
    required this.currentDistrict,
    required this.imagePath,
  });

  @override
  State<CommodityDetailScreen> createState() => _CommodityDetailScreenState();
}

class _CommodityDetailScreenState extends State<CommodityDetailScreen> {
  bool _isLoadingTrends = true;
  List<FlSpot> _spots = [];
  List<String> _dates = [];
  String _trendError = '';

  @override
  void initState() {
    super.initState();
    // Default to fetch trends for the most relevant district (usually local, which is first in list)
    _fetchTrends(widget.prices.first.district);
  }

  Future<void> _fetchTrends(String district) async {
    setState(() {
      _isLoadingTrends = true;
      _trendError = '';
    });

    try {
      final response =
          await ApiService.getCommodityTrends(district, widget.commodity);
      if (mounted) {
        if (response['success'] == true) {
          final trends = response['trends'] as List;
          if (trends.isEmpty) {
            setState(() {
              _trendError = context.tr('no_historical_data_for_district',
                  namedArgs: {'district': district});
              _isLoadingTrends = false;
            });
            return;
          }

          List<FlSpot> spots = [];
          List<String> dates = [];

          for (int i = 0; i < trends.length; i++) {
            final t = trends[i];
            spots.add(
                FlSpot(i.toDouble(), double.parse(t['avg_price'].toString())));
            dates.add(t['arrival_date'].toString().substring(5)); // just mm-dd
          }

          setState(() {
            _spots = spots;
            _dates = dates;
            _isLoadingTrends = false;
          });
        } else {
          setState(() {
            _trendError = response['error'] ?? 'Failed to load trends.';
            _isLoadingTrends = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _trendError = 'Network error.';
          _isLoadingTrends = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(widget.commodity),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: CustomScrollView(
        slivers: [
          // Trend Graph Header
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.show_chart_rounded,
                            color: AppTheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('price_trends'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              widget.prices.first
                                  .district, // Showing trend for first district
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 180,
                    child: _isLoadingTrends
                        ? const Center(child: CircularProgressIndicator())
                        : _trendError.isNotEmpty
                            ? Center(
                                child: Text(_trendError,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: AppTheme.textHint)))
                            : LineChart(
                                LineChartData(
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    horizontalInterval: 1000,
                                    getDrawingHorizontalLine: (value) => FlLine(
                                        color: Colors.grey.shade200,
                                        strokeWidth: 1),
                                  ),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    rightTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                    topTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 30,
                                        interval: 1,
                                        getTitlesWidget: (value, meta) {
                                          int index = value.toInt();
                                          if (index < 0 ||
                                              index >= _dates.length) {
                                            return const SizedBox();
                                          }
                                          if (index % 3 != 0 &&
                                              index != _dates.length - 1) {
                                            return const SizedBox();
                                          }
                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8.0),
                                            child: Text(_dates[index],
                                                style: const TextStyle(
                                                    color: AppTheme.textHint,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          );
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        interval: 1000,
                                        reservedSize: 42,
                                        getTitlesWidget: (value, meta) {
                                          return Text('₹${value.toInt()}',
                                              style: const TextStyle(
                                                  color: AppTheme.textHint,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold));
                                        },
                                      ),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: _spots,
                                      isCurved: true,
                                      color: AppTheme.primary,
                                      barWidth: 3,
                                      isStrokeCapRound: true,
                                      dotData: const FlDotData(show: false),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                  ),
                ],
              ),
            ),
          ),

          // List of Prices across districts
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                context.tr('all_state_markets'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final price = widget.prices[index];
                  final isLocal = price.district.toLowerCase() ==
                      widget.currentDistrict.toLowerCase();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: isLocal
                          ? Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.5),
                              width: 1.5)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.storefront_rounded,
                                color: AppTheme.primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  price.market,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        size: 12,
                                        color: AppTheme.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      price.district,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    if (isLocal) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          "Nearby",
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Variety: ${price.variety}",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${price.modalPrice}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const Text(
                                '/ quintal',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textHint,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: widget.prices.length,
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }
}
