import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/reaction.dart';
import '../services/reaction_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../utils/constants.dart';

/// Widget hiển thị reaction button với animation và popup picker
/// Tự động cập nhật UI qua StreamBuilder, không cần callback
class ReactionButton extends StatefulWidget {
  final String targetId;
  final ReactionTargetType targetType;
  final String?
  targetOwnerId; // ID của người sở hữu target (để gửi notification)
  final ReactionStats initialStats;
  final bool showCount; // Hiển thị số lượng reaction
  final double iconSize;

  const ReactionButton({
    super.key,
    required this.targetId,
    required this.targetType,
    this.targetOwnerId,
    required this.initialStats,
    this.showCount = true,
    this.iconSize = 20,
  });

  @override
  State<ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<ReactionButton>
    with SingleTickerProviderStateMixin {
  final ReactionService _reactionService = ReactionService();
  final NotificationService _notificationService = NotificationService();
  final UserService _userService = UserService();

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  // Thêm flag để tránh gọi animation an toàn
  bool _isMounted = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _isMounted = false; // Đánh dấu không còn dùng nữa
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleReaction(ReactionType reactionType) async {
    if (currentUserId == null || !_isMounted) return;

    // Animation an toàn: chỉ chạy nếu widget còn sống
    if (_isMounted) {
      await _animationController.forward();
      if (_isMounted) _animationController.reverse();
    }

    final success = await _reactionService.toggleReaction(
      userId: currentUserId!,
      targetId: widget.targetId,
      targetType: widget.targetType,
      reactionType: reactionType,
    );

    if (success && _isMounted) {
      // Stream tự động update UI, không cần callback
      if (widget.targetOwnerId != null &&
          widget.targetOwnerId != currentUserId) {
        _sendReactionNotification(reactionType);
      }
    }
  }

  Future<void> _sendReactionNotification(ReactionType reactionType) async {
    try {
      final currentUser = await _userService.getUserById(currentUserId!);
      if (currentUser == null) return;

      switch (widget.targetType) {
        case ReactionTargetType.message:
          // Cần chatId để navigate, có thể lấy từ message document
          // Tạm thời skip hoặc cần refactor để truyền chatId
          break;
        case ReactionTargetType.comment:
          // Cần postId để navigate
          await _notificationService.sendCommentReactionNotification(
            toUserId: widget.targetOwnerId!,
            fromUserId: currentUserId!,
            fromUserName: currentUser.name,
            commentId: widget.targetId,
            postId: '',
            reactionEmoji: reactionType.emoji,
            fromUserAvatar: currentUser.avatarUrl,
          );
          break;
        case ReactionTargetType.review:
          // Cần placeId để navigate
          await _notificationService.sendReviewReactionNotification(
            toUserId: widget.targetOwnerId!,
            fromUserId: currentUserId!,
            fromUserName: currentUser.name,
            reviewId: widget.targetId,
            placeId: '',
            reactionEmoji: reactionType.emoji,
            fromUserAvatar: currentUser.avatarUrl,
          );
          break;
        case ReactionTargetType.post:
          await _notificationService.sendPostLikeNotification(
            toUserId: widget.targetOwnerId!,
            fromUserId: currentUserId!,
            fromUserName: currentUser.name,
            postId: widget.targetId,
            fromUserAvatar: currentUser.avatarUrl,
            reactionEmoji: reactionType.emoji,
          );
          break;
      }
    } catch (e) {
      debugPrint('Error sending reaction notification: $e');
    }
  }

  void _showReactionPicker() {
    // Haptic feedback khi mở picker
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: false,
      isDismissible: true, // Cho phép dismiss bằng cách tap outside
      enableDrag: true, // Cho phép kéo xuống để đóng
      builder:
          (pickerContext) => _ReactionPickerSheet(
            onReactionSelected: (reactionType) {
              Navigator.of(pickerContext, rootNavigator: false).pop();
              _handleReaction(reactionType);
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reaction>>(
      stream: _reactionService.getReactionsStream(
        targetId: widget.targetId,
        targetType: widget.targetType,
      ),
      initialData: const [],
      builder: (context, snapshot) {
        final reactions = snapshot.data ?? [];
        final stats = ReactionStats.fromReactions(reactions, currentUserId);

        final userReaction = stats.userReaction;
        final totalCount = stats.totalCount;
        final hasReacted = userReaction != null;

        // Lấy top 3 reactions có nhiều người thả nhất
        final topReactions = _getTopReactions(stats, maxCount: 3);

        // Xác định border color dựa trên loại reaction
        Color borderColor;
        if (hasReacted) {
          switch (userReaction) {
            case ReactionType.like:
              borderColor = Colors.blue.withOpacity(0.3);
              break;
            case ReactionType.love:
              borderColor = Colors.red.withOpacity(0.3);
              break;
            case ReactionType.haha:
              borderColor = Colors.orange.withOpacity(0.3);
              break;
            case ReactionType.wow:
              borderColor = Colors.purple.withOpacity(0.3);
              break;
            case ReactionType.sad:
              borderColor = Colors.yellow.withOpacity(0.3);
              break;
            case ReactionType.angry:
              borderColor = Colors.deepOrange.withOpacity(0.3);
              break;
          }
        } else {
          borderColor = Colors.grey.withOpacity(0.3);
        }

        return GestureDetector(
          onTap: () => _handleReaction(ReactionType.like),
          onLongPress: _showReactionPicker,
          onLongPressStart: (_) {
            // Haptic feedback ngay khi bắt đầu long press
            HapticFeedback.selectionClick();
          },
          // Hiển thị visual feedback khi long press
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.getSurfaceColor(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Show top reactions stack or default icon
                      if (totalCount > 0 && topReactions.isNotEmpty)
                        _buildTopReactionsStack(topReactions)
                      else
                        Icon(
                          Icons.thumb_up_off_alt,
                          size: widget.iconSize,
                          color: AppTheme.getIconPrimaryColor(context),
                        ),
                      if (widget.showCount && totalCount > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          totalCount.toString(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Lấy top N reactions có nhiều người thả nhất
  List<ReactionType> _getTopReactions(ReactionStats stats, {int maxCount = 3}) {
    final reactionCounts = <ReactionType, int>{};

    // Đếm số lượng mỗi loại reaction
    for (final type in ReactionType.values) {
      final count = stats.counts[type] ?? 0;
      if (count > 0) {
        reactionCounts[type] = count;
      }
    }

    // Sắp xếp theo số lượng giảm dần và lấy top N
    final sortedTypes =
        reactionCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return sortedTypes.take(maxCount).map((entry) => entry.key).toList();
  }

  Widget _buildTopReactionsStack(List<ReactionType> topReactions) {
    double emojiSize = AppSizes.icon(context, SizeCategory.small);
    const double overlapOffset = 14;
    return SizedBox(
      width: emojiSize + (topReactions.length - 1) * overlapOffset,
      height: emojiSize,
      child: Stack(
        children: List.generate(topReactions.length, (index) {
          final reaction = topReactions[index];
          return Positioned(
            left: index * overlapOffset,
            child: SizedBox(
              width: emojiSize,
              height: emojiSize,
              child: Center(
                child: Text(
                  reaction.emoji,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Reaction Picker – Cuộn ngang mượt như Facebook/Instagram
class _ReactionPickerSheet extends StatelessWidget {
  final Function(ReactionType) onReactionSelected;

  const _ReactionPickerSheet({required this.onReactionSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children:
            ReactionType.values.map((type) {
              return Expanded(
                child: _ReactionItem(
                  reactionType: type,
                  onTap: () => onReactionSelected(type),
                ),
              );
            }).toList(),
      ),
    );
  }
}

/// Widget cho mỗi reaction item trong picker
class _ReactionItem extends StatefulWidget {
  final ReactionType reactionType;
  final VoidCallback onTap;

  const _ReactionItem({required this.reactionType, required this.onTap});

  @override
  State<_ReactionItem> createState() => _ReactionItemState();
}

class _ReactionItemState extends State<_ReactionItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100), // Nhanh hơn
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.4, // Scale nhẹ hơn
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (mounted) {
          setState(() => _isPressed = true);
          _controller.forward();
          HapticFeedback.lightImpact(); // Rung nhẹ khi tap
        }
      },
      onTapUp: (_) {
        if (mounted) {
          setState(() => _isPressed = false);
          _controller.reverse();
          // Delay nhỏ để animation hoàn thành trước khi callback
          Future.delayed(const Duration(milliseconds: 50), () {
            widget.onTap();
          });
        }
      },
      onTapCancel: () {
        if (mounted) {
          setState(() => _isPressed = false);
          _controller.reverse();
        }
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                _isPressed
                    ? AppColors.primaryGreen.withOpacity(0.1)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.reactionType.emoji,
            style: const TextStyle(fontSize: 32),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Widget hiển thị chi tiết reactions (dùng cho bottom sheet xem ai đã react)
class ReactionDetailSheet extends StatelessWidget {
  final String targetId;
  final ReactionTargetType targetType;

  const ReactionDetailSheet({
    super.key,
    required this.targetId,
    required this.targetType,
  });

  @override
  Widget build(BuildContext context) {
    final reactionService = ReactionService();
    final userService = UserService();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getBackgroundColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Text(
            'Reactions',
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.xlarge),
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: StreamBuilder<List<Reaction>>(
              stream: reactionService.getReactionsStream(
                targetId: targetId,
                targetType: targetType,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Chưa có reactions'));
                }

                final reactions = snapshot.data!;

                return ListView.builder(
                  itemCount: reactions.length,
                  itemBuilder: (context, index) {
                    final reaction = reactions[index];

                    return FutureBuilder(
                      future: userService.getUserById(reaction.userId),
                      builder: (context, userSnapshot) {
                        final user = userSnapshot.data;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                (user?.avatarUrl?.isNotEmpty ?? false)
                                    ? NetworkImage(user!.avatarUrl!)
                                    : null,
                            child:
                                !(user?.avatarUrl?.isNotEmpty ?? false)
                                    ? const Icon(Icons.person, size: 12)
                                    : null,
                          ),
                          title: Text(user?.name ?? 'User'),
                          trailing: Text(
                            reaction.reactionType.emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
