import 'package:cloud_firestore/cloud_firestore.dart';

/// Model cho Like của Post
class Like {
  final String? likeId;
  final String postId;
  final String userId;
  final DateTime? createdAt;

  Like({
    this.likeId,
    required this.postId,
    required this.userId,
    this.createdAt,
  });

  /// Tạo từ Firestore Document
  factory Like.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Like(
      likeId: doc.id,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
    );
  }

  /// Chuyển sang Map để lưu Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'userId': userId,
      'createdAt':
          createdAt != null
              ? Timestamp.fromDate(createdAt!)
              : FieldValue.serverTimestamp(),
    };
  }
}
