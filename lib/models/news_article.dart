/// Data model representing an agricultural news article
class NewsArticle {
  final int id;
  final String title;
  final String summary;
  final String content;
  final String category;
  final String? imageUrl;
  final String author;
  final String sourceName;
  final int viewsCount;
  final int likesCount;
  final int commentsCount;
  final bool isFeatured;
  final bool hasLiked;
  final DateTime? publishedAt;
  final DateTime? createdAt;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.category,
    this.imageUrl,
    this.author = 'CropSync Desk',
    this.sourceName = 'Krishi News',
    this.viewsCount = 0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isFeatured = false,
    this.hasLiked = false,
    this.publishedAt,
    this.createdAt,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    return NewsArticle(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Govt Schemes',
      imageUrl: json['image_url']?.toString(),
      author: json['author']?.toString() ?? 'CropSync Desk',
      sourceName: json['source_name']?.toString() ?? 'Krishi News',
      viewsCount: int.tryParse(json['views_count']?.toString() ?? '0') ?? 0,
      likesCount: int.tryParse(json['likes_count']?.toString() ?? '0') ?? 0,
      commentsCount: int.tryParse(json['comments_count']?.toString() ?? '0') ?? 0,
      isFeatured: json['is_featured'] == true ||
          json['is_featured'] == 1 ||
          json['is_featured'] == '1',
      hasLiked: json['has_liked'] == true ||
          json['has_liked'] == 1 ||
          json['has_liked'] == '1',
      publishedAt: parseDate(json['published_at']),
      createdAt: parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'content': content,
      'category': category,
      'image_url': imageUrl,
      'author': author,
      'source_name': sourceName,
      'views_count': viewsCount,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'is_featured': isFeatured ? 1 : 0,
      'has_liked': hasLiked ? 1 : 0,
      'published_at': publishedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  NewsArticle copyWith({
    int? id,
    String? title,
    String? summary,
    String? content,
    String? category,
    String? imageUrl,
    String? author,
    String? sourceName,
    int? viewsCount,
    int? likesCount,
    int? commentsCount,
    bool? isFeatured,
    bool? hasLiked,
    DateTime? publishedAt,
    DateTime? createdAt,
  }) {
    return NewsArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      content: content ?? this.content,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      author: author ?? this.author,
      sourceName: sourceName ?? this.sourceName,
      viewsCount: viewsCount ?? this.viewsCount,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isFeatured: isFeatured ?? this.isFeatured,
      hasLiked: hasLiked ?? this.hasLiked,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Format publication time in a clean, human-friendly way
  String get formattedPublishedDate {
    if (publishedAt == null) return 'Recently';
    final now = DateTime.now();
    final difference = now.difference(publishedAt!);

    if (difference.inMinutes < 60) {
      final mins = difference.inMinutes.clamp(1, 60);
      return '$mins min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final d = publishedAt!;
      return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
    }
  }

  /// Estimated reading time in minutes
  int get estimatedReadTimeMinutes {
    final wordCount = content.split(RegExp(r'\s+')).length;
    final mins = (wordCount / 180).ceil();
    return mins < 1 ? 1 : mins;
  }
}

/// Data model representing a comment on a news article
class NewsComment {
  final int id;
  final int articleId;
  final String? userId;
  final String userName;
  final String userRole;
  final String phoneNumber;
  final String commentText;
  final DateTime? createdAt;

  const NewsComment({
    required this.id,
    required this.articleId,
    this.userId,
    required this.userName,
    this.userRole = 'farmer',
    required this.phoneNumber,
    required this.commentText,
    this.createdAt,
  });

  factory NewsComment.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    return NewsComment(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      articleId: int.tryParse(json['article_id']?.toString() ?? '0') ?? 0,
      userId: json['user_id']?.toString(),
      userName: json['user_name']?.toString() ?? 'Farmer',
      userRole: json['user_role']?.toString() ?? 'farmer',
      phoneNumber: json['phone_number']?.toString() ?? '',
      commentText: json['comment_text']?.toString() ?? '',
      createdAt: parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'article_id': articleId,
      'user_id': userId,
      'user_name': userName,
      'user_role': userRole,
      'phone_number': phoneNumber,
      'comment_text': commentText,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  String get formattedDate {
    if (createdAt == null) return 'Just now';
    final now = DateTime.now();
    final difference = now.difference(createdAt!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final d = createdAt!;
      return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]}';
    }
  }
}
