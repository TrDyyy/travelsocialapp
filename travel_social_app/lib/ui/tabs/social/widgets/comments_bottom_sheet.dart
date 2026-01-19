import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:travel_social_app/models/comment.dart';
import 'package:travel_social_app/models/post.dart';
import 'package:travel_social_app/models/user_model.dart';
import 'package:travel_social_app/models/reaction.dart';
import 'package:travel_social_app/models/violation_request.dart';
import 'package:travel_social_app/services/media_service.dart';
import 'package:travel_social_app/services/user_service.dart';
import 'package:travel_social_app/states/post_provider.dart';
import 'package:travel_social_app/utils/constants.dart';
import 'package:travel_social_app/widgets/media_viewer.dart';
import 'package:travel_social_app/widgets/editable_image_grid.dart';
import 'package:travel_social_app/widgets/image_picker_buttons.dart';
import 'package:travel_social_app/widgets/limited_text_field.dart';
import 'package:travel_social_app/widgets/reaction_button.dart';
import 'package:travel_social_app/widgets/violation_report_dialog.dart';
import '../../../profile/profile_screen.dart';

/// Bottom sheet hiển thị comments (80% parent)
class CommentsBottomSheet extends StatefulWidget {
  final Post post;

  const CommentsBottomSheet({super.key, required this.post});

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final _userService = UserService();
  final _mediaService = MediaService();
  final _commentController = TextEditingController();

  final List<File> _selectedImages = [];
  bool _isSending = false;

  // For editing
  Comment? _editingComment;
  List<String> _existingImageUrls = []; // Ảnh cũ của comment đang edit
  final List<String> _imagesToDelete = []; // Ảnh cần xóa khỏi Storage

  // For replying
  Comment? _replyingToComment;
  UserModel? _replyingToUser;

