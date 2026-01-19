import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:line_icons/line_icons.dart';
import 'package:provider/provider.dart';
import 'package:travel_social_app/models/place.dart';
import 'package:travel_social_app/models/post.dart';
import 'package:travel_social_app/models/reaction.dart';
import 'package:travel_social_app/models/review.dart';
import 'package:travel_social_app/models/user_model.dart';
import 'package:travel_social_app/models/violation_request.dart';
import 'package:travel_social_app/services/media_service.dart';
import 'package:travel_social_app/services/user_service.dart';
import 'package:travel_social_app/services/saved_post_service.dart';
import 'package:travel_social_app/states/post_provider.dart';
import 'package:travel_social_app/utils/constants.dart';
import 'package:travel_social_app/utils/navigation_helper.dart';
import 'package:travel_social_app/widgets/media_viewer.dart';
import 'package:travel_social_app/widgets/expandable_text.dart';
import 'package:travel_social_app/widgets/violation_report_dialog.dart';
import 'package:travel_social_app/widgets/reaction_button.dart';

import '../../../profile/profile_screen.dart';
import '../post/create_post_screen.dart';
import 'comments_bottom_sheet.dart';

/// Widget hiển thị một post item
class PostItem extends StatefulWidget {
  final Post post;
  final VoidCallback? onDeleted;
  final bool showGroupAdminDelete; // Hiển thị nút xóa cho group admin
  final VoidCallback? onGroupAdminDelete; // Callback khi admin xóa

  const PostItem({
    super.key,
    required this.post,
    this.onDeleted,
    this.showGroupAdminDelete = false,
    this.onGroupAdminDelete,
  });

  @override
  State<PostItem> createState() => _PostItemState();
}

