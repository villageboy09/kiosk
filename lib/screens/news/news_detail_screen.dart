import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/models/news_article.dart';
import 'package:cropsync/services/news_service.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Detailed view for a Krishi News article with live views, likes, and comments
class NewsDetailScreen extends StatefulWidget {
  final NewsArticle article;

  const NewsDetailScreen({
    super.key,
    required this.article,
  });

  static Route<void> route(NewsArticle article) {
    return MaterialPageRoute(
      builder: (context) => NewsDetailScreen(article: article),
    );
  }

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  late NewsArticle _article;
  List<NewsComment> _comments = [];
  bool _isLoadingComments = true;
  bool _isPostingComment = false;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Interactive like state (optimistic update)
  late bool _isLiked;
  late int _likesCount;
  late int _viewsCount;
  late int _commentsCount;

  @override
  void initState() {
    super.initState();
    _article = widget.article;
    _isLiked = widget.article.hasLiked;
    _likesCount = widget.article.likesCount;
    _viewsCount = widget.article.viewsCount + 1; // optimistic view increment
    _commentsCount = widget.article.commentsCount;

    _loadArticleDetailsAndComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadArticleDetailsAndComments() async {
    // 1. Fetch fresh article state & comments
    final updatedArticleFuture = NewsService.getArticleDetail(_article.id, incrementView: true);
    final commentsFuture = NewsService.getComments(_article.id);

    final results = await Future.wait([updatedArticleFuture, commentsFuture]);

    if (!mounted) return;

    final updatedArticle = results[0] as NewsArticle?;
    final comments = results[1] as List<NewsComment>?;

    setState(() {
      if (updatedArticle != null) {
        _article = updatedArticle;
        _isLiked = updatedArticle.hasLiked;
        _likesCount = updatedArticle.likesCount;
        _viewsCount = updatedArticle.viewsCount;
        _commentsCount = updatedArticle.commentsCount;
      }
      if (comments != null) {
        _comments = comments;
      }
      _isLoadingComments = false;
    });
  }

  Future<void> _toggleLike() async {
    HapticFeedback.lightImpact();

    final prevLiked = _isLiked;
    final prevCount = _likesCount;

    // Optimistic UI update
    setState(() {
      _isLiked = !_isLiked;
      _likesCount = _isLiked ? _likesCount + 1 : (_likesCount > 0 ? _likesCount - 1 : 0);
    });

    final res = await NewsService.toggleLike(
      _article.id,
      title: _article.title,
      category: _article.category,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      setState(() {
        _isLiked = res['is_liked'] == true;
        _likesCount = res['likes_count'] ?? _likesCount;
      });
    } else {
      // Rollback on failure
      setState(() {
        _isLiked = prevLiked;
        _likesCount = prevCount;
      });
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('news_comment_empty_error'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => _isPostingComment = true);

    final newComment = await NewsService.addComment(
      articleId: _article.id,
      commentText: text,
      articleTitle: _article.title,
      category: _article.category,
    );

    if (!mounted) return;

    _commentController.clear();
    _commentFocusNode.unfocus();

    if (newComment != null) {
      setState(() {
        _comments.insert(0, newComment);
        _commentsCount++;
        _isPostingComment = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('news_comment_success'.tr()),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      setState(() => _isPostingComment = false);
    }
  }

  void _shareArticle() {
    HapticFeedback.lightImpact();
    final shareText = '${_article.title}\n\n${_article.summary}\n\n'
        '📲 Read more on CropSync app: https://cropsync.in/news/${_article.id}';
    SharePlus.instance.share(
      ShareParams(
        text: shareText,
        subject: _article.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // App Bar with Hero Image
                  _buildSliverAppBar(isTablet),

                  // Article Content
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isTablet ? 780 : double.infinity,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 32 : 20,
                            vertical: 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category & Read Time
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(
                                        color: AppTheme.primary.withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      _article.category,
                                      style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 13,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${_article.estimatedReadTimeMinutes} ${'news_min_read'.tr()}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _article.formattedPublishedDate,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey[500],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Headline
                              Text(
                                _article.title,
                                style: TextStyle(
                                  fontSize: isTablet ? 26 : 21,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF111827),
                                  height: 1.3,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Author & Source Row
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                                      child: const Icon(
                                        Icons.verified_user_rounded,
                                        size: 20,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _article.author,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF1F2937),
                                            ),
                                          ),
                                          Text(
                                            _article.sourceName,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Summary / Lead Paragraph
                              if (_article.summary.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(12),
                                    border: const Border(
                                      left: BorderSide(
                                        color: Color(0xFF059669),
                                        width: 4,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    _article.summary,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],

                              // Full Content Body
                              Text(
                                _article.content,
                                style: TextStyle(
                                  fontSize: isTablet ? 16 : 15,
                                  color: const Color(0xFF1F2937),
                                  height: 1.75,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.1,
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Action Metrics Row (Views, Likes, Comments, Share)
                              _buildActionMetricsBar(),

                              const SizedBox(height: 32),
                              const Divider(color: Color(0xFFE5E7EB), height: 1),
                              const SizedBox(height: 24),

                              // Comments Section Header
                              Row(
                                children: [
                                  const Icon(
                                    Icons.forum_rounded,
                                    color: Color(0xFF111827),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'news_comments_header'.tr(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      '$_commentsCount',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Comments List
                              if (_isLoadingComments)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else if (_comments.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        size: 40,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'news_no_comments'.tr(),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _comments.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final comment = _comments[index];
                                    return _buildCommentCard(comment);
                                  },
                                ),

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Sticky Bottom Comment Input Bar
            _buildBottomCommentBar(isTablet),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(bool isTablet) {
    return SliverAppBar(
      expandedHeight: isTablet ? 340 : 250,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.black,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black.withValues(alpha: 0.5),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black.withValues(alpha: 0.5),
            child: IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
              onPressed: _shareArticle,
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (_article.imageUrl != null && _article.imageUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: _article.imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFF1E293B),
                  child: const Center(
                    child: Icon(Icons.newspaper_rounded, size: 64, color: Colors.white24),
                  ),
                ),
              )
            else
              Container(
                color: const Color(0xFF1E293B),
                child: const Center(
                  child: Icon(Icons.newspaper_rounded, size: 64, color: Colors.white24),
                ),
              ),
            // Gradient overlay
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionMetricsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          // Views Count
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.visibility_rounded, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '$_viewsCount',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(width: 1, height: 18, color: const Color(0xFFE5E7EB)),

          // Like Button (Interactive)
          Expanded(
            child: InkWell(
              onTap: _toggleLike,
              borderRadius: BorderRadius.circular(100),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: _isLiked ? 1.2 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 18,
                        color: _isLiked ? const Color(0xFFEF4444) : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '$_likesCount',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _isLiked ? const Color(0xFFEF4444) : Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Container(width: 1, height: 18, color: const Color(0xFFE5E7EB)),

          // Comments Count (Tapping focuses comment input)
          Expanded(
            child: InkWell(
              onTap: () {
                _commentFocusNode.requestFocus();
              },
              borderRadius: BorderRadius.circular(100),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mode_comment_outlined, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '$_commentsCount',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Container(width: 1, height: 18, color: const Color(0xFFE5E7EB)),

          // Share Button
          Expanded(
            child: InkWell(
              onTap: _shareArticle,
              borderRadius: BorderRadius.circular(100),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.share_rounded, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Share',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[800],
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
    );
  }

  Widget _buildCommentCard(NewsComment comment) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                child: Text(
                  comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : 'F',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Farmer',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                comment.formattedDate,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Text(
              comment.commentText,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF374151),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCommentBar(bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 32 : 16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 780 : double.infinity,
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Center(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      textAlignVertical: TextAlignVertical.center,
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF111827)),
                      decoration: InputDecoration(
                        hintText: 'news_comment_hint'.tr(),
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                        isDense: true,
                        filled: false,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      onSubmitted: (_) => _submitComment(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 44,
                width: 44,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _isPostingComment ? null : _submitComment,
                    child: _isPostingComment
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


