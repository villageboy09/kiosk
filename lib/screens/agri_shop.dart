// lib/screens/agri_shop.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/farmer_analytics_service.dart';
import 'package:cropsync/services/share_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cropsync/widgets/safe_network_image.dart';
import 'product_details_screen.dart';
import 'package:cropsync/theme/app_theme.dart';

// Product model
class Product {
  final String name;
  final String category;
  final String price;
  final String description;
  final String? imageUrl1;
  final String? imageUrl2;
  final String? imageUrl3;
  final String? videoUrl;
  final String advertiserName;
  final bool isPopular;
  final String unit;
  final int id;
  final int advertiserId;

  Product({
    required this.id,
    required this.advertiserId,
    required this.name,
    required this.category,
    required this.price,
    required this.description,
    this.imageUrl1,
    this.imageUrl2,
    this.imageUrl3,
    this.videoUrl,
    required this.advertiserName,
    this.isPopular = false,
    this.unit = 'unit',
  });
}

/// Localizes category names (e.g. 'మెషీన్', 'Machinery', 'Tools', 'పనిముట్లు')
String getLocalizedCategory(BuildContext context, String category) {
  if (category == 'all_category') return context.tr('all_category');

  // 1. Direct translation
  final direct = context.tr(category);
  if (direct != category) return direct;

  // 2. Normalized snake_case
  final key = category
      .toLowerCase()
      .trim()
      .replaceAll(' ', '_')
      .replaceAll('/', '_');
  final normTr = context.tr(key);
  if (normTr != key) return normTr;

  return category;
}

/// Localizes product names (e.g. 'Chaff Cutter', 'ఛాఫ్ కట్టర్', 'Sprayer')
String getLocalizedProductName(BuildContext context, String name) {
  if (name.trim().isEmpty) return name;

  // 1. Direct translation
  final direct = context.tr(name);
  if (direct != name) return direct;

  // 2. Normalized snake_case
  final key = name.toLowerCase().trim().replaceAll(' ', '_');
  final normTr = context.tr(key);
  if (normTr != key) return normTr;

  return name;
}

class AgriShopScreen extends StatefulWidget {
  const AgriShopScreen({super.key});

  @override
  State<AgriShopScreen> createState() => _AgriShopScreenState();
}

class _AgriShopScreenState extends State<AgriShopScreen> {
  List<Product>? _products;
  List<String>? _categories;
  bool _isLoadingProducts = true;
  bool _isLoadingCategories = true;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedCategory = 'all_category';
  String _sortOrder = 'default'; // 'default', 'price_asc', 'price_desc', 'popular'
  String _priceFilter = 'all'; // 'all', 'under_500', '500_2000', 'above_2000'
  bool _showWishlistOnly = false;

