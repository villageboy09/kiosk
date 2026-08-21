import 'reel_model.dart';
import 'news_article.dart';

class CreatorStats {
  final int totalViews;
  final int totalLikes;
  final int totalComments;
  final int totalSaves;
  final int totalCalls;
  final int totalShares;
  final double engagementRate;
  final double avgWatchDurationSeconds;
  final int totalReels;
  final int totalArticles;

  const CreatorStats({
    this.totalViews = 0,
    this.totalLikes = 0,
    this.totalComments = 0,
    this.totalSaves = 0,
    this.totalCalls = 0,
    this.totalShares = 0,
    this.engagementRate = 0.0,
    this.avgWatchDurationSeconds = 0.0,
    this.totalReels = 0,
    this.totalArticles = 0,
  });

  factory CreatorStats.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val is int) return val;
      return int.tryParse(val?.toString() ?? '0') ?? 0;
    }

    double parseDouble(dynamic val) {
      if (val is double) return val;
      if (val is int) return val.toDouble();
      return double.tryParse(val?.toString() ?? '0.0') ?? 0.0;
    }

    return CreatorStats(
      totalViews: parseInt(json['totalViews'] ?? json['total_views']),
      totalLikes: parseInt(json['totalLikes'] ?? json['total_likes']),
      totalComments: parseInt(json['totalComments'] ?? json['total_comments']),
      totalSaves: parseInt(json['totalSaves'] ?? json['total_saves']),
      totalCalls: parseInt(json['totalCalls'] ?? json['total_calls']),
      totalShares: parseInt(json['totalShares'] ?? json['total_shares']),
      engagementRate: parseDouble(json['engagementRate'] ?? json['engagement_rate']),
      avgWatchDurationSeconds: parseDouble(json['avgWatchDurationSeconds'] ?? json['avg_watch_duration_seconds']),
      totalReels: parseInt(json['totalReels'] ?? json['total_reels']),
      totalArticles: parseInt(json['totalArticles'] ?? json['total_articles']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalViews': totalViews,
      'totalLikes': totalLikes,
      'totalComments': totalComments,
      'totalSaves': totalSaves,
      'totalCalls': totalCalls,
      'totalShares': totalShares,
      'engagementRate': engagementRate,
      'avgWatchDurationSeconds': avgWatchDurationSeconds,
      'totalReels': totalReels,
      'totalArticles': totalArticles,
    };
  }
}

class DailyTrendItem {
  final String day;
  final int views;
  final int likes;

  const DailyTrendItem({
    required this.day,
    required this.views,
    required this.likes,
  });

  factory DailyTrendItem.fromJson(Map<String, dynamic> json) {
    return DailyTrendItem(
      day: json['day']?.toString() ?? '',
      views: int.tryParse(json['views']?.toString() ?? '0') ?? 0,
      likes: int.tryParse(json['likes']?.toString() ?? '0') ?? 0,
    );
  }
}

class CreatorStudioData {
  final ReelCreator creator;
  final CreatorStats stats;
  final List<ReelModel> reels;
  final List<NewsArticle> articles;
  final List<DailyTrendItem> dailyTrends;

  const CreatorStudioData({
    required this.creator,
    required this.stats,
    this.reels = const [],
    this.articles = const [],
    this.dailyTrends = const [],
  });

  factory CreatorStudioData.fromJson(Map<String, dynamic> json) {
    final creatorJson = json['creator'] is Map<String, dynamic>
        ? json['creator'] as Map<String, dynamic>
        : <String, dynamic>{};
    final statsJson = json['stats'] is Map<String, dynamic>
        ? json['stats'] as Map<String, dynamic>
        : <String, dynamic>{};

    final rawReels = json['reels'] as List<dynamic>? ?? [];
    final reels = rawReels
        .whereType<Map<String, dynamic>>()
        .map((r) => ReelModel.fromJson(r))
        .toList();

    final rawArticles = json['articles'] as List<dynamic>? ?? [];
    final articles = rawArticles
        .whereType<Map<String, dynamic>>()
        .map((a) => NewsArticle.fromJson(a))
        .toList();

    final rawTrends = json['trends'] as List<dynamic>? ?? [];
    final trends = rawTrends
        .whereType<Map<String, dynamic>>()
        .map((t) => DailyTrendItem.fromJson(t))
        .toList();

    return CreatorStudioData(
      creator: ReelCreator.fromJson(creatorJson),
      stats: CreatorStats.fromJson(statsJson),
      reels: reels,
      articles: articles,
      dailyTrends: trends,
    );
  }
}