  // For expand/collapse replies
  final Map<String, bool> _expandedReplies = {}; // commentId -> isExpanded

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await _mediaService.pickImages();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  Future<void> _takePhoto() async {
    final image = await _mediaService.takePhoto();
    if (image != null) {
      setState(() {
        _selectedImages.add(image);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  /// Xóa ảnh cũ (từ comment đang edit)
  void _removeExistingImage(int index) {
    setState(() {
      final imageUrl = _existingImageUrls.removeAt(index);
      _imagesToDelete.add(imageUrl); // Đánh dấu để xóa khỏi Storage
    });
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty &&
        _selectedImages.isEmpty &&
        _existingImageUrls.isEmpty) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      final postProvider = Provider.of<PostProvider>(context, listen: false);

      // Nếu đang edit
      if (_editingComment != null) {
        // Upload ảnh mới nếu có
        List<String> newImageUrls = [];
        if (_selectedImages.isNotEmpty) {
          newImageUrls = await _mediaService.uploadMedia(
            _selectedImages,
            'comments/${widget.post.postId}_${user.uid}_${DateTime.now().millisecondsSinceEpoch}',
          );
        }

        // Xóa ảnh cũ đã đánh dấu xóa
        if (_imagesToDelete.isNotEmpty) {
          await _mediaService.deleteMedia(_imagesToDelete);
        }

        // Kết hợp ảnh cũ (còn lại) + ảnh mới
        final updatedImageUrls = [..._existingImageUrls, ...newImageUrls];

        // Update comment - luôn truyền imageUrls (có thể là empty list để xóa hết)
        final success = await postProvider.updateComment(
          widget.post.postId!,
          _editingComment!.commentId!,
          content: content,
          imageUrls:
              updatedImageUrls, // Truyền [] nếu xóa hết, không truyền null
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Đã sửa bình luận'),
              backgroundColor: AppColors.primaryGreen,
            ),
          );
          setState(() {
            _editingComment = null;
            _existingImageUrls.clear();
            _imagesToDelete.clear();
          });
        }
      }
      // Nếu đang reply hoặc tạo mới
      else {
        final comment = Comment(
          postId: widget.post.postId!,
          userId: user.uid,
          content: content,
          parentCommentId: _replyingToComment?.commentId,
        );

        final success = await postProvider.createComment(
          comment,
          _selectedImages.isNotEmpty ? _selectedImages : null,
        );

        if (success && mounted) {
          if (_replyingToComment != null) {
            setState(() {
              _replyingToComment = null;
              _replyingToUser = null;
            });
          }
        }
      }

      if (mounted) {
        _commentController.clear();
        setState(() {
          _selectedImages.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xóa bình luận'),
            content: const Text(
              'Bạn có chắc muốn xóa bình luận này?\n'
              '(Tất cả các trả lời cũng sẽ bị xóa)',
            ),
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
      final success = await postProvider.deleteComment(
        widget.post.postId!,
        commentId,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã xóa bình luận'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    }
  }

  void _reportComment(Comment comment) {
    showDialog(
      context: context,
      builder:
          (context) => ViolationReportDialog(
            objectType: ViolatedObjectType.comment,
            violatedObject: comment,
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

  void _startEditing(Comment comment) {
    setState(() {
      _editingComment = comment;
      _commentController.text = comment.content;
      _replyingToComment = null;
      _replyingToUser = null;

      // Load ảnh cũ
      _existingImageUrls =
          comment.imageUrls != null
              ? List<String>.from(comment.imageUrls!)
              : [];
      _imagesToDelete.clear();
      _selectedImages.clear();
    });
  }

  void _startReplying(Comment comment, UserModel user) {
    setState(() {
      _replyingToComment = comment;
      _replyingToUser = user;
      _editingComment = null;
      // Thêm @mention vào đầu text
      _commentController.text = '@${user.name} ';
      // Đặt cursor ở cuối
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commentController.text.length),
      );
    });
    // Focus vào text field
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelEditOrReply() {
    setState(() {
      _editingComment = null;
      _replyingToComment = null;
      _replyingToUser = null;
      _commentController.clear();
      _existingImageUrls.clear();
      _imagesToDelete.clear();
      _selectedImages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Colors.transparent,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: GestureDetector(
          onTap: () {}, // Ngăn dismiss khi tap vào sheet
          child: DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.getBackgroundColor(context),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    // Drag handle
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSizes.padding(
                          context,
                          SizeCategory.medium,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Bình luận',
                            style: TextStyle(
                              fontSize: AppSizes.font(
                                context,
                                SizeCategory.xlarge,
                              ),
                              fontWeight: FontWeight.bold,
                              color: AppTheme.getTextPrimaryColor(context),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    // Comments list
                    Expanded(
                      child: Consumer<PostProvider>(
                        builder: (context, postProvider, child) {
                          return StreamBuilder<List<Comment>>(
                            stream: postProvider.commentsStream(
                              widget.post.postId!,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primaryGreen,
                                  ),
                                );
                              }

                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.comment_outlined,
                                        size: 60,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Chưa có bình luận nào',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final comments = snapshot.data!;

                              // Build comment tree structure
                              final parentComments =
                                  comments
                                      .where((c) => c.parentCommentId == null)
                                      .toList();

                              return ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                itemCount: parentComments.length,
                                itemBuilder: (context, index) {
                                  return _buildCommentThread(
                                    parentComments[index],
                                    comments,
                                    0, // depth level
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const Divider(height: 1),

                    // Input area
                    _buildInputArea(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Build comment thread recursively (hỗ trợ nested replies không giới hạn)
  Widget _buildCommentThread(
    Comment comment,
    List<Comment> allComments,
    int depth,
  ) {
    // Giới hạn indent tối đa ở level 3 để tránh tràn UI
    final displayDepth = depth > 3 ? 3 : depth;

    // Tìm tất cả replies của comment này
    final replies =
        allComments
            .where((c) => c.parentCommentId == comment.commentId)
            .toList();

    // Check expand state cho level 0
    final isExpanded = _expandedReplies[comment.commentId] ?? false;
    final hasReplies = replies.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Comment hiện tại với indent theo depth (tối đa level 3)
        Padding(
          padding: EdgeInsets.only(left: displayDepth * 28.0), // 28px mỗi level
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vertical line indicator cho nested comments
              if (displayDepth > 0)
                Container(
                  width: 2,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCommentItem(comment, depth, replies.length),

                    // "Xem thêm/Đóng" button chỉ cho level 0
                    if (depth == 0 && hasReplies)
                      Padding(
                        padding: EdgeInsets.only(
                          left: AppSizes.padding(
                            context,
                            SizeCategory.xxxlarge,
                          ),
                          top: AppSizes.padding(context, SizeCategory.small),
                          bottom: AppSizes.padding(
                            context,
                            SizeCategory.medium,
                          ),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _expandedReplies[comment.commentId!] =
                                  !isExpanded;
                            });
                          },
                          child: Row(
                            children: [
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 16,
                                color: AppColors.primaryGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isExpanded
                                    ? 'Đóng (${replies.length} phản hồi)'
                                    : 'Xem ${replies.length} phản hồi',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Hiển thị replies nếu:
        // - Depth > 0 (luôn hiển thị nested replies)
        // - Depth == 0 và isExpanded == true
        if ((depth > 0 || isExpanded) && hasReplies)
          ...replies.map((reply) {
            return _buildCommentThread(reply, allComments, depth + 1);
          }),
      ],
    );
  }

  Widget _buildCommentItem(Comment comment, int depth, int replyCount) {
    return FutureBuilder<UserModel?>(
      future: _userService.getUserById(comment.userId),
      builder: (context, userSnapshot) {
        final user = userSnapshot.data;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar + tap để vào profile
              GestureDetector(
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(userId: comment.userId),
                      ),
                    ),
                child: CircleAvatar(
                  radius: depth == 0 ? 18 : 15,
                  backgroundImage:
                      (user?.avatarUrl?.isNotEmpty ?? false)
                          ? NetworkImage(user!.avatarUrl!)
                          : null,
                  backgroundColor: AppColors.primaryGreen,
                  child:
                      (user?.avatarUrl?.isEmpty ?? true)
                          ? Icon(
                            Icons.person,
                            color: Colors.white,
                            size: depth == 0 ? 18 : 15,
                          )
                          : null,
                ),
              ),
              const SizedBox(width: 12),

              // Toàn bộ nội dung comment → bọc trong GestureDetector để bắt long press
              Expanded(
                child: GestureDetector(
                  onLongPress: () {
                    HapticFeedback.mediumImpact(); // rung nhẹ (tùy chọn)
                    _showCommentActionDialog(comment, user);
                  },
                  child: Container(
                    padding: EdgeInsets.all(
                      AppSizes.padding(context, SizeCategory.medium),
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.getSurfaceColor(context),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tên người dùng
                        GestureDetector(
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) =>
                                          ProfileScreen(userId: comment.userId),
                                ),
                              ),
                          child: Text(
                            user?.name ?? 'Người dùng',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: AppSizes.font(
                                context,
                                SizeCategory.medium,
                              ),
                              color: AppTheme.getTextPrimaryColor(context),
                            ),
                          ),
                        ),

                        // Nội dung comment
                        if (comment.content.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            comment.content,
                            style: TextStyle(
                              fontSize: AppSizes.font(
                                context,
                                SizeCategory.medium,
                              ),
                              height: 1.45,
                              color: AppTheme.getTextSecondaryColor(context),
                            ),
                          ),
                        ],

                        // Ảnh đính kèm
                        if (comment.imageUrls != null &&
                            comment.imageUrls!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children:
                                  comment.imageUrls!.asMap().entries.map((e) {
                                    final index = e.key;
                                    final url = e.value;
                                    return GestureDetector(
                                      onTap:
                                          () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) => MediaViewer(
                                                    mediaUrls:
                                                        comment.imageUrls!,
                                                    initialIndex: index,
                                                  ),
                                            ),
                                          ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          url,
                                          width: 84,
                                          height: 84,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (
                                            context,
                                            child,
                                            loadingProgress,
                                          ) {
                                            if (loadingProgress == null)
                                              return child;
                                            return Container(
                                              width: 84,
                                              height: 84,
                                              color: Colors.grey[200],
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                            );
                                          },
                                          errorBuilder:
                                              (_, __, ___) => Container(
                                                width: 84,
                                                height: 84,
                                                color: Colors.grey[300],
                                                child: const Icon(
                                                  Icons.broken_image,
                                                ),
                                              ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ),

                        // Footer: thời gian + reaction (gọn, không bị tràn)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Text(
                                comment.createdAt != null
                                    ? DateFormat(
                                      'dd/MM HH:mm',
                                    ).format(comment.createdAt!)
                                    : '',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const Spacer(),

                              // Reaction button - tự động update qua stream, không cần callback
                              ReactionButton(
                                targetId: comment.commentId!,
                                targetType: ReactionTargetType.comment,
                                targetOwnerId: comment.userId,
                                initialStats: ReactionStats.empty(),
                                showCount: true,
                                iconSize: 17,
                              ),
                            ],
                          ),
                        ),
                      ],
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

  void _showCommentActionDialog(Comment comment, UserModel? user) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwnComment = currentUserId == comment.userId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: AppTheme.getBackgroundColor(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.getSurfaceColor(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Các nút hành động
                  if (!isOwnComment) ...[
                    _buildActionTile(
                      icon: Icons.reply,
                      title: 'Trả lời',
                      onTap: () {
                        Navigator.pop(context);
                        if (user != null) {
                          _startReplying(comment, user);
                        }
                      },
                    ),
                    const Divider(height: 1),
                    _buildActionTile(
                      icon: Icons.flag_outlined,
                      title: 'Báo cáo bình luận',
                      color: AppColors.error,
                      onTap: () {
                        Navigator.pop(context);
                        _reportComment(comment);
                      },
                    ),
                  ] else ...[
                    _buildActionTile(
                      icon: Icons.reply,
                      title: 'Trả lời',
                      onTap: () {
                        Navigator.pop(context);
                        if (user != null) {
                          _startReplying(comment, user);
                        }
                      },
                    ),
                    const Divider(height: 1),
                    _buildActionTile(
                      icon: Icons.edit_outlined,
                      title: 'Sửa bình luận',
                      onTap: () {
                        Navigator.pop(context);
                        _startEditing(comment);
                      },
                    ),
                    const Divider(height: 1),
                    _buildActionTile(
                      icon: Icons.delete_outline,
                      title: 'Xóa bình luận',
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(context);
                        _deleteComment(comment.commentId!);
                      },
                    ),
                  ],

                  const SizedBox(height: 8),
                  _buildActionTile(
                    icon: Icons.cancel_outlined,
                    title: 'Hủy',
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
    );
  }

  // Widget con để tái sử dụng
  Widget _buildActionTile({
    required IconData icon,
    required String title,
    Color? color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: color ?? AppTheme.getTextSecondaryColor(context),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? AppTheme.getTextPrimaryColor(context),
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      minLeadingWidth: 24,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  Widget _buildInputArea() {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Edit/Reply indicator
          if (_editingComment != null || _replyingToComment != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _editingComment != null ? Icons.edit : Icons.reply,
                    size: 16,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _editingComment != null
                          ? 'Đang sửa: "${_editingComment!.content}"'
                          : 'Trả lời: @${_replyingToUser?.name ?? ""}',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: _cancelEditOrReply,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          // Images preview (existing + new) - Using reusable widget
          EditableImageGrid(
            existingImageUrls: _existingImageUrls,
            newImages: _selectedImages,
            onRemoveExisting: _removeExistingImage,
            onRemoveNew: _removeImage,
          ),

          // Input row
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage:
                    (currentUser?.photoURL?.isNotEmpty ?? false)
                        ? NetworkImage(currentUser!.photoURL!)
                        : null,
                backgroundColor: AppColors.primaryGreen,
                child:
                    !(currentUser?.photoURL?.isNotEmpty ?? false)
                        ? const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 16,
                        )
                        : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LimitedTextField(
                  controller: _commentController,
                  enabled: !_isSending,
                  maxLength: 100,
                  hintText:
                      _editingComment != null
                          ? 'Sửa bình luận...'
                          : _replyingToComment != null
                          ? 'Trả lời...'
                          : 'Viết bình luận...',
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                ),
              ),
              const SizedBox(width: 8),
              // Image picker buttons - Using reusable widget
              ImagePickerButtons(
                onCamera: _takePhoto,
                onGallery: _pickImages,
                enabled: !_isSending,
              ),
              IconButton(
                icon:
                    _isSending
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryGreen,
                          ),
                        )
                        : const Icon(Icons.send, color: AppColors.primaryGreen),
                onPressed: _isSending ? null : _sendComment,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
