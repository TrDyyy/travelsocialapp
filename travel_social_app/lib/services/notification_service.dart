import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../models/notification.dart';

/// Service quản lý notifications
class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  late final CollectionReference _notificationsRef;
  late final CollectionReference _usersRef;

  NotificationService() {
    _notificationsRef = _firestore.collection('notifications');
    _usersRef = _firestore.collection('users');
  }

  /// Initialize FCM
  Future<void> initialize() async {
    // Request permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ FCM permission granted');

      // Get FCM token
      final token = await _messaging.getToken();
      debugPrint('📱 FCM Token: $token');

      // Setup foreground message handler
      _setupForegroundHandler();

      // Setup token refresh handler
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM token refreshed: $newToken');
        // Token will be saved on next login
      });
    } else {
      debugPrint('❌ FCM permission denied');
    }
  }

  /// Setup foreground message handler
  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📬 Received foreground message: ${message.messageId}');

      if (message.notification != null) {
        debugPrint('Title: ${message.notification!.title}');
        debugPrint('Body: ${message.notification!.body}');
        // Note: Local notifications will be shown automatically by FCM
      }
    });
  }

  /// Save FCM token to user document
  Future<void> saveFCMToken(String userId, String token) async {
    try {
      await _usersRef.doc(userId).update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Saved FCM token for user: $userId');
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  /// Create notification trong Firestore
  Future<String?> createNotification(AppNotification notification) async {
    try {
      final docRef = await _notificationsRef.add(notification.toFirestore());
      debugPrint('✅ Created notification: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating notification: $e');
      return null;
    }
  }

  /// Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _notificationsRef.doc(notificationId).update({'isRead': true});
      debugPrint('✅ Marked notification as read: $notificationId');
      return true;
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read for user
  Future<bool> markAllAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final unreadDocs =
          await _notificationsRef
              .where('userId', isEqualTo: userId)
              .where('isRead', isEqualTo: false)
              .get();

      for (var doc in unreadDocs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      debugPrint('✅ Marked all notifications as read for user: $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Error marking all as read: $e');
      return false;
    }
  }

  /// Delete notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _notificationsRef.doc(notificationId).delete();
      debugPrint('✅ Deleted notification: $notificationId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
      return false;
    }
  }

  /// Stream notifications for user
  Stream<List<AppNotification>> notificationsStream(String userId) {
    return _notificationsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AppNotification.fromFirestore(doc))
              .toList();
        });
  }

  /// Get unread notification count
  Stream<int> unreadCountStream(String userId) {
    return _notificationsRef
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Send friend request notification
  Future<void> sendFriendRequestNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
    String? fromUserAvatar,
  }) async {
    final notification = AppNotification(
      userId: toUserId,
      type: 'friend_request',
      title: 'Lời mời kết bạn',
      body: '$fromUserName đã gửi lời mời kết bạn',
      imageUrl: fromUserAvatar,
      data: {'fromUserId': fromUserId, 'action': 'friend_request'},
    );

    await createNotification(notification);
  }

  /// Send friend accept notification
  Future<void> sendFriendAcceptNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
    String? fromUserAvatar,
  }) async {
    final notification = AppNotification(
      userId: toUserId,
      type: 'friend_accept',
      title: 'Chấp nhận kết bạn',
      body: '$fromUserName đã chấp nhận lời mời kết bạn',
      imageUrl: fromUserAvatar,
      data: {'fromUserId': fromUserId, 'action': 'friend_accept'},
    );

    await createNotification(notification);
  }

  /// Send post reaction notification (supports all reaction types)
  Future<void> sendPostLikeNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
    required String postId,
    String? fromUserAvatar,
    String? reactionEmoji, // New parameter for reaction emoji
  }) async {
    final reactionText = reactionEmoji ?? '👍';
    final notification = AppNotification(
      userId: toUserId,
      type: 'post_like',
      title: 'Phản ứng mới',
      body: '$fromUserName đã thả $reactionText vào bài viết của bạn',
      imageUrl: fromUserAvatar,
      data: {'fromUserId': fromUserId, 'postId': postId, 'action': 'post_like'},
    );

    await createNotification(notification);
  }

  /// Send post comment notification
  Future<void> sendPostCommentNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
    required String postId,
    String? fromUserAvatar,
  }) async {
    final notification = AppNotification(
      userId: toUserId,
      type: 'post_comment',
      title: 'Bình luận mới',
      body: '$fromUserName đã bình luận bài viết của bạn',
      imageUrl: fromUserAvatar,
      data: {
        'fromUserId': fromUserId,
        'postId': postId,
        'action': 'post_comment',
      },
    );

    await createNotification(notification);
  }

  /// Send chat message notification
  Future<void> sendMessageNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
    required String chatId,
    required String messageContent,
    String? fromUserAvatar,
  }) async {
    final notification = AppNotification(
      userId: toUserId,
      type: 'chat_message',
      title: fromUserName,
      body: messageContent,
      imageUrl: fromUserAvatar,
      data: {
        'fromUserId': fromUserId,
        'chatId': chatId,
        'action': 'chat_message',
      },
    );

    await createNotification(notification);
  }

  /// Send group chat message notification
  Future<void> sendGroupMessageNotification({
    required List<String> memberIds,
    required String fromUserId,
    required String fromUserName,
    required String chatId,
    required String groupName,
    required String messageContent,
    String? fromUserAvatar,
  }) async {
    // Send to all members except sender
    for (String memberId in memberIds) {
      if (memberId != fromUserId) {
        final notification = AppNotification(
          userId: memberId,
          type: 'group_message',
          title: '$groupName',
          body: '$fromUserName: $messageContent',
          imageUrl: fromUserAvatar,
          data: {
            'fromUserId': fromUserId,
            'chatId': chatId,
            'groupName': groupName,
            'action': 'group_message',
          },
        );

        await createNotification(notification);
      }
    }
  }

  /// Send comment reply notification
  Future<void> sendCommentReplyNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
    required String postId,
    required String commentId,
    String? fromUserAvatar,
  }) async {
    final notification = AppNotification(
      userId: toUserId,
      type: 'comment_reply',
      title: 'Trả lời bình luận',
      body: '$fromUserName đã trả lời bình luận của bạn',
      imageUrl: fromUserAvatar,
      data: {
        'fromUserId': fromUserId,
        'postId': postId,
        'commentId': commentId,
        'action': 'comment_reply',
      },
    );

    await createNotification(notification);
  }

  /// Send message reaction notification
  Future<void> sendMessageReactionNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
    required String messageId,
    required String chatId,
    required String reactionEmoji,
    String? fromUserAvatar,
  }) async {
    final notification = AppNotification(
      userId: toUserId,
      type: 'message_reaction',
      title: 'Thả cảm xúc tin nhắn',
      body: '$fromUserName đã thả $reactionEmoji vào tin nhắn của bạn',
      imageUrl: fromUserAvatar,
      data: {
        'fromUserId': fromUserId,
        'messageId': messageId,
        'chatId': chatId,
        'action': 'message_reaction',
      },
    );

    await createNotification(notification);
  }

  /// Send comment reaction notification
  Future<void> sendCommentReactionNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
    required String commentId,
    required String postId,
    required String reactionEmoji,
    String? fromUserAvatar,
  }) async {
    final notification = AppNotification(
      userId: toUserId,
      type: 'comment_reaction',
      title: 'Thả cảm xúc bình luận',
      body: '$fromUserName đã thả $reactionEmoji vào bình luận của bạn',
      imageUrl: fromUserAvatar,
      data: {
        'fromUserId': fromUserId,
        'commentId': commentId,
        'postId': postId,
        'action': 'comment_reaction',
      },
    );

    await createNotification(notification);
  }

  /// Send review reaction notification
  Future<void> sendReviewReactionNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
    required String reviewId,
    required String placeId,
    required String reactionEmoji,
    String? fromUserAvatar,
  }) async {
    final notification = AppNotification(
      userId: toUserId,
      type: 'review_reaction',
      title: 'Thả cảm xúc đánh giá',
      body: '$fromUserName đã thả $reactionEmoji vào đánh giá của bạn',
      imageUrl: fromUserAvatar,
      data: {
        'fromUserId': fromUserId,
        'reviewId': reviewId,
        'placeId': placeId,
        'action': 'review_reaction',
      },
    );

    await createNotification(notification);
  }

  /// Send group join request notification (to admin)
  Future<void> sendGroupJoinRequestNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
    required String communityId,
    required String communityName,
    String? fromUserAvatar,
  }) async {
    final notification = AppNotification(
      userId: toUserId,
      type: 'group_join_request',
      title: 'Yêu cầu tham gia nhóm',
      body: '$fromUserName muốn tham gia nhóm "$communityName"',
      imageUrl: fromUserAvatar,
      data: {
        'fromUserId': fromUserId,
        'communityId': communityId,
        'action': 'group_join_request',
      },
    );

    await createNotification(notification);
  }

  /// Send group join approved notification (to member)
  Future<void> sendGroupJoinApprovedNotification({
    required String toUserId,
    required String communityId,
    required String communityName,
    String? communityAvatar,
  }) async {
    final notification = AppNotification(
      userId: toUserId,
      type: 'group_join_approved',
      title: 'Yêu cầu được chấp nhận',
      body: 'Bạn đã được duyệt tham gia nhóm "$communityName"',
      imageUrl: communityAvatar,
      data: {'communityId': communityId, 'action': 'group_join_approved'},
    );

    await createNotification(notification);
  }

  /// Send group join rejected notification (to member)
  Future<void> sendGroupJoinRejectedNotification({
    required String toUserId,
    required String communityId,
    required String communityName,
    String? communityAvatar,
  }) async {
    final notification = AppNotification(
      userId: toUserId,
      type: 'group_join_rejected',
      title: 'Yêu cầu bị từ chối',
      body: 'Yêu cầu tham gia nhóm "$communityName" đã bị từ chối',
      imageUrl: communityAvatar,
      data: {'communityId': communityId, 'action': 'group_join_rejected'},
    );

    await createNotification(notification);
  }

  /// Send generic notification to user (for calls, etc.)
  Future<void> sendNotificationToUser(
    String userId,
    String title,
    String body, {
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    final notification = AppNotification(
      userId: userId,
      type: data?['type'] ?? 'general',
      title: title,
      body: body,
      imageUrl: imageUrl,
      data: data ?? {},
    );

    await createNotification(notification);
  }
}
