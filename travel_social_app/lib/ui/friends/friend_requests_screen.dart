import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/friend.dart';
import '../../models/user_model.dart';
import '../../services/friend_service.dart';
import '../profile/profile_screen.dart';

/// Screen hiển thị các lời mời kết bạn (nhận + đã gửi)
class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen>
    with SingleTickerProviderStateMixin {
  final FriendService _friendService = FriendService();
  late TabController _tabController;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lời mời kết bạn')),
        body: const Center(child: Text('Vui lòng đăng nhập')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lời mời kết bạn'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Nhận được'), Tab(text: 'Đã gửi')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab: Received Requests
          _buildReceivedRequests(),

          // Tab: Sent Requests
          _buildSentRequests(),
        ],
      ),
    );
  }

  Widget _buildReceivedRequests() {
    return StreamBuilder<List<Friendship>>(
      stream: _friendService.receivedRequestsStream(_currentUserId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Không có lời mời kết bạn nào'));
        }

        final requests = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final friendship = requests[index];
            return FutureBuilder<UserModel?>(
              future: _getUserById(friendship.userId1),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final user = userSnapshot.data!;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => ProfileScreen(userId: user.userId),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        backgroundImage:
                            (user.avatarUrl?.isNotEmpty ?? false)
                                ? NetworkImage(user.avatarUrl!)
                                : null,
                        child:
                            !(user.avatarUrl?.isNotEmpty ?? false)
                                ? Text(user.name[0].toUpperCase())
                                : null,
                      ),
                    ),
                    title: Text(user.name),
                    subtitle: Text(user.email),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            final success = await _friendService
                                .acceptFriendRequest(friendship.friendshipId!);
                            if (success && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã chấp nhận lời mời'),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text('Chấp nhận'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () async {
                            final success = await _friendService
                                .rejectFriendRequest(friendship.friendshipId!);
                            if (success && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Đã từ chối')),
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text('Từ chối'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSentRequests() {
    return StreamBuilder<List<Friendship>>(
      stream: _friendService.sentRequestsStream(_currentUserId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Chưa gửi lời mời nào'));
        }

        final requests = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final friendship = requests[index];
            return FutureBuilder<UserModel?>(
              future: _getUserById(friendship.userId2),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final user = userSnapshot.data!;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => ProfileScreen(userId: user.userId),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        backgroundImage:
                            (user.avatarUrl?.isNotEmpty ?? false)
                                ? NetworkImage(user.avatarUrl!)
                                : null,
                        child:
                            !(user.avatarUrl?.isNotEmpty ?? false)
                                ? Text(user.name[0].toUpperCase())
                                : null,
                      ),
                    ),
                    title: Text(user.name),
                    subtitle: const Text('Đang chờ phản hồi'),
                    trailing: OutlinedButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Hủy lời mời'),
                                content: const Text(
                                  'Bạn có chắc muốn hủy lời mời này?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, false),
                                    child: const Text('Không'),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, true),
                                    child: const Text('Có'),
                                  ),
                                ],
                              ),
                        );

                        if (confirm == true) {
                          final success = await _friendService.removeFriendship(
                            friendship.friendshipId!,
                          );
                          if (success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã hủy lời mời')),
                            );
                          }
                        }
                      },
                      child: const Text('Hủy'),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<UserModel?> _getUserById(String userId) async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error loading user: $e');
      return null;
    }
  }
}
