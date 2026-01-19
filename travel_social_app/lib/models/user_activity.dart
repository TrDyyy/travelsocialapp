import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum cho các loại hoạt động người dùng
enum ActivityType {
  viewPlace, // Xem chi tiết địa điểm
  reviewPlace, // Đánh giá địa điểm
  postWithPlace, // Đăng bài với tag địa điểm
  searchPlace, // Tìm kiếm địa điểm
  getDirections, // Xem chỉ đường đến địa điểm
  savePlace, // Lưu địa điểm yêu thích
  sharePlace, // Chia sẻ địa điểm
  commentOnPost, // Bình luận bài viết có tag địa điểm
  likePost, // Thích bài viết có tag địa điểm
  joinGroup, // Tham gia nhóm về địa điểm
  clickRecommendation, // Click vào gợi ý
}

/// Model cho hoạt động người dùng
class UserActivity {
  final String activityId;
  final String userId;
  final ActivityType activityType;
  final String? placeId; // ID của địa điểm liên quan
  final String? placeTypeId; // Loại địa điểm
  final String? targetId; // ID của target (postId, commentId, etc.)
  final Map<String, dynamic>? metadata; // Dữ liệu bổ sung
  final DateTime timestamp;

  UserActivity({
    required this.activityId,
    required this.userId,
    required this.activityType,
    this.placeId,
    this.placeTypeId,
    this.targetId,
    this.metadata,
    required this.timestamp,
  });

  /// Convert từ Firestore document
  factory UserActivity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserActivity(
      activityId: doc.id,
      userId: data['userId'] as String,
      activityType: ActivityType.values.firstWhere(
        (e) => e.toString() == 'ActivityType.${data['activityType']}',
        orElse: () => ActivityType.viewPlace,
      ),
      placeId: data['placeId'] as String?,
      placeTypeId: data['placeTypeId'] as String?,
      targetId: data['targetId'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  /// Convert sang Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'activityType': activityType.name,
      'placeId': placeId,
      'placeTypeId': placeTypeId,
      'targetId': targetId,
      'metadata': metadata,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  /// Copy with method
  UserActivity copyWith({
    String? activityId,
    String? userId,
    ActivityType? activityType,
    String? placeId,
    String? placeTypeId,
    String? targetId,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
  }) {
    return UserActivity(
      activityId: activityId ?? this.activityId,
      userId: userId ?? this.userId,
      activityType: activityType ?? this.activityType,
      placeId: placeId ?? this.placeId,
      placeTypeId: placeTypeId ?? this.placeTypeId,
      targetId: targetId ?? this.targetId,
      metadata: metadata ?? this.metadata,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
