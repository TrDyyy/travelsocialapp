import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../models/user_model.dart';
import '../models/review.dart';
import '../models/place.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../services/review_service.dart';
import '../services/place_service.dart';
import '../services/notification_service.dart';

/// Provider quản lý state của posts
class PostProvider extends ChangeNotifier {
  final PostService _postService = PostService();
  final UserService _userService = UserService();
  final ReviewService _reviewService = ReviewService();
  final PlaceService _placeService = PlaceService();
  final NotificationService _notificationService = NotificationService();

  List<Post> _posts = [];
  List<Post> _allPosts = []; // Store all posts from stream
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  StreamSubscription<List<Post>>? _postsSubscription;

  int _currentLimit = 15; // Initial limit
  static const int _loadMoreCount = 10; // Load 10 more each time
  bool _hasMore = true;

  // Cache cho user, review, place để tránh load lại nhiều lần
  final Map<String, UserModel?> _userCache = {};
  final Map<String, Review?> _reviewCache = {};
  final Map<String, Place?> _placeCache = {};

  // Getters
  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;

  PostProvider() {
    _initializePosts();
  }

  /// Khởi tạo và lắng nghe stream posts
  void _initializePosts() {
    _setLoading(true);

    // Listen to posts stream
    _postsSubscription = _postService.postsStream().listen(
      (posts) {
        _allPosts = posts;
        _posts = _allPosts.take(_currentLimit).toList();
        _hasMore = _allPosts.length > _currentLimit;
        _setLoading(false);
        notifyListeners();
      },
      onError: (error) {
        _setError('Lỗi tải bài viết: $error');
        _setLoading(false);
      },
      cancelOnError: false, // Không cancel stream khi có lỗi
    );
  }

  /// Load more posts (pagination)
  void loadMore() {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    _currentLimit += _loadMoreCount;
    _posts = _allPosts.take(_currentLimit).toList();
    _hasMore = _allPosts.length > _currentLimit;

    _isLoadingMore = false;
    notifyListeners();
  }

  /// Lấy user từ cache hoặc load mới
  Future<UserModel?> getUserForPost(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    try {
      final user = await _userService.getUserById(userId);
      _userCache[userId] = user;
      return user;
    } catch (e) {
      debugPrint('Lỗi load user $userId: $e');
      return null;
    }
  }

  /// Lấy review từ cache hoặc load mới
  Future<Review?> getReviewForPost(String reviewId) async {
    if (_reviewCache.containsKey(reviewId)) {
      return _reviewCache[reviewId];
    }

    try {
      final review = await _reviewService.getReviewById(reviewId);
      _reviewCache[reviewId] = review;
      return review;
    } catch (e) {
      debugPrint('Lỗi load review $reviewId: $e');
      return null;
    }
  }

  /// Lấy place từ cache hoặc load mới
  Future<Place?> getPlaceForPost(String placeId) async {
    if (_placeCache.containsKey(placeId)) {
      return _placeCache[placeId];
    }

    try {
      final place = await _placeService.getPlaceById(placeId);
      _placeCache[placeId] = place;
      return place;
    } catch (e) {
      debugPrint('Lỗi load place $placeId: $e');
      return null;
    }
  }

