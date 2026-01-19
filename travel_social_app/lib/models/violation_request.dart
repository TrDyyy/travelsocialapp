import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum cho loại đối tượng bị vi phạm
enum ViolatedObjectType {
  place, // Địa điểm
  post, // Bài viết
  comment, // Bình luận
  review, // Đánh giá
  user, // Người dùng
}

extension ViolatedObjectTypeExtension on ViolatedObjectType {
  String toFirestore() {
    return toString().split('.').last;
  }

  static ViolatedObjectType fromFirestore(String value) {
    return ViolatedObjectType.values.firstWhere(
      (e) => e.toFirestore() == value,
      orElse: () => ViolatedObjectType.post,
    );
  }

  String get displayName {
    switch (this) {
      case ViolatedObjectType.place:
        return 'Địa điểm';
      case ViolatedObjectType.post:
        return 'Bài viết';
      case ViolatedObjectType.comment:
        return 'Bình luận';
      case ViolatedObjectType.review:
        return 'Đánh giá';
      case ViolatedObjectType.user:
        return 'Người dùng';
    }
  }
}

/// Model cho yêu cầu báo cáo vi phạm
class ViolationRequest {
  final String? requestId;
  final String reporterId; // ID người dùng gửi báo cáo
  final ViolatedObjectType objectType; // Loại đối tượng vi phạm
  final Map<String, dynamic>
  violatedObject; // Toàn bộ thông tin đối tượng vi phạm
  final String violationType; // Loại vi phạm (từ ViolationConstants)
  final String violationReason; // Lý do chi tiết vi phạm
  final String status; // Trạng thái: "pending", "approved", "rejected"
  final DateTime createdAt;
  final DateTime? reviewedAt; // Thời gian admin xem xét
  final String? reviewNote; // Ghi chú từ admin khi xử lý
  final String? adminId; // ID admin xử lý

  ViolationRequest({
    this.requestId,
    required this.reporterId,
    required this.objectType,
    required this.violatedObject,
    required this.violationType,
    required this.violationReason,
    this.status = 'pending',
    DateTime? createdAt,
    this.reviewedAt,
    this.reviewNote,
    this.adminId,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Tạo từ Firestore document
  factory ViolationRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ViolationRequest(
      requestId: doc.id,
      reporterId: data['reporterId'] ?? '',
      objectType: ViolatedObjectTypeExtension.fromFirestore(
        data['objectType'] ?? 'post',
      ),
      violatedObject: Map<String, dynamic>.from(data['violatedObject'] ?? {}),
      violationType: data['violationType'] ?? '',
      violationReason: data['violationReason'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewNote: data['reviewNote'],
      adminId: data['adminId'],
    );
  }

  /// Chuyển đổi sang Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'reporterId': reporterId,
      'objectType': objectType.toFirestore(),
      'violatedObject': violatedObject,
      'violationType': violationType,
      'violationReason': violationReason,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (reviewNote != null) 'reviewNote': reviewNote,
      if (adminId != null) 'adminId': adminId,
    };
  }

  /// Copy with
  ViolationRequest copyWith({
    String? requestId,
    String? reporterId,
    ViolatedObjectType? objectType,
    Map<String, dynamic>? violatedObject,
    String? violationType,
    String? violationReason,
    String? status,
    DateTime? createdAt,
    DateTime? reviewedAt,
    String? reviewNote,
    String? adminId,
  }) {
    return ViolationRequest(
      requestId: requestId ?? this.requestId,
      reporterId: reporterId ?? this.reporterId,
      objectType: objectType ?? this.objectType,
      violatedObject: violatedObject ?? this.violatedObject,
      violationType: violationType ?? this.violationType,
      violationReason: violationReason ?? this.violationReason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNote: reviewNote ?? this.reviewNote,
      adminId: adminId ?? this.adminId,
    );
  }

  /// Helper để lấy ID của đối tượng vi phạm
  String? get violatedObjectId {
    switch (objectType) {
      case ViolatedObjectType.place:
        return violatedObject['placeId'] as String?;
      case ViolatedObjectType.post:
        return violatedObject['postId'] as String?;
      case ViolatedObjectType.comment:
        return violatedObject['commentId'] as String?;
      case ViolatedObjectType.review:
        return violatedObject['reviewId'] as String?;
      case ViolatedObjectType.user:
        return violatedObject['userId'] as String?;
    }
  }

  /// Helper để lấy user ID của chủ sở hữu đối tượng vi phạm
  String? get violatedObjectOwnerId {
    return violatedObject['userId'] as String?;
  }

  /// Helper để lấy nội dung preview của đối tượng vi phạm
  String? get violatedObjectPreview {
    switch (objectType) {
      case ViolatedObjectType.place:
        return violatedObject['name'] as String?;
      case ViolatedObjectType.post:
        return violatedObject['content'] as String?;
      case ViolatedObjectType.comment:
        return violatedObject['content'] as String?;
      case ViolatedObjectType.review:
        return violatedObject['content'] as String?;
      case ViolatedObjectType.user:
        return violatedObject['username'] as String?;
    }
  }
}
