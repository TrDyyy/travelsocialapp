import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/violation_request.dart';
import '../utils/constants.dart';

/// Service xử lý yêu cầu báo cáo vi phạm
class ViolationRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _requestsRef =>
      _firestore.collection('violationRequests');

  /// Tạo yêu cầu báo cáo vi phạm mới
  ///
  /// [request] - Thông tin yêu cầu báo cáo vi phạm
  ///
  /// Returns: ID của request đã tạo hoặc null nếu thất bại
  Future<String?> createViolationReport(ViolationRequest request) async {
    try {
      final docRef = await _requestsRef.add(request.toFirestore());
      debugPrint('✅ Created violation report: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating violation report: $e');
      return null;
    }
  }

  /// Lấy danh sách báo cáo vi phạm của user
  ///
  /// [userId] - ID của user
  /// [limit] - Số lượng tối đa kết quả trả về
  ///
  /// Returns: Danh sách các báo cáo vi phạm
  Future<List<ViolationRequest>> getUserReports(
    String userId, {
    int? limit,
  }) async {
    try {
      Query query = _requestsRef
          .where('reporterId', isEqualTo: userId)
          .orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) => ViolationRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting user reports: $e');
      return [];
    }
  }

  /// Lấy danh sách báo cáo vi phạm theo trạng thái
  ///
  /// [userId] - ID của user
  /// [status] - Trạng thái cần lọc (pending, approved, rejected)
  /// [limit] - Số lượng tối đa kết quả trả về
  ///
  /// Returns: Danh sách các báo cáo vi phạm theo trạng thái
  Future<List<ViolationRequest>> getUserReportsByStatus(
    String userId,
    String status, {
    int? limit,
  }) async {
    try {
      Query query = _requestsRef
          .where('reporterId', isEqualTo: userId)
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) => ViolationRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting user reports by status: $e');
      return [];
    }
  }

  /// Lấy chi tiết một báo cáo vi phạm
  ///
  /// [requestId] - ID của báo cáo
  ///
  /// Returns: Thông tin báo cáo hoặc null nếu không tìm thấy
  Future<ViolationRequest?> getReportById(String requestId) async {
    try {
      final doc = await _requestsRef.doc(requestId).get();
      if (doc.exists) {
        return ViolationRequest.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting report by ID: $e');
      return null;
    }
  }

  /// Đếm số lượng báo cáo vi phạm của user theo trạng thái
  ///
  /// [userId] - ID của user
  ///
  /// Returns: Map chứa số lượng báo cáo theo từng trạng thái
  Future<Map<String, int>> getReportCountsByStatus(String userId) async {
    try {
      final reports = await getUserReports(userId);

      final counts = {
        ViolationConstants.statusPending: 0,
        ViolationConstants.statusApproved: 0,
        ViolationConstants.statusRejected: 0,
      };

      for (var report in reports) {
        counts[report.status] = (counts[report.status] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      debugPrint('❌ Error getting report counts: $e');
      return {
        ViolationConstants.statusPending: 0,
        ViolationConstants.statusApproved: 0,
        ViolationConstants.statusRejected: 0,
      };
    }
  }

  /// Kiểm tra xem user đã báo cáo đối tượng này chưa
  ///
  /// [userId] - ID của user
  /// [objectType] - Loại đối tượng (place, post, comment, review, user)
  /// [objectId] - ID của đối tượng
  ///
  /// Returns: true nếu đã báo cáo, false nếu chưa
  Future<bool> hasUserReportedObject(
    String userId,
    ViolatedObjectType objectType,
    String objectId,
  ) async {
    try {
      final querySnapshot =
          await _requestsRef
              .where('reporterId', isEqualTo: userId)
              .where('objectType', isEqualTo: objectType.toFirestore())
              .get();

      for (var doc in querySnapshot.docs) {
        final request = ViolationRequest.fromFirestore(doc);
        if (request.violatedObjectId == objectId) {
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error checking if user reported object: $e');
      return false;
    }
  }

  /// Xóa báo cáo vi phạm (chỉ khi đang pending)
  ///
  /// [requestId] - ID của báo cáo
  /// [userId] - ID của user (để kiểm tra quyền)
  ///
  /// Returns: true nếu xóa thành công, false nếu thất bại
  Future<bool> deleteReport(String requestId, String userId) async {
    try {
      // Kiểm tra quyền sở hữu và trạng thái
      final report = await getReportById(requestId);
      if (report == null) {
        debugPrint('❌ Report not found');
        return false;
      }

      if (report.reporterId != userId) {
        debugPrint('❌ User does not have permission to delete this report');
        return false;
      }

      if (report.status != ViolationConstants.statusPending) {
        debugPrint('❌ Cannot delete report that has been reviewed');
        return false;
      }

      await _requestsRef.doc(requestId).delete();
      debugPrint('✅ Deleted report: $requestId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting report: $e');
      return false;
    }
  }

  /// Stream để lắng nghe thay đổi của báo cáo vi phạm theo user
  ///
  /// [userId] - ID của user
  ///
  /// Returns: Stream các báo cáo vi phạm
  Stream<List<ViolationRequest>> getUserReportsStream(String userId) {
    return _requestsRef
        .where('reporterId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ViolationRequest.fromFirestore(doc))
                  .toList(),
        );
  }

  /// Stream để lắng nghe thay đổi của một báo cáo cụ thể
  ///
  /// [requestId] - ID của báo cáo
  ///
  /// Returns: Stream báo cáo vi phạm
  Stream<ViolationRequest?> getReportStream(String requestId) {
    return _requestsRef.doc(requestId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return ViolationRequest.fromFirestore(snapshot);
      }
      return null;
    });
  }

  // ==================== HELPER METHODS ====================

  /// Tạo violated object map từ Place
  static Map<String, dynamic> createViolatedObjectFromPlace(dynamic place) {
    return {
      'placeId': place.placeId,
      'name': place.name,
      'address': place.address ?? '',
      'googlePlaceId': place.googlePlaceId ?? '',
      'description': place.description ?? '',
      'typeId': place.typeId ?? '',
      'createdBy': place.createdBy, // userId của người tạo
      'images': place.images ?? [],
      'rating': place.rating ?? 0.0,
      'reviewCount': place.reviewCount ?? 0,
      'latitude': place.latitude,
      'longitude': place.longitude,
      'createdAt': place.createdAt?.toIso8601String(),
    };
  }

  /// Tạo violated object map từ Post
  static Map<String, dynamic> createViolatedObjectFromPost(dynamic post) {
    return {
      'postId': post.postId,
      'userId': post.userId,
      'type': post.type.toString(),
      'content': post.content,
      'mediaUrls': post.mediaUrls ?? [], // Ảnh hoặc video
      'taggedPlaceId': post.taggedPlaceId,
      'taggedPlaceName': post.taggedPlaceName,
      'taggedUserIds': post.taggedUserIds ?? [],
      'feeling': post.feeling?.toString(),
      'communityId': post.communityId,
      'reviewId': post.reviewId,
      'placeId': post.placeId,
      'createdAt': post.createdAt?.toIso8601String(),
      'updatedAt': post.updatedAt?.toIso8601String(),
      'reactionCount': post.reactionCount,
      'commentCount': post.commentCount,
    };
  }

  /// Tạo violated object map từ Comment
  static Map<String, dynamic> createViolatedObjectFromComment(dynamic comment) {
    return {
      'commentId': comment.commentId,
      'postId': comment.postId,
      'userId': comment.userId,
      'content': comment.content,
      'imageUrls': comment.imageUrls ?? [], // Ảnh của comment
      'parentCommentId': comment.parentCommentId,
      'createdAt': comment.createdAt?.toIso8601String(),
      'updatedAt': comment.updatedAt?.toIso8601String(),
      'reactionCount': comment.reactionCount,
    };
  }

  /// Tạo violated object map từ Review
  static Map<String, dynamic> createViolatedObjectFromReview(dynamic review) {
    return {
      'reviewId': review.reviewId,
      'placeId': review.placeId,
      'userId': review.userId,
      'content': review.content,
      'rating': review.rating,
      'images': review.images ?? [],
      'isCheckedIn': review.isCheckedIn,
      'checkedInAt': review.checkedInAt?.toIso8601String(),
      'createdAt': review.createdAt?.toIso8601String(),
      'reactionCount': review.reactionCount,
    };
  }

  /// Tạo violated object map từ User
  static Map<String, dynamic> createViolatedObjectFromUser(dynamic user) {
    return {
      'userId': user.userId,
      'name': user.name,
      'email': user.email,
      'avatarUrl': user.avatarUrl ?? '',
      'bio': user.bio ?? '',
      'role': user.role,
      'totalPoints': user.totalPoints,
      'level': user.level,
      'currentBadge': user.currentBadge?.toFirestore(),
      'createdAt': user.createdAt.toIso8601String(),
    };
  }
}