  /// Tạo post mới
  Future<bool> createPost(Post post, List<dynamic>? mediaFiles) async {
    try {
      _setLoading(true);
      _clearError();

      final postId = await _postService.createPost(
        post,
        mediaFiles?.cast<File>(),
      );

      _setLoading(false);
      return postId != null;
    } catch (e) {
      _setError('Lỗi tạo bài viết: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Cập nhật post
  Future<bool> updatePost(
    String postId,
    String content,
    List<String> mediaUrls, {
    String? taggedPlaceId,
    String? taggedPlaceName,
    List<String>? taggedUserIds,
    Feeling? feeling,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final success = await _postService.updatePost(
        postId,
        content: content,
        mediaUrls: mediaUrls,
        taggedPlaceId: taggedPlaceId,
        taggedPlaceName: taggedPlaceName,
        taggedUserIds: taggedUserIds,
        feeling: feeling?.name,
      );

      // Update local post ngay lập tức (không đợi stream)
      if (success) {
        final index = _posts.indexWhere((p) => p.postId == postId);
        if (index != -1) {
          _posts[index] = _posts[index].copyWith(
            content: content,
            clearMediaUrls: mediaUrls.isEmpty, // Set null nếu empty
            mediaUrls: mediaUrls.isNotEmpty ? mediaUrls : null,
            updatedAt: DateTime.now(),
            taggedPlaceId: taggedPlaceId, // null = cleared
            taggedPlaceName: taggedPlaceName, // null = cleared
            taggedUserIds:
                taggedUserIds != null && taggedUserIds.isNotEmpty
                    ? taggedUserIds
                    : null, // [] or null = cleared
            feeling: feeling, // null = cleared
          );
          notifyListeners(); // Notify để UI update ngay
        }
      }

      _setLoading(false);
      return success;
    } catch (e) {
      _setError('Lỗi cập nhật bài viết: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Xóa post
  Future<bool> deletePost(String postId) async {
    try {
      _setLoading(true);
      _clearError();

      final success = await _postService.deletePost(postId);

      // Xóa cache liên quan
      _posts.removeWhere((p) => p.postId == postId);

      _setLoading(false);
      notifyListeners();
      return success;
    } catch (e) {
      _setError('Lỗi xóa bài viết: $e');
      _setLoading(false);
      return false;
    }
  }

  // Reaction methods removed - now handled by ReactionService directly
  // ReactionButton widget will use ReactionService.toggleReaction() and getReactionsStream()

  /// Tạo comment
  Future<bool> createComment(Comment comment, List<dynamic>? imageFiles) async {
    try {
      final commentId = await _postService.createComment(
        comment,
        imageFiles?.cast<File>(),
      );

      // Trigger UI update để commentCount cập nhật ngay
      if (commentId != null) {
        notifyListeners();

        // Gửi notification
        final post = await _postService.getPostById(comment.postId);
        final currentUser = await _userService.getUserById(comment.userId);

        if (post != null && currentUser != null) {
          // Nếu là reply (có parentCommentId)
          if (comment.parentCommentId != null) {
            // Tìm parent comment để lấy userId của người bị reply
            final comments =
                await _postService.commentsStream(comment.postId).first;
            final parentComment = comments.firstWhere(
              (c) => c.commentId == comment.parentCommentId,
              orElse: () => comment,
            );

            // Gửi thông báo reply nếu không phải tự reply chính mình
            if (parentComment.userId != comment.userId) {
              await _notificationService.sendCommentReplyNotification(
                toUserId: parentComment.userId,
                fromUserId: comment.userId,
                fromUserName: currentUser.name,
                postId: comment.postId,
                commentId: commentId,
                fromUserAvatar: currentUser.avatarUrl,
              );
            }
          } else {
            // Nếu là comment mới (không phải reply)
            // Gửi thông báo cho chủ bài viết nếu không phải tự comment
            if (post.userId != comment.userId) {
              await _notificationService.sendPostCommentNotification(
                toUserId: post.userId,
                fromUserId: comment.userId,
                fromUserName: currentUser.name,
                postId: comment.postId,
                fromUserAvatar: currentUser.avatarUrl,
              );
            }
          }
        }
      }

      return commentId != null;
    } catch (e) {
      _setError('Lỗi tạo bình luận: $e');
      return false;
    }
  }

  /// Sửa comment
  Future<bool> updateComment(
    String postId,
    String commentId, {
    String? content,
    List<String>? imageUrls,
  }) async {
    try {
      final success = await _postService.updateComment(
        postId,
        commentId,
        content: content,
        imageUrls: imageUrls,
      );

      // Trigger UI update (nếu cần)
      if (success) {
        notifyListeners();
      }

      return success;
    } catch (e) {
      _setError('Lỗi sửa bình luận: $e');
      return false;
    }
  }

  /// Xóa comment (và tất cả replies nếu là parent)
  Future<bool> deleteComment(String postId, String commentId) async {
    try {
      final success = await _postService.deleteComment(postId, commentId);

      // Trigger UI update để commentCount cập nhật ngay
      if (success) {
        notifyListeners();
      }

      return success;
    } catch (e) {
      _setError('Lỗi xóa bình luận: $e');
      return false;
    }
  }

  /// Lấy stream comments của post
  Stream<List<Comment>> commentsStream(String postId) {
    return _postService.commentsStream(postId);
  }

  /// Lấy stream user posts
  Stream<List<Post>> userPostsStream(String userId) {
    return _postService.userPostsStream(userId);
  }

  /// Lấy post by ID
  Future<Post?> getPostById(String postId) async {
    try {
      return await _postService.getPostById(postId);
    } catch (e) {
      debugPrint('Lỗi load post $postId: $e');
      return null;
    }
  }

  /// Refresh posts
  Future<void> refresh() async {
    _clearError();
    // Stream sẽ tự động cập nhật
  }

  /// Clear cache (khi cần)
  void clearCache() {
    _userCache.clear();
    _reviewCache.clear();
    _placeCache.clear();
    notifyListeners();
  }

  // Helper methods
  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  void _setError(String message) {
    if (_errorMessage != message) {
      _errorMessage = message;
      notifyListeners();
    }
  }

  void _clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
    }
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    super.dispose();
  }
}
