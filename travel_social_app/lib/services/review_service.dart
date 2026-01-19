import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../models/review.dart';

/// Service quản lý đánh giá địa điểm
class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference get _reviewsRef => _firestore.collection('reviews');
  CollectionReference get _placesRef => _firestore.collection('places');

  /// Tạo đánh giá mới
  Future<String?> createReview(Review review) async {
    try {
      final docRef = await _reviewsRef.add(review.toFirestore());

      // Cập nhật rating và reviewCount của place
      await _updatePlaceRating(review.placeId);

      debugPrint('✅ Created review: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating review: $e');
      return null;
    }
  }

  /// Upload ảnh đánh giá lên Firebase Storage
  Future<List<String>> uploadReviewImages(
    List<File> images,
    String reviewFolder,
  ) async {
    final List<String> imageUrls = [];

    try {
      for (int i = 0; i < images.length; i++) {
        final file = images[i];
        final fileName =
            'review_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final ref = _storage.ref().child('reviews/$reviewFolder/$fileName');

        final uploadTask = await ref.putFile(file);
        final imageUrl = await uploadTask.ref.getDownloadURL();
        imageUrls.add(imageUrl);

        debugPrint('✅ Uploaded image ${i + 1}/${images.length}');
      }

      debugPrint('✅ All images uploaded successfully');
      return imageUrls;
    } catch (e) {
      debugPrint('❌ Error uploading images: $e');
      return [];
    }
  }

  /// Cập nhật rating và reviewCount của place
  Future<void> _updatePlaceRating(String placeId) async {
    try {
      final reviewsSnapshot =
          await _reviewsRef.where('placeId', isEqualTo: placeId).get();

      if (reviewsSnapshot.docs.isEmpty) {
        return;
      }

      double totalRating = 0.0;
      int reviewCount = reviewsSnapshot.docs.length;

      for (var doc in reviewsSnapshot.docs) {
        final review = Review.fromFirestore(doc);
        totalRating += review.rating;
      }

      final avgRating = totalRating / reviewCount;

      await _placesRef.doc(placeId).update({
        'rating': avgRating,
        'reviewCount': reviewCount,
      });

      debugPrint('✅ Updated place rating: $avgRating ($reviewCount reviews)');
    } catch (e) {
      debugPrint('❌ Error updating place rating: $e');
    }
  }

  /// Lấy danh sách đánh giá của một địa điểm
  Future<List<Review>> getReviewsByPlace(String placeId) async {
    try {
      final querySnapshot =
          await _reviewsRef
              .where('placeId', isEqualTo: placeId)
              .orderBy('createdAt', descending: true)
              .get();

      return querySnapshot.docs
          .map((doc) => Review.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting reviews: $e');
      return [];
    }
  }

  /// Stream đánh giá của một địa điểm
  Stream<List<Review>> reviewsStreamByPlace(String placeId) {
    return _reviewsRef
        .where('placeId', isEqualTo: placeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList(),
        );
  }

  /// Lấy đánh giá của user cho một địa điểm
  Future<Review?> getUserReviewForPlace(String userId, String placeId) async {
    try {
      final querySnapshot =
          await _reviewsRef
              .where('userId', isEqualTo: userId)
              .where('placeId', isEqualTo: placeId)
              .limit(1)
              .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return Review.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      debugPrint('❌ Error getting user review: $e');
      return null;
    }
  }

  /// Lấy tất cả reviews của user (cho profile screen)
  Stream<List<Review>> getUserReviews(String userId) {
    return _reviewsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList(),
        );
  }

  /// Lấy review theo ID
  Future<Review?> getReviewById(String reviewId) async {
    try {
      final doc = await _reviewsRef.doc(reviewId).get();
      if (doc.exists) {
        return Review.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting review by id: $e');
      return null;
    }
  }

  /// Xóa đánh giá
  Future<bool> deleteReview(String reviewId, String placeId) async {
    try {
      // Lấy thông tin review trước khi xóa để xóa ảnh
      final reviewDoc = await _reviewsRef.doc(reviewId).get();
      if (reviewDoc.exists) {
        final review = Review.fromFirestore(reviewDoc);

        // Xóa tất cả ảnh của review khỏi Storage
        if (review.images != null && review.images!.isNotEmpty) {
          await deleteReviewImages(review.images!);
        }
      }

      // Xóa document khỏi Firestore
      await _reviewsRef.doc(reviewId).delete();

      // Cập nhật lại rating của place
      await _updatePlaceRating(placeId);

      debugPrint('✅ Deleted review: $reviewId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting review: $e');
      return false;
    }
  }

  /// Xóa ảnh từ Firebase Storage
  Future<void> deleteReviewImages(List<String> imageUrls) async {
    try {
      for (final imageUrl in imageUrls) {
        try {
          // Lấy reference từ URL
          final ref = _storage.refFromURL(imageUrl);
          await ref.delete();
          debugPrint('✅ Deleted image: $imageUrl');
        } catch (e) {
          debugPrint('⚠️ Failed to delete image: $imageUrl - $e');
          // Tiếp tục xóa các ảnh khác ngay cả khi một ảnh lỗi
        }
      }
    } catch (e) {
      debugPrint('❌ Error deleting images: $e');
    }
  }

  /// Cập nhật đánh giá
  Future<bool> updateReview(
    String reviewId,
    String placeId, {
    double? rating,
    String? content,
    List<String>? images,
    bool? isCheckedIn,
    DateTime? checkedInAt,
  }) async {
    try {
      final Map<String, dynamic> updates = {};

      if (rating != null) updates['rating'] = rating;
      if (content != null) updates['content'] = content;

      // Xử lý images: null giữ nguyên, empty list = xóa hết, list có data = update
      if (images != null) {
        if (images.isEmpty) {
          updates['images'] = []; // Empty array = không có image
        } else {
          updates['images'] = images;
        }
      }

      if (isCheckedIn != null) updates['isCheckedIn'] = isCheckedIn;
      if (checkedInAt != null) {
        updates['checkedInAt'] = Timestamp.fromDate(checkedInAt);
      }

      await _reviewsRef.doc(reviewId).update(updates);

      // Cập nhật lại rating của place nếu rating thay đổi
      if (rating != null) {
        await _updatePlaceRating(placeId);
      }

      debugPrint('✅ Updated review: $reviewId');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating review: $e');
      return false;
    }
  }

  /// Lấy tất cả ảnh của các review cho một địa điểm
  Future<List<String>> getAllReviewImagesForPlace(String placeId) async {
    try {
      final reviewsSnapshot =
          await _reviewsRef.where('placeId', isEqualTo: placeId).get();

      final List<String> allImages = [];

      for (var doc in reviewsSnapshot.docs) {
        final review = Review.fromFirestore(doc);
        if (review.images != null && review.images!.isNotEmpty) {
          allImages.addAll(review.images!);
        }
      }

      return allImages;
    } catch (e) {
      debugPrint('❌ Error getting all review images: $e');
      return [];
    }
  }

  /// Stream lắng nghe thay đổi ảnh review của một địa điểm (realtime)
  Stream<List<String>> reviewImagesStreamByPlace(String placeId) {
    return _reviewsRef.where('placeId', isEqualTo: placeId).snapshots().map((
      snapshot,
    ) {
      final List<String> allImages = [];

      for (var doc in snapshot.docs) {
        final review = Review.fromFirestore(doc);
        if (review.images != null && review.images!.isNotEmpty) {
          allImages.addAll(review.images!);
        }
      }

      return allImages;
    });
  }
}
