import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user_model.dart';
import '../../../models/friend.dart';
import '../../../models/chat.dart';
import '../../../services/chat_service.dart';
import '../../../services/friend_service.dart';
import '../../../utils/constants.dart';
import 'chat_screen.dart';

class SelectFriendScreen extends StatefulWidget {
  const SelectFriendScreen({super.key});

  @override
  State<SelectFriendScreen> createState() => _SelectFriendScreenState();
}

class _SelectFriendScreenState extends State<SelectFriendScreen> {
  final FriendService _friendService = FriendService();
  final ChatService _chatService = ChatService();
  String _searchQuery = '';
  bool _isLoading = false;

  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        title: Text(
          'Chọn bạn bè',
          style: TextStyle(
            color: Colors.white,
            fontSize: AppSizes.font(context, SizeCategory.large),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: AppSizes.icon(context, SizeCategory.medium),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [_buildSearchBar(), Expanded(child: _buildFriendList())],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
      child: TextField(
        style: TextStyle(
          color: AppTheme.getTextPrimaryColor(context),
          fontSize: AppSizes.font(context, SizeCategory.medium),
        ),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm bạn bè...',
          hintStyle: TextStyle(color: AppTheme.getTextSecondaryColor(context)),
          prefixIcon: Icon(
            Icons.search,
            color: AppTheme.getIconSecondaryColor(context),
            size: AppSizes.icon(context, SizeCategory.medium),
          ),
          filled: true,
          fillColor: AppTheme.getSurfaceColor(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              AppSizes.radius(context, SizeCategory.medium),
            ),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
      ),
    );
  }

  Widget _buildFriendList() {
    return StreamBuilder<List<Friendship>>(
      stream: _friendService.friendsStream(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                  'Chưa có bạn bè',
                  style: TextStyle(
                    fontSize: AppSizes.font(context, SizeCategory.medium),
                    color: AppTheme.getTextSecondaryColor(context),
                  ),
                ),
              ],
            ),
          );
        }

        var friendships = snapshot.data!;

        return ListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.padding(context, SizeCategory.small),
          ),
          itemCount: friendships.length,
          itemBuilder: (context, index) {
            final friendship = friendships[index];
            final friendId =
                friendship.userId1 == currentUserId
                    ? friendship.userId2
                    : friendship.userId1;

            return FutureBuilder<DocumentSnapshot>(
              future:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(friendId)
                      .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final friend = UserModel.fromFirestore(userSnapshot.data!);

                if (_searchQuery.isNotEmpty) {
                  final name = friend.name.toLowerCase();
                  if (!name.contains(_searchQuery)) {
                    return const SizedBox.shrink();
                  }
                }

                return _buildFriendItem(friend);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFriendItem(UserModel friend) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSizes.padding(context, SizeCategory.small),
        vertical: AppSizes.padding(context, SizeCategory.small) * 0.5,
      ),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(
          AppSizes.padding(context, SizeCategory.small),
        ),
        leading: CircleAvatar(
          radius: AppSizes.icon(context, SizeCategory.xlarge) * 0.875,
          backgroundColor: AppColors.primaryGreen,
          backgroundImage:
              (friend.avatarUrl?.isNotEmpty ?? false)
                  ? NetworkImage(friend.avatarUrl!)
                  : null,
          child:
              !(friend.avatarUrl?.isNotEmpty ?? false)
                  ? Text(
                    friend.name[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: AppSizes.font(context, SizeCategory.medium),
                    ),
                  )
                  : null,
        ),
        title: Text(
          friend.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppSizes.font(context, SizeCategory.medium),
            color: AppTheme.getTextPrimaryColor(context),
          ),
        ),
        subtitle:
            friend.bio != null
                ? Text(
                  friend.bio!,
                  style: TextStyle(
                    fontSize: AppSizes.font(context, SizeCategory.small),
                    color: AppTheme.getTextSecondaryColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
                : null,
        onTap: () => _createPrivateChat(friend),
      ),
    );
  }

  Future<void> _createPrivateChat(UserModel friend) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final chatId = await _chatService.getOrCreatePrivateChat(
        currentUserId,
        friend.userId,
      );

      // Lấy chat object
      final chatDoc =
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .get();
      final chat = Chat.fromFirestore(chatDoc);

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
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
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tạo trò chuyện: $e')));
      }
    }
  }
}
