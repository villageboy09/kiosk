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
    this.unit = 'kg',
  });
}

class AgriShopScreen extends StatefulWidget {
  const AgriShopScreen({super.key});

  @override
  State<AgriShopScreen> createState() => _AgriShopScreenState();
}

class _AgriShopScreenState extends State<AgriShopScreen> {
  late Future<List<Product>> _productsFuture;
  late Future<List<String>> _categoriesFuture;
  String _searchQuery = '';
  String _selectedCategory = 'all_category';
  String _sortOrder = 'default'; // 'price_asc', 'price_desc'
  final TextEditingController _searchController = TextEditingController();

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
      _categoriesFuture = _fetchCategories();
      _loadProducts();
    }
  }

  void _loadProducts() {
    if (mounted) {
      setState(() {
        _productsFuture = _fetchProducts(
            category: _selectedCategory,
            search: _searchQuery,
            sort: _sortOrder);
      });
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

  Future<List<String>> _fetchCategories() async {
    try {
      final locale = _getLocaleField(context.locale.languageCode);
      final categories = await ApiService.getProductCategories(lang: locale);
      return [
        'all_category',
        ...categories
      ];
    } catch (e) {
      return ['all_category'];
    }
  }

  Future<List<Product>> _fetchProducts(
      {String? category, String? search, String? sort}) async {
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
        sort: sort,
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(),
          _buildFeaturedHero(),
          _buildSearchAndFilters(),
          _buildCategorySliver(),
        ],
        body: _buildProductsList(),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      centerTitle: false,
      leading: AppTheme.backButton(context),
      titleSpacing: Navigator.canPop(context) ? 4 : 16,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('crop_sync_market'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.googleSans(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          Text(
            'Verified Agricultural Products & Inputs',
            style: GoogleFonts.googleSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: const Color(0xFFE2E8F0),
          height: 1,
        ),
      ),
    );
  }

  Widget _buildFeaturedHero() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded,
                      color: Color(0xFF38BDF8), size: 13),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'AUTHORIZED AGRI DEALERS',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.googleSans(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Genuine Farm Inputs & Tools',
              style: GoogleFonts.googleSans(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Direct ordering of genuine fertilizers, seed treatments, crop protection & farm machinery.',
              style: GoogleFonts.googleSans(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.googleSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: context.tr('search_products'),
                    hintStyle: GoogleFonts.googleSans(
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFF64748B), size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                size: 16, color: Color(0xFF64748B)),
                            onPressed: () {
                              _searchController.clear();
                              _searchQuery = '';
                              _loadProducts();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    border: InputBorder.none,
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
            Container(
              decoration: BoxDecoration(
                color: _sortOrder != 'default'
                    ? const Color(0xFF0F172A)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: _sortOrder != 'default'
                      ? Colors.white
                      : const Color(0xFF0F172A),
                ),
                onPressed: _showFilterBottomSheet,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySliver() {
    return SliverAppBar(
      backgroundColor: const Color(0xFFF8FAFC),
      surfaceTintColor: Colors.transparent,
      pinned: true,
      primary: false,
      automaticallyImplyLeading: false,
      toolbarHeight: 52,
      elevation: 0,
      flexibleSpace: _buildCategoryTabs(),
    );
  }

  Widget _buildCategoryTabs() {
    return FutureBuilder<List<String>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final categories = snapshot.data!;
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(
              bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
          ),
          height: 52,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = _selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = category);
                      _loadProducts();
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF0F172A)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF0F172A)
                                      .withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        context.tr(category),
                        style: GoogleFonts.googleSans(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF475569),
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 12.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProductsList() {
    return FutureBuilder<List<Product>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerGrid();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _buildErrorState(snapshot.error.toString());
        }
        final products = snapshot.data!;
        if (products.isEmpty) return _buildEmptyState();

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  childAspectRatio: 0.62,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ProductCardWidget(
                    key: ValueKey(products[index].id),
                    product: products[index],
                  ),
                  childCount: products.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildTrustGuarantees(),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrustGuarantees() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.verified_user_outlined,
                    color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CropSync Input Assurance',
                    style: GoogleFonts.googleSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Certified products directly from registered suppliers',
                    style: GoogleFonts.googleSans(
                      fontSize: 11.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 12),
          _buildAssuranceRow(
            Icons.local_shipping_outlined,
            'Direct Farm Delivery',
            'Orders coordinated with local Custom Hiring Centers and dealers.',
          ),
          const SizedBox(height: 10),
          _buildAssuranceRow(
            Icons.shield_outlined,
            'Sealed Manufacturer Packaging',
            'Tamper-evident bags and bottles with official batch certificates.',
          ),
          const SizedBox(height: 10),
          _buildAssuranceRow(
            Icons.support_agent_outlined,
            'Direct Dealer Assistance',
            'Call or send direct enquiries to verified agricultural dealers.',
          ),
        ],
      ),
    );
  }

  Widget _buildAssuranceRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF2563EB)),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.googleSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                desc,
                style: GoogleFonts.googleSans(
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

  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF8FAFC),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 280,
          childAspectRatio: 0.62,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            context.tr('no_products_found'),
            style: GoogleFonts.googleSans(
              color: const Color(0xFF64748B),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Text(
        context.tr('error_message', namedArgs: {'error': error}),
        style: GoogleFonts.googleSans(color: Colors.red[600]),
      ),
    );
  }

  void _showFilterBottomSheet() {
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.tr('sort_by'),
                    style: GoogleFonts.googleSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSortTile(
                    label: context.tr('relevance'),
                    value: 'default',
                    setSheetState: setSheetState,
                  ),
                  _buildSortTile(
                    label: context.tr('price_low_to_high'),
                    value: 'price_asc',
                    setSheetState: setSheetState,
                  ),
                  _buildSortTile(
                    label: context.tr('price_high_to_low'),
                    value: 'price_desc',
                    setSheetState: setSheetState,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _loadProducts();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        context.tr('apply_filters'),
                        style: GoogleFonts.googleSans(
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

  Widget _buildSortTile({
    required String label,
    required String value,
    required StateSetter setSheetState,
  }) {
    final isSelected = _sortOrder == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setSheetState(() => _sortOrder = value);
          setState(() => _sortOrder = value);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.googleSans(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 14,
                  color: isSelected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF475569),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_rounded,
                    color: Color(0xFF0F172A), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// iOS-Inspired Product Card with Continuous Squircles & Tactile Press
class _ProductCardWidget extends StatefulWidget {
  final Product product;
  const _ProductCardWidget({super.key, required this.product});

  @override
  State<_ProductCardWidget> createState() => _ProductCardWidgetState();
}

class _ProductCardWidgetState extends State<_ProductCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _controller.forward();
      },
      onTapUp: (_) {
        _controller.reverse();
        FarmerAnalyticsService.logShopItemView(
          productId: widget.product.id,
          productName: widget.product.name,
          category: widget.product.category,
          price: widget.product.price,
          advertiserName: widget.product.advertiserName,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailsScreen(product: widget.product),
          ),
        );
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image Studio Showcase
              Expanded(
                flex: 12,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.all(12),
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
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // iOS Pill Badge (Hot / Category)
                    if (widget.product.isPopular)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'HOT',
                            style: GoogleFonts.googleSans(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    // Floating Frosted Glass Share Button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.88),
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
                                padding: const EdgeInsets.all(5.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.share_outlined,
                                  size: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Product Metadata & iOS Pricing
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.advertiserName.toUpperCase(),
                      style: GoogleFonts.googleSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.product.name,
                      style: GoogleFonts.googleSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '₹${widget.product.price}',
                          style: GoogleFonts.googleSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'View',
                            style: GoogleFonts.googleSans(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }
}
