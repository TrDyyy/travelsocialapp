import 'package:cloud_firestore/cloud_firestore.dart';

/// Model cho Comment của Post
class Comment {
  final String? commentId;
  final String postId;
  final String userId;
  final String content;
  final List<String>? imageUrls; // Ảnh của comment
  final String? parentCommentId; // ID của comment cha (nếu là reply)
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int reactionCount; // Tổng số reactions

  Comment({
    this.commentId,
    required this.postId,
    required this.userId,
    required this.content,
    this.imageUrls,
    this.parentCommentId,
    this.createdAt,
    this.updatedAt,
    this.reactionCount = 0,
  });

  /// Tạo từ Firestore Document
  factory Comment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Comment(
      commentId: doc.id,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      content: data['content'] ?? '',
      imageUrls:
          data['imageUrls'] != null
              ? List<String>.from(data['imageUrls'])
              : null,
      parentCommentId: data['parentCommentId'],
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
      updatedAt:
          data['updatedAt'] != null
              ? (data['updatedAt'] as Timestamp).toDate()
              : null,
      reactionCount: data['reactionCount'] ?? 0,
    );
  }

  /// Chuyển sang Map để lưu Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'userId': userId,
      'content': content,
      'imageUrls': imageUrls,
      'parentCommentId': parentCommentId,
      'createdAt':
          createdAt != null
              ? Timestamp.fromDate(createdAt!)
              : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'reactionCount': reactionCount,
    };
  }

  /// Copy with
  Comment copyWith({
    String? commentId,
    String? postId,
    String? userId,
    String? content,
    List<String>? imageUrls,
    String? parentCommentId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? reactionCount,
  }) {
    return Comment(
      commentId: commentId ?? this.commentId,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reactionCount: reactionCount ?? this.reactionCount,
    );
  }
}
