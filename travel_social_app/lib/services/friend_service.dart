import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/friend.dart';
import 'notification_service.dart';
import 'user_service.dart';

/// Service xử lý friendship/friend requests
class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final UserService _userService = UserService();
  late final CollectionReference _friendshipsRef;

  FriendService() {
    _friendshipsRef = _firestore.collection('friendships');
  }

  /// Gửi lời mời kết bạn
  Future<String?> sendFriendRequest(String fromUserId, String toUserId) async {
    try {
      // Kiểm tra đã có friendship chưa (bất kể trạng thái)
      final existing =
          await _friendshipsRef
              .where('userId1', whereIn: [fromUserId, toUserId])
              .where('userId2', whereIn: [fromUserId, toUserId])
              .get();

      if (existing.docs.isNotEmpty) {
        debugPrint('⚠️ Friendship already exists');
        return null;
      }

      final friendship = Friendship(
        userId1: fromUserId,
        userId2: toUserId,
        status: FriendshipStatus.pending,
        createdAt: DateTime.now(),
      );

      final docRef = await _friendshipsRef.add(friendship.toFirestore());
      debugPrint('✅ Sent friend request: ${docRef.id}');

      // Send notification
      final fromUser = await _userService.getUserById(fromUserId);
      if (fromUser != null) {
        await _notificationService.sendFriendRequestNotification(
          toUserId: toUserId,
          fromUserId: fromUserId,
          fromUserName: fromUser.name,
          fromUserAvatar: fromUser.avatarUrl,
        );
      }

      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error sending friend request: $e');
      return null;
    }
  }

  /// Chấp nhận lời mời kết bạn
  Future<bool> acceptFriendRequest(String friendshipId) async {
    try {
      // Get friendship to get user IDs
      final doc = await _friendshipsRef.doc(friendshipId).get();
      if (!doc.exists) return false;

      final friendship = Friendship.fromFirestore(doc);

      await _friendshipsRef.doc(friendshipId).update({
        'status': FriendshipStatus.accepted.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Accepted friend request: $friendshipId');

      // Send notification to sender (userId1)
      final acceptorUser = await _userService.getUserById(friendship.userId2);
      if (acceptorUser != null) {
        await _notificationService.sendFriendAcceptNotification(
          toUserId: friendship.userId1,
          fromUserId: friendship.userId2,
          fromUserName: acceptorUser.name,
          fromUserAvatar: acceptorUser.avatarUrl,
        );
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error accepting friend request: $e');
      return false;
    }
  }

  /// Từ chối lời mời kết bạn
  Future<bool> rejectFriendRequest(String friendshipId) async {
    try {
      await _friendshipsRef.doc(friendshipId).update({
        'status': FriendshipStatus.rejected.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Rejected friend request: $friendshipId');
      return true;
    } catch (e) {
      debugPrint('❌ Error rejecting friend request: $e');
      return false;
    }
  }

  /// Hủy kết bạn / Hủy lời mời
  Future<bool> removeFriendship(String friendshipId) async {
    try {
      await _friendshipsRef.doc(friendshipId).delete();
      debugPrint('✅ Removed friendship: $friendshipId');
      return true;
    } catch (e) {
      debugPrint('❌ Error removing friendship: $e');
      return false;
    }
  }

  /// Lấy trạng thái friendship giữa 2 user
  Future<Friendship?> getFriendship(String userId1, String userId2) async {
    try {
      // Tìm trong cả 2 hướng (userId1-userId2 hoặc userId2-userId1)
      final query1 =
          await _friendshipsRef
              .where('userId1', isEqualTo: userId1)
              .where('userId2', isEqualTo: userId2)
              .limit(1)
              .get();

      if (query1.docs.isNotEmpty) {
        return Friendship.fromFirestore(query1.docs.first);
      }

      final query2 =
          await _friendshipsRef
              .where('userId1', isEqualTo: userId2)
              .where('userId2', isEqualTo: userId1)
              .limit(1)
              .get();

      if (query2.docs.isNotEmpty) {
        return Friendship.fromFirestore(query2.docs.first);
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error getting friendship: $e');
      return null;
    }
  }

  /// Stream friendship status giữa 2 user
  Stream<Friendship?> friendshipStream(String userId1, String userId2) {
    return _friendshipsRef.snapshots().map((snapshot) {
      for (var doc in snapshot.docs) {
        final friendship = Friendship.fromFirestore(doc);
        if ((friendship.userId1 == userId1 && friendship.userId2 == userId2) ||
            (friendship.userId1 == userId2 && friendship.userId2 == userId1)) {
          return friendship;
        }
      }
      return null;
    });
  }

  /// Lấy danh sách bạn bè (status = accepted)
  Stream<List<Friendship>> friendsStream(String userId) {
    return _friendshipsRef
        .where(
          'status',
          isEqualTo: FriendshipStatus.accepted.toString().split('.').last,
        )
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Friendship.fromFirestore(doc))
              .where((f) => f.userId1 == userId || f.userId2 == userId)
              .toList();
        });
  }

  /// Lấy danh sách lời mời đã gửi (pending)
  Stream<List<Friendship>> sentRequestsStream(String userId) {
    return _friendshipsRef
        .where('userId1', isEqualTo: userId)
        .where(
          'status',
          isEqualTo: FriendshipStatus.pending.toString().split('.').last,
        )
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Friendship.fromFirestore(doc))
              .toList();
        });
  }

  /// Lấy danh sách lời mời nhận được (pending)
  Stream<List<Friendship>> receivedRequestsStream(String userId) {
    return _friendshipsRef
        .where('userId2', isEqualTo: userId)
        .where(
          'status',
          isEqualTo: FriendshipStatus.pending.toString().split('.').last,
        )
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Friendship.fromFirestore(doc))
              .toList();
        });
  }

  /// Đếm số lượng bạn bè
  Future<int> getFriendCount(String userId) async {
    try {
      final friendsSnapshot =
          await _friendshipsRef
              .where(
                'status',
                isEqualTo: FriendshipStatus.accepted.toString().split('.').last,
              )
              .get();

      int count = 0;
      for (var doc in friendsSnapshot.docs) {
        final friendship = Friendship.fromFirestore(doc);
        if (friendship.userId1 == userId || friendship.userId2 == userId) {
          count++;
        }
      }

      return count;
    } catch (e) {
      debugPrint('❌ Error getting friend count: $e');
      return 0;
    }
  }

  /// Đếm số lời mời chờ (received)
  Future<int> getPendingRequestCount(String userId) async {
    try {
      final snapshot =
          await _friendshipsRef
              .where('userId2', isEqualTo: userId)
              .where(
                'status',
                isEqualTo: FriendshipStatus.pending.toString().split('.').last,
              )
              .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('❌ Error getting pending request count: $e');
      return 0;
    }
  }
}
