class ReelCreator {
  final int id;
  final String username;
  final String displayName;
  final String profileImageUrl;
  final bool isVerified;
  final String phoneNumber;
  final String bio;

  const ReelCreator({
    required this.id,
    required this.username,
    required this.displayName,
    required this.profileImageUrl,
    this.isVerified = true,
    this.phoneNumber = '',
    this.bio = '',
  });

  factory ReelCreator.fromJson(Map<String, dynamic> json) {
    return ReelCreator(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      username: json['username']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? json['display_name']?.toString() ?? 'Farmer',
      profileImageUrl: json['profileImageUrl']?.toString() ?? json['profile_image_url']?.toString() ?? '',
      isVerified: json['isVerified'] == true || json['is_verified'] == 1 || json['is_verified'] == '1',
      phoneNumber: json['phoneNumber']?.toString() ?? json['phone_number']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'profileImageUrl': profileImageUrl,
      'isVerified': isVerified,
      'phoneNumber': phoneNumber,
      'bio': bio,
    };
  }
}

class ReelComment {
  final int id;
  final int reelId;
  final String farmerUsername;
  final String phoneNumber;
  final String userId;
  final String commentText;
  final DateTime createdAt;

  const ReelComment({
    required this.id,
    required this.reelId,
    required this.farmerUsername,
    this.phoneNumber = '',
    this.userId = '',
    required this.commentText,
    required this.createdAt,
  });

  factory ReelComment.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return ReelComment(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      reelId: json['reel_id'] is int ? json['reel_id'] : int.tryParse(json['reel_id']?.toString() ?? '0') ?? 0,
      farmerUsername: json['farmer_username']?.toString() ?? json['username']?.toString() ?? 'Farmer',
      phoneNumber: json['phone_number']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      commentText: json['comment_text']?.toString() ?? json['text']?.toString() ?? '',
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reel_id': reelId,
      'farmer_username': farmerUsername,
      'phone_number': phoneNumber,
      'user_id': userId,
      'comment_text': commentText,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get formattedTimeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 7) {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    } else if (diff.inDays >= 1) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes >= 1) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }
}

class Reel {
  final int id;
  final String videoUrl;
  final ReelCreator creator;
  final String caption;
  final String musicTitle;
  final String phoneNumber;
  final String tags;
  final String likes;
  final int likesRaw;
  final bool hasLiked;
  final String saves;
  final int savesRaw;
  final bool hasSaved;
  final int commentsCount;
  final List<ReelComment> comments;
  final int viewsCount;
  final bool isActive;
  final DateTime createdAt;

  const Reel({
    required this.id,
    required this.videoUrl,
    required this.creator,
    required this.caption,
    this.musicTitle = 'Original Audio',
    this.phoneNumber = '',
    this.tags = '',
    this.likes = '0',
    this.likesRaw = 0,
    this.hasLiked = false,
    this.saves = '0',
    this.savesRaw = 0,
    this.hasSaved = false,
    this.commentsCount = 0,
    this.comments = const [],
    this.viewsCount = 0,
    this.isActive = true,
    required this.createdAt,
  });

  factory Reel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    final rawLikes = json['likesRaw'] is int ? json['likesRaw'] as int : int.tryParse(json['likes_count']?.toString() ?? '0') ?? 0;
    final rawSaves = json['savesRaw'] is int ? json['savesRaw'] as int : int.tryParse(json['saves_count']?.toString() ?? '0') ?? 0;

    List<ReelComment> parsedComments = [];
    if (json['comments'] is List) {
      parsedComments = (json['comments'] as List)
          .map((c) => c is Map<String, dynamic> ? ReelComment.fromJson(c) : null)
          .whereType<ReelComment>()
          .toList();
    }

    Map<String, dynamic> creatorData = {};
    if (json['creator'] is Map<String, dynamic>) {
      creatorData = json['creator'] as Map<String, dynamic>;
    } else {
      creatorData = {
        'username': json['username']?.toString() ?? 'farmer',
        'displayName': json['display_name']?.toString() ?? json['username']?.toString() ?? 'Farmer',
        'profileImageUrl': json['profile_image_url']?.toString() ?? '',
      };
    }

    final likeStr = json['likes']?.toString() ?? _formatCount(rawLikes);
    final saveStr = json['saves']?.toString() ?? _formatCount(rawSaves);

    return Reel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      videoUrl: json['videoUrl']?.toString() ?? json['video_url']?.toString() ?? '',
      creator: ReelCreator.fromJson(creatorData),
      caption: json['caption']?.toString() ?? '',
      musicTitle: json['musicTitle']?.toString() ?? json['music_title']?.toString() ?? 'Original Audio',
      phoneNumber: json['phoneNumber']?.toString() ?? json['phone_number']?.toString() ?? '',
      tags: json['tags']?.toString() ?? '',
      likes: likeStr,
      likesRaw: rawLikes,
      hasLiked: json['hasLiked'] == true || json['has_liked'] == true || json['has_liked'] == 1,
      saves: saveStr,
      savesRaw: rawSaves,
      hasSaved: json['hasSaved'] == true || json['has_saved'] == true || json['has_saved'] == 1,
      commentsCount: json['commentsCount'] is int
          ? json['commentsCount'] as int
          : int.tryParse(json['comments_count']?.toString() ?? '${parsedComments.length}') ?? parsedComments.length,
      comments: parsedComments,
      viewsCount: json['viewsCount'] is int ? json['viewsCount'] as int : int.tryParse(json['views_count']?.toString() ?? '0') ?? 0,
      isActive: json['isActive'] == true || json['is_active'] == 1 || json['is_active'] == '1' || json['is_active'] == null,
      createdAt: parsedDate,
    );
  }

  static String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  Reel copyWith({
    int? id,
    String? videoUrl,
    ReelCreator? creator,
    String? caption,
    String? musicTitle,
    String? phoneNumber,
    String? tags,
    String? likes,
    int? likesRaw,
    bool? hasLiked,
    String? saves,
    int? savesRaw,
    bool? hasSaved,
    int? commentsCount,
    List<ReelComment>? comments,
    int? viewsCount,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Reel(
      id: id ?? this.id,
      videoUrl: videoUrl ?? this.videoUrl,
      creator: creator ?? this.creator,
      caption: caption ?? this.caption,
      musicTitle: musicTitle ?? this.musicTitle,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      tags: tags ?? this.tags,
      likes: likes ?? this.likes,
      likesRaw: likesRaw ?? this.likesRaw,
      hasLiked: hasLiked ?? this.hasLiked,
      saves: saves ?? this.saves,
      savesRaw: savesRaw ?? this.savesRaw,
      hasSaved: hasSaved ?? this.hasSaved,
      commentsCount: commentsCount ?? this.commentsCount,
      comments: comments ?? this.comments,
      viewsCount: viewsCount ?? this.viewsCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Typedef alias for ReelModel
typedef ReelModel = Reel;
