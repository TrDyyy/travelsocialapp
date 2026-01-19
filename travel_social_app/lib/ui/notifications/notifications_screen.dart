import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:travel_social_app/utils/constants.dart';
import '../../models/notification.dart';
import '../../services/notification_service.dart';
import '../../services/community_service.dart';
import '../profile/profile_screen.dart';
import '../tabs/social/post/post_detail_screen.dart';
import '../tabs/social/group/group_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final CommunityService _communityService = CommunityService();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thông báo')),
        body: const Center(child: Text('Vui lòng đăng nhập')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () async {
              await _notificationService.markAllAsRead(_currentUserId!);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã đánh dấu tất cả là đã đọc')),
                );
              }
            },
            tooltip: 'Đánh dấu tất cả là đã đọc',
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _notificationService.notificationsStream(_currentUserId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off,
                    size: AppSizes.icon(context, SizeCategory.large),
                    color: AppTheme.getIconSecondaryColor(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có thông báo nào',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!;
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationItem(notification);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(AppNotification notification) {
    return Dismissible(
      key: Key(notification.notificationId!),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        _notificationService.deleteNotification(notification.notificationId!);
      },
      child: Container(
        color:
            notification.isRead
                ? AppTheme.getSurfaceColor(context)
                : AppTheme.getBackgroundColor(context),
        child: ListTile(
          leading: CircleAvatar(
            backgroundImage:
                notification.imageUrl != null
                    ? NetworkImage(notification.imageUrl!)
                    : null,
            child:
                notification.imageUrl == null
                    ? Icon(_getIconForType(notification.type))
                    : null,
          ),
          title: Text(
            notification.title,
            style: TextStyle(
              color: AppTheme.getTextPrimaryColor(context),
              fontWeight:
                  notification.isRead ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(notification.body),
              const SizedBox(height: 4),
              Text(
                _formatTimestamp(notification.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.getTextSecondaryColor(context),
                ),
              ),
            ],
          ),
          trailing:
              !notification.isRead
                  ? Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  )
                  : null,
          onTap: () => _handleNotificationTap(notification),
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'friend_request':
        return Icons.person_add;
      case 'friend_accept':
        return Icons.check_circle;
      case 'post_like':
        return Icons.favorite;
      case 'post_comment':
        return Icons.comment;
      case 'review_like':
        return Icons.star;
      default:
        return Icons.notifications;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(timestamp);
    }
  }

  Future<void> _handleNotificationTap(AppNotification notification) async {
    // Mark as read
    if (!notification.isRead) {
      await _notificationService.markAsRead(notification.notificationId!);
    }

    // Navigate based on type
    if (!mounted) return;

    switch (notification.type) {
      case 'friend_request':
      case 'friend_accept':
        final fromUserId = notification.data?['fromUserId'];
        if (fromUserId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: fromUserId),
            ),
          );
        }
        break;

      case 'post_like':
      case 'post_comment':
        final postId = notification.data?['postId'];
        if (postId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailScreen(postId: postId),
            ),
          );
        }
        break;

      case 'group_join_request':
        // Admin nhận thông báo có người xin join -> đi đến màn hình quản lý pending requests
        final communityId = notification.data?['communityId'];
        if (communityId != null) {
          // Load community trước khi navigate
          final community = await _communityService.getCommunityById(
            communityId,
          );
          if (community != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupDetailScreen(community: community),
              ),
            );
          }
        }
        break;

      case 'group_join_approved':
      case 'group_join_rejected':
        // User nhận thông báo được/bị từ chối -> đi đến màn hình group detail
        final communityId = notification.data?['communityId'];
        if (communityId != null) {
          // Load community trước khi navigate
          final community = await _communityService.getCommunityById(
            communityId,
          );
          if (community != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupDetailScreen(community: community),
              ),
            );
          }
        }
        break;

      default:
        break;
    }
  }
}
