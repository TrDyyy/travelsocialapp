import 'package:cloud_firestore/cloud_firestore.dart';

/// Model cho thông báo
class AppNotification {
  final String? notificationId;
  final String userId; // Người nhận thông báo
  final String type;
  // Types: 'friend_request', 'friend_accept',
  // 'post_like', 'post_comment', 'comment_reply',
  // 'message_reaction', 'comment_reaction', 'review_reaction'
  final String title;
  final String body;
  final String? imageUrl;
  final Map<String, dynamic>? data; // Extra data (userId, postId, etc.)
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    this.notificationId,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.imageUrl,
    this.data,
    this.isRead = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Tạo từ Firestore document
  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      notificationId: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      imageUrl: data['imageUrl'],
      data:
          data['data'] != null ? Map<String, dynamic>.from(data['data']) : null,
      isRead: data['isRead'] ?? false,
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
      'type': type,
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'data': data,
      'isRead': isRead,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Copy with
  AppNotification copyWith({
    String? notificationId,
    String? userId,
    String? type,
    String? title,
    String? body,
    String? imageUrl,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      notificationId: notificationId ?? this.notificationId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
