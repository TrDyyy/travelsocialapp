import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

/// Service xử lý chat và messages
class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  late final CollectionReference _chatsRef;
  late final CollectionReference _messagesRef;

  ChatService() {
    _chatsRef = _firestore.collection('chats');
    _messagesRef = _firestore.collection('messages');
  }

  // ==================== CHAT OPERATIONS ====================

  /// Tạo hoặc lấy private chat giữa 2 users
  Future<String> getOrCreatePrivateChat(String userId1, String userId2) async {
    try {
      // Tìm chat đã tồn tại
      final existingChats =
          await _chatsRef
              .where('chatType', isEqualTo: 'Riêng tư')
              .where('members', arrayContains: userId1)
              .get();

      for (var doc in existingChats.docs) {
        final chat = Chat.fromFirestore(doc);
        if (chat.members.contains(userId2)) {
          debugPrint('✅ Found existing private chat: ${doc.id}');
          return doc.id;
        }
      }

      // Tạo chat mới
      final newChat = Chat(
        id: '',
        chatType: ChatType.private,
        members: [userId1, userId2],
        createdAt: DateTime.now(),
      );

      final docRef = await _chatsRef.add(newChat.toFirestore());
      debugPrint('✅ Created new private chat: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error getting/creating private chat: $e');
      rethrow;
    }
  }

  /// Tạo group chat
  Future<String> createGroupChat(List<String> memberIds, String adminId) async {
    try {
      final newChat = Chat(
        id: '',
        chatType: ChatType.group,
        members: memberIds,
        groupAdmin: adminId,
        createdAt: DateTime.now(),
      );

      final docRef = await _chatsRef.add(newChat.toFirestore());
      debugPrint('✅ Created group chat: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating group chat: $e');
      rethrow;
    }
  }

  /// Tạo community chat
  Future<Chat> createCommunityChat({
    required String creatorId,
    required String communityName,
    String? communityAvatar,
  }) async {
    try {
      final newChat = Chat(
        id: '',
        chatType: ChatType.community,
        members: [creatorId], // Creator là thành viên đầu tiên
        createdAt: DateTime.now(),
        groupName: communityName,
        groupAvatar: communityAvatar,
        groupAdmin: creatorId, // Creator là admin
        isPublic: true, // Community chat luôn public
      );

      final docRef = await _chatsRef.add(newChat.toFirestore());
      debugPrint('✅ Created community chat: ${docRef.id}');

      // Lấy chat vừa tạo với ID đầy đủ
      final createdChat = newChat.copyWith(id: docRef.id);
      return createdChat;
    } catch (e) {
      debugPrint('❌ Error creating community chat: $e');
      rethrow;
    }
  }

  /// Lấy danh sách chats của user
  Stream<List<Chat>> getUserChats(String userId) {
    return _chatsRef
        .where('members', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Chat.fromFirestore(doc)).toList();
        });
  }

  /// Lấy tất cả community public (không cần là member)
  Stream<List<Chat>> getPublicCommunities() {
    return _chatsRef
        .where('chatType', isEqualTo: 'Cộng đồng')
        .where('isPublic', isEqualTo: true)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Chat.fromFirestore(doc)).toList();
        });
  }

  /// Lấy tất cả chats của user (private + group + public communities)
  /// Kết hợp getUserChats + getPublicCommunities để tránh permission issues
  Stream<List<Chat>> getAllChatsForUser(String userId) {
    return _chatsRef.where('members', arrayContains: userId).snapshots().asyncMap((
      memberSnapshot,
    ) async {
      try {
        // Get chats where user is member (private + group + joined communities)
        final memberChats =
            memberSnapshot.docs.map((doc) => Chat.fromFirestore(doc)).toList();

        // Get all public communities
        final publicCommunitiesSnapshot =
            await _chatsRef
                .where('chatType', isEqualTo: 'Cộng đồng')
                .where('isPublic', isEqualTo: true)
                .get();

        final publicCommunities =
            publicCommunitiesSnapshot.docs
                .map((doc) => Chat.fromFirestore(doc))
                .toList();

        // Combine and remove duplicates (community user already joined)
        final allChatIds = <String>{};
        final allChats = <Chat>[];

        for (final chat in memberChats) {
          if (!allChatIds.contains(chat.id)) {
            allChatIds.add(chat.id);
            allChats.add(chat);
          }
        }

        for (final chat in publicCommunities) {
          if (!allChatIds.contains(chat.id)) {
            allChatIds.add(chat.id);
            allChats.add(chat);
          }
        }

        // Sort by lastMessageTime
        allChats.sort((a, b) {
          final aTime = a.lastMessageTime ?? DateTime(2000);
          final bTime = b.lastMessageTime ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });

        return allChats;
      } catch (e) {
        debugPrint('❌ Error in getAllChatsForUser: $e');
        return [];
      }
    });
  }

  /// Join community (thêm userId vào members)
  Future<void> joinCommunity(String chatId, String userId) async {
    try {
      await _chatsRef.doc(chatId).update({
        'members': FieldValue.arrayUnion([userId]),
      });
      debugPrint('✅ User $userId joined community $chatId');
    } catch (e) {
      debugPrint('❌ Error joining community: $e');
      rethrow;
    }
  }

  /// Leave community (xóa userId khỏi members)
  Future<void> leaveCommunity(String chatId, String userId) async {
    try {
      await _chatsRef.doc(chatId).update({
        'members': FieldValue.arrayRemove([userId]),
      });
      debugPrint('✅ User $userId left community $chatId');
    } catch (e) {
      debugPrint('❌ Error leaving community: $e');
      rethrow;
    }
  }

  /// Mute notifications for a chat
  Future<void> muteChat(String chatId, String userId) async {
    try {
      await _chatsRef.doc(chatId).update({
        'mutedBy': FieldValue.arrayUnion([userId]),
      });
      debugPrint('✅ User $userId muted chat $chatId');
    } catch (e) {
      debugPrint('❌ Error muting chat: $e');
      rethrow;
    }
  }

  /// Unmute notifications for a chat
  Future<void> unmuteChat(String chatId, String userId) async {
    try {
      await _chatsRef.doc(chatId).update({
        'mutedBy': FieldValue.arrayRemove([userId]),
      });
      debugPrint('✅ User $userId unmuted chat $chatId');
    } catch (e) {
      debugPrint('❌ Error unmuting chat: $e');
      rethrow;
    }
  }

  /// Lấy chat by ID
  Future<Chat?> getChatById(String chatId) async {
    try {
      final doc = await _chatsRef.doc(chatId).get();
      if (!doc.exists) return null;
      return Chat.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ Error getting chat: $e');
      return null;
    }
  }

  /// Lấy chat stream by ID (real-time updates)
  Stream<Chat?> getChatStream(String chatId) {
    return _chatsRef.doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Chat.fromFirestore(doc);
    });
  }

  /// Update last message của chat
  Future<void> updateLastMessage(
    String chatId,
    String message,
    String senderId, {
    int? imageCount,
  }) async {
    try {
      await _chatsRef.doc(chatId).update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'lastMessageImageCount': imageCount,
      });
    } catch (e) {
      debugPrint('❌ Error updating last message: $e');
    }
  }

  /// Thêm member vào group chat
  Future<void> addMemberToGroup(String chatId, String userId) async {
    try {
      await _chatsRef.doc(chatId).update({
        'members': FieldValue.arrayUnion([userId]),
      });
      debugPrint('✅ Added member to group: $userId');
    } catch (e) {
      debugPrint('❌ Error adding member: $e');
    }
  }

  /// Xóa member khỏi group chat
  Future<void> removeMemberFromGroup(String chatId, String userId) async {
    try {
      await _chatsRef.doc(chatId).update({
        'members': FieldValue.arrayRemove([userId]),
      });
      debugPrint('✅ Removed member from group: $userId');
    } catch (e) {
      debugPrint('❌ Error removing member: $e');
    }
  }

  // ==================== CUSTOMIZATION OPERATIONS ====================

  /// Cập nhật tên nhóm hoặc cộng đồng (chỉ admin)
  Future<void> updateGroupName(
    String chatId,
    String newName,
    String userId,
  ) async {
    try {
      final chat = await getChatById(chatId);
      if (chat == null) {
        throw Exception('Chat not found');
      }

      if (chat.chatType != ChatType.group &&
          chat.chatType != ChatType.community) {
        throw Exception('Only group and community chats can have custom names');
      }

      if (chat.groupAdmin != userId) {
        throw Exception('Only admin can change name');
      }

      await _chatsRef.doc(chatId).update({'groupName': newName});
      debugPrint('✅ Updated chat name: $newName');
    } catch (e) {
      debugPrint('❌ Error updating chat name: $e');
      rethrow;
    }
  }

  /// Cập nhật avatar nhóm hoặc cộng đồng (chỉ admin)
  Future<void> updateGroupAvatar(
    String chatId,
    String avatarUrl,
    String userId,
  ) async {
    try {
      final chat = await getChatById(chatId);
      if (chat == null) {
        throw Exception('Chat not found');
      }

      if (chat.chatType != ChatType.group &&
          chat.chatType != ChatType.community) {
        throw Exception(
          'Only group and community chats can have custom avatars',
        );
      }

      if (chat.groupAdmin != userId) {
        throw Exception('Only admin can change avatar');
      }

      await _chatsRef.doc(chatId).update({'groupAvatar': avatarUrl});
      debugPrint('✅ Updated chat avatar');
    } catch (e) {
      debugPrint('❌ Error updating chat avatar: $e');
      rethrow;
    }
  }

  /// Cập nhật background cho group chat (chỉ admin, ảnh chung cho cả nhóm)
  Future<void> updateGroupBackground(
    String chatId,
    String backgroundUrl,
    String userId,
  ) async {
    try {
      final chat = await getChatById(chatId);
      if (chat == null) {
        throw Exception('Chat not found');
      }

      if (chat.chatType != ChatType.group) {
        throw Exception('Only group chats can use this method');
      }

      // Kiểm tra quyền admin
      if (chat.groupAdmin != userId) {
        throw Exception('Only admin can change group background');
      }

      // Cập nhật ảnh nền chung cho cả nhóm
      await _chatsRef.doc(chatId).update({
        'groupBackground': backgroundUrl,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      // Tạo system message
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userName =
          userDoc.exists ? (UserModel.fromFirestore(userDoc).name) : 'Ai đó';

      await sendMessage(
        chatId: chatId,
        senderId: userId,
        messageText: '$userName đã thay đổi ảnh nền nhóm',
      );

      debugPrint('✅ Updated group background (admin only)');
    } catch (e) {
      debugPrint('❌ Error updating group background: $e');
      rethrow;
    }
  }

  /// Cập nhật background chung cho private chat (ai đổi cũng được, hiển thị chung)
  Future<void> updatePrivateBackground(
    String chatId,
    String userId,
    String backgroundUrl,
  ) async {
    try {
      final chat = await getChatById(chatId);
      if (chat == null) {
        throw Exception('Chat not found');
      }

      if (chat.chatType != ChatType.private) {
        throw Exception('Only private chats support per-user backgrounds');
      }

      if (!chat.members.contains(userId)) {
        throw Exception('User is not a member of this chat');
      }

      // Lưu ảnh nền chung - dùng key 'shared' để đánh dấu là ảnh chung
      await _chatsRef.doc(chatId).update({
        'backgroundImages': {'shared': backgroundUrl},
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      // Tạo system message
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userName =
          userDoc.exists ? (UserModel.fromFirestore(userDoc).name) : 'Ai đó';

      await sendMessage(
        chatId: chatId,
        senderId: userId,
        messageText: '$userName đã thay đổi ảnh nền',
      );

      debugPrint('✅ Updated private background (shared): $userId');
    } catch (e) {
      debugPrint('❌ Error updating private background: $e');
      rethrow;
    }
  }

  /// Kiểm tra 2 users có phải bạn bè không
  Future<bool> checkFriendship(String userId1, String userId2) async {
    try {
      final friendshipDoc =
          await _firestore
              .collection('friendships')
              .where('users', arrayContains: userId1)
              .where('status', isEqualTo: 'accepted')
              .get();

      for (var doc in friendshipDoc.docs) {
        final users = List<String>.from(doc.data()['users'] ?? []);
        if (users.contains(userId2)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error checking friendship: $e');
      return false;
    }
  }

  /// Chuyển quyền admin cho thành viên khác
  Future<void> transferAdmin(
    String chatId,
    String currentAdminId,
    String newAdminId,
  ) async {
    try {
      final chat = await getChatById(chatId);
      if (chat == null) {
        throw Exception('Chat not found');
      }

      if (chat.chatType != ChatType.group) {
        throw Exception('Only group chats have admin');
      }

      if (chat.groupAdmin != currentAdminId) {
        throw Exception('Only current admin can transfer admin rights');
      }

      if (!chat.members.contains(newAdminId)) {
        throw Exception('New admin must be a member of the group');
      }

      await _chatsRef.doc(chatId).update({'groupAdmin': newAdminId});
      debugPrint('✅ Transferred admin to: $newAdminId');
    } catch (e) {
      debugPrint('❌ Error transferring admin: $e');
      rethrow;
    }
  }

  /// Giải tán nhóm (chỉ admin)
  Future<void> disbandGroup(String chatId, String userId) async {
    try {
      final chat = await getChatById(chatId);
      if (chat == null) {
        throw Exception('Chat not found');
      }

      if (chat.chatType != ChatType.group) {
        throw Exception('Only group chats can be disbanded');
      }

      if (chat.groupAdmin != userId) {
        throw Exception('Only admin can disband the group');
      }

      // Xóa tất cả tin nhắn trong nhóm
      final messages =
          await _messagesRef.where('chatId', isEqualTo: chatId).get();

      final batch = _firestore.batch();
      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }

      // Xóa chat
      batch.delete(_chatsRef.doc(chatId));
      await batch.commit();

      debugPrint('✅ Disbanded group: $chatId');
    } catch (e) {
      debugPrint('❌ Error disbanding group: $e');
      rethrow;
    }
  }

  /// Kiểm tra và xử lý khi admin rời nhóm
  /// Trả về true nếu cần hiển thị dialog giải tán
  Future<bool> handleAdminLeaving(String chatId, String adminId) async {
    try {
      final chat = await getChatById(chatId);
      if (chat == null) return false;

      if (chat.chatType != ChatType.group) return false;
      if (chat.groupAdmin != adminId) return false;

      // Nếu nhóm có ít hơn 3 người, cần dialog giải tán
      if (chat.members.length < 3) {
        return true;
      }

      // Nếu >= 3 người, bắt buộc chuyển quyền admin trước
      return false;
    } catch (e) {
      debugPrint('❌ Error handling admin leaving: $e');
      return false;
    }
  }

  // ==================== MESSAGE OPERATIONS ====================

  /// Gửi tin nhắn
  Future<String> sendMessage({
    required String chatId,
    required String senderId,
    required String messageText,
    List<String>? imageUrls,
    String? replyToMessageId,
  }) async {
    try {
      final message = Message(
        id: '',
        chatId: chatId,
        senderId: senderId,
        message: messageText,
        sentAt: DateTime.now(),
        isRead: false,
        imageUrls: imageUrls,
        replyToMessageId: replyToMessageId,
      );

      final docRef = await _messagesRef.add(message.toFirestore());
      debugPrint('✅ Sent message: ${docRef.id}');

      // Update last message trong chat
      // Nếu có ảnh thì set imageCount, nếu không có text thì lastMessage = ""
      final displayMessage =
          (imageUrls != null && imageUrls.isNotEmpty && messageText.isEmpty)
              ? ""
              : messageText;
      final imageCount = imageUrls?.length;
      await updateLastMessage(
        chatId,
        displayMessage,
        senderId,
        imageCount: imageCount,
      );

      // Send notification to other members
      await _sendMessageNotifications(chatId, senderId, messageText);

      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      rethrow;
    }
  }

  /// Send notification to chat members
  Future<void> _sendMessageNotifications(
    String chatId,
    String senderId,
    String messageText,
  ) async {
    try {
      // Get chat info
      final chatDoc = await _chatsRef.doc(chatId).get();
      if (!chatDoc.exists) return;

      final chat = Chat.fromFirestore(chatDoc);

      // Get sender info
      final senderDoc =
          await _firestore.collection('users').doc(senderId).get();
      if (!senderDoc.exists) return;

      final sender = UserModel.fromFirestore(senderDoc);

      // Check notification preferences
      final prefs = await SharedPreferences.getInstance();
      final notificationEnabled =
          prefs.getBool('chat_notification_enabled') ?? true;
      final previewEnabled = prefs.getBool('chat_preview_enabled') ?? true;

      if (!notificationEnabled) {
        debugPrint('🔕 Chat notifications disabled');
        return;
      }

      // Prepare message preview
      final messagePreview =
          previewEnabled
              ? (messageText.length > 50
                  ? '${messageText.substring(0, 50)}...'
                  : messageText)
              : 'Tin nhắn mới';

      // Send notifications based on chat type
      if (chat.chatType == ChatType.private) {
        // Private chat - send to the other user
        final receiverId = chat.members.firstWhere(
          (id) => id != senderId,
          orElse: () => '',
        );

        // Check if receiver has muted this chat
        if (receiverId.isNotEmpty &&
            !(chat.mutedBy?.contains(receiverId) ?? false)) {
          await _notificationService.sendMessageNotification(
            toUserId: receiverId,
            fromUserId: senderId,
            fromUserName: sender.name,
            chatId: chatId,
            messageContent: messagePreview,
            fromUserAvatar: sender.avatarUrl,
          );
        }
      } else {
        // Group/Community chat - send to all members except sender
        // Filter out users who muted this chat
        final mutedBy = chat.mutedBy ?? [];
        final membersToNotify =
            chat.members.where((id) => !mutedBy.contains(id)).toList();

        if (membersToNotify.isNotEmpty) {
          await _notificationService.sendGroupMessageNotification(
            memberIds: membersToNotify,
            fromUserId: senderId,
            fromUserName: sender.name,
            chatId: chatId,
            groupName: chat.groupName ?? 'Nhóm',
            messageContent: messagePreview,
            fromUserAvatar: sender.avatarUrl,
          );
        }
      }

      debugPrint('✅ Sent message notifications');
    } catch (e) {
      debugPrint('❌ Error sending message notifications: $e');
      // Don't throw - notification failure shouldn't break message sending
    }
  }

  /// Lấy messages của chat (real-time)
  Stream<List<Message>> getChatMessages(String chatId) {
    return _messagesRef
        .where('chatId', isEqualTo: chatId)
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Message.fromFirestore(doc))
              .toList();
        });
  }

  /// Đánh dấu tin nhắn đã đọc
  Future<void> markMessageAsRead(String messageId) async {
    try {
      await _messagesRef.doc(messageId).update({'isRead': true});
    } catch (e) {
      debugPrint('❌ Error marking message as read: $e');
    }
  }

  /// Đánh dấu tất cả tin nhắn trong chat đã đọc
  Future<void> markAllMessagesAsRead(String chatId, String userId) async {
    try {
      final messages =
          await _messagesRef
              .where('chatId', isEqualTo: chatId)
              .where('senderId', isNotEqualTo: userId)
              .where('isRead', isEqualTo: false)
              .get();

      final batch = _firestore.batch();
      for (var doc in messages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      debugPrint('✅ Marked all messages as read in chat: $chatId');
    } catch (e) {
      debugPrint('❌ Error marking all messages as read: $e');
    }
  }

  /// Xóa tin nhắn (chỉ người gửi)
  /// Thu hồi tin nhắn (thay vì xóa hẳn)
  Future<bool> recallMessage(String messageId, String currentUserId) async {
    try {
      // Check if user is the sender
      final messageDoc = await _messagesRef.doc(messageId).get();
      if (!messageDoc.exists) {
        debugPrint('❌ Message not found');
        return false;
      }

      final message = Message.fromFirestore(messageDoc);
      if (message.senderId != currentUserId) {
        debugPrint('❌ User is not the sender');
        return false;
      }

      // Update message to recalled state
      await _messagesRef.doc(messageId).update({
        'isRecalled': true,
        'recalledAt': FieldValue.serverTimestamp(),
        'recalledBy': currentUserId,
        'message': '', // Clear message content
        'imageUrls': null, // Clear images
      });

      // Update lastMessage in chat
      final chat = await getChatById(message.chatId);
      if (chat != null) {
        await _chatsRef.doc(message.chatId).update({
          'lastMessage': 'Tin nhắn đã bị thu hồi',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageImageCount': null, // Clear image count
        });

        // Send notification to other members
        await _sendRecallNotification(message, currentUserId, chat);
      }

      debugPrint('✅ Recalled message: $messageId');
      return true;
    } catch (e) {
      debugPrint('❌ Error recalling message: $e');
      return false;
    }
  }

  /// Gửi thông báo khi thu hồi tin nhắn
  Future<void> _sendRecallNotification(
    Message message,
    String recallerUserId,
    Chat chat,
  ) async {
    try {
      // Get recaller info
      final recallerDoc =
          await _firestore.collection('users').doc(recallerUserId).get();
      if (!recallerDoc.exists) return;

      final recaller = UserModel.fromFirestore(recallerDoc);

      // Check notification preferences
      final prefs = await SharedPreferences.getInstance();

      // Send to other members based on chat type
      if (chat.chatType == ChatType.private) {
        // Private: send to the other person
        final recipientId = chat.members.firstWhere(
          (id) => id != recallerUserId,
        );

        // Check if notifications enabled
        final notifEnabled = prefs.getBool('chat_notification_enabled') ?? true;
        if (!notifEnabled) return;

        await _notificationService.sendMessageNotification(
          toUserId: recipientId,
          fromUserId: recallerUserId,
          fromUserName: recaller.name,
          chatId: message.chatId,
          messageContent: 'đã thu hồi một tin nhắn',
          fromUserAvatar: recaller.avatarUrl,
        );
      } else {
        // Group/Community: send to all members except recaller
        for (final memberId in chat.members) {
          if (memberId != recallerUserId) {
            final notifEnabled =
                prefs.getBool('chat_notification_enabled') ?? true;
            if (!notifEnabled) continue;

            await _notificationService.sendMessageNotification(
              toUserId: memberId,
              fromUserId: recallerUserId,
              fromUserName: recaller.name,
              chatId: message.chatId,
              messageContent: 'đã thu hồi một tin nhắn',
              fromUserAvatar: recaller.avatarUrl,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error sending recall notification: $e');
    }
  }

  /// Sửa tin nhắn (chỉ người gửi)
  Future<bool> editMessage(
    String messageId,
    String currentUserId,
    String newMessageText,
  ) async {
    try {
      // Check if user is the sender
      final messageDoc = await _messagesRef.doc(messageId).get();
      if (!messageDoc.exists) {
        debugPrint('❌ Message not found');
        return false;
      }

      final message = Message.fromFirestore(messageDoc);
      if (message.senderId != currentUserId) {
        debugPrint('❌ User is not the sender');
        return false;
      }

      await _messagesRef.doc(messageId).update({
        'message': newMessageText,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });

      // Update lastMessage in chat if this was the last message
      final chat = await getChatById(message.chatId);
      if (chat != null && chat.lastMessage == message.message) {
        // Nếu message có ảnh, giữ nguyên imageCount
        final imageCount =
            (message.imageUrls != null && message.imageUrls!.isNotEmpty)
                ? message.imageUrls!.length
                : null;
        await _chatsRef.doc(message.chatId).update({
          'lastMessage': newMessageText,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageImageCount': imageCount,
        });
      }

      // Send notification to other members
      await _sendEditNotification(message, currentUserId, chat!);

      debugPrint('✅ Edited message: $messageId');
      return true;
    } catch (e) {
      debugPrint('❌ Error editing message: $e');
      return false;
    }
  }

  /// Gửi thông báo khi sửa tin nhắn
  Future<void> _sendEditNotification(
    Message message,
    String editorUserId,
    Chat chat,
  ) async {
    try {
      // Get editor info
      final editorDoc =
          await _firestore.collection('users').doc(editorUserId).get();
      if (!editorDoc.exists) return;

      final editor = UserModel.fromFirestore(editorDoc);

      // Check notification preferences
      final prefs = await SharedPreferences.getInstance();

      // Send to other members based on chat type
      if (chat.chatType == ChatType.private) {
        // Private: send to the other person
        final recipientId = chat.members.firstWhere((id) => id != editorUserId);

        // Check if notifications enabled
        final notifEnabled = prefs.getBool('chat_notification_enabled') ?? true;
        if (!notifEnabled) return;

        await _notificationService.sendMessageNotification(
          toUserId: recipientId,
          fromUserId: editorUserId,
          fromUserName: editor.name,
          chatId: message.chatId,
          messageContent: 'đã chỉnh sửa một tin nhắn',
          fromUserAvatar: editor.avatarUrl,
        );
      } else {
        // Group/Community: send to all members except editor
        for (final memberId in chat.members) {
          if (memberId != editorUserId) {
            final notifEnabled =
                prefs.getBool('chat_notification_enabled') ?? true;
            if (!notifEnabled) continue;

            await _notificationService.sendMessageNotification(
              toUserId: memberId,
              fromUserId: editorUserId,
              fromUserName: editor.name,
              chatId: message.chatId,
              messageContent: 'đã chỉnh sửa một tin nhắn',
              fromUserAvatar: editor.avatarUrl,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error sending edit notification: $e');
    }
  }

  /// Xóa tin nhắn hẳn (deprecated - dùng recallMessage thay thế)
  Future<bool> deleteMessage(String messageId, String currentUserId) async {
    return recallMessage(messageId, currentUserId);
  }

  /// Lấy số lượng tin nhắn chưa đọc
  Stream<int> getUnreadMessageCount(String userId) {
    return _messagesRef
        .where('senderId', isNotEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .asyncMap((snapshot) async {
          int count = 0;
          for (var doc in snapshot.docs) {
            final message = Message.fromFirestore(doc);
            final chat = await getChatById(message.chatId);
            if (chat != null && chat.members.contains(userId)) {
              count++;
            }
          }
          return count;
        });
  }
}
