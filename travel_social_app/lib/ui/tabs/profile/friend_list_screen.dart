import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/friend.dart';
import '../../../models/user_model.dart';
import '../../../models/chat.dart';
import '../../../services/chat_service.dart';
import '../../../utils/constants.dart';
import '../../profile/profile_screen.dart';
import '../message/chat_screen.dart';

/// Màn hình hiển thị danh sách bạn bè
class FriendListScreen extends StatefulWidget {
  final String? userId; // Nếu null thì xem danh sách bạn bè của mình

  const FriendListScreen({super.key, this.userId});

  @override
  State<FriendListScreen> createState() => _FriendListScreenState();
}

class _FriendListScreenState extends State<FriendListScreen> {
  final ChatService _chatService = ChatService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  late String _targetUserId; // UserId của người đang xem danh sách bạn bè
  bool _isViewingOwnFriends = false;

  @override
  void initState() {
    super.initState();
    _targetUserId = widget.userId ?? _currentUserId ?? '';
    _isViewingOwnFriends = _targetUserId == _currentUserId;
  }

  Future<void> _navigateToChat(UserModel friend) async {
    if (_currentUserId == null) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
      );

      // Get or create private chat
      final chatId = await _chatService.getOrCreatePrivateChat(
        _currentUserId,
        friend.userId,
      );

      // Get chat details
      final chatDoc =
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .get();

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (chatDoc.exists) {
        final chat = Chat.fromFirestore(chatDoc);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ChatScreen(
                  chat: chat,
                  displayName: friend.name,
                  displayAvatar: friend.avatarUrl,
                ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể mở chat: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_targetUserId.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.getBackgroundColor(context),
        appBar: AppBar(
          title: Text(
            'Danh sách bạn bè',
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.large),
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppTheme.getSurfaceColor(context),
        ),
        body: Center(
          child: Text(
            'Vui lòng đăng nhập',
            style: TextStyle(
              color: AppTheme.getTextSecondaryColor(context),
              fontSize: AppSizes.font(context, SizeCategory.medium),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          _isViewingOwnFriends ? 'Bạn bè của bạn' : 'Danh sách bạn bè',
          style: TextStyle(
            fontSize: AppSizes.font(context, SizeCategory.large),
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
            size: AppSizes.icon(context, SizeCategory.medium),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('friendships')
                .where('status', isEqualTo: 'accepted')
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: AppSizes.icon(context, SizeCategory.xxxlarge),
                    color: AppColors.error,
                  ),
                  SizedBox(
                    height: AppSizes.padding(context, SizeCategory.medium),
                  ),
                  Text(
                    'Đã xảy ra lỗi khi tải danh sách',
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.medium),
                      color: AppTheme.getTextSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryGreen,
                strokeWidth: 3,
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: AppSizes.icon(context, SizeCategory.xxxlarge),
                    color: AppTheme.getIconSecondaryColor(context),
                  ),
                  SizedBox(
                    height: AppSizes.padding(context, SizeCategory.medium),
                  ),
                  Text(
                    'Chưa có bạn bè nào',
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.large),
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getTextPrimaryColor(context),
                    ),
                  ),
                ],
              ),
            );
          }

          // Filter friendships for target user
          final friendships =
              snapshot.data!.docs
                  .map((doc) => Friendship.fromFirestore(doc))
                  .where(
                    (friendship) =>
                        friendship.userId1 == _targetUserId ||
                        friendship.userId2 == _targetUserId,
                  )
                  .toList();

          if (friendships.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: AppSizes.icon(context, SizeCategory.xxxlarge),
                    color: AppTheme.getIconSecondaryColor(context),
                  ),
                  SizedBox(
                    height: AppSizes.padding(context, SizeCategory.medium),
                  ),
                  Text(
                    'Chưa có bạn bè nào',
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.large),
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getTextPrimaryColor(context),
                    ),
                  ),
                ],
              ),
            );
          }

          // Get list of friend IDs
          final friendIds =
              friendships
                  .map((friendship) => friendship.getOtherUserId(_targetUserId))
                  .toList();

          return ListView.separated(
            padding: EdgeInsets.all(
              AppSizes.padding(context, SizeCategory.medium),
            ),
            itemCount: friendIds.length,
            separatorBuilder:
                (context, index) =>
                    Divider(height: 1, color: AppTheme.getBorderColor(context)),
            itemBuilder: (context, index) {
              return FutureBuilder<DocumentSnapshot>(
                future:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(friendIds[index])
                        .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return const SizedBox.shrink();
                  }

                  final friend = UserModel.fromFirestore(userSnapshot.data!);

                  return _FriendListTile(
                    friend: friend,
                    showMessageButton: _isViewingOwnFriends,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => ProfileScreen(userId: friend.userId),
                        ),
                      );
                    },
                    onMessageTap: () => _navigateToChat(friend),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Widget hiển thị một item trong danh sách bạn bè
class _FriendListTile extends StatelessWidget {
  final UserModel friend;
  final bool showMessageButton;
  final VoidCallback onTap;
  final VoidCallback onMessageTap;

  const _FriendListTile({
    required this.friend,
    required this.showMessageButton,
    required this.onTap,
    required this.onMessageTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: AppSizes.padding(context, SizeCategory.medium),
          horizontal: AppSizes.padding(context, SizeCategory.small),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: AppSizes.icon(context, SizeCategory.large),
              backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
              backgroundImage:
                  friend.avatarUrl != null
                      ? CachedNetworkImageProvider(friend.avatarUrl!)
                      : null,
              child:
                  friend.avatarUrl == null
                      ? Icon(
                        Icons.person,
                        size: AppSizes.icon(context, SizeCategory.large),
                        color: AppColors.primaryGreen,
                      )
                      : null,
            ),
            SizedBox(width: AppSizes.padding(context, SizeCategory.medium)),

            // Name and bio
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.name,
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.medium),
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getTextPrimaryColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (friend.bio != null && friend.bio!.isNotEmpty) ...[
                    SizedBox(
                      height: AppSizes.padding(context, SizeCategory.small) / 2,
                    ),
                    Text(
                      friend.bio!,
                      style: TextStyle(
                        fontSize: AppSizes.font(context, SizeCategory.small),
                        color: AppTheme.getTextSecondaryColor(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Message button
            if (showMessageButton) ...[
              SizedBox(width: AppSizes.padding(context, SizeCategory.small)),
              IconButton(
                icon: Icon(
                  Icons.message,
                  color: AppColors.primaryGreen,
                  size: AppSizes.icon(context, SizeCategory.medium),
                ),
                onPressed: onMessageTap,
                tooltip: 'Nhắn tin',
              ),
            ],

            // Arrow icon
            Icon(
              Icons.arrow_forward_ios,
              size: AppSizes.icon(context, SizeCategory.small),
              color: AppTheme.getIconSecondaryColor(context),
            ),
          ],
        ),
      ),
    );
  }
}
