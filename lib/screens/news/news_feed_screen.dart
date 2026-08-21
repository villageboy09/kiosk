import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/models/news_article.dart';
import 'package:cropsync/screens/news/news_detail_screen.dart';
import 'package:cropsync/screens/creator/creator_studio_screen.dart';
import 'package:cropsync/services/news_service.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

/// News & Insights feed tab for farmers
class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all';

  List<NewsArticle> _articles = [];
  bool _isLoading = true;
  String? _errorMessage;

  final List<Map<String, dynamic>> _categories = [
    {'key': 'all', 'label': 'news_category_all', 'icon': Icons.grid_view_rounded},
    {'key': 'Govt Schemes', 'label': 'news_category_schemes', 'icon': null},
    {'key': 'Market & MSP', 'label': 'news_category_market', 'icon': null},
    {'key': 'Tech & Drones', 'label': 'news_category_tech', 'icon': null},
    {'key': 'Weather & Climate', 'label': 'news_category_weather', 'icon': null},
    {'key': 'Farming Tips', 'label': 'news_category_tips', 'icon': null},
  ];

  @override
  void initState() {
    super.initState();
    _loadArticles();
    _searchController.addListener(() {
      final text = _searchController.text.trim();
      if (_searchQuery != text) {
        setState(() => _searchQuery = text);
        _filterArticles();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadArticles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await NewsService.getArticles(
        category: _selectedCategory,
        searchQuery: _searchQuery,
      );
      if (!mounted) return;
      setState(() {
        _articles = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load news. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _filterArticles() async {
    final items = await NewsService.getArticles(
      category: _selectedCategory,
      searchQuery: _searchQuery,
    );
    if (!mounted) return;
    setState(() {
      _articles = items;
    });
  }

  void _onCategorySelected(String key) {
    if (_selectedCategory == key) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategory = key;
    });
    _loadArticles();
  }

  void _openArticle(NewsArticle article) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      NewsDetailScreen.route(article),
    ).then((_) {
      // Refresh feed in background to update views/likes count
      _filterArticles();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 600;

    final featuredArticles = _articles.where((a) => a.isFeatured).toList();
    final NewsArticle? topFeatured = featuredArticles.isNotEmpty ? featuredArticles.first : null;
    final nonFeaturedArticles = topFeatured != null
        ? _articles.where((a) => a.id != topFeatured.id).toList()
        : _articles;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        top: false,
        child: RefreshIndicator.adaptive(
          onRefresh: _loadArticles,
          color: AppTheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Top Search & Header Banner
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: EdgeInsets.fromLTRB(
                    isTablet ? 28 : 16,
                    16,
                    isTablet ? 28 : 16,
                    14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Screen Header Title
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.newspaper_rounded,
                              color: AppTheme.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'news_title'.tr(),
                                  style: TextStyle(
                                    fontSize: isTablet ? 22 : 19,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF111827),
                                  ),
                                ),
                                Text(
                                  'news_subtitle'.tr(),
                                  style: TextStyle(
                                    fontSize: isTablet ? 13 : 12,
                                    color: const Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const CreatorStudioScreen()),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 18),
                                  SizedBox(width: 4),
                                  Text(
                                    'Studio',
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Pill-Shaped Search Bar
                      Container(
                        height: isTablet ? 52 : 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          textAlignVertical: TextAlignVertical.center,
                          style: TextStyle(
                            fontSize: isTablet ? 15 : 14,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'news_search_hint'.tr(),
                            hintStyle: TextStyle(
                              fontSize: isTablet ? 13.5 : 12.5,
                              color: const Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF9CA3AF),
                              size: 20,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      color: Color(0xFF9CA3AF),
                                      size: 18,
                                    ),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                            filled: false,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Category Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: _categories.map((cat) {
                            final key = cat['key'] as String;
                            final label = (cat['label'] as String).tr();
                            final icon = cat['icon'] as IconData?;
                            final isSelected = _selectedCategory == key;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => _onCategorySelected(key),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.primary : Colors.white,
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: isSelected ? AppTheme.primary : const Color(0xFFE5E7EB),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppTheme.primary.withValues(alpha: 0.20),
                                              blurRadius: 8,
                                              spreadRadius: 0,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.02),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (icon != null) ...[
                                        Icon(
                                          icon,
                                          size: 14,
                                          color: isSelected ? Colors.white : AppTheme.textSecondary,
                                        ),
                                        const SizedBox(width: 5),
                                      ],
                                      Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content Area
              if (_isLoading)
                _buildLoadingSliver(isTablet)
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(_errorMessage!, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadArticles,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_articles.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.newspaper_outlined, size: 56, color: Colors.grey[300]),
                          const SizedBox(height: 14),
                          Text(
                            'news_empty_title'.tr(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'news_empty_subtitle'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                // Hero Featured Article Banner
                if (topFeatured != null && _searchQuery.isEmpty && _selectedCategory == 'all')
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      isTablet ? 28 : 16,
                      16,
                      isTablet ? 28 : 16,
                      8,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _FeaturedHeroCard(
                        article: topFeatured,
                        isTablet: isTablet,
                        onTap: () => _openArticle(topFeatured),
                      ),
                    ),
                  ),

                // Latest Articles Grid / List
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    isTablet ? 28 : 16,
                    8,
                    isTablet ? 28 : 16,
                    28,
                  ),
                  sliver: isTablet
                      ? SliverGrid(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 420,
                            crossAxisSpacing: 18,
                            mainAxisSpacing: 18,
                            childAspectRatio: 0.82,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final article = nonFeaturedArticles[index];
                              return _TabletNewsCard(
                                article: article,
                                onTap: () => _openArticle(article),
                              );
                            },
                            childCount: nonFeaturedArticles.length,
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final article = nonFeaturedArticles[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _MobileNewsCard(
                                  article: article,
                                  onTap: () => _openArticle(article),
                                ),
                              );
                            },
                            childCount: nonFeaturedArticles.length,
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSliver(bool isTablet) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 28 : 16,
        vertical: 16,
      ),
      sliver: SliverToBoxAdapter(
        child: Shimmer.fromColors(
          baseColor: Colors.grey[200]!,
          highlightColor: Colors.grey[50]!,
          child: Column(
            children: List.generate(
              4,
              (index) => Container(
                margin: const EdgeInsets.only(bottom: 14),
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Featured Hero Card for Top Agricultural Story
class _FeaturedHeroCard extends StatelessWidget {
  final NewsArticle article;
  final bool isTablet;
  final VoidCallback onTap;

  const _FeaturedHeroCard({
    required this.article,
    required this.isTablet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Image with Overlay
              Stack(
                children: [
                  SizedBox(
                    height: isTablet ? 240 : 180,
                    width: double.infinity,
                    child: article.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: article.imageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFF1E293B),
                              child: const Icon(Icons.newspaper_rounded, color: Colors.white38, size: 48),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF1E293B),
                            child: const Icon(Icons.newspaper_rounded, color: Colors.white38, size: 48),
                          ),
                  ),
                  // Dark bottom gradient
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.1),
                            Colors.black.withValues(alpha: 0.7),
                          ],
                          stops: const [0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Top Story Badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        ),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 13, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            'news_featured_badge'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Category Tag
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        article.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Content Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Metrics Bar (Views, Likes, Comments, Relative Time)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${article.sourceName} • ${article.formattedPublishedDate}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildMetricChip(Icons.visibility_outlined, article.viewsCount),
                        const SizedBox(width: 8),
                        _buildMetricChip(Icons.favorite_border_rounded, article.likesCount),
                        const SizedBox(width: 8),
                        _buildMetricChip(Icons.mode_comment_outlined, article.commentsCount),
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

  Widget _buildMetricChip(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

/// Mobile Card for News Feed
class _MobileNewsCard extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback onTap;

  const _MobileNewsCard({
    required this.article,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: article.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: article.imageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFFF3F4F6),
                              child: const Icon(Icons.newspaper_rounded, color: Colors.grey, size: 30),
                            ),
                          )
                        : Container(
                            color: const Color(0xFFF3F4F6),
                            child: const Icon(Icons.newspaper_rounded, color: Colors.grey, size: 30),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Text details
                Expanded(
                  child: SizedBox(
                    height: 96,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category Tag
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                article.category,
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Headline
                            Text(
                              article.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),

                        // Bottom metrics
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                article.formattedPublishedDate,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.visibility_outlined, size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 2),
                            Text(
                              '${article.viewsCount}',
                              style: TextStyle(fontSize: 10.5, color: Colors.grey[600], fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              article.hasLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 12,
                              color: article.hasLiked ? Colors.red : Colors.grey[500],
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${article.likesCount}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: article.hasLiked ? Colors.red : Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.mode_comment_outlined, size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 2),
                            Text(
                              '${article.commentsCount}',
                              style: TextStyle(fontSize: 10.5, color: Colors.grey[600], fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tablet Card for News Grid
class _TabletNewsCard extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback onTap;

  const _TabletNewsCard({
    required this.article,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              SizedBox(
                height: 150,
                width: double.infinity,
                child: article.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: article.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFFF3F4F6),
                          child: const Icon(Icons.newspaper_rounded, color: Colors.grey, size: 36),
                        ),
                      )
                    : Container(
                        color: const Color(0xFFF3F4F6),
                        child: const Icon(Icons.newspaper_rounded, color: Colors.grey, size: 36),
                      ),
              ),

              // Details
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        article.category,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          article.formattedPublishedDate,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.visibility_outlined, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${article.viewsCount}',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey[600], fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.favorite_border_rounded, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${article.likesCount}',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey[600], fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.mode_comment_outlined, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${article.commentsCount}',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey[600], fontWeight: FontWeight.w600),
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
