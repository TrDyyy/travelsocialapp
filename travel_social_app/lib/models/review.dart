import 'package:cloud_firestore/cloud_firestore.dart';

/// Model cho đánh giá địa điểm
class Review {
  final String? reviewId;
  final String userId; // Reference đến User
  final String placeId; // Reference đến Place
  final double rating; // 1.0 - 5.0
  final String content; // Nội dung đánh giá
  final List<String>? images; // Danh sách URL hình ảnh
  final DateTime? createdAt;
  final bool isCheckedIn; // User đã check-in tại địa điểm
  final DateTime? checkedInAt; // Thời gian check-in
  final int reactionCount; // Tổng số reactions

  Review({
    this.reviewId,
    required this.userId,
    required this.placeId,
    required this.rating,
    required this.content,
    this.images,
    this.createdAt,
    this.isCheckedIn = false,
    this.checkedInAt,
    this.reactionCount = 0,
  });

  /// Tạo Review từ Firestore document
  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Review(
      reviewId: doc.id,
      userId: data['userId'] ?? '',
      placeId: data['placeId'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      content: data['content'] ?? '',
      images: data['images'] != null ? List<String>.from(data['images']) : null,
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
      isCheckedIn: data['isCheckedIn'] ?? false,
      checkedInAt:
          data['checkedInAt'] != null
              ? (data['checkedInAt'] as Timestamp).toDate()
              : null,
      reactionCount: data['reactionCount'] ?? 0,
    );
  }

  /// Chuyển Review thành Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'placeId': placeId,
      'rating': rating,
      'content': content,
      'images': images,
      'createdAt':
          createdAt != null
              ? Timestamp.fromDate(createdAt!)
              : FieldValue.serverTimestamp(),
      'isCheckedIn': isCheckedIn,
      'checkedInAt':
          checkedInAt != null ? Timestamp.fromDate(checkedInAt!) : null,
      'reactionCount': reactionCount,
    };
  }

  /// Copy with
  Review copyWith({
    String? reviewId,
    String? userId,
    String? placeId,
    double? rating,
    String? content,
    List<String>? images,
    DateTime? createdAt,
    bool? isCheckedIn,
    DateTime? checkedInAt,
    int? reactionCount,
  }) {
    return Review(
      reviewId: reviewId ?? this.reviewId,
      userId: userId ?? this.userId,
      placeId: placeId ?? this.placeId,
      rating: rating ?? this.rating,
      content: content ?? this.content,
      images: images ?? this.images,
      createdAt: createdAt ?? this.createdAt,
      isCheckedIn: isCheckedIn ?? this.isCheckedIn,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      reactionCount: reactionCount ?? this.reactionCount,
    );
  }
}
