import 'package:cloud_firestore/cloud_firestore.dart';

/// Message model
class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String message;
  final DateTime sentAt;
  final bool? isRead; // Đã đọc chưa (optional)
  final List<String>? imageUrls; // List URL ảnh (optional) - hỗ trợ nhiều ảnh
  final String? replyToMessageId; // ID tin nhắn được reply (optional)
  final bool isEdited; // Đã sửa chưa
  final DateTime? editedAt; // Thời gian sửa
  final bool isRecalled; // Đã thu hồi chưa
  final DateTime? recalledAt; // Thời gian thu hồi
  final String? recalledBy; // Người thu hồi (có thể là admin)
  final int reactionCount; // Tổng số reactions

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.message,
    required this.sentAt,
    this.isRead,
    this.imageUrls,
    this.replyToMessageId,
    this.isEdited = false,
    this.editedAt,
    this.isRecalled = false,
    this.recalledAt,
    this.recalledBy,
    this.reactionCount = 0,
  });

  /// Create from Firestore
  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      message: data['message'] ?? '',
      sentAt: (data['sentAt'] as Timestamp).toDate(),
      isRead: data['isRead'],
      imageUrls:
          data['imageUrls'] != null
              ? List<String>.from(data['imageUrls'])
              : null,
      replyToMessageId: data['replyToMessageId'],
      isEdited: data['isEdited'] ?? false,
      editedAt:
          data['editedAt'] != null
              ? (data['editedAt'] as Timestamp).toDate()
              : null,
      isRecalled: data['isRecalled'] ?? false,
      recalledAt:
          data['recalledAt'] != null
              ? (data['recalledAt'] as Timestamp).toDate()
              : null,
      recalledBy: data['recalledBy'],
      reactionCount: data['reactionCount'] ?? 0,
    );
  }

  /// Convert to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'message': message,
      'sentAt': Timestamp.fromDate(sentAt),
      'isRead': isRead,
      'imageUrls': imageUrls,
      'replyToMessageId': replyToMessageId,
      'isEdited': isEdited,
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'isRecalled': isRecalled,
      'recalledAt': recalledAt != null ? Timestamp.fromDate(recalledAt!) : null,
      'recalledBy': recalledBy,
      'reactionCount': reactionCount,
    };
  }

  /// Copy with
  Message copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? message,
    DateTime? sentAt,
    bool? isRead,
    List<String>? imageUrls,
    String? replyToMessageId,
    bool? isEdited,
    DateTime? editedAt,
    bool? isRecalled,
    DateTime? recalledAt,
    String? recalledBy,
    int? reactionCount,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      message: message ?? this.message,
      sentAt: sentAt ?? this.sentAt,
      isRead: isRead ?? this.isRead,
      imageUrls: imageUrls ?? this.imageUrls,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      isRecalled: isRecalled ?? this.isRecalled,
      recalledAt: recalledAt ?? this.recalledAt,
      recalledBy: recalledBy ?? this.recalledBy,
      reactionCount: reactionCount ?? this.reactionCount,
    );
  }

  /// Check if message is from current user
  bool isFromCurrentUser(String currentUserId) {
    return senderId == currentUserId;
  }
}
