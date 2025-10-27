// lib/screens/agri_shop.dart

// ignore_for_file: use_build_context_synchronously

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cropsync/main.dart'; // Assuming supabase here
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'product_details_screen.dart'; // Your redesigned details screen

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
  final int id; // Add for navigation
  final int advertiserId; // Add for purchase requests

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
  String _selectedCategory = 'All';
  String _sortOrder = 'default'; // 'price_asc', 'price_desc'
  final TextEditingController _searchController = TextEditingController();
  bool _isInit = true; // Flag for didChangeDependencies

  @override
  void initState() {
    super.initState();
    // Data fetching moved to didChangeDependencies
  }

  // FIX 1: Use didChangeDependencies to safely initialize
  // futures that depend on 'context'.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _categoriesFuture = _fetchCategories();
      _loadProducts(); // This will also use the correct locale
      _isInit = false;
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

  // FIX 2: Added helper to get locale code
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
      // FIX 3: Localized category fetching
      final locale = _getLocaleField(context.locale.languageCode);
      // Assumes 'category' is Telugu, as per your schema
      final categoryField = locale == 'en'
          ? 'category_en'
          : (locale == 'hi' ? 'category_hi' : 'category');

      final response = await supabase
          .from('products')
          .select(categoryField) // Fetch localized category
          .not(categoryField, 'is', null);

      final Set<String> unique =
          response.map((p) => (p[categoryField] as String).trim()).toSet();
      return [
        context.tr('all_category'),
        ...unique.map((c) => c.replaceAllMapped(
            RegExp(r'\b\w'), (m) => m.group(0)!.toUpperCase()))
      ];
    } catch (e) {
      return [context.tr('all_category')];
    }
  }

  // FIX 4: Fully localized query building
  Future<List<Product>> _fetchProducts(
      {String? category, String? search, String? sort}) async {
    // Get localized field names
    final locale = _getLocaleField(context.locale.languageCode);
    final nameField = 'product_name_$locale';
    final descField = 'description_$locale';
    final categoryField = locale == 'en'
        ? 'category_en'
        : (locale == 'hi' ? 'category_hi' : 'category');

    PostgrestFilterBuilder query = supabase.from('products').select(
        'id, advertiser_id, product_code, '
        '$categoryField, category_en, category, ' // Select localized category + fallbacks
        '$nameField, product_name_en, ' // Select localized name + fallback
        'price, '
        '$descField, description_en, ' // Select localized desc + fallback
        'video_url, image_url_1, image_url_2, image_url_3, '
        'advertisers(advertiser_name)');

    // Apply FILTERS
    if (category != null && category != context.tr('all_category')) {
      // Filter on the same localized field we fetched
      query = query.eq(categoryField, category.toLowerCase());
    }
    if (search != null && search.isNotEmpty) {
      // Search on the localized name and description
      query = query.or('$nameField.ilike.%$search%,$descField.ilike.%$search%');
    }

    // Apply TRANSFORMS (Sorting)
    if (sort != null && sort != 'default') {
      final ascending = sort == 'price_asc';
      final transformedQuery = query.order('price', ascending: ascending);
      final response = await transformedQuery;
      return _mapResponseToProducts(response, locale); // Pass locale
    } else {
      final response = await query;
      return _mapResponseToProducts(response, locale); // Pass locale
    }
  }

  // FIX 5: Localized mapping with fallbacks
  List<Product> _mapResponseToProducts(List<dynamic> response, String locale) {
    // Get field names again for parsing
    final nameField = 'product_name_$locale';
    final descField = 'description_$locale';
    final categoryField = locale == 'en'
        ? 'category_en'
        : (locale == 'hi' ? 'category_hi' : 'category');

    return response.map((p) {
      final priceValue = p['price'] as num? ?? 0;
      return Product(
        id: p['id'],
        advertiserId: p['advertiser_id'],
        // Use localized name, fallback to English, then to 'N/A'
        name: p[nameField] ?? p['product_name_en'] ?? 'N/A',
        // Use localized category, fallback to English, then to Telugu, then 'General'
        category:
            p[categoryField] ?? p['category_en'] ?? p['category'] ?? 'General',
        price: priceValue.toStringAsFixed(0),
        // Use localized description, fallback to English, then to default text
        description:
            p[descField] ?? p['description_en'] ?? context.tr('no_description'),
        imageUrl1: p['image_url_1'],
        imageUrl2: p['image_url_2'],
        imageUrl3: p['image_url_3'],
        videoUrl: p['video_url'],
        advertiserName: p['advertisers']?['advertiser_name'] ??
            context.tr('unknown_seller'),
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

  // ... (Rest of your UI code remains exactly the same) ...
  // No changes needed in build, _buildSearchAndFilters, _buildCategoryTabs,
  // _buildProductsList, _buildProductCard, _buildShimmerGrid,
  // _buildEmptyState, _buildErrorState, or _showFilterBottomSheet.
  // ... (The rest of your UI code for AgriShopScreen remains the same...)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // Apple-like background
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
        centerTitle: true,
        title: Text(
          context.tr('crop_sync_market'),
          style: GoogleFonts.lexend(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(child: _buildSearchAndFilters()),
          SliverAppBar(
            backgroundColor: const Color(0xFFF5F5F7),
            pinned: true,
            automaticallyImplyLeading: false,
            toolbarHeight: 60,
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
          color: const Color(0xFFF5F5F7),
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7, // Adjusted for new design
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
                  // NOTE: The RadioListTile deprecation warning is for a future version.
                  // This implementation is the current standard and correct way to use it.
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
                        _loadProducts(); // Apply the sort
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
