import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_activity.dart';
import '../models/place.dart';

/// Service để track hoạt động người dùng
class ActivityTrackingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Collection reference
  CollectionReference get _activitiesRef =>
      _firestore.collection('user_activities');

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Track activity - phương thức chung
  Future<void> trackActivity({
    required ActivityType activityType,
    String? placeId,
    String? placeTypeId,
    String? targetId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (_currentUserId == null) return;

      final activity = UserActivity(
        activityId: '', // Firestore sẽ tự tạo ID
        userId: _currentUserId!,
        activityType: activityType,
        placeId: placeId,
        placeTypeId: placeTypeId,
        targetId: targetId,
        metadata: metadata,
        timestamp: DateTime.now(),
      );

      await _activitiesRef.add(activity.toFirestore());
      print('✅ Tracked activity: ${activityType.name}');
    } catch (e) {
      print('❌ Error tracking activity: $e');
    }
  }

  /// Track khi xem chi tiết địa điểm
  Future<void> trackViewPlace(Place place) async {
    await trackActivity(
      activityType: ActivityType.viewPlace,
      placeId: place.placeId,
      placeTypeId: place.typeId,
      metadata: {'placeName': place.name, 'placeRating': place.rating},
    );
  }

  /// Track khi đánh giá địa điểm
  Future<void> trackReviewPlace({
    required String placeId,
    required String placeTypeId,
    required double rating,
  }) async {
    await trackActivity(
      activityType: ActivityType.reviewPlace,
      placeId: placeId,
      placeTypeId: placeTypeId,
      metadata: {'rating': rating},
    );
  }

  /// Track khi đăng bài với tag địa điểm
  Future<void> trackPostWithPlace({
    required String postId,
    required String placeId,
    required String placeTypeId,
  }) async {
    await trackActivity(
      activityType: ActivityType.postWithPlace,
      placeId: placeId,
      placeTypeId: placeTypeId,
      targetId: postId,
    );
  }

  /// Track khi tìm kiếm địa điểm
  Future<void> trackSearchPlace({
    required String searchQuery,
    String? placeId,
    String? placeTypeId,
  }) async {
    await trackActivity(
      activityType: ActivityType.searchPlace,
      placeId: placeId,
      placeTypeId: placeTypeId,
      metadata: {'searchQuery': searchQuery},
    );
  }

  /// Track khi xem chỉ đường
  Future<void> trackGetDirections(Place place) async {
    await trackActivity(
      activityType: ActivityType.getDirections,
      placeId: place.placeId,
      placeTypeId: place.typeId,
      metadata: {'placeName': place.name},
    );
  }

  /// Track khi lưu địa điểm yêu thích
  Future<void> trackSavePlace(Place place) async {
    await trackActivity(
      activityType: ActivityType.savePlace,
      placeId: place.placeId,
      placeTypeId: place.typeId,
      metadata: {'placeName': place.name},
    );
  }

  /// Track khi chia sẻ địa điểm
  Future<void> trackSharePlace(Place place) async {
    await trackActivity(
      activityType: ActivityType.sharePlace,
      placeId: place.placeId,
      placeTypeId: place.typeId,
      metadata: {'placeName': place.name},
    );
  }

  /// Track khi bình luận bài viết có tag địa điểm
  Future<void> trackCommentOnPost({
    required String postId,
    String? placeId,
    String? placeTypeId,
  }) async {
    await trackActivity(
      activityType: ActivityType.commentOnPost,
      placeId: placeId,
      placeTypeId: placeTypeId,
      targetId: postId,
    );
  }

  /// Track khi thích bài viết có tag địa điểm
  Future<void> trackLikePost({
    required String postId,
    String? placeId,
    String? placeTypeId,
  }) async {
    await trackActivity(
      activityType: ActivityType.likePost,
      placeId: placeId,
      placeTypeId: placeTypeId,
      targetId: postId,
    );
  }

  /// Track khi tham gia nhóm về địa điểm
  Future<void> trackJoinGroup({
    required String groupId,
    String? placeId,
    String? placeTypeId,
  }) async {
    await trackActivity(
      activityType: ActivityType.joinGroup,
      placeId: placeId,
      placeTypeId: placeTypeId,
      targetId: groupId,
    );
  }

  /// Track khi click vào gợi ý
  Future<void> trackClickRecommendation({
    required Place place,
    required String recommendationType, // 'smart', 'nearby', 'preference'
  }) async {
    await trackActivity(
      activityType: ActivityType.clickRecommendation,
      placeId: place.placeId,
      placeTypeId: place.typeId,
      metadata: {
        'placeName': place.name,
        'recommendationType': recommendationType,
      },
    );
  }

  /// Lấy lịch sử hoạt động của user
  Future<List<UserActivity>> getUserActivities({
    String? userId,
    int limit = 100,
  }) async {
    try {
      final targetUserId = userId ?? _currentUserId;
      if (targetUserId == null) return [];

      final snapshot =
          await _activitiesRef
              .where('userId', isEqualTo: targetUserId)
              .orderBy('timestamp', descending: true)
              .limit(limit)
              .get();

      return snapshot.docs
          .map((doc) => UserActivity.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ Error getting user activities: $e');
      return [];
    }
  }

  /// Lấy hoạt động theo loại
  Future<List<UserActivity>> getActivitiesByType({
    required ActivityType activityType,
    String? userId,
    int limit = 50,
  }) async {
    try {
      final targetUserId = userId ?? _currentUserId;
      if (targetUserId == null) return [];

      final snapshot =
          await _activitiesRef
              .where('userId', isEqualTo: targetUserId)
              .where('activityType', isEqualTo: activityType.name)
              .orderBy('timestamp', descending: true)
              .limit(limit)
              .get();

      return snapshot.docs
          .map((doc) => UserActivity.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ Error getting activities by type: $e');
      return [];
    }
  }

  /// Phân tích sở thích dựa trên activities
  Future<Map<String, dynamic>> analyzeUserPreferences({String? userId}) async {
    try {
      final targetUserId = userId ?? _currentUserId;
      if (targetUserId == null) return _emptyPreferences();

      final activities = await getUserActivities(userId: targetUserId);

      // Đếm tần suất theo placeTypeId với trọng số
      final typeScores = <String, double>{};

      for (final activity in activities) {
        if (activity.placeTypeId == null) continue;

        // Trọng số cho từng loại hoạt động
        double weight = _getActivityWeight(activity.activityType);

        typeScores[activity.placeTypeId!] =
            (typeScores[activity.placeTypeId!] ?? 0) + weight;
      }

      // Sắp xếp theo điểm
      final sortedTypes =
          typeScores.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      // Lấy top 5 loại yêu thích
      final favoriteTypes = sortedTypes.take(5).map((e) => e.key).toList();

      // Đếm số địa điểm unique đã tương tác
      final uniquePlaces =
          activities
              .where((a) => a.placeId != null)
              .map((a) => a.placeId!)
              .toSet()
              .length;

      return {
        'favoriteTypes': favoriteTypes,
        'typeScores': Map.fromEntries(sortedTypes.take(5)),
        'totalActivities': activities.length,
        'uniquePlaces': uniquePlaces,
        'lastActivity':
            activities.isNotEmpty ? activities.first.timestamp : null,
      };
    } catch (e) {
      print('❌ Error analyzing user preferences: $e');
      return _emptyPreferences();
    }
  }

  /// Trọng số cho từng loại hoạt động
  double _getActivityWeight(ActivityType type) {
    switch (type) {
      case ActivityType.reviewPlace:
        return 5.0; // Đánh giá = quan tâm cao nhất
      case ActivityType.postWithPlace:
        return 4.0; // Đăng bài = quan tâm rất cao
      case ActivityType.savePlace:
        return 3.5; // Lưu = quan tâm cao
      case ActivityType.getDirections:
        return 3.0; // Chỉ đường = có ý định đi
      case ActivityType.viewPlace:
        return 2.0; // Xem chi tiết = quan tâm trung bình
      case ActivityType.sharePlace:
        return 2.5; // Chia sẻ = quan tâm khá
      case ActivityType.commentOnPost:
        return 1.5; // Bình luận = tương tác nhẹ
      case ActivityType.likePost:
        return 1.0; // Thích = tương tác nhẹ nhất
      case ActivityType.clickRecommendation:
        return 1.5; // Click gợi ý = quan tâm
      case ActivityType.searchPlace:
        return 2.0; // Tìm kiếm = có nhu cầu
      case ActivityType.joinGroup:
        return 3.0; // Tham gia nhóm = quan tâm cao
    }
  }

  /// Empty preferences
  Map<String, dynamic> _emptyPreferences() {
    return {
      'favoriteTypes': <String>[],
      'typeScores': <String, double>{},
      'totalActivities': 0,
      'uniquePlaces': 0,
      'lastActivity': null,
    };
  }

  /// Xóa activities cũ (cho cleanup)
  Future<void> cleanupOldActivities({int daysToKeep = 90}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

      final snapshot =
          await _activitiesRef
              .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
              .limit(500)
              .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('✅ Cleaned up ${snapshot.docs.length} old activities');
    } catch (e) {
      print('❌ Error cleaning up old activities: $e');
    }
  }
}
