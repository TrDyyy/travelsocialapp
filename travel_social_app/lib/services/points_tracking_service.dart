import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_badge.dart';
import '../utils/points_system.dart';

/// Model cho lịch sử điểm
class PointHistory {
  final String id;
  final String userId;
  final String action;
  final int points;
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  PointHistory({
    required this.id,
    required this.userId,
    required this.action,
    required this.points,
    required this.description,
    required this.timestamp,
    this.metadata,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'action': action,
      'points': points,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }

  factory PointHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PointHistory(
      id: doc.id,
      userId: data['userId'] ?? '',
      action: data['action'] ?? '',
      points: data['points'] ?? 0,
      description: data['description'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      metadata: data['metadata'],
    );
  }
}

/// Service quản lý điểm số và danh hiệu
class PointsTrackingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// Award points to user
  /// IMPORTANT: Điểm người dùng được lưu trong totalPoints field
  /// currentBadge được cập nhật dựa trên totalPoints
  Future<bool> awardPoints({
    required String userId,
    required String action,
    required int points,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // 1. Add point history
      await _firestore.collection('point_history').add({
        'userId': userId,
        'action': action,
        'points': points,
        'description': description ?? PointsSystem.getActionDescription(action),
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata,
      });

      // 2. Update user totalPoints and badge
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        print('❌ User not found: $userId');
        return false;
      }

      // Get current totalPoints
      final userData = userDoc.data();
      final currentTotalPoints = userData?['totalPoints'] ?? 0;

      // Calculate new totalPoints
      final newTotalPoints = currentTotalPoints + points;

      // Get appropriate badge for new totalPoints
      final oldBadge =
          userData?['currentBadge'] != null
              ? UserBadge.fromMap(userData!['currentBadge'])
              : null;
      final newBadge = UserBadge.getBadgeByPoints(newTotalPoints);

      // Update user document
      await userRef.update({
        'totalPoints': newTotalPoints, // MAIN SOURCE OF TRUTH
        'currentBadge': newBadge.toFirestore(),
        'level': newBadge.level,
        'points': newTotalPoints, // Deprecated but kept for compatibility
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print(
        '✅ Awarded $points points to user $userId for $action (Total: $newTotalPoints)',
      );

      // Check if badge upgraded
      if (oldBadge?.badgeId != newBadge.badgeId) {
        print('🏆 User $userId badge updated to ${newBadge.name}');
        await _sendBadgeUpgradeNotification(userId, newBadge);
      }

      return true;
    } catch (e) {
      print('❌ Error awarding points: $e');
      return false;
    }
  }

  /// Send notification when user gets new badge
  Future<void> _sendBadgeUpgradeNotification(
    String userId,
    UserBadge newBadge,
  ) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': 'badge_upgrade',
        'title': 'Chúc mừng! 🎉',
        'message': 'Bạn đã đạt danh hiệu ${newBadge.icon} ${newBadge.name}',
        'data': newBadge.toFirestore(),
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error sending badge notification: $e');
    }
  }

  /// Get user total points
  /// IMPORTANT: Lấy từ totalPoints field (nguồn dữ liệu chính)
  Future<int> getUserPoints(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data()?['totalPoints'] ?? 0;
    } catch (e) {
      print('❌ Error getting user points: $e');
      return 0;
    }
  }

  /// Get user current badge
  Future<UserBadge?> getUserBadge(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final badgeData = userDoc.data()?['currentBadge'];
      if (badgeData == null) return null;
      return UserBadge.fromMap(badgeData);
    } catch (e) {
      print('❌ Error getting user badge: $e');
      return null;
    }
  }

  /// Get user point history
  Stream<List<PointHistory>> getUserPointHistory(String userId) {
    return _firestore
        .collection('point_history')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => PointHistory.fromFirestore(doc))
                  .toList(),
        );
  }

  /// Get leaderboard (top users by points)
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 50}) async {
    try {
      final snapshot =
          await _firestore
              .collection('users')
              .orderBy('totalPoints', descending: true)
              .limit(limit)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'userId': doc.id,
          'name': data['name'] ?? 'Unknown',
          'avatarUrl': data['avatarUrl'],
          'totalPoints': data['totalPoints'] ?? 0,
          'currentBadge': data['currentBadge'],
          'level': data['level'] ?? 1,
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting leaderboard: $e');
      return [];
    }
  }

  /// Get user rank
  Future<int> getUserRank(String userId) async {
    try {
      final userPoints = await getUserPoints(userId);
      final snapshot =
          await _firestore
              .collection('users')
              .where('totalPoints', isGreaterThan: userPoints)
              .get();

      return snapshot.docs.length + 1; // Rank starts from 1
    } catch (e) {
      print('❌ Error getting user rank: $e');
      return 0;
    }
  }

  /// Get user points earned today
  Future<int> getTodayPoints(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final snapshot =
          await _firestore
              .collection('point_history')
              .where('userId', isEqualTo: userId)
              .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
              .get();

      int totalToday = 0;
      for (final doc in snapshot.docs) {
        totalToday += (doc.data()['points'] as int?) ?? 0;
      }

      return totalToday;
    } catch (e) {
      print('❌ Error getting today points: $e');
      return 0;
    }
  }

  // ==================== Specific Action Tracking ====================

  /// Award points for place request approval
  Future<void> awardPlaceRequestApproved(String userId, String placeId) async {
    await awardPoints(
      userId: userId,
      action: 'placeRequestApproved',
      points: PointsSystem.placeRequestApproved,
      metadata: {'placeId': placeId},
    );
  }

  /// Award points for review
  Future<void> awardReview({
    required String userId,
    required String placeId,
    required String reviewText,
    required int imageCount,
    required double rating,
  }) async {
    final points = PointsSystem.getReviewPoints(
      reviewText: reviewText,
      imageCount: imageCount,
      rating: rating,
    );

    await awardPoints(
      userId: userId,
      action: 'reviewPlace',
      points: points,
      metadata: {
        'placeId': placeId,
        'textLength': reviewText.length,
        'imageCount': imageCount,
        'rating': rating,
      },
    );
  }

  /// Award points for post
  Future<void> awardPost({
    required String userId,
    required String postId,
    required String postText,
    required int imageCount,
    required bool hasTaggedPlace,
    required bool isInCommunity,
  }) async {
    final points = PointsSystem.getPostPoints(
      postText: postText,
      imageCount: imageCount,
      hasTaggedPlace: hasTaggedPlace,
      isInCommunity: isInCommunity,
    );

    await awardPoints(
      userId: userId,
      action: 'createPost',
      points: points,
      metadata: {
        'postId': postId,
        'textLength': postText.length,
        'imageCount': imageCount,
        'hasTaggedPlace': hasTaggedPlace,
        'isInCommunity': isInCommunity,
      },
    );
  }

  /// Award points for comment
  Future<void> awardComment(String userId, String postId) async {
    await awardPoints(
      userId: userId,
      action: 'commentOnPost',
      points: PointsSystem.commentOnPost,
      metadata: {'postId': postId},
    );
  }

  /// Award points for like
  Future<void> awardLike(String userId, String postId) async {
    await awardPoints(
      userId: userId,
      action: 'likePost',
      points: PointsSystem.likePost,
      metadata: {'postId': postId},
    );
  }

  /// Award points for daily login
  Future<void> awardDailyLogin(String userId) async {
    // Check if already awarded today
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final snapshot =
        await _firestore
            .collection('point_history')
            .where('userId', isEqualTo: userId)
            .where('action', isEqualTo: 'dailyLoginBonus')
            .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
            .limit(1)
            .get();

    if (snapshot.docs.isEmpty) {
      await awardPoints(
        userId: userId,
        action: 'dailyLoginBonus',
        points: PointsSystem.dailyLoginBonus,
      );
    }
  }
}