class _PostItemState extends State<PostItem>
    with AutomaticKeepAliveClientMixin {
  final _mediaService = MediaService();
  final _savedPostService = SavedPostService();

  UserModel? _user;
  Review? _review;
  Place? _place;
  bool _isLoadingData = true;
  bool _isSaved = false;
  bool _isToggingSave = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadSavedStatus();
  }

  @override
  void didUpdateWidget(PostItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reload nếu post thay đổi (ID khác HOẶC content/media khác)
    final postChanged =
        oldWidget.post.postId != widget.post.postId ||
        oldWidget.post.content != widget.post.content ||
        _hasMediaChanged(oldWidget.post.mediaUrls, widget.post.mediaUrls) ||
        oldWidget.post.updatedAt != widget.post.updatedAt;

    if (postChanged) {
      _loadData();
    }
  }

  // Helper để kiểm tra mediaUrls có thay đổi không
  bool _hasMediaChanged(List<String>? oldMedia, List<String>? newMedia) {
    if (oldMedia == null && newMedia == null) return false;
    if (oldMedia == null || newMedia == null) return true;
    if (oldMedia.length != newMedia.length) return true;

    for (int i = 0; i < oldMedia.length; i++) {
      if (oldMedia[i] != newMedia[i]) return true;
    }

    return false;
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    final postProvider = Provider.of<PostProvider>(context, listen: false);

    // Load user từ cache/provider
    _user = await postProvider.getUserForPost(widget.post.userId);

    // Nếu là review share, load review và place từ cache/provider
    if (widget.post.type == PostType.reviewShare) {
      if (widget.post.reviewId != null) {
        _review = await postProvider.getReviewForPost(widget.post.reviewId!);
      }
      if (widget.post.placeId != null) {
        _place = await postProvider.getPlaceForPost(widget.post.placeId!);
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  Future<void> _loadSavedStatus() async {
    if (widget.post.postId == null) return;

    final isSaved = await _savedPostService.isPostSaved(widget.post.postId!);
    if (mounted) {
      setState(() {
        _isSaved = isSaved;
      });
    }
  }

  Future<void> _toggleSave() async {
    if (widget.post.postId == null || _isToggingSave) return;

    setState(() {
      _isToggingSave = true;
    });

    final success = await _savedPostService.toggleSavePost(widget.post.postId!);

    if (success && mounted) {
      setState(() {
        _isSaved = !_isSaved;
        _isToggingSave = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isSaved ? '✅ Đã lưu bài viết' : 'Đã bỏ lưu bài viết'),
          backgroundColor: AppColors.primaryGreen,
          duration: const Duration(seconds: 1),
        ),
      );
    } else if (mounted) {
      setState(() {
        _isToggingSave = false;
      });
    }
  }

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xóa bài viết'),
            content: const Text('Bạn có chắc muốn xóa bài viết này?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Xóa'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final postProvider = Provider.of<PostProvider>(context, listen: false);
      final success = await postProvider.deletePost(widget.post.postId!);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Đã xóa bài viết'),
              backgroundColor: AppColors.primaryGreen,
            ),
          );
          widget.onDeleted?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Không thể xóa bài viết. Vui lòng thử lại!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editPost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(existingPost: widget.post),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Đã cập nhật bài viết'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    }
  }

  void _reportPost() {
    showDialog(
      context: context,
      builder:
          (context) => ViolationReportDialog(
            objectType: ViolatedObjectType.post,
            violatedObject: widget.post,
            onReportSuccess: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Đã gửi báo cáo vi phạm'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
          ),
    );
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(post: widget.post),
    );
  }

  void _showMediaViewer(int index) {
    if (widget.post.mediaUrls != null && widget.post.mediaUrls!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => MediaViewer(
                mediaUrls: widget.post.mediaUrls!,
                initialIndex: index,
              ),
        ),
      );
    }
  }

  Future<List<UserModel>> _loadTaggedUsers() async {
    debugPrint('🔍 Loading tagged users for post ${widget.post.postId}');
    debugPrint('📋 Tagged user IDs: ${widget.post.taggedUserIds}');

    if (widget.post.taggedUserIds == null ||
        widget.post.taggedUserIds!.isEmpty) {
      debugPrint('❌ No tagged users found');
      return [];
    }

    final userService = UserService();
    final users = <UserModel>[];

    for (final userId in widget.post.taggedUserIds!) {
      try {
        final user = await userService.getUserById(userId);
        if (user != null) {
          users.add(user);
        }
      } catch (e) {
        debugPrint('Error loading tagged user $userId: $e');
      }
    }

    debugPrint(
      '✅ Loaded ${users.length} tagged users: ${users.map((u) => u.name).join(", ")}',
    );
    return users;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Don't show loading spinner, just return empty container while loading
    // This prevents UI flickering during rebuild
    if (_isLoadingData) {
      return const SizedBox.shrink();
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwnPost = currentUser?.uid == widget.post.userId;
    final showAdminMenu = widget.showGroupAdminDelete && !isOwnPost;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: AppTheme.getSurfaceColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Time
          _buildHeader(isOwnPost, showAdminMenu),

          // Tags (location, friends, feeling)
          _buildTags(),

          // Content
          if (widget.post.content.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.padding(context, SizeCategory.medium),
                vertical: AppSizes.padding(context, SizeCategory.small),
              ),
              child: ExpandableText(
                text: widget.post.content,
                maxWords: 50,
                style: TextStyle(
                  color: AppTheme.getTextPrimaryColor(context),
                  fontSize: AppSizes.font(context, SizeCategory.medium),
                  height: AppSizes.padding(context, SizeCategory.small) * 0.14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // Media (images/videos)
          if (widget.post.mediaUrls != null &&
              widget.post.mediaUrls!.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(
                AppSizes.padding(context, SizeCategory.small),
              ),
              child: _buildMediaSection(),
            ),

          // Review card (nếu là review share)
          if (widget.post.type == PostType.reviewShare &&
              _review != null &&
              _place != null)
            _buildReviewCard(),

          // Actions: Like, Comment
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isOwnPost, bool showAdminMenu) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              // Navigate to profile screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => ProfileScreen(userId: widget.post.userId),
                ),
              );
            },
            child: CircleAvatar(
              radius: 20,
              backgroundImage:
                  _user?.avatarUrl != null && _user!.avatarUrl!.isNotEmpty
                      ? NetworkImage(_user!.avatarUrl!)
                      : null,
              backgroundColor: AppColors.primaryGreen,
              child:
                  _user?.avatarUrl == null || _user!.avatarUrl!.isEmpty
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                // Navigate to profile screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ProfileScreen(userId: widget.post.userId),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _user?.name ?? 'Người dùng',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.post.createdAt != null
                        ? DateFormat(
                          'dd/MM/yyyy HH:mm',
                        ).format(widget.post.createdAt!)
                        : '',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          // Menu cho admin xóa post trong group
          if (showAdminMenu)
            PopupMenuButton(
              icon: const Icon(Icons.more_horiz),
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'delete_admin',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Xóa bài viết (Admin)',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
              onSelected: (value) {
                if (value == 'delete_admin' &&
                    widget.onGroupAdminDelete != null) {
                  widget.onGroupAdminDelete!();
                }
              },
            ),
          // Menu cho chủ post
          if (isOwnPost)
            PopupMenuButton(
              icon: const Icon(Icons.more_horiz),
              itemBuilder:
                  (context) => [
                    // Cho phép edit tất cả loại post (kể cả review share)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Chỉnh sửa'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'save',
                      child: Row(
                        children: [
                          Icon(
                            _isSaved ? Icons.bookmark : Icons.bookmark_border,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(_isSaved ? 'Bỏ lưu' : 'Lưu bài viết'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Xóa', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
              onSelected: (value) {
                if (value == 'edit') {
                  _editPost();
                } else if (value == 'save') {
                  _toggleSave();
                } else if (value == 'delete') {
                  _deletePost();
                }
              },
            ),
          // Menu cho người dùng khác (lưu bài viết + báo cáo vi phạm)
          if (!isOwnPost &&
              !showAdminMenu &&
              FirebaseAuth.instance.currentUser != null)
            PopupMenuButton(
              icon: const Icon(Icons.more_horiz),
              itemBuilder:
                  (context) => [
                    PopupMenuItem(
                      value: 'save',
                      child: Row(
                        children: [
                          Icon(
                            _isSaved ? Icons.bookmark : Icons.bookmark_border,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(_isSaved ? 'Bỏ lưu' : 'Lưu bài viết'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag, size: 20, color: AppColors.error),
                          SizedBox(width: 8),
                          Text(
                            'Báo cáo vi phạm',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  ],
              onSelected: (value) {
                if (value == 'save') {
                  _toggleSave();
                } else if (value == 'report') {
                  _reportPost();
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTags() {
    final hasTags =
        widget.post.taggedPlaceName != null ||
        (widget.post.taggedUserIds != null &&
            widget.post.taggedUserIds!.isNotEmpty) ||
        widget.post.feeling != null;

    if (!hasTags) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.padding(context, SizeCategory.medium),
        vertical: AppSizes.padding(context, SizeCategory.small) * 0.5,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          // Location tag
          if (widget.post.taggedPlaceName != null)
            InkWell(
              onTap: () async {
                if (widget.post.taggedPlaceId != null) {
                  // Trường hợp 1: Place đã có trong hệ thống
                  final place = await Provider.of<PostProvider>(
                    context,
                    listen: false,
                  ).getPlaceForPost(widget.post.taggedPlaceId!);

                  if (place != null && mounted) {
                    _navigateToPlaceOnMap(place);
                  }
                } else {
                  // Trường hợp 2: Place chưa có trong hệ thống
                  // Navigate đến Map tab để search
                  NavigationHelper.navigateToMapWithSearch(
                    context,
                    widget.post.taggedPlaceName!,
                  );
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.getInputBackgroundColor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: AppTheme.getTextSecondaryColor(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.post.taggedPlaceName!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.getTextSecondaryColor(context),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Friends tag
          if (widget.post.taggedUserIds != null &&
              widget.post.taggedUserIds!.isNotEmpty)
            FutureBuilder<List<UserModel>>(
              future: _loadTaggedUsers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.getInputBackgroundColor(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people,
                          size: 14,
                          color: AppTheme.getTextSecondaryColor(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Cùng với ${widget.post.taggedUserIds!.length} người',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.getTextSecondaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final users = snapshot.data!;
                final names = users.map((u) => u.name).join(', ');
                debugPrint('👥 Displaying tagged friends: $names');

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.getInputBackgroundColor(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people,
                        size: 14,
                        color: AppTheme.getTextSecondaryColor(context),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Cùng với $names',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.getTextSecondaryColor(context),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          // Feeling tag
          if (widget.post.feeling != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.getInputBackgroundColor(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.post.feeling!.emoji,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.post.feeling!.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.getTextSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaSection() {
    // Safety check: validate mediaUrls trước khi parse
    if (widget.post.mediaUrls == null || widget.post.mediaUrls!.isEmpty) {
      return const SizedBox.shrink();
    }

    final mediaItems = _mediaService.parseMediaUrls(widget.post.mediaUrls!);

    // Double check sau khi parse
    if (mediaItems.isEmpty) {
      return const SizedBox.shrink();
    }

    if (mediaItems.length == 1) {
      // Single media
      return GestureDetector(
        onTap: () => _showMediaViewer(0),
        child: _buildMediaItem(mediaItems[0], height: 300),
      );
    } else if (mediaItems.length == 2) {
      // Two media side by side
      return Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _showMediaViewer(0),
              child: _buildMediaItem(mediaItems[0], height: 200),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _showMediaViewer(1),
              child: _buildMediaItem(mediaItems[1], height: 200),
            ),
          ),
        ],
      );
    } else {
      // 3+ media in grid
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: mediaItems.length > 4 ? 4 : mediaItems.length,
        itemBuilder: (context, index) {
          final isLast = index == 3 && mediaItems.length > 4;

          return GestureDetector(
            onTap: () => _showMediaViewer(index),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildMediaItem(mediaItems[index]),
                if (isLast)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Text(
                        '+${mediaItems.length - 4}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }
  }

  Widget _buildMediaItem(MediaItem mediaItem, {double? height}) {
    if (mediaItem.isImage) {
      return Image.network(
        mediaItem.url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: height,
            color: Colors.grey[200],
            child: Center(
              child: CircularProgressIndicator(
                value:
                    loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                color: AppColors.primaryGreen,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ Error loading image: $error');
          return Container(
            height: height,
            color: Colors.grey[300],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_not_supported,
                  size: 40,
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 8),
                Text(
                  'Không thể tải ảnh',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        },
      );
    } else {
      // Video thumbnail với play icon overlay
      return Container(
        height: height,
        color: Colors.black87,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Gradient overlay để làm nổi icon
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.black],
                ),
              ),
            ),
            // Play icon với background circle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 40,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildReviewCard() {
    if (_review == null || _place == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        border: Border.all(color: AppTheme.getBorderColor(context)),
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Review icon + label
          Container(
            padding: EdgeInsets.all(
              AppSizes.padding(context, SizeCategory.medium),
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.getBorderColor(context)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(
                      AppSizes.radius(context, SizeCategory.small),
                    ),
                  ),
                  child: Icon(
                    Icons.rate_review,
                    size: AppSizes.icon(context, SizeCategory.small),
                    color: AppColors.primaryGreen,
                  ),
                ),
                SizedBox(width: AppSizes.padding(context, SizeCategory.small)),
                Text(
                  'Đã chia sẻ đánh giá',
                  style: TextStyle(
                    fontSize: AppSizes.font(context, SizeCategory.small),
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Review content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rating stars
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      return Icon(
                        index < _review!.rating
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                        size: 18,
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      '${_review!.rating}/5',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_review!.isCheckedIn) ...[
                      SizedBox(
                        width: AppSizes.padding(context, SizeCategory.small),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.padding(
                            context,
                            SizeCategory.small,
                          ),
                          vertical: AppSizes.padding(
                            context,
                            SizeCategory.small,
                          ),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            AppSizes.radius(context, SizeCategory.small),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified,
                              size: AppSizes.icon(context, SizeCategory.small),
                              color: AppColors.primaryGreen,
                            ),
                            SizedBox(
                              width: AppSizes.padding(
                                context,
                                SizeCategory.small,
                              ),
                            ),
                            Text(
                              'Đã check in',
                              style: TextStyle(
                                fontSize: AppSizes.font(
                                  context,
                                  SizeCategory.small,
                                ),
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: AppSizes.padding(context, SizeCategory.small)),

                // Review content
                Text(
                  _review!.content,
                  style: TextStyle(
                    fontSize: AppSizes.font(context, SizeCategory.medium),
                    color: AppTheme.getTextPrimaryColor(context),
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                // Review images preview (nếu có)
                if (_review!.images != null && _review!.images!.isNotEmpty) ...[
                  SizedBox(
                    height: AppSizes.padding(context, SizeCategory.small),
                  ),
                  SizedBox(
                    height:
                        AppSizes.container(context, SizeCategory.small) * 0.8,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount:
                          _review!.images!.length > 3
                              ? 3
                              : _review!.images!.length,
                      itemBuilder: (context, index) {
                        final isLast =
                            index == 2 && _review!.images!.length > 3;
                        return Container(
                          width:
                              AppSizes.container(context, SizeCategory.small) *
                              0.8,
                          margin: const EdgeInsets.only(right: 8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  _review!.images![index],
                                  fit: BoxFit.cover,
                                ),
                              ),
                              if (isLast)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '+${_review!.images!.length - 3}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],

                SizedBox(height: AppSizes.padding(context, SizeCategory.small)),
                Divider(color: AppTheme.getBorderColor(context)),
                SizedBox(height: AppSizes.padding(context, SizeCategory.small)),

                // Place info - clickable
                GestureDetector(
                  onTap: () => _navigateToPlaceOnMap(_place!),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _place!.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Text(
                                  'Xem trên bản đồ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 10,
                                  color: AppColors.primaryGreen,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToPlaceOnMap(Place place) {
    // Sử dụng NavigationHelper để navigate đến Map tab với placeId
    NavigationHelper.navigateToMapWithPlace(
      context,
      place.placeId!,
      place.name,
    );
  }

  Widget _buildActions() {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: AppSizes.padding(context, SizeCategory.small),
        horizontal: AppSizes.padding(context, SizeCategory.medium),
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.getBorderColor(context)),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: AppSizes.padding(context, SizeCategory.small)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Reaction button - Using ReactionButton widget
              ReactionButton(
                targetId: widget.post.postId!,
                targetType: ReactionTargetType.post,
                targetOwnerId: widget.post.userId,
                initialStats: ReactionStats.empty(),
                showCount: true,
                iconSize: 20,
              ),

              // Comment button
              InkWell(
                onTap: _showComments,
                child: Row(
                  children: [
                    Icon(
                      LineIcons.commentDots,
                      color: AppTheme.getTextSecondaryColor(context),
                      size: AppSizes.icon(context, SizeCategory.medium),
                    ),
                    SizedBox(
                      width: AppSizes.padding(context, SizeCategory.small),
                    ),
                    Consumer<PostProvider>(
                      builder: (context, postProvider, child) {
                        final post = postProvider.posts.firstWhere(
                          (p) => p.postId == widget.post.postId,
                          orElse: () => widget.post,
                        );
                        return Text(
                          '${post.commentCount}',
                          style: TextStyle(
                            fontSize: AppSizes.font(
                              context,
                              SizeCategory.medium,
                            ),
                            color: AppTheme.getTextSecondaryColor(context),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Bookmark button
              InkWell(
                onTap: _isToggingSave ? null : _toggleSave,
                child:
                    _isToggingSave
                        ? SizedBox(
                          width: AppSizes.icon(context, SizeCategory.medium),
                          height: AppSizes.icon(context, SizeCategory.medium),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.getTextSecondaryColor(context),
                            ),
                          ),
                        )
                        : Icon(
                          _isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color:
                              _isSaved
                                  ? AppColors.primaryGreen
                                  : AppTheme.getTextSecondaryColor(context),
                          size: AppSizes.icon(context, SizeCategory.medium),
                        ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
