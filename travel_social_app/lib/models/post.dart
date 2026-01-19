import 'package:cloud_firestore/cloud_firestore.dart';

enum PostType {
  reviewShare, // Chia sẻ review
  normal, // Post thông thường
  community, // Post trong community
}

enum Feeling {
  happy, // 😊 Vui
  excited, // 🤩 Hào hứng
  nostalgic, // 🥺 Hoài niệm
  relaxed, // 😌 Thư giãn
  adventurous, // 🏔️ Phiêu lưu
  grateful, // 🙏 Biết ơn
}

extension FeelingExtension on Feeling {
  String get displayName {
    switch (this) {
      case Feeling.happy:
        return 'Vui';
      case Feeling.excited:
        return 'Hào hứng';
      case Feeling.nostalgic:
        return 'Hoài niệm';
      case Feeling.relaxed:
        return 'Thư giãn';
      case Feeling.adventurous:
        return 'Phiêu lưu';
      case Feeling.grateful:
        return 'Biết ơn';
    }
  }

  String get emoji {
    switch (this) {
      case Feeling.happy:
        return '😊';
      case Feeling.excited:
        return '🤩';
      case Feeling.nostalgic:
        return '🥺';
      case Feeling.relaxed:
        return '😌';
      case Feeling.adventurous:
        return '🏔️';
      case Feeling.grateful:
        return '🙏';
    }
  }
}

/// Model cho Post trong mạng xã hội
class Post {
  final String? postId;
  final String userId;
  final PostType type;
  final String content;
  final List<String>? mediaUrls; // Ảnh hoặc video
  final String? reviewId; // Nếu là review share
  final String? placeId; // Nếu là review share

  // New fields for tagging
  final String? taggedPlaceId; // ID địa điểm được tag
  final String? taggedPlaceName; // Tên địa điểm được tag
  final List<String>? taggedUserIds; // Danh sách user IDs được tag
  final Feeling? feeling; // Tâm trạng
  final String? communityId; // ID community nếu là community post
  final List<String>? isSavedBy; // Danh sách userId đã lưu bài viết này

  final int reactionCount;
  final int commentCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Post({
    this.postId,
    required this.userId,
    required this.type,
    required this.content,
    this.mediaUrls,
    this.reviewId,
    this.placeId,
    this.taggedPlaceId,
    this.taggedPlaceName,
    this.taggedUserIds,
    this.feeling,
    this.communityId,
    this.isSavedBy,
    this.reactionCount = 0,
    this.commentCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// Tạo từ Firestore Document
  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Post(
      postId: doc.id,
      userId: data['userId'] ?? '',
      type: PostType.values.firstWhere(
        (e) => e.toString() == 'PostType.${data['type']}',
        orElse: () => PostType.normal,
      ),
      content: data['content'] ?? '',
      mediaUrls:
          data['mediaUrls'] != null
              ? List<String>.from(data['mediaUrls'])
              : null,
      reviewId: data['reviewId'],
      placeId: data['placeId'],
      taggedPlaceId: data['taggedPlaceId'],
      taggedPlaceName: data['taggedPlaceName'],
      taggedUserIds:
          data['taggedUserIds'] != null
              ? List<String>.from(data['taggedUserIds'])
              : null,
      feeling:
          data['feeling'] != null
              ? Feeling.values.firstWhere(
                (e) => e.toString() == 'Feeling.${data['feeling']}',
                orElse: () => Feeling.happy,
              )
              : null,
      communityId: data['communityId'],
      isSavedBy:
          data['isSavedBy'] != null
              ? List<String>.from(data['isSavedBy'])
              : null,
      reactionCount: data['reactionCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
      updatedAt:
          data['updatedAt'] != null
              ? (data['updatedAt'] as Timestamp).toDate()
              : null,
    );
  }

  /// Chuyển sang Map để lưu Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type.toString().split('.').last,
      'content': content,
      'mediaUrls': mediaUrls,
      'reviewId': reviewId,
      'placeId': placeId,
      'taggedPlaceId': taggedPlaceId,
      'taggedPlaceName': taggedPlaceName,
      'taggedUserIds': taggedUserIds,
      'feeling': feeling?.toString().split('.').last,
      'communityId': communityId,
      'isSavedBy': isSavedBy,
      'reactionCount': reactionCount,
      'commentCount': commentCount,
      'createdAt':
          createdAt != null
              ? Timestamp.fromDate(createdAt!)
              : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Copy with (hỗ trợ nullable fields)
  Post copyWith({
    String? postId,
    String? userId,
    PostType? type,
    String? content,
    List<String>? mediaUrls,
    bool clearMediaUrls = false, // Flag để set mediaUrls = null
    String? reviewId,
    String? placeId,
    String? taggedPlaceId,
    String? taggedPlaceName,
    List<String>? taggedUserIds,
    Feeling? feeling,
    String? communityId,
    List<String>? isSavedBy,
    int? reactionCount,
    int? commentCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Post(
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      content: content ?? this.content,
      mediaUrls: clearMediaUrls ? null : (mediaUrls ?? this.mediaUrls),
      reviewId: reviewId ?? this.reviewId,
      placeId: placeId ?? this.placeId,
      taggedPlaceId: taggedPlaceId ?? this.taggedPlaceId,
      taggedPlaceName: taggedPlaceName ?? this.taggedPlaceName,
      taggedUserIds: taggedUserIds ?? this.taggedUserIds,
      feeling: feeling ?? this.feeling,
      communityId: communityId ?? this.communityId,
      isSavedBy: isSavedBy ?? this.isSavedBy,
      reactionCount: reactionCount ?? this.reactionCount,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
