import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/chat.dart';
import '../../../models/user_model.dart';
import '../../../services/chat_service.dart';
import '../../../utils/constants.dart';
import 'chat_screen.dart';
import 'select_friend_screen.dart';
import 'create_group_screen.dart';
import 'create_community_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  String _searchQuery = '';

  // Notification preferences
  bool _notificationEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _previewEnabled = true;

  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
  }

  Future<void> _loadNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationEnabled = prefs.getBool('chat_notification_enabled') ?? true;
      _soundEnabled = prefs.getBool('chat_sound_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('chat_vibration_enabled') ?? true;
      _previewEnabled = prefs.getBool('chat_preview_enabled') ?? true;
    });
  }

  Future<void> _saveNotificationPreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(child: _buildChatList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.getSurfaceColor(context),
            AppTheme.getSurfaceColor(context).withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.padding(context, SizeCategory.medium),
            vertical: AppSizes.padding(context, SizeCategory.large),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tin nhắn',
                        style: TextStyle(
                          fontSize: AppSizes.font(
                            context,
                            SizeCategory.xxlarge,
                          ),
                          fontWeight: FontWeight.bold,
                          color: AppTheme.getTextPrimaryColor(context),
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(
                        height:
                            AppSizes.padding(context, SizeCategory.small) * 0.5,
                      ),
                      StreamBuilder<List<Chat>>(
                        stream: _chatService.getAllChatsForUser(currentUserId),
                        builder: (context, snapshot) {
                          final count = snapshot.data?.length ?? 0;
                          return Text(
                            count > 0
                                ? '$count cuộc trò chuyện'
                                : 'Chưa có trò chuyện',
                            style: TextStyle(
                              fontSize: AppSizes.font(
                                context,
                                SizeCategory.small,
                              ),
                              color: AppTheme.getTextSecondaryColor(context),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildHeaderIconButton(
                        icon: Icons.notifications_outlined,
                        onPressed: _showNotificationSettings,
                      ),
                      SizedBox(
                        width: AppSizes.padding(context, SizeCategory.small),
                      ),
                      _buildHeaderIconButton(
                        icon: Icons.add_circle_outline,
                        onPressed: _showCreateChatDialog,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getBackgroundColor(context),
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: AppTheme.getIconPrimaryColor(context),
          size: AppSizes.icon(context, SizeCategory.medium),
        ),
        onPressed: onPressed,
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
          hintText: 'Tìm kiếm tin nhắn...',
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

  Widget _buildChatList() {
    return StreamBuilder<List<Chat>>(
      stream: _chatService.getAllChatsForUser(currentUserId),
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
                  Icons.chat_bubble_outline,
                  size: AppSizes.icon(context, SizeCategory.xxxlarge),
                  color: AppTheme.getIconSecondaryColor(context),
                ),
                SizedBox(
                  height: AppSizes.padding(context, SizeCategory.medium),
                ),
                Text(
                  'Chưa có tin nhắn',
                  style: TextStyle(
                    fontSize: AppSizes.font(context, SizeCategory.medium),
                    color: AppTheme.getTextSecondaryColor(context),
                  ),
                ),
              ],
            ),
          );
        }

        var chats = snapshot.data!;

        // Sort chats
        chats.sort((a, b) {
          final typeOrder = {
            ChatType.private: 0,
            ChatType.community: 1,
            ChatType.group: 2,
          };
          final typeCompare = typeOrder[a.chatType]!.compareTo(
            typeOrder[b.chatType]!,
          );
          if (typeCompare != 0) return typeCompare;

          final aTime = a.lastMessageTime ?? a.createdAt;
          final bTime = b.lastMessageTime ?? b.createdAt;
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.padding(context, SizeCategory.small),
          ),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];

            // Apply search filter in item builder
            if (_searchQuery.isNotEmpty) {
              final searchName =
                  (chat.chatType == ChatType.private)
                      ? '' // Will be filtered in FutureBuilder
                      : (chat.groupName ?? '').toLowerCase();

              if (chat.chatType != ChatType.private &&
                  !searchName.contains(_searchQuery)) {
                return const SizedBox.shrink();
              }
            }

            return _buildChatItem(chat);
          },
        );
      },
    );
  }

  Widget _buildChatItem(Chat chat) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getChatDisplayInfo(chat),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final displayName = snapshot.data!['name'] as String;
        final displayAvatar = snapshot.data!['avatar'] as String?;

        // Apply search filter for private chats
        if (_searchQuery.isNotEmpty && chat.chatType == ChatType.private) {
          if (!displayName.toLowerCase().contains(_searchQuery)) {
            return const SizedBox.shrink();
          }
        }

        final unreadCount = 0; // TODO: Implement unread count later

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
                  displayAvatar != null ? NetworkImage(displayAvatar) : null,
              child:
                  displayAvatar == null
                      ? Text(
                        displayName[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: AppSizes.font(context, SizeCategory.medium),
                        ),
                      )
                      : null,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppSizes.font(context, SizeCategory.medium),
                      color: AppTheme.getTextPrimaryColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (chat.lastMessageTime != null)
                  Text(
                    _formatTime(chat.lastMessageTime!),
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.small),
                      color: AppTheme.getTextSecondaryColor(context),
                    ),
                  ),
              ],
            ),
            subtitle: Row(
              children: [
                Expanded(
                  child: Text(
                    _getLastMessageDisplay(chat),
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.small),
                      color: AppTheme.getTextSecondaryColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (unreadCount > 0)
                  Container(
                    padding: EdgeInsets.all(
                      AppSizes.padding(context, SizeCategory.small) * 0.5,
                    ),
                    constraints: BoxConstraints(
                      minWidth: AppSizes.icon(context, SizeCategory.small),
                      minHeight: AppSizes.icon(context, SizeCategory.small),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize:
                              AppSizes.font(context, SizeCategory.small) * 0.8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => ChatScreen(
                        chat: chat,
                        displayName: displayName,
                        displayAvatar: displayAvatar,
                      ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getChatDisplayInfo(Chat chat) async {
    switch (chat.chatType) {
      case ChatType.private:
        final otherUserId = chat.members.firstWhere(
          (id) => id != currentUserId,
          orElse: () => currentUserId,
        );
        try {
          final userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(otherUserId)
                  .get();

          if (userDoc.exists) {
            final user = UserModel.fromFirestore(userDoc);
            return {'name': user.name, 'avatar': user.avatarUrl};
          }
        } catch (e) {
          debugPrint('❌ Error fetching user info: $e');
        }
        return {'name': 'User $otherUserId', 'avatar': null};
      case ChatType.community:
      case ChatType.group:
        return {
          'name': chat.groupName ?? 'Group Chat',
          'avatar': chat.groupAvatar,
        };
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${time.day}/${time.month}';
    }
  }

  String _getLastMessageDisplay(Chat chat) {
    // Nếu có ảnh trong tin nhắn cuối
    if (chat.lastMessageImageCount != null && chat.lastMessageImageCount! > 0) {
      final imageText = 'đã gửi ${chat.lastMessageImageCount} ảnh';
      // Nếu có cả text message
      if (chat.lastMessage?.isNotEmpty ?? false) {
        return '${chat.lastMessage} ($imageText)';
      }
      // Chỉ có ảnh
      return imageText;
    }

    // Chỉ có text hoặc chưa có tin nhắn
    return (chat.lastMessage?.isEmpty ?? true)
        ? 'Chưa có tin nhắn'
        : chat.lastMessage!;
  }

  void _showNotificationSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getSurfaceColor(context),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radius(context, SizeCategory.large)),
        ),
      ),
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => Padding(
                  padding: EdgeInsets.all(
                    AppSizes.padding(context, SizeCategory.medium),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.getIconSecondaryColor(context),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: AppSizes.padding(context, SizeCategory.medium),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(
                              AppSizes.padding(context, SizeCategory.small),
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                AppSizes.radius(context, SizeCategory.medium),
                              ),
                            ),
                            child: Icon(
                              Icons.notifications,
                              color: AppColors.primaryGreen,
                              size: AppSizes.icon(context, SizeCategory.medium),
                            ),
                          ),
                          SizedBox(
                            width: AppSizes.padding(
                              context,
                              SizeCategory.medium,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Cài đặt thông báo',
                              style: TextStyle(
                                fontSize: AppSizes.font(
                                  context,
                                  SizeCategory.large,
                                ),
                                fontWeight: FontWeight.bold,
                                color: AppTheme.getTextPrimaryColor(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: AppSizes.padding(context, SizeCategory.large),
                      ),
                      _buildNotificationOptionStateful(
                        context: context,
                        setModalState: setModalState,
                        icon: Icons.notifications_active,
                        title: 'Thông báo tin nhắn',
                        subtitle: 'Nhận thông báo khi có tin nhắn mới',
                        value: _notificationEnabled,
                        onChanged: (value) {
                          setState(() => _notificationEnabled = value);
                          setModalState(() => _notificationEnabled = value);
                          _saveNotificationPreference(
                            'chat_notification_enabled',
                            value,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value
                                    ? 'Đã bật thông báo tin nhắn'
                                    : 'Đã tắt thông báo tin nhắn',
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      Divider(color: AppTheme.getBorderColor(context)),
                      _buildNotificationOptionStateful(
                        context: context,
                        setModalState: setModalState,
                        icon: Icons.volume_up,
                        title: 'Âm thanh',
                        subtitle: 'Phát âm thanh khi có thông báo',
                        value: _soundEnabled,
                        onChanged: (value) {
                          setState(() => _soundEnabled = value);
                          setModalState(() => _soundEnabled = value);
                          _saveNotificationPreference(
                            'chat_sound_enabled',
                            value,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value ? 'Đã bật âm thanh' : 'Đã tắt âm thanh',
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      Divider(color: AppTheme.getBorderColor(context)),
                      _buildNotificationOptionStateful(
                        context: context,
                        setModalState: setModalState,
                        icon: Icons.vibration,
                        title: 'Rung',
                        subtitle: 'Rung khi có thông báo',
                        value: _vibrationEnabled,
                        onChanged: (value) {
                          setState(() => _vibrationEnabled = value);
                          setModalState(() => _vibrationEnabled = value);
                          _saveNotificationPreference(
                            'chat_vibration_enabled',
                            value,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value ? 'Đã bật rung' : 'Đã tắt rung',
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      Divider(color: AppTheme.getBorderColor(context)),
                      _buildNotificationOptionStateful(
                        context: context,
                        setModalState: setModalState,
                        icon: Icons.preview,
                        title: 'Hiển thị nội dung',
                        subtitle: 'Hiển thị nội dung tin nhắn trong thông báo',
                        value: _previewEnabled,
                        onChanged: (value) {
                          setState(() => _previewEnabled = value);
                          setModalState(() => _previewEnabled = value);
                          _saveNotificationPreference(
                            'chat_preview_enabled',
                            value,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value
                                    ? 'Đã bật hiển thị nội dung'
                                    : 'Đã tắt hiển thị nội dung',
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      SizedBox(
                        height: AppSizes.padding(context, SizeCategory.medium),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _buildNotificationOptionStateful({
    required BuildContext context,
    required StateSetter setModalState,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: AppSizes.padding(context, SizeCategory.small) * 0.5,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppColors.primaryGreen,
            size: AppSizes.icon(context, SizeCategory.medium),
          ),
          SizedBox(width: AppSizes.padding(context, SizeCategory.medium)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: AppSizes.font(context, SizeCategory.medium),
                    color: AppTheme.getTextPrimaryColor(context),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: AppSizes.font(context, SizeCategory.small),
                    color: AppTheme.getTextSecondaryColor(context),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: AppSizes.padding(context, SizeCategory.small)),
          Switch(
            value: value,
            activeColor: AppColors.primaryGreen,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _showCreateChatDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radius(context, SizeCategory.large)),
        ),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.all(
              AppSizes.padding(context, SizeCategory.medium),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tạo đoạn chat mới',
                  style: TextStyle(
                    fontSize: AppSizes.font(context, SizeCategory.large),
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextPrimaryColor(context),
                  ),
                ),
                SizedBox(
                  height: AppSizes.padding(context, SizeCategory.medium),
                ),
                _buildChatTypeOption(
                  icon: Icons.person,
                  title: 'Chat riêng tư',
                  subtitle: 'Trò chuyện 1-1 với bạn bè',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SelectFriendScreen(),
                      ),
                    );
                  },
                ),
                _buildChatTypeOption(
                  icon: Icons.group,
                  title: 'Tạo nhóm',
                  subtitle: 'Tạo nhóm chat với nhiều người',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateGroupScreen(),
                      ),
                    );
                  },
                ),
                _buildChatTypeOption(
                  icon: Icons.public,
                  title: 'Tạo cộng đồng',
                  subtitle: 'Cộng đồng công khai cho mọi người',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateCommunityScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildChatTypeOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        AppSizes.radius(context, SizeCategory.medium),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(
                AppSizes.padding(context, SizeCategory.small),
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(
                  AppSizes.radius(context, SizeCategory.medium),
                ),
              ),
              child: Icon(
                icon,
                color: AppColors.primaryGreen,
                size: AppSizes.icon(context, SizeCategory.medium),
              ),
            ),
            SizedBox(width: AppSizes.padding(context, SizeCategory.medium)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.medium),
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getTextPrimaryColor(context),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.small),
                      color: AppTheme.getTextSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
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
