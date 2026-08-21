import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:cropsync/models/creator_studio_model.dart';
import 'package:cropsync/models/reel_model.dart';
import 'package:cropsync/models/news_article.dart';
import 'package:cropsync/services/creator_service.dart';
import 'package:cropsync/screens/creator/upload_reel_screen.dart';
import 'package:cropsync/screens/creator/upload_news_screen.dart';
import 'package:cropsync/screens/news/news_detail_screen.dart';

class CreatorStudioScreen extends StatefulWidget {
  const CreatorStudioScreen({super.key});

  @override
  State<CreatorStudioScreen> createState() => _CreatorStudioScreenState();
}

class _CreatorStudioScreenState extends State<CreatorStudioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CreatorStudioData? _studioData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStudioData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStudioData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final data = await CreatorService.getStudioData(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _studioData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleReelActive(ReelModel reel, bool val) async {
    final success = await CreatorService.toggleReelStatus(reel.id, val);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(val ? 'Reel activated' : 'Reel hidden from public feed'),
          duration: const Duration(seconds: 2),
        ),
      );
      _loadStudioData(forceRefresh: true);
    }
  }

  Future<void> _deleteReel(ReelModel reel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('creator_delete_confirm_title'.tr()),
        content: Text('creator_delete_confirm_desc'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('creator_cancel_btn'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('creator_delete_btn'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await CreatorService.deleteReel(reel.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reel deleted successfully')),
        );
        _loadStudioData(forceRefresh: true);
      }
    }
  }

  Future<void> _deleteArticle(NewsArticle article) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('creator_delete_confirm_title'.tr()),
        content: Text('creator_delete_confirm_desc'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('creator_cancel_btn'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('creator_delete_btn'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await CreatorService.deleteNewsArticle(article.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Article deleted successfully')),
        );
        _loadStudioData(forceRefresh: true);
      }
    }
  }

  void _showCreateActionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create & Share with Farmers',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.videocam_rounded, color: AppTheme.accentGreen),
              ),
              title: Text('creator_upload_reel'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Record or upload a short farming reel'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                Navigator.of(ctx).pop();
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const UploadReelScreen()),
                );
                if (created == true) _loadStudioData(forceRefresh: true);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryDark.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.article_rounded, color: AppTheme.primaryDark),
              ),
              title: Text('creator_upload_news'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Write an agricultural update or farming advisory'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                Navigator.of(ctx).pop();
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const UploadNewsScreen()),
                );
                if (created == true) _loadStudioData(forceRefresh: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundCream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textDark, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'creator_studio_title'.tr(),
              style: const TextStyle(
                color: AppTheme.textDark,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'creator_studio_subtitle'.tr(),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _showCreateActionSheet,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryDark,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: AppTheme.accentGreen,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: 'creator_tab_reels'.tr()),
            Tab(text: 'creator_tab_news'.tr()),
            Tab(text: 'creator_tab_analytics'.tr()),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen))
          : RefreshIndicator(
              color: AppTheme.accentGreen,
              onRefresh: () => _loadStudioData(forceRefresh: true),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildReelsTab(),
                  _buildArticlesTab(),
                  _buildAnalyticsTab(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateActionSheet,
        backgroundColor: AppTheme.accentGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Content', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- REELS TAB ---
  Widget _buildReelsTab() {
    final reels = _studioData?.reels ?? [];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKPIHeader(),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${'creator_tab_reels'.tr()} (${reels.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final res = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (_) => const UploadReelScreen()),
                      );
                      if (res == true) _loadStudioData(forceRefresh: true);
                    },
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                    label: Text('creator_upload_reel'.tr(), style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.accentGreen),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (reels.isEmpty)
                _buildEmptyState(
                  icon: Icons.videocam_off_outlined,
                  title: 'creator_no_reels'.tr(),
                  subtitle: 'creator_no_reels_sub'.tr(),
                  buttonLabel: 'creator_upload_reel'.tr(),
                  onPressed: () async {
                    final res = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => const UploadReelScreen()),
                    );
                    if (res == true) _loadStudioData(forceRefresh: true);
                  },
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reels.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) => _buildReelManageCard(reels[idx]),
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReelManageCard(ReelModel reel) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 36),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reel.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.music_note_rounded, size: 13, color: AppTheme.accentGreen),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            reel.musicTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildBadge(Icons.remove_red_eye_outlined, '${reel.viewsCount} views'),
                        _buildBadge(Icons.favorite_outline, '${reel.likesRaw} likes'),
                        _buildBadge(Icons.chat_bubble_outline, '${reel.commentsCount}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    reel.isActive ? 'creator_status_active'.tr() : 'creator_status_inactive'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: reel.isActive ? AppTheme.accentGreen : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Switch(
                    value: reel.isActive,
                    activeThumbColor: AppTheme.accentGreen,
                    onChanged: (val) => _toggleReelActive(reel, val),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                onPressed: () => _deleteReel(reel),
                tooltip: 'creator_delete_btn'.tr(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- ARTICLES TAB ---
  Widget _buildArticlesTab() {
    final articles = _studioData?.articles ?? [];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKPIHeader(),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${'creator_tab_news'.tr()} (${articles.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final res = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (_) => const UploadNewsScreen()),
                      );
                      if (res == true) _loadStudioData(forceRefresh: true);
                    },
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                    label: Text('creator_upload_news'.tr(), style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.primaryDark),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (articles.isEmpty)
                _buildEmptyState(
                  icon: Icons.article_outlined,
                  title: 'creator_no_articles'.tr(),
                  subtitle: 'creator_no_articles_sub'.tr(),
                  buttonLabel: 'creator_upload_news'.tr(),
                  onPressed: () async {
                    final res = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => const UploadNewsScreen()),
                    );
                    if (res == true) _loadStudioData(forceRefresh: true);
                  },
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: articles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) => _buildArticleManageCard(articles[idx]),
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArticleManageCard(NewsArticle article) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: article.imageUrl!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.newspaper_rounded, color: Colors.grey),
                    ),
                  ),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryDark.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        article.category,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildBadge(Icons.remove_red_eye_outlined, '${article.viewsCount} reads'),
                        _buildBadge(Icons.thumb_up_alt_outlined, '${article.likesCount}'),
                        _buildBadge(Icons.chat_bubble_outline, '${article.commentsCount}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => NewsDetailScreen(article: article)),
                  );
                },
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Preview Article', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: AppTheme.primaryDark),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                onPressed: () => _deleteArticle(article),
                tooltip: 'creator_delete_btn'.tr(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- ANALYTICS TAB ---
  Widget _buildAnalyticsTab() {
    final stats = _studioData?.stats ?? const CreatorStats();
    final trends = _studioData?.dailyTrends ?? [];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKPIHeader(),
              const SizedBox(height: 20),
              _buildTrendChart(trends),
              const SizedBox(height: 20),
              _buildDeepInsightsCard(stats),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKPIHeader() {
    final stats = _studioData?.stats ?? const CreatorStats();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKPICard(
                'creator_stat_views'.tr(),
                stats.totalViews >= 1000 ? '${(stats.totalViews / 1000).toStringAsFixed(1)}K' : '${stats.totalViews}',
                Icons.trending_up_rounded,
                AppTheme.accentGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKPICard(
                'creator_stat_likes'.tr(),
                stats.totalLikes >= 1000 ? '${(stats.totalLikes / 1000).toStringAsFixed(1)}K' : '${stats.totalLikes}',
                Icons.favorite_rounded,
                Colors.pinkAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildKPICard(
                'creator_stat_comments'.tr(),
                '${stats.totalComments}',
                Icons.chat_bubble_rounded,
                AppTheme.accentTeal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKPICard(
                'creator_stat_calls'.tr(),
                '${stats.totalCalls}',
                Icons.call_rounded,
                AppTheme.primaryDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKPICard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(List<DailyTrendItem> trends) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly View Trends',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Last 7 Days',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: trends.isEmpty
                ? const Center(child: Text('No trend data yet'))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: trends.map((e) => e.views.toDouble()).reduce((a, b) => a > b ? a : b) * 1.2,
                      barTouchData: const BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              final idx = val.toInt();
                              if (idx >= 0 && idx < trends.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    trends[idx].day,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: trends.asMap().entries.map((entry) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.views.toDouble(),
                              color: AppTheme.accentGreen,
                              width: 14,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeepInsightsCard(CreatorStats stats) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Audience Reach & Retention',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
          ),
          const SizedBox(height: 16),
          _buildInsightRow(
            'creator_stat_engagement'.tr(),
            '${stats.engagementRate}%',
            'Based on likes, saves, shares & comments',
            Icons.speed_rounded,
            AppTheme.accentTeal,
          ),
          const Divider(height: 24),
          _buildInsightRow(
            'creator_stat_avg_watch'.tr(),
            '${stats.avgWatchDurationSeconds}s',
            'Average video duration completed per farmer',
            Icons.timer_outlined,
            AppTheme.primaryDark,
          ),
          const Divider(height: 24),
          _buildInsightRow(
            'creator_stat_shares'.tr(),
            '${stats.totalShares}',
            'Farmer shares forwarded to WhatsApp & groups',
            Icons.share_rounded,
            AppTheme.accentGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(String title, String value, String subtitle, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade600),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
