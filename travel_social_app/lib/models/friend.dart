import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendshipStatus {
  pending, // Chờ chấp nhận
  accepted, // Đã kết bạn
  rejected, // Đã từ chối
}

/// Model cho Friend/Friendship
class Friendship {
  final String? friendshipId;
  final String userId1; // Người gửi lời mời
  final String userId2; // Người nhận lời mời
  final FriendshipStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Friendship({
    this.friendshipId,
    required this.userId1,
    required this.userId2,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  /// Tạo từ Firestore Document
  factory Friendship.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Friendship(
      friendshipId: doc.id,
      userId1: data['userId1'] ?? '',
      userId2: data['userId2'] ?? '',
      status: FriendshipStatus.values.firstWhere(
        (e) => e.toString() == 'FriendshipStatus.${data['status']}',
        orElse: () => FriendshipStatus.pending,
      ),
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
      'userId1': userId1,
      'userId2': userId2,
      'status': status.toString().split('.').last,
      'createdAt':
          createdAt != null
              ? Timestamp.fromDate(createdAt!)
              : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Copy with
  Friendship copyWith({
    String? friendshipId,
    String? userId1,
    String? userId2,
    FriendshipStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Friendship(
      friendshipId: friendshipId ?? this.friendshipId,
      userId1: userId1 ?? this.userId1,
      userId2: userId2 ?? this.userId2,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check nếu userId là người gửi lời mời
  bool isSender(String userId) => userId1 == userId;

  /// Check nếu userId là người nhận lời mời
  bool isReceiver(String userId) => userId2 == userId;

  /// Lấy ID của người bạn (không phải mình)
  String getOtherUserId(String myUserId) {
    return userId1 == myUserId ? userId2 : userId1;
  }
}