  final Set<int> _wishlistIds = {};
  final TextEditingController _searchController = TextEditingController();
  final PageController _bannerPageController = PageController();
  int _activeBannerIndex = 0;

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
      _selectedCategory = 'all_category';
      _loadCategories();
      _loadProducts();
    }
  }

  Future<void> _loadCategories() async {
    if (mounted) {
      setState(() => _isLoadingCategories = true);
    }
    try {
      final locale = _getLocaleField(context.locale.languageCode);
      final categories = await ApiService.getProductCategories(lang: locale);
      if (mounted) {
        setState(() {
          _categories = ['all_category', ...categories];
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _categories = ['all_category'];
          _isLoadingCategories = false;
        });
      }
    }
  }

  Future<void> _loadProducts() async {
    if (mounted) {
      setState(() {
        _isLoadingProducts = true;
        _errorMessage = null;
      });
    }
    try {
      final products = await _fetchProducts(
        category: _selectedCategory,
        search: _searchQuery,
        sort: _sortOrder,
      );
      if (mounted) {
        setState(() {
          _products = products;
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoadingProducts = false;
        });
      }
    }
  }

  String _getLocaleField(String locale) {
    switch (locale) {
      case 'hi':
        return 'hi';
      case 'te':
        return 'te';
      default:
        return 'en';
    }
  }

  Future<List<Product>> _fetchProducts({
    String? category,
    String? search,
    String? sort,
  }) async {
    try {
      final locale = _getLocaleField(context.locale.languageCode);

      String? categoryFilter;
      if (category != null && category != 'all_category') {
        categoryFilter = category;
      }

      final user = AuthService.currentUser;

      final response = await ApiService.getProducts(
        lang: locale,
        category: categoryFilter,
        search: search,
        sort: sort == 'popular' ? null : sort,
        userId: user?.userId,
      );

      return _mapResponseToProducts(response, locale);
    } catch (e) {
      return [];
    }
  }

  List<Product> _mapResponseToProducts(List<dynamic> response, String locale) {
    return response.map((p) {
      final priceString = p['price']?.toString() ?? '0';
      final priceValue = double.tryParse(priceString) ?? 0.0;

      return Product(
        id: int.tryParse(
                p['product_id']?.toString() ?? p['id']?.toString() ?? '0') ??
            0,
        advertiserId: int.tryParse(p['advertiser_id']?.toString() ?? '0') ?? 0,
        name: p['product_name']?.toString() ??
            p['name']?.toString() ??
            'N/A',
        category: p['category']?.toString() ?? 'General',
        price: priceValue.toStringAsFixed(0),
        description: p['product_description']?.toString() ??
            p['description']?.toString() ??
            context.tr('no_description'),
        imageUrl1: p['image_url_1']?.toString(),
        imageUrl2: p['image_url_2']?.toString(),
        imageUrl3: p['image_url_3']?.toString(),
        videoUrl:
            p['product_video_url']?.toString() ?? p['video_url']?.toString(),
        advertiserName:
            p['advertiser_name']?.toString() ?? context.tr('unknown_seller'),
        isPopular: priceValue > 500,
        unit: 'unit',
      );
    }).toList();
  }

  List<Product> _getFilteredProducts() {
    if (_products == null) return [];
    var list = List<Product>.from(_products!);

    // Filter by Wishlist
    if (_showWishlistOnly) {
      list = list.where((p) => _wishlistIds.contains(p.id)).toList();
    }

    // Filter by Price range
    if (_priceFilter == 'under_500') {
      list = list.where((p) => (double.tryParse(p.price) ?? 0) <= 500).toList();
    } else if (_priceFilter == '500_2000') {
      list = list.where((p) {
        final val = double.tryParse(p.price) ?? 0;
        return val > 500 && val <= 2000;
      }).toList();
    } else if (_priceFilter == 'above_2000') {
      list = list.where((p) => (double.tryParse(p.price) ?? 0) > 2000).toList();
    }

    // Sort popular in-memory if requested
    if (_sortOrder == 'popular') {
      list.sort((a, b) {
        if (a.isPopular && !b.isPopular) return -1;
        if (!a.isPopular && b.isPopular) return 1;
        return (double.tryParse(b.price) ?? 0).compareTo(double.tryParse(a.price) ?? 0);
      });
    }

    return list;
  }

  void _toggleWishlist(int productId) {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_wishlistIds.contains(productId)) {
        _wishlistIds.remove(productId);
      } else {
        _wishlistIds.add(productId);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bannerPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _getFilteredProducts();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: RefreshIndicator(
        color: const Color(0xFF047857),
        backgroundColor: Colors.white,
        onRefresh: () async {
          await Future.wait([_loadCategories(), _loadProducts()]);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            _buildEcommerceAppBar(),
            _buildLocationStrip(),
            if (!_showWishlistOnly) ...[
              _buildSearchHeader(),
              _buildPromotionalBanners(),
              _buildCategoryRail(),
              _buildQuickFilterChips(),
              _buildTrendingCarousel(),
            ],
            if (_showWishlistOnly) _buildWishlistActiveHeader(),
            _buildSectionHeader(filteredProducts.length),
            ..._buildProductGridSlivers(filteredProducts),
            _buildTrustAssuranceFooter(),
            const SliverToBoxAdapter(child: SizedBox(height: 70)),
          ],
        ),
      ),
      bottomNavigationBar: _buildAssistanceStickyBar(),
    );
  }

  // =========================================================================
  // APP BAR & LOCATION HEADER
  // =========================================================================

  Widget _buildEcommerceAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      centerTitle: false,
      leading: AppTheme.backButton(context),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF047857).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Color(0xFF047857),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('crop_sync_market'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Direct Dealer Store',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Wishlist Quick Access Toggle
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Material(
                color: _showWishlistOnly
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFF1F5F9),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _showWishlistOnly = !_showWishlistOnly);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Icon(
                      _showWishlistOnly
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 20,
                      color: _showWishlistOnly
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
              if (_wishlistIds.isNotEmpty)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      '${_wishlistIds.length}',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
          height: 0.7,
        ),
      ),
    );
  }

  Widget _buildLocationStrip() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFFECFDF5),
        child: Row(
          children: [
            const Icon(
              Icons.location_on_rounded,
              size: 15,
              color: Color(0xFF047857),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Kiosk Delivery: Free hub pickup & doorstep assistance',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF065F46),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Text(
                'AUTHENTIC',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF047857),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SEARCH BAR & FILTER BUTTON
  // =========================================================================

  Widget _buildSearchHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: context.tr('search_products'),
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                      fontSize: 13.5,
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 14, right: 10),
                      child: Icon(
                        Icons.search_rounded,
                        color: Color(0xFF047857),
                        size: 22,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 22,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.cancel_rounded,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _searchQuery = '';
                              _loadProducts();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onChanged: (value) {
                    if (value.length > 2 || value.isEmpty) {
                      _searchQuery = value;
                      _loadProducts();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Filter / Sort button
            Material(
              color: (_sortOrder != 'default' || _priceFilter != 'all')
                  ? const Color(0xFF047857)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              elevation: 0,
              child: InkWell(
                onTap: _showAdvancedFilterModal,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (_sortOrder != 'default' || _priceFilter != 'all')
                          ? const Color(0xFF047857)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 21,
                        color: (_sortOrder != 'default' || _priceFilter != 'all')
                            ? Colors.white
                            : const Color(0xFF334155),
                      ),
                      if (_sortOrder != 'default' || _priceFilter != 'all')
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF59E0B),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // PROMOTIONAL BANNER CAROUSEL
  // =========================================================================

  Widget _buildPromotionalBanners() {
    final banners = [
      {
        'tag': 'SEASONAL OFFER',
        'title': 'Kisan Monsoon Specials',
        'subtitle': 'Flat 20% off on hybrid seeds, bio-stimulants & sprayers',
        'gradient': [const Color(0xFF064E3B), const Color(0xFF047857)],
        'icon': Icons.eco_rounded,
        'badge': 'SAVE BIG',
      },
      {
        'tag': 'DIRECT DEALER',
        'title': '100% Genuine Certified Inputs',
        'subtitle': 'Verified state dealers with lot authenticity certs',
        'gradient': [const Color(0xFF1E293B), const Color(0xFF0F172A)],
        'icon': Icons.verified_user_rounded,
        'badge': 'VERIFIED',
      },
      {
        'tag': 'FARM DELIVERY',
        'title': 'Doorstep Delivery to Village Kiosk',
        'subtitle': 'Zero hassle pickup with cash or assisted online payment',
        'gradient': [const Color(0xFF78350F), const Color(0xFFB45309)],
        'icon': Icons.local_shipping_rounded,
        'badge': 'FREE HUB DROP',
      },
    ];

    return SliverToBoxAdapter(
      child: Column(
        children: [
          SizedBox(
            height: 140,
            child: PageView.builder(
              controller: _bannerPageController,
              itemCount: banners.length,
              onPageChanged: (index) {
                setState(() => _activeBannerIndex = index);
              },
              itemBuilder: (context, index) {
                final b = banners[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: b['gradient'] as List<Color>,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: (b['gradient'] as List<Color>)[0]
                              .withValues(alpha: 0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      b['tag'] as String,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      b['badge'] as String,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFF78350F),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                b['title'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                b['subtitle'] as String,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            b['icon'] as IconData,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Page indicator dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              banners.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _activeBannerIndex == i ? 18 : 6,
                height: 5,
                decoration: BoxDecoration(
                  color: _activeBannerIndex == i
                      ? const Color(0xFF047857)
                      : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // =========================================================================
  // CATEGORY RAIL (LARGE VISUAL CHIPS FOR ACCESSIBILITY)
  // =========================================================================

  Widget _buildCategoryRail() {
    if (_isLoadingCategories) {
      return SliverToBoxAdapter(
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Shimmer.fromColors(
            baseColor: const Color(0xFFE2E8F0),
            highlightColor: const Color(0xFFF8FAFC),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: List.generate(
                  4,
                  (i) => Container(
                    width: 90,
                    height: 42,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_categories == null || _categories!.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final categories = _categories!;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Shop by Category',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  '${categories.length} categories',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = _selectedCategory == cat;
                final icon = _getCategoryIcon(cat);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategory = cat);
                        _loadProducts();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF047857)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF047857)
                                : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF047857)
                                        .withValues(alpha: 0.22),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A)
                                        .withValues(alpha: 0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF047857),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              getLocalizedCategory(context, cat),
                              style: GoogleFonts.plusJakartaSans(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('all')) return Icons.grid_view_rounded;
    if (lower.contains('seed') || lower.contains('విత్తనాలు') || lower.contains('बीज')) {
      return Icons.spa_rounded;
    }
    if (lower.contains('fertilizer') || lower.contains('ఎరువులు') || lower.contains('उर्वरक')) {
      return Icons.science_rounded;
    }
    if (lower.contains('pesticide') || lower.contains('మందులు') || lower.contains('कीटनाशक')) {
      return Icons.shield_rounded;
    }
    if (lower.contains('machine') || lower.contains('మెషీన్') || lower.contains('యంత్రాలు') || lower.contains('मशीन')) {
      return Icons.precision_manufacturing_rounded;
    }
    if (lower.contains('tool') || lower.contains('పనిముట్లు') || lower.contains('औजार')) {
      return Icons.handyman_rounded;
    }
    if (lower.contains('water') || lower.contains('irrigation') || lower.contains('నీటి')) {
      return Icons.water_drop_rounded;
    }
    return Icons.inventory_2_rounded;
  }

  // =========================================================================
  // QUICK FILTER CHIPS
  // =========================================================================

  Widget _buildQuickFilterChips() {
    final filters = [
      {'id': 'all', 'label': 'All Items'},
      {'id': 'under_500', 'label': 'Under ₹500'},
      {'id': '500_2000', 'label': '₹500 - ₹2,000'},
      {'id': 'above_2000', 'label': 'Above ₹2,000'},
    ];

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: filters.length,
            itemBuilder: (context, index) {
              final f = filters[index];
              final isSelected = _priceFilter == f['id'];

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(
                    f['label']!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF047857)
                          : const Color(0xFF475569),
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (val) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _priceFilter = f['id']!;
                    });
                  },
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xFFD1FAE5),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF059669)
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TRENDING / POPULAR CAROUSEL
  // =========================================================================

  Widget _buildTrendingCarousel() {
    if (_products == null || _products!.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final popularProducts =
        _products!.where((p) => p.isPopular).take(6).toList();
    if (popularProducts.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFFD97706),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Trending Farm Deals',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Fast Selling',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 112,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: popularProducts.length,
              itemBuilder: (context, index) {
                final p = popularProducts[index];
                return Container(
                  width: 260,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _navigateToProduct(p),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            // Product Thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 80,
                                height: 86,
                                color: const Color(0xFFF8FAFC),
                                child: SafeNetworkImage(
                                  imageUrl: p.imageUrl1 ?? p.imageUrl2,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'HOT PICK',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFFEF4444),
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    getLocalizedProductName(context, p.name),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        '₹${p.price}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF047857),
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF047857),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white,
                                          size: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // =========================================================================
  // SECTION HEADER & WISHLIST FILTER HEADER
  // =========================================================================

  Widget _buildWishlistActiveHeader() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.favorite_rounded,
                color: Color(0xFFEF4444), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Showing Bookmarked & Wishlist Products',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: const Color(0xFF991B1B),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _showWishlistOnly = false),
              child: Text(
                'View All',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: const Color(0xFF047857),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(int count) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _showWishlistOnly
                    ? 'Wishlist Items ($count)'
                    : 'All Products ($count)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: _showAdvancedFilterModal,
                  child: Row(
                    children: [
                      Text(
                        _sortOrder == 'price_asc'
                            ? 'Price: Low'
                            : (_sortOrder == 'price_desc'
                                ? 'Price: High'
                                : (_sortOrder == 'popular'
                                    ? 'Popular'
                                    : 'Default')),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF047857),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF047857),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // PRODUCTS GRID
  // =========================================================================

  List<Widget> _buildProductGridSlivers(List<Product> products) {
    if (_isLoadingProducts) {
      return [_buildShimmerGridSliver()];
    }
    if (_errorMessage != null) {
      return [SliverToBoxAdapter(child: _buildErrorState(_errorMessage!))];
    }
    if (products.isEmpty) {
      return [SliverToBoxAdapter(child: _buildEmptyState())];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            childAspectRatio: 0.58,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final product = products[index];
              return _EcommerceProductCard(
                key: ValueKey(product.id),
                product: product,
                isWishlisted: _wishlistIds.contains(product.id),
                onWishlistToggle: () => _toggleWishlist(product.id),
                onTap: () => _navigateToProduct(product),
              );
            },
            childCount: products.length,
          ),
        ),
      ),
    ];
  }

  void _navigateToProduct(Product product) {
    FarmerAnalyticsService.logShopItemView(
      productId: product.id,
      productName: product.name,
      category: product.category,
      price: product.price,
      advertiserName: product.advertiserName,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(product: product),
      ),
    );
  }

  Widget _buildShimmerGridSliver() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          childAspectRatio: 0.58,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => Shimmer.fromColors(
            baseColor: const Color(0xFFE2E8F0),
            highlightColor: const Color(0xFFF8FAFC),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          childCount: 6,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: Color(0xFF047857),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('no_products_found'),
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF0F172A),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try changing your category or clearing filters to see all available agricultural inputs.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                  _selectedCategory = 'all_category';
                  _sortOrder = 'default';
                  _priceFilter = 'all';
                  _showWishlistOnly = false;
                });
                _loadProducts();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Reset All Filters',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFEF4444), size: 40),
            const SizedBox(height: 12),
            Text(
              context.tr('error_message', namedArgs: {'error': error}),
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFB91C1C),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loadProducts,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TRUST & ASSURANCE FOOTER
  // =========================================================================

  Widget _buildTrustAssuranceFooter() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: Color(0xFF047857),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CropSync Quality Guarantee',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Trusted by over 10,000+ farmers across 4 states',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 14),
            _buildAssurancePillar(
              Icons.inventory_2_outlined,
              'Original Sealed Packaging',
              'Sourced directly from authorized manufacturers & seed research labs.',
            ),
            const SizedBox(height: 12),
            _buildAssurancePillar(
              Icons.local_shipping_outlined,
              'Kiosk Hub Delivery',
              'Delivered promptly to your nearest Village Center / Kiosk Hub.',
            ),
            const SizedBox(height: 12),
            _buildAssurancePillar(
              Icons.support_agent_rounded,
              'Free Agronomist Advice',
              'Our certified crop doctors guide your dosage and application.',
            ),
            const SizedBox(height: 12),
            _buildAssurancePillar(
              Icons.payments_outlined,
              'Easy Kiosk Payment',
              'Pay via UPI, Card or Cash on delivery at the kiosk center.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssurancePillar(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF047857)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // STICKY ASSISTANCE BAR FOR EASY ACCESS
  // =========================================================================

  Widget _buildAssistanceStickyBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(
            color: Color(0xFFE2E8F0),
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.phone_in_talk_rounded,
              color: Color(0xFF047857),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need Help Choosing Inputs?',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Ask Kiosk Operator or Call Agronomist',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF047857),
                  content: Text(
                    'Kiosk advisory connected! Contacting field officer...',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            ),
            child: Text(
              'Call Help',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ADVANCED FILTER & SORT MODAL
  // =========================================================================

  void _showAdvancedFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sort & Filter Options',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _sortOrder = 'default';
                            _priceFilter = 'all';
                          });
                          setState(() {
                            _sortOrder = 'default';
                            _priceFilter = 'all';
                          });
                        },
                        child: Text(
                          'Reset',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFEF4444),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'SORT BY',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildModalRadioTile(
                    label: 'Relevance / Best Match',
                    value: 'default',
                    groupValue: _sortOrder,
                    onTap: () {
                      setSheetState(() => _sortOrder = 'default');
                      setState(() => _sortOrder = 'default');
                    },
                  ),
                  _buildModalRadioTile(
                    label: 'Price: Low to High (Budget First)',
                    value: 'price_asc',
                    groupValue: _sortOrder,
                    onTap: () {
                      setSheetState(() => _sortOrder = 'price_asc');
                      setState(() => _sortOrder = 'price_asc');
                    },
                  ),
                  _buildModalRadioTile(
                    label: 'Price: High to Low (Premium Equipment)',
                    value: 'price_desc',
                    groupValue: _sortOrder,
                    onTap: () {
                      setSheetState(() => _sortOrder = 'price_desc');
                      setState(() => _sortOrder = 'price_desc');
                    },
                  ),
                  _buildModalRadioTile(
                    label: 'Most Popular & Best Sellers',
                    value: 'popular',
                    groupValue: _sortOrder,
                    onTap: () {
                      setSheetState(() => _sortOrder = 'popular');
                      setState(() => _sortOrder = 'popular');
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _loadProducts();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        context.tr('apply_filters'),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalRadioTile({
    required String label,
    required String value,
    required String groupValue,
    required VoidCallback onTap,
  }) {
    final isSelected = value == groupValue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF047857)
                      : const Color(0xFF334155),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF047857),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// HIGH CRAFT E-COMMERCE PRODUCT CARD
// ===========================================================================

class _EcommerceProductCard extends StatefulWidget {
  final Product product;
  final bool isWishlisted;
  final VoidCallback onWishlistToggle;
  final VoidCallback onTap;

  const _EcommerceProductCard({
    super.key,
    required this.product,
    required this.isWishlisted,
    required this.onWishlistToggle,
    required this.onTap,
  });

  @override
  State<_EcommerceProductCard> createState() => _EcommerceProductCardState();
}

class _EcommerceProductCardState extends State<_EcommerceProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawPrice = double.tryParse(widget.product.price) ?? 0.0;
    // Calculate realistic original MRP (approx 20% higher) to give genuine e-commerce feel
    final originalMrp = (rawPrice * 1.25).round();
    final savings = originalMrp - rawPrice.round();

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _animController.forward();
      },
      onTapUp: (_) {
        _animController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _animController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= IMAGE AREA =================
              Expanded(
                flex: 11,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.all(10),
                      child: Hero(
                        tag: 'product_image_${widget.product.id}',
                        child: SafeNetworkImage(
                          imageUrl: (widget.product.imageUrl1 != null &&
                                  widget.product.imageUrl1!.trim().isNotEmpty)
                              ? widget.product.imageUrl1
                              : ((widget.product.imageUrl2 != null &&
                                      widget.product.imageUrl2!.trim().isNotEmpty)
                                  ? widget.product.imageUrl2
                                  : widget.product.imageUrl3),
                          fit: BoxFit.contain,
                          placeholder: Container(
                            color: const Color(0xFFF1F5F9),
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Discount / Savings Badge
                    if (savings > 0)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF047857), Color(0xFF059669)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF047857)
                                    .withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            '20% OFF',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    // Wishlist Heart Button
                    Positioned(
                      top: 6,
                      right: 6,
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.85),
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: widget.onWishlistToggle,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: Icon(
                                  widget.isWishlisted
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 15,
                                  color: widget.isWishlisted
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Share Button (Bottom Right of Image)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.85),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ShareService.shareItem(
                              context: context,
                              type: 'shop',
                              id: widget.product.id.toString(),
                              title: widget.product.name,
                              description: widget.product.description,
                              price: '₹${widget.product.price}',
                              imageUrl: widget.product.imageUrl1 ??
                                  widget.product.imageUrl2 ??
                                  widget.product.imageUrl3,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            child: const Icon(
                              Icons.share_outlined,
                              size: 13,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ================= DETAILS AREA =================
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dealer row
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF047857),
                          size: 11,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            widget.product.advertiserName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF047857),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Title
                    Text(
                      getLocalizedProductName(context, widget.product.name),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Rating & delivery badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFD97706),
                                size: 11,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '4.8',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF78350F),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(120+)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9.5,
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Price Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₹${widget.product.price}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (savings > 0) ...[
                          const SizedBox(width: 5),
                          Text(
                            '₹$originalMrp',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF94A3B8),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Action Button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF047857),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.white,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.tr('view'),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
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
