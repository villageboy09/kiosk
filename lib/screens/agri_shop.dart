// lib/screens/agri_shop.dart

// ignore_for_file: use_build_context_synchronously

import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:easy_localization/easy_localization.dart';
import 'product_details_screen.dart';

// Same Product model as before...
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
  String _selectedCategory = '';
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
      _selectedCategory = context.tr('all_category');
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
        context.tr('all_category'),
        ...categories.map((c) => c.replaceAllMapped(
            RegExp(r'\b\w'), (m) => m.group(0)!.toUpperCase()))
      ];
    } catch (e) {
      return [context.tr('all_category')];
    }
  }

  Future<List<Product>> _fetchProducts(
      {String? category, String? search, String? sort}) async {
    try {
      final locale = _getLocaleField(context.locale.languageCode);

      // Determine category filter
      String? categoryFilter;
      if (category != null && category != context.tr('all_category')) {
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
      // Safely parse price, handling both String ("60000.00") and num (60000)
      final priceString = p['price']?.toString() ?? '0';
      final priceValue = double.tryParse(priceString) ?? 0.0;

      return Product(
        id: int.tryParse(
                p['product_id']?.toString() ?? p['id']?.toString() ?? '0') ??
            0,
        advertiserId: int.tryParse(p['advertiser_id']?.toString() ?? '0') ?? 0,
        name: p['product_name']?.toString() ??
            p['name']?.toString() ??
            'N/A', // Handle schema diffs
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
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            centerTitle: false,
            leadingWidth: 0,
            leading: null,
            title: Text(
              context.tr('crop_sync_market'),
              style: GoogleFonts.lexend(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A1A),
                letterSpacing: -0.5,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildSearchAndFilters(),
            ),
          ),
          SliverAppBar(
            backgroundColor: Colors.white,
            pinned: true,
            primary: false,
            automaticallyImplyLeading: false,
            toolbarHeight: 60,
            elevation: 0,
            flexibleSpace: _buildCategoryTabs(),
          )
        ],
        body: _buildProductsList(),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.tr('search_products'),
                hintStyle: GoogleFonts.lexend(color: Colors.grey[500]),
                prefixIcon:
                    Icon(Icons.search, color: Colors.grey[500], size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                if (value.length > 2 || value.isEmpty) {
                  _searchQuery = value;
                  _loadProducts();
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              fixedSize: const Size(50, 50),
            ),
            icon: Icon(Icons.tune_rounded, color: Colors.green.shade700),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
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
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
          ),
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = _selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(category),
                  labelStyle: GoogleFonts.lexend(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  selected: isSelected,
                  selectedColor: Colors.green.shade600,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = category);
                      _loadProducts();
                    }
                  },
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
        return AnimationLimiter(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) =>
                AnimationConfiguration.staggeredGrid(
              position: index,
              duration: const Duration(milliseconds: 375),
              columnCount: 2,
              child: ScaleAnimation(
                child: FadeInAnimation(
                  child: _buildProductCard(products[index]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ProductDetailsScreen(product: product)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Hero(
                tag: 'product_image_${product.id}',
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl1 ?? '',
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: Colors.grey.shade100),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.shade100,
                      child: Icon(Icons.eco_outlined,
                          color: Colors.grey.shade300, size: 40),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: GoogleFonts.lexend(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('per_unit', namedArgs: {'unit': product.unit}),
                    style: GoogleFonts.lexend(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${product.price}',
                    style: GoogleFonts.lexend(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[50]!,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Text(context.tr('no_products_found')));
  }

  Widget _buildErrorState(String error) {
    return Center(
        child: Text(context.tr('error_message', namedArgs: {'error': error})));
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(context.tr('sort_by'),
                      style: GoogleFonts.lexend(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  RadioGroup<String>(
                    groupValue: _sortOrder,
                    onChanged: (String? value) {
                      setSheetState(() {
                        _sortOrder = value!;
                      });
                    },
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          title: Text(context.tr('relevance'),
                              style: GoogleFonts.lexend()),
                          value: 'default',
                          activeColor: Colors.green.shade600,
                        ),
                        RadioListTile<String>(
                          title: Text(context.tr('price_low_to_high'),
                              style: GoogleFonts.lexend()),
                          value: 'price_asc',
                          activeColor: Colors.green.shade600,
                        ),
                        RadioListTile<String>(
                          title: Text(context.tr('price_high_to_low'),
                              style: GoogleFonts.lexend()),
                          value: 'price_desc',
                          activeColor: Colors.green.shade600,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _loadProducts();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(context.tr('apply_filters'),
                          style: GoogleFonts.lexend(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
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
}
