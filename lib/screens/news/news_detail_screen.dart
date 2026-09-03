import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/models/news_article.dart';
import 'package:cropsync/services/news_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/creator_service.dart';

/// Clean, Editorial, Minimalist News Article Detail View
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

  late bool _isLiked;
  late int _likesCount;
  late int _commentsCount;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _commentsSectionKey = GlobalKey();

  bool _isAuthor = false;

  @override
  void initState() {
    super.initState();
    _article = widget.article;
    _isLiked = widget.article.hasLiked;
    _likesCount = widget.article.likesCount;
    _commentsCount = widget.article.commentsCount;

    _checkAuthor();
    _loadArticleData();
  }

  Future<void> _checkAuthor() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null && mounted) {
        final authorLower = _article.author.toLowerCase().trim();
        final userNameLower = user.name.toLowerCase().trim();
        if (authorLower == userNameLower || authorLower.contains(userNameLower) || user.isCreator) {
          setState(() => _isAuthor = true);
        }
      }
    } catch (_) {}
  }

  Future<void> _deleteArticleConfirm() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Article?'),
        content: const Text('Are you sure you want to delete this article? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await CreatorService.deleteArticle(_article.id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Article deleted successfully')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete article. Please try again.')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadArticleData() async {
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
        _likesCount = res['likes_count'] as int? ?? _likesCount;
      });
    } else {
      setState(() {
        _isLiked = prevLiked;
        _likesCount = prevCount;
      });
    }
  }

  Future<void> _shareOnWhatsApp() async {
    HapticFeedback.selectionClick();
    final text = '🌾 *${_article.title}*\n\n'
        '${_article.summary.isNotEmpty ? _article.summary : _article.content}\n\n'
        '📲 *Read full story on CropSync:*\n'
        'https://cropsync.in/news/${_article.id}';

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

  void _shareGeneral() {
    HapticFeedback.lightImpact();
    final text = '🌾 ${_article.title}\n\n'
        '${_article.summary.isNotEmpty ? _article.summary : _article.content}\n\n'
        'Read more on CropSync App: https://cropsync.in/news/${_article.id}';
    SharePlus.instance.share(ShareParams(text: text, subject: _article.title));
  }

  void _openCommentBottomSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet<NewsComment>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ArticleCommentModal(
        article: _article,
        onCommentAdded: (newComment) {
          setState(() {
            _comments.insert(0, newComment);
            _commentsCount++;
          });
        },
      ),
    );
  }

  void _scrollToComments() {
    final context = _commentsSectionKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('MMMM d, yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final hasImage = _article.imageUrl != null && _article.imageUrl!.trim().isNotEmpty;
    final formattedDate = _formatDate(_article.publishedAt ?? _article.createdAt);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
          splashRadius: 20,
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                _article.category.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF059669),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (_isAuthor)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
              onPressed: _deleteArticleConfirm,
              splashRadius: 20,
              tooltip: 'Delete Article',
            ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Color(0xFF475569), size: 21),
            onPressed: _shareGeneral,
            splashRadius: 20,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Scrollable Story Content
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isTablet ? 720 : double.infinity),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 36 : 20,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Title (Clean, bold editorial headline)
                          Text(
                            _article.title,
                            style: TextStyle(
                              fontSize: isTablet ? 26 : 22,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              height: 1.34,
                              letterSpacing: -0.4,
                            ),
                          ),

                          const SizedBox(height: 14),

                          // 2. Byline & Timestamp
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.12),
                                child: Text(
                                  _article.author.isNotEmpty ? _article.author[0].toUpperCase() : 'C',
                                  style: const TextStyle(
                                    color: Color(0xFF059669),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          _article.author,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                        if (_article.sourceName.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _article.sourceName,
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        if (formattedDate.isNotEmpty) formattedDate,
                                        '${_article.estimatedReadTimeMinutes} min read',
                                      ].join(' • '),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // 3. Hero Image (Proportional with subtle border & shadow)
                          if (hasImage) ...[
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: CachedNetworkImage(
                                imageUrl: _article.imageUrl!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  height: 200,
                                  color: const Color(0xFFF1F5F9),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            ),
                            const SizedBox(height: 22),
                          ],

                          // 4. Lead Summary (if present)
                          if (_article.summary.isNotEmpty && _article.summary != _article.content) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: const Border(
                                  left: BorderSide(color: Color(0xFF10B981), width: 3.5),
                                ),
                              ),
                              child: Text(
                                _article.summary,
                                style: TextStyle(
                                  fontSize: isTablet ? 16 : 15,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF334155),
                                  height: 1.55,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // 5. Full Story Body
                          Text(
                            _article.content.isNotEmpty ? _article.content : _article.summary,
                            style: TextStyle(
                              fontSize: isTablet ? 16 : 15,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF1E293B),
                              height: 1.75,
                              letterSpacing: 0.1,
                            ),
                          ),

                          const SizedBox(height: 32),

                          // 6. Share Section Banner
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Share this update',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Help fellow farmers stay informed with daily news',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: _shareOnWhatsApp,
                                  icon: const Icon(Icons.share_rounded, size: 15, color: Colors.white),
                                  label: const Text('WhatsApp'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 36),

                          // 7. Comments Header
                          Container(
                            key: _commentsSectionKey,
                            child: Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline_rounded, size: 20, color: Color(0xFF0F172A)),
                                const SizedBox(width: 8),
                                Text(
                                  'Comments (${_comments.length})',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: _openCommentBottomSheet,
                                  icon: const Icon(Icons.add_comment_rounded, size: 16, color: Color(0xFF10B981)),
                                  label: const Text(
                                    'Write Comment',
                                    style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // 8. Comments List
                          if (_isLoadingComments)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                              ),
                            )
                          else if (_comments.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.chat_bubble_outline_rounded, size: 36, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No comments yet.',
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Be the first to share your thoughts on this story!',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _comments.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final c = _comments[index];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 13,
                                            backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                                            child: Text(
                                              c.userName.isNotEmpty ? c.userName[0].toUpperCase() : 'F',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF059669),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            c.userName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            c.formattedDate,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 34),
                                        child: Text(
                                          c.commentText,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF334155),
                                            height: 1.45,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                          const SizedBox(height: 80), // Extra space for fixed action bar
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 9. Clean Docked Action Bar at bottom
            Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Like Button
                  InkWell(
                    onTap: _toggleLike,
                    borderRadius: BorderRadius.circular(100),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 21,
                            color: _isLiked ? const Color(0xFFEF4444) : const Color(0xFF475569),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$_likesCount',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _isLiked ? const Color(0xFFEF4444) : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Comment Button
                  InkWell(
                    onTap: _scrollToComments,
                    borderRadius: BorderRadius.circular(100),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 20,
                            color: Color(0xFF475569),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$_commentsCount',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Add Comment Button
                  OutlinedButton.icon(
                    onPressed: _openCommentBottomSheet,
                    icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF10B981)),
                    label: const Text('Comment'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // WhatsApp Share
                  IconButton(
                    onPressed: _shareOnWhatsApp,
                    icon: const Icon(Icons.share_rounded, color: Color(0xFF25D366), size: 21),
                    tooltip: 'Share on WhatsApp',
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Comment Bottom Sheet Modal for clean commenting without keyboard layout distortion
class _ArticleCommentModal extends StatefulWidget {
  final NewsArticle article;
  final ValueChanged<NewsComment> onCommentAdded;

  const _ArticleCommentModal({
    required this.article,
    required this.onCommentAdded,
  });

  @override
  State<_ArticleCommentModal> createState() => _ArticleCommentModalState();
}

class _ArticleCommentModalState extends State<_ArticleCommentModal> {
  final TextEditingController _commentController = TextEditingController();
  bool _isPosting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
    setState(() => _isPosting = false);

    if (comment != null) {
      widget.onCommentAdded(comment);
      Navigator.pop(context, comment);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Write a Comment',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            autofocus: true,
            maxLines: 4,
            minLines: 2,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Share your perspective or ask a question...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF10B981)),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isPosting ? null : _submit,
                icon: _isPosting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                label: const Text('Post Comment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
