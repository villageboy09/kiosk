import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/models/news_article.dart';
import 'package:cropsync/screens/news/news_detail_screen.dart';
import 'package:cropsync/screens/creator/creator_home_screen.dart';
import 'package:cropsync/services/news_service.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

/// Way2News & Inshorts Style News Cards Feed
/// Designed to seamlessly match CropSync's modern, clean, light green theme
class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();

  List<NewsArticle> _articles = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isCreator = false;

  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _isSearchExpanded = false;
  int _currentPageIndex = 0;

  Timer? _viewTrackerTimer;

  final List<Map<String, dynamic>> _categories = [
    {'key': 'all', 'label': 'news_category_all', 'emoji': '⚡', 'default': 'All News'},
    {'key': 'Govt Schemes', 'label': 'news_category_schemes', 'emoji': '🏛️', 'default': 'Govt Schemes'},
    {'key': 'Market & MSP', 'label': 'news_category_market', 'emoji': '📈', 'default': 'Market & MSP'},
    {'key': 'Tech & Drones', 'label': 'news_category_tech', 'emoji': '🛰️', 'default': 'Tech & Drones'},
    {'key': 'Weather & Climate', 'label': 'news_category_weather', 'emoji': '🌦️', 'default': 'Weather'},
    {'key': 'Farming Tips', 'label': 'news_category_tips', 'emoji': '🌱', 'default': 'Farming Tips'},
  ];

  @override
  void initState() {
    super.initState();
    _checkCreatorStatus();
    _loadArticles();
  }

  @override
  void dispose() {
    _viewTrackerTimer?.cancel();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkCreatorStatus() async {
    final isCreator = await AuthService.isCreator();
    if (mounted) {
      setState(() => _isCreator = isCreator);
    }
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
        _currentPageIndex = 0;
      });

      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }

      _scheduleViewTracking(0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load news. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _onCategorySelected(String key) {
    if (_selectedCategory == key) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategory = key;
    });
    _loadArticles();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPageIndex = index;
    });
    _scheduleViewTracking(index);
  }

  void _scheduleViewTracking(int index) {
    _viewTrackerTimer?.cancel();
    if (index >= 0 && index < _articles.length) {
      _viewTrackerTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted && _currentPageIndex == index) {
          NewsService.incrementView(_articles[index].id);
        }
      });
    }
  }

  void _updateArticleInList(NewsArticle updated) {
    setState(() {
      final idx = _articles.indexWhere((a) => a.id == updated.id);
      if (idx != -1) {
        _articles[idx] = updated;
      }
    });
  }

  void _openArticleDetail(NewsArticle article) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      NewsDetailScreen.route(article),
    ).then((_) {
      _loadArticles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Clean, light slate background matching app theme
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Clean, Modern Header Bar (White surface)
            _buildTopNavBar(),

            // Horizontal Category Pills (Clean light pills)
            _buildCategoryBar(),

            // Search Bar (expandable)
            if (_isSearchExpanded) _buildSearchBar(),

            // Vertical Swipe Cards Feed
            Expanded(
              child: _isLoading
                  ? const _InshortsCardShimmer()
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _articles.isEmpty
                          ? _buildEmptyState()
                          : Stack(
                              children: [
                                PageView.builder(
                                  controller: _pageController,
                                  scrollDirection: Axis.vertical,
                                  physics: const BouncingScrollPhysics(),
                                  onPageChanged: _onPageChanged,
                                  itemCount: _articles.length,
                                  itemBuilder: (context, index) {
                                    final article = _articles[index];
                                    return _InshortsNewsCard(
                                      key: ValueKey(article.id),
                                      article: article,
                                      currentIndex: index + 1,
                                      totalCount: _articles.length,
                                      onTapReadMore: () => _openArticleDetail(article),
                                      onArticleUpdated: _updateArticleInList,
                                    );
                                  },
                                ),

                                // Subtle Swipe Up Cue on First Card
                                if (_currentPageIndex == 0 && _articles.length > 1)
                                  Positioned(
                                    bottom: 12,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.70),
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.1),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.keyboard_double_arrow_up_rounded,
                                              size: 15,
                                              color: Colors.white.withValues(alpha: 0.9),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Swipe up for next news',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: Colors.white.withValues(alpha: 0.9),
                                                fontWeight: FontWeight.w600,
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
          ],
        ),
      ),
    );
  }

  Widget _buildTopNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Logo & Branding
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.newspaper_rounded,
                  color: Color(0xFF059669),
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'CropSync News',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 17.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Spacer(),

          // Creator Studio Badge
          if (_isCreator) ...[
            InkWell(
              onTap: () => CreatorHomeScreen.navigateToStudio(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_note_rounded, color: Color(0xFF059669), size: 15),
                    SizedBox(width: 4),
                    Text(
                      'Studio',
                      style: TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Search Button
          IconButton(
            icon: Icon(
              _isSearchExpanded ? Icons.close_rounded : Icons.search_rounded,
              color: const Color(0xFF475569),
              size: 21,
            ),
            onPressed: () {
              setState(() {
                _isSearchExpanded = !_isSearchExpanded;
                if (!_isSearchExpanded) {
                  _searchController.clear();
                  _searchQuery = '';
                  _loadArticles();
                }
              });
            },
            visualDensity: VisualDensity.compact,
            splashRadius: 18,
          ),

          // Refresh Button
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF475569),
              size: 21,
            ),
            onPressed: _loadArticles,
            visualDensity: VisualDensity.compact,
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar() {
    return Container(
      height: 46,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat['key'];
          final labelKey = cat['label'] as String;
          final localized = labelKey.tr();
          final displayLabel = (localized.isNotEmpty && localized != labelKey)
              ? localized
              : cat['default'] as String;
          final emoji = cat['emoji'] as String;

          return GestureDetector(
            onTap: () => _onCategorySelected(cat['key'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 5),
                  Text(
                    displayLabel,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
          textInputAction: TextInputAction.search,
          onSubmitted: (val) {
            setState(() => _searchQuery = val.trim());
            _loadArticles();
          },
          decoration: InputDecoration(
            hintText: 'Search agricultural news, schemes, weather...',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF10B981), size: 18),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, color: Color(0xFF64748B), size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                      _loadArticles();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.newspaper_rounded,
                size: 42,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No news found',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No stories match "$_searchQuery". Try different keywords.'
                  : 'No stories available in this category currently.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedCategory = 'all';
                });
                _loadArticles();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 44, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Error loading news',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadArticles,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A standalone Inshorts / Way2News Card that occupies the full viewport
class _InshortsNewsCard extends StatefulWidget {
  final NewsArticle article;
  final int currentIndex;
  final int totalCount;
  final VoidCallback onTapReadMore;
  final ValueChanged<NewsArticle> onArticleUpdated;

  const _InshortsNewsCard({
    super.key,
    required this.article,
    required this.currentIndex,
    required this.totalCount,
    required this.onTapReadMore,
    required this.onArticleUpdated,
  });

  @override
  State<_InshortsNewsCard> createState() => _InshortsNewsCardState();
}

class _InshortsNewsCardState extends State<_InshortsNewsCard> {
  late bool _hasLiked;
  late int _likesCount;
  late int _commentsCount;

  @override
  void initState() {
    super.initState();
    _hasLiked = widget.article.hasLiked;
    _likesCount = widget.article.likesCount;
    _commentsCount = widget.article.commentsCount;
  }

  @override
  void didUpdateWidget(covariant _InshortsNewsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.article != widget.article) {
      _hasLiked = widget.article.hasLiked;
      _likesCount = widget.article.likesCount;
      _commentsCount = widget.article.commentsCount;
    }
  }

  Future<void> _handleLike() async {
    HapticFeedback.lightImpact();
    final prevLiked = _hasLiked;
    final prevCount = _likesCount;

    setState(() {
      _hasLiked = !_hasLiked;
      _likesCount = _hasLiked ? _likesCount + 1 : (_likesCount > 0 ? _likesCount - 1 : 0);
    });

    final res = await NewsService.toggleLike(
      widget.article.id,
      title: widget.article.title,
      category: widget.article.category,
    );

    if (res['success'] == true) {
      final updated = widget.article.copyWith(
        hasLiked: res['is_liked'] as bool? ?? _hasLiked,
        likesCount: res['likes_count'] as int? ?? _likesCount,
      );
      widget.onArticleUpdated(updated);
    } else {
      setState(() {
        _hasLiked = prevLiked;
        _likesCount = prevCount;
      });
    }
  }

  Future<void> _shareOnWhatsApp() async {
    HapticFeedback.selectionClick();
    final text = '🌾 *${widget.article.title}*\n\n'
        '${widget.article.summary}\n\n'
        '📲 *Read full story on CropSync:*\n'
        'https://cropsync.in/news/${widget.article.id}';

    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final webUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } else {
          await SharePlus.instance.share(ShareParams(text: text));
        }
      }
    } catch (_) {
      await SharePlus.instance.share(ShareParams(text: text));
    }
  }

  Future<void> _shareGeneral() async {
    HapticFeedback.selectionClick();
    final text = '🌾 ${widget.article.title}\n\n'
        '${widget.article.summary}\n\n'
        'Read more on CropSync App: https://cropsync.in/news/${widget.article.id}';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  void _openCommentsSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InshortsCommentsSheet(article: widget.article),
    ).then((newCount) {
      if (newCount != null && newCount != _commentsCount) {
        setState(() => _commentsCount = newCount);
        widget.onArticleUpdated(widget.article.copyWith(commentsCount: newCount));
      }
    });
  }

  String _formatTimeAgo(DateTime? dt) {
    if (dt == null) return 'Recent';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return m <= 1 ? 'Just now' : '$m mins ago';
    } else if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h hr${h > 1 ? 's' : ''} ago';
    } else if (diff.inDays < 7) {
      final d = diff.inDays;
      return '$d day${d > 1 ? 's' : ''} ago';
    } else {
      return DateFormat('dd MMM yyyy').format(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.article.imageUrl != null && widget.article.imageUrl!.trim().isNotEmpty;
    final timeAgo = _formatTimeAgo(widget.article.publishedAt ?? widget.article.createdAt);
    final isTelugu = context.locale.languageCode == 'te';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. TOP HERO MEDIA FRAME (Fixed height so wide banners look natural)
          SizedBox(
            height: 220,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasImage)
                  CachedNetworkImage(
                    imageUrl: widget.article.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: const Color(0xFFF1F5F9),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => _buildImageFallback(),
                  )
                else
                  _buildImageFallback(),

                // Subtle top gradient for chip readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                // Top Badges Overlay
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Row(
                    children: [
                      // Category Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
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
                            const SizedBox(width: 5),
                            Text(
                              widget.article.category,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Time Ago Chip & Page Counter
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule_rounded, size: 12, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              timeAgo,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.currentIndex}/${widget.totalCount}',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Source watermark bottom left
                Positioned(
                  bottom: 8,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.60),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded, size: 13, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(
                          widget.article.sourceName.isNotEmpty ? widget.article.sourceName : 'CropSync',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. STORY SECTION
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Headline (Bold, high impact)
                  Text(
                    widget.article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isTelugu ? 17.5 : 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      height: 1.32,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Concise Story Body (Scrollable if long, no empty void if short)
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        widget.article.summary.isNotEmpty
                            ? widget.article.summary
                            : widget.article.content,
                        style: TextStyle(
                          fontSize: isTelugu ? 14 : 14.5,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF334155),
                          height: 1.55,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Reporter attribution line & tap for details
                  InkWell(
                    onTap: widget.onTapReadMore,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Text(
                            'Short by ${widget.article.author}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Read full story',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF059669),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: Color(0xFF059669),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Divider
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

          // 3. BOTTOM ACTION BAR (Clean Way2News Style)
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            color: const Color(0xFFFAFAFA),
            child: Row(
              children: [
                // WhatsApp Share Button (Way2News style)
                InkWell(
                  onTap: _shareOnWhatsApp,
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.40), width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share_rounded, size: 14, color: Color(0xFF25D366)),
                        SizedBox(width: 5),
                        Text(
                          'WhatsApp',
                          style: TextStyle(
                            color: Color(0xFF1E8E48),
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Like Button
                InkWell(
                  onTap: _handleLike,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _hasLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 19,
                          color: _hasLiked ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_likesCount',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _hasLiked ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Comments Button
                InkWell(
                  onTap: _openCommentsSheet,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_commentsCount',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // General Share
                IconButton(
                  onPressed: _shareGeneral,
                  icon: const Icon(
                    Icons.share_outlined,
                    size: 19,
                    color: Color(0xFF64748B),
                  ),
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFE2E8F0),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.agriculture_rounded,
              size: 44,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 6),
            Text(
              widget.article.category,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slide-up Comments Sheet directly on top of the Inshorts Card
class _InshortsCommentsSheet extends StatefulWidget {
  final NewsArticle article;

  const _InshortsCommentsSheet({required this.article});

  @override
  State<_InshortsCommentsSheet> createState() => _InshortsCommentsSheetState();
}

class _InshortsCommentsSheetState extends State<_InshortsCommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  List<NewsComment> _comments = [];
  bool _isLoading = true;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    try {
      final items = await NewsService.getComments(widget.article.id);
      if (!mounted) return;
      setState(() {
        _comments = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isPosting) return;

    HapticFeedback.selectionClick();
    setState(() => _isPosting = true);

    final comment = await NewsService.addComment(
      articleId: widget.article.id,
      commentText: text,
      articleTitle: widget.article.title,
      category: widget.article.category,
    );

    if (!mounted) return;
    setState(() {
      _isPosting = false;
      if (comment != null) {
        _comments.insert(0, comment);
        _commentController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_rounded, size: 18, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Text(
                  'Comments (${_comments.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context, _comments.length),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Comments List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                : _comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.forum_outlined, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text(
                              'No comments yet. Be the first to share!',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _comments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final c = _comments[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          c.userName.isNotEmpty ? c.userName[0].toUpperCase() : 'F',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      c.userName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Farmer',
                                        style: TextStyle(
                                          color: Color(0xFF059669),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  c.commentText,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF334155),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Comment Input Box
          Container(
            padding: EdgeInsets.fromLTRB(14, 8, 14, MediaQuery.of(context).viewInsets.bottom + 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isPosting ? null : _submitComment,
                  icon: _isPosting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                        )
                      : const Icon(Icons.send_rounded, color: Color(0xFF10B981)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer Skeleton matching the Inshorts card geometry
class _InshortsCardShimmer extends StatelessWidget {
  const _InshortsCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFE2E8F0),
        highlightColor: const Color(0xFFF1F5F9),
        child: Column(
          children: [
            // Top Image Shimmer
            Container(
              height: 220,
              color: Colors.white,
            ),
            // Middle Content Shimmer
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 20, width: double.infinity, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(height: 20, width: 220, color: Colors.white),
                    const SizedBox(height: 16),
                    Container(height: 14, width: double.infinity, color: Colors.white),
                    const SizedBox(height: 6),
                    Container(height: 14, width: double.infinity, color: Colors.white),
                    const SizedBox(height: 6),
                    Container(height: 14, width: 260, color: Colors.white),
                  ],
                ),
              ),
            ),
            // Bottom Bar Shimmer
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  Container(height: 28, width: 85, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(100))),
                  const Spacer(),
                  Container(height: 20, width: 35, color: Colors.white),
                  const SizedBox(width: 16),
                  Container(height: 20, width: 35, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
