import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum cho các loại reaction
enum ReactionType {
  like, // 👍
  love, // ❤️
  haha, // 😄
  wow, // 😮
  sad, // 😢
  angry, // 😠
}

/// Extension cho ReactionType
extension ReactionTypeExtension on ReactionType {
  String get emoji {
    switch (this) {
      case ReactionType.like:
        return '👍';
      case ReactionType.love:
        return '❤️';
      case ReactionType.haha:
        return '😄';
      case ReactionType.wow:
        return '😮';
      case ReactionType.sad:
        return '😢';
      case ReactionType.angry:
        return '😠';
    }
  }

  String get name {
    switch (this) {
      case ReactionType.like:
        return 'like';
      case ReactionType.love:
        return 'love';
      case ReactionType.haha:
        return 'haha';
      case ReactionType.wow:
        return 'wow';
      case ReactionType.sad:
        return 'sad';
      case ReactionType.angry:
        return 'angry';
    }
  }

  static ReactionType fromString(String value) {
    switch (value) {
      case 'like':
        return ReactionType.like;
      case 'love':
        return ReactionType.love;
      case 'haha':
        return ReactionType.haha;
      case 'wow':
        return ReactionType.wow;
      case 'sad':
        return ReactionType.sad;
      case 'angry':
        return ReactionType.angry;
      default:
        return ReactionType.like;
    }
  }
}

/// Enum cho các loại target (message, comment, review, post)
enum ReactionTargetType { message, comment, review, post }

extension ReactionTargetTypeExtension on ReactionTargetType {
  String get name {
    switch (this) {
      case ReactionTargetType.message:
        return 'message';
      case ReactionTargetType.comment:
        return 'comment';
      case ReactionTargetType.review:
        return 'review';
      case ReactionTargetType.post:
        return 'post';
    }
  }

  static ReactionTargetType fromString(String value) {
    switch (value) {
      case 'message':
        return ReactionTargetType.message;
      case 'comment':
        return ReactionTargetType.comment;
      case 'review':
        return ReactionTargetType.review;
      case 'post':
        return ReactionTargetType.post;
      default:
        return ReactionTargetType.message;
    }
  }
}

/// Model cho Reaction
class Reaction {
  final String? reactionId;
  final String userId; // Người thả reaction
  final String targetId; // ID của message/comment/review
  final ReactionTargetType targetType; // Loại target
  final ReactionType reactionType; // Loại reaction
  final DateTime createdAt;

  Reaction({
    this.reactionId,
    required this.userId,
    required this.targetId,
    required this.targetType,
    required this.reactionType,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Tạo từ Firestore document
  factory Reaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Reaction(
      reactionId: doc.id,
      userId: data['userId'] ?? '',
      targetId: data['targetId'] ?? '',
      targetType: ReactionTargetTypeExtension.fromString(
        data['targetType'] ?? 'message',
      ),
      reactionType: ReactionTypeExtension.fromString(
        data['reactionType'] ?? 'like',
      ),
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  /// Chuyển sang Map cho Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'targetId': targetId,
      'targetType': targetType.name,
      'reactionType': reactionType.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Copy with
  Reaction copyWith({
    String? reactionId,
    String? userId,
    String? targetId,
    ReactionTargetType? targetType,
    ReactionType? reactionType,
    DateTime? createdAt,
  }) {
    return Reaction(
      reactionId: reactionId ?? this.reactionId,
      userId: userId ?? this.userId,
      targetId: targetId ?? this.targetId,
      targetType: targetType ?? this.targetType,
      reactionType: reactionType ?? this.reactionType,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Model cho thống kê reactions (dùng để cache)
class ReactionStats {
  final Map<ReactionType, int> counts; // Đếm số lượng mỗi loại reaction
  final int totalCount; // Tổng số reactions
  final ReactionType? userReaction; // Reaction của user hiện tại (nếu có)

  ReactionStats({
    required this.counts,
    required this.totalCount,
    this.userReaction,
  });

  factory ReactionStats.empty() {
    return ReactionStats(counts: {}, totalCount: 0, userReaction: null);
  }

  /// Tạo từ danh sách reactions
  factory ReactionStats.fromReactions(
    List<Reaction> reactions,
    String? currentUserId,
  ) {
    final Map<ReactionType, int> counts = {};
    ReactionType? userReaction;

    for (final reaction in reactions) {
      // Đếm số lượng
      counts[reaction.reactionType] = (counts[reaction.reactionType] ?? 0) + 1;

      // Tìm reaction của user hiện tại
      if (currentUserId != null && reaction.userId == currentUserId) {
        userReaction = reaction.reactionType;
      }
    }

    return ReactionStats(
      counts: counts,
      totalCount: reactions.length,
      userReaction: userReaction,
    );
  }

  /// Copy with
  ReactionStats copyWith({
    Map<ReactionType, int>? counts,
    int? totalCount,
    ReactionType? userReaction,
    bool clearUserReaction = false,
  }) {
    return ReactionStats(
      counts: counts ?? this.counts,
      totalCount: totalCount ?? this.totalCount,
      userReaction:
          clearUserReaction ? null : (userReaction ?? this.userReaction),
    );
  }
}
