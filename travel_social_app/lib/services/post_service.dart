import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../models/comment.dart';
import 'media_service.dart';
import 'community_service.dart';

/// Service quản lý Posts, Comments (Reactions handled by ReactionService)
class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MediaService _mediaService = MediaService();
  final CommunityService _communityService = CommunityService();

  CollectionReference get _postsRef => _firestore.collection('posts');

  // ==================== POST CRUD ====================

  /// Tạo post mới
  Future<String?> createPost(Post post, List<File>? mediaFiles) async {
    try {
      // Upload media nếu có
      List<String>? mediaUrls;
      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        mediaUrls = await _mediaService.uploadMedia(
          mediaFiles,
          'posts/${post.userId}_${DateTime.now().millisecondsSinceEpoch}',
        );

        if (mediaUrls.isEmpty && mediaFiles.isNotEmpty) {
          debugPrint('❌ Failed to upload media');
          return null;
        }
      }

      // Tạo post với media URLs
      final postData = post.copyWith(mediaUrls: mediaUrls).toFirestore();
      final docRef = await _postsRef.add(postData);

      // Nếu post trong community, increment postCount
      if (post.communityId != null) {
        await _communityService.incrementPostCount(post.communityId!);
      }

      debugPrint('✅ Created post: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating post: $e');
      return null;
    }
  }

  /// Update post
  Future<bool> updatePost(
    String postId, {
    String? content,
    List<String>? mediaUrls,
    String? taggedPlaceId,
    String? taggedPlaceName,
    List<String>? taggedUserIds,
    String? feeling,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (content != null) updates['content'] = content;

      // Xử lý mediaUrls: null giữ nguyên, empty list = xóa hết, list có data = update
      if (mediaUrls != null) {
        if (mediaUrls.isEmpty) {
          updates['mediaUrls'] = []; // Empty array = không có media
        } else {
          updates['mediaUrls'] = mediaUrls;
        }
      }

      // Update tagged place (always update to allow clearing)
      updates['taggedPlaceId'] = taggedPlaceId;
      updates['taggedPlaceName'] = taggedPlaceName;

      // Update tagged users (empty list or null = clear tags)
      updates['taggedUserIds'] = taggedUserIds ?? [];

      // Update feeling (null = clear feeling)
      updates['feeling'] = feeling;

      await _postsRef.doc(postId).update(updates);

      debugPrint('✅ Updated post: $postId');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating post: $e');
      return false;
    }
  }

  /// Xóa post (bao gồm media, comments, likes)
  Future<bool> deletePost(String postId) async {
    try {
      final postDoc = await _postsRef.doc(postId).get();
      if (!postDoc.exists) return false;

      final post = Post.fromFirestore(postDoc);

      // Xóa media từ Storage
      if (post.mediaUrls != null && post.mediaUrls!.isNotEmpty) {
        await _mediaService.deleteMedia(post.mediaUrls!);
      }

      // Xóa tất cả comments
      final commentsSnapshot =
          await _postsRef.doc(postId).collection('comments').get();
      for (var doc in commentsSnapshot.docs) {
        final comment = Comment.fromFirestore(doc);
        // Xóa ảnh của comment
        if (comment.imageUrls != null && comment.imageUrls!.isNotEmpty) {
          await _mediaService.deleteMedia(comment.imageUrls!);
        }
        await doc.reference.delete();
      }

      // Xóa tất cả likes
      final likesSnapshot =
          await _postsRef.doc(postId).collection('likes').get();
      for (var doc in likesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Xóa post document
      await _postsRef.doc(postId).delete();

      // Nếu post trong community, decrement postCount
      if (post.communityId != null) {
        await _communityService.decrementPostCount(post.communityId!);
      }

      debugPrint('✅ Deleted post: $postId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting post: $e');
      return false;
    }
  }

  /// Lấy post theo ID
  Future<Post?> getPostById(String postId) async {
    try {
      final doc = await _postsRef.doc(postId).get();
      if (doc.exists) {
        return Post.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting post: $e');
      return null;
    }
  }

  /// Stream tất cả posts (mới nhất trước)
  /// Lấy tất cả posts và filter ở client-side để loại bỏ group posts
  Stream<List<Post>> postsStream() {
    return _postsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => Post.fromFirestore(doc))
                  .where(
                    (post) => post.communityId == null,
                  ) // Filter client-side
                  .toList(),
        );
  }

  /// Stream posts của user
  Stream<List<Post>> userPostsStream(String userId) {
    return _postsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList(),
        );
  }

  /// Lấy posts của user (cho profile screen)
  Stream<List<Post>> getUserPosts(String userId) {
    return userPostsStream(userId);
  }

  // ==================== LIKE CRUD REMOVED ====================
  // Like functionality replaced with Reaction system
  // Use ReactionService for adding/removing reactions on posts
  // See: services/reaction_service.dart and widgets/reaction_button.dart

  // ==================== COMMENT CRUD ====================

  /// Tạo comment
  Future<String?> createComment(Comment comment, List<File>? imageFiles) async {
    try {
      // Upload images nếu có
      List<String>? imageUrls;
      if (imageFiles != null && imageFiles.isNotEmpty) {
        imageUrls = await _mediaService.uploadMedia(
          imageFiles,
          'comments/${comment.postId}_${comment.userId}_${DateTime.now().millisecondsSinceEpoch}',
        );

        if (imageUrls.isEmpty && imageFiles.isNotEmpty) {
          debugPrint('❌ Failed to upload comment images');
          return null;
        }
      }

      // Tạo comment với image URLs
      final commentData = comment.copyWith(imageUrls: imageUrls).toFirestore();
      final docRef = await _postsRef
          .doc(comment.postId)
          .collection('comments')
          .add(commentData);

      // Tăng commentCount
      await _postsRef.doc(comment.postId).update({
        'commentCount': FieldValue.increment(1),
      });

      debugPrint('✅ Created comment: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating comment: $e');
      return null;
    }
  }

  /// Update comment
  Future<bool> updateComment(
    String postId,
    String commentId, {
    String? content,
    List<String>? imageUrls,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (content != null) updates['content'] = content;

      // Xử lý imageUrls: null giữ nguyên, empty list = xóa hết, list có data = update
      if (imageUrls != null) {
        if (imageUrls.isEmpty) {
          updates['imageUrls'] = []; // Empty array = không có image
        } else {
          updates['imageUrls'] = imageUrls;
        }
      }

      await _postsRef
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .update(updates);

      debugPrint('✅ Updated comment: $commentId');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating comment: $e');
      return false;
    }
  }

  /// Xóa comment (và tất cả replies nếu là parent comment)
  Future<bool> deleteComment(String postId, String commentId) async {
    try {
      final commentDoc =
          await _postsRef
              .doc(postId)
              .collection('comments')
              .doc(commentId)
              .get();

      if (!commentDoc.exists) return false;

      final comment = Comment.fromFirestore(commentDoc);

      // Xóa ảnh của comment
      if (comment.imageUrls != null && comment.imageUrls!.isNotEmpty) {
        await _mediaService.deleteMedia(comment.imageUrls!);
      }

      int totalDeletedCount = 1; // Count comment chính

      // Nếu là comment cha, xóa tất cả replies (đệ quy cho nested)
      if (comment.parentCommentId == null) {
        totalDeletedCount += await _deleteRepliesRecursively(postId, commentId);
      }

      // Xóa comment chính
      await commentDoc.reference.delete();

      // Giảm commentCount một lần với tổng số (comment + all replies)
      await _postsRef.doc(postId).update({
        'commentCount': FieldValue.increment(-totalDeletedCount),
      });

      debugPrint('✅ Deleted comment: $commentId (total: $totalDeletedCount)');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting comment: $e');
      return false;
    }
  }

  /// Xóa tất cả replies đệ quy và trả về số lượng đã xóa
  Future<int> _deleteRepliesRecursively(
    String postId,
    String parentCommentId,
  ) async {
    int deletedCount = 0;

    final repliesSnapshot =
        await _postsRef
            .doc(postId)
            .collection('comments')
            .where('parentCommentId', isEqualTo: parentCommentId)
            .get();

    for (var replyDoc in repliesSnapshot.docs) {
      final reply = Comment.fromFirestore(replyDoc);

      // Xóa ảnh của reply
      if (reply.imageUrls != null && reply.imageUrls!.isNotEmpty) {
        await _mediaService.deleteMedia(reply.imageUrls!);
      }

      // Đệ quy xóa replies của reply này
      deletedCount += await _deleteRepliesRecursively(postId, replyDoc.id);

      // Xóa reply
      await replyDoc.reference.delete();
      deletedCount++; // Tăng count cho reply này
    }

    return deletedCount;
  }

  /// Stream comments của post
  Stream<List<Comment>> commentsStream(String postId) {
    return _postsRef
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Comment.fromFirestore(doc)).toList(),
        );
  }

  /// Xóa media từ comment
  Future<void> deleteCommentImages(List<String> imageUrls) async {
    try {
      await _mediaService.deleteMedia(imageUrls);
    } catch (e) {
      debugPrint('❌ Error deleting comment images: $e');
    }
  }
}
