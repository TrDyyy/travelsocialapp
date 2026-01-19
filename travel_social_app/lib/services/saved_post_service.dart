import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Service quản lý bài viết đã lưu (sử dụng trường isSavedBy trong Post)
class SavedPostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Collection reference cho posts
  CollectionReference get _postsCollection => _firestore.collection('posts');

  /// Lưu bài viết (thêm userId vào mảng isSavedBy)
  Future<bool> savePost(String postId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        debugPrint('❌ User not authenticated');
        return false;
      }

      await _postsCollection.doc(postId).update({
        'isSavedBy': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Saved post: $postId by user: $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving post: $e');
      return false;
    }
  }

  /// Bỏ lưu bài viết (xóa userId khỏi mảng isSavedBy)
  Future<bool> unsavePost(String postId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        debugPrint('❌ User not authenticated');
        return false;
      }

      await _postsCollection.doc(postId).update({
        'isSavedBy': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Unsaved post: $postId by user: $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Error unsaving post: $e');
      return false;
    }
  }

  /// Kiểm tra bài viết đã được lưu chưa
  Future<bool> isPostSaved(String postId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return false;
      }

      final doc = await _postsCollection.doc(postId).get();
      if (!doc.exists) {
        return false;
      }

      final data = doc.data() as Map<String, dynamic>;
      final isSavedBy = data['isSavedBy'] as List<dynamic>?;

      return isSavedBy?.contains(userId) ?? false;
    } catch (e) {
      // Ignore permission errors - user not logged in or no permission
      // This is expected behavior and won't affect UX
      return false;
    }
  }

  /// Stream kiểm tra trạng thái saved của bài viết
  Stream<bool> watchPostSavedStatus(String postId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value(false);
    }

    return _postsCollection.doc(postId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return false;
      }

      final data = snapshot.data() as Map<String, dynamic>?;
      final isSavedBy = data?['isSavedBy'] as List<dynamic>?;

      return isSavedBy?.contains(userId) ?? false;
    });
  }

  /// Lấy danh sách bài viết đã lưu của user
  Future<List<String>> getSavedPostIds() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return [];
      }

      final querySnapshot =
          await _postsCollection
              .where('isSavedBy', arrayContains: userId)
              .orderBy('updatedAt', descending: true)
              .get();

      return querySnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('❌ Error getting saved posts: $e');
      return [];
    }
  }

  /// Stream danh sách bài viết đã lưu
  Stream<List<String>> watchSavedPostIds() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }

    return _postsCollection
        .where('isSavedBy', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => doc.id).toList();
        });
  }

  /// Đếm số lượng bài viết đã lưu
  Future<int> getSavedPostCount() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return 0;
      }

      final querySnapshot =
          await _postsCollection
              .where('isSavedBy', arrayContains: userId)
              .get();

      return querySnapshot.docs.length;
    } catch (e) {
      debugPrint('❌ Error getting saved post count: $e');
      return 0;
    }
  }

  /// Toggle saved status (lưu nếu chưa lưu, bỏ lưu nếu đã lưu)
  Future<bool> toggleSavePost(String postId) async {
    final isSaved = await isPostSaved(postId);

    if (isSaved) {
      return await unsavePost(postId);
    } else {
      return await savePost(postId);
    }
  }
}
