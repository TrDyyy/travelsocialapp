import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/community.dart';
import '../../../../models/post.dart';
import '../../../../models/user_model.dart';
import '../../../../services/community_service.dart';
import '../../../../services/user_service.dart';
import '../../../../utils/constants.dart';
import '../post/create_post_screen.dart';
import '../widgets/post_item.dart';
import 'edit_group_screen.dart';

/// Màn hình chi tiết Group với post list và quản lý members
class GroupDetailScreen extends StatefulWidget {
  final Community community;

  const GroupDetailScreen({super.key, required this.community});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  final CommunityService _communityService = CommunityService();
  final UserService _userService = UserService();

  late TabController _tabController;
  Community? _currentCommunity;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentCommunity = widget.community;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _navigateToCreatePost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentCommunity == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => CreatePostScreen(
              groupCommunityId: _currentCommunity!.communityId,
            ),
      ),
    );
  }

  Future<void> _approveRequest(String userId) async {
    if (_currentCommunity == null) return;

    final success = await _communityService.approveJoinRequest(
      _currentCommunity!.communityId!,
      userId,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã duyệt thành viên'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    }
  }

  Future<void> _rejectRequest(String userId) async {
    if (_currentCommunity == null) return;

    final success = await _communityService.rejectJoinRequest(
      _currentCommunity!.communityId!,
      userId,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã từ chối yêu cầu')));
    }
  }

  Future<void> _removeMember(String userId) async {
    if (_currentCommunity == null) return;

    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xóa thành viên'),
            content: const Text('Bạn có chắc muốn xóa thành viên này?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Xóa', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    final success = await _communityService.removeMember(
      _currentCommunity!.communityId!,
      userId,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa thành viên')));
    }
  }

  Future<void> _deletePost(String postId) async {
    if (_currentCommunity == null) return;

    // Confirm dialog
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
                child: const Text('Xóa', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    final success = await _communityService.deletePostFromGroup(
      postId,
      _currentCommunity!.communityId!,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa bài viết')));
    }
  }

  Future<void> _editGroup(Community community) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditGroupScreen(community: community),
      ),
    );

    if (result == true && mounted) {
      // Refresh community data
      setState(() {});
    }
  }

  Future<void> _deleteGroup(Community community) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xóa nhóm'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bạn có chắc muốn xóa nhóm này?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Hành động này sẽ:'),
                const SizedBox(height: 4),
                Text('• Xóa tất cả ${community.postCount} bài viết'),
                Text('• Xóa ${community.memberCount} thành viên khỏi nhóm'),
                const Text('• Không thể hoàn tác'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Xóa nhóm',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    final success = await _communityService.deleteCommunity(
      community.communityId!,
    );

    if (success && mounted) {
      Navigator.pop(context); // Quay lại màn hình trước
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa nhóm')));
    }
  }

  Future<void> _toggleMemberAdmin(String userId, bool makeAdmin) async {
    if (_currentCommunity == null) return;

    final success = await _communityService.toggleAdminRole(
      _currentCommunity!.communityId!,
      userId,
      makeAdmin,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(makeAdmin ? 'Đã thăng chức admin' : 'Đã hạ chức admin'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<Community?>(
      stream: _communityService.getCommunityStream(
        widget.community.communityId!,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _currentCommunity = snapshot.data;
        }

        final community = _currentCommunity ?? widget.community;
        final isAdmin = user != null && community.isAdmin(user.uid);
        final isMember = user != null && community.isMember(user.uid);

        return Scaffold(
          backgroundColor: AppTheme.getBackgroundColor(context),
          appBar: AppBar(
            backgroundColor: AppColors.primaryGreen,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              community.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              if (isAdmin)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editGroup(community);
                        break;
                      case 'delete':
                        _deleteGroup(community);
                        break;
                    }
                  },
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 12),
                              Text('Chỉnh sửa nhóm'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 12),
                              Text(
                                'Xóa nhóm',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [Tab(text: 'Bài viết'), Tab(text: 'Thành viên')],
            ),
          ),
          body: Column(
            children: [
              // Group info header
              Container(
                color: AppTheme.getSurfaceColor(context),
                padding: EdgeInsets.all(
                  AppSizes.padding(context, SizeCategory.medium),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius:
                              AppSizes.radius(context, SizeCategory.xxxlarge) *
                              1.3,
                          backgroundColor: AppColors.primaryGreen,
                          backgroundImage:
                              community.avatarUrl != null &&
                                      community.avatarUrl!.isNotEmpty
                                  ? NetworkImage(community.avatarUrl!)
                                  : null,
                          child:
                              community.avatarUrl == null ||
                                      community.avatarUrl!.isEmpty
                                  ? Text(
                                    community.name[0].toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: AppSizes.font(
                                        context,
                                        SizeCategory.xxlarge,
                                      ),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                  : null,
                        ),
                        SizedBox(
                          width: AppSizes.padding(context, SizeCategory.medium),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      community.name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isAdmin)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryGreen,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Admin',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              StreamBuilder<Community?>(
                                stream: _communityService.getCommunityStream(
                                  community.communityId!,
                                ),
                                builder: (context, streamSnapshot) {
                                  final updatedCommunity =
                                      streamSnapshot.data ?? community;
                                  return Row(
                                    children: [
                                      Icon(
                                        Icons.people,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${updatedCommunity.memberCount} thành viên',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.article,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${updatedCommunity.postCount} bài viết',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      community.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (community.tourismTypes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children:
                            community.tourismTypes.map((type) {
                              return Chip(
                                label: Text(
                                  type.name,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                backgroundColor: AppColors.primaryGreen
                                    .withOpacity(0.1),
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              );
                            }).toList(),
                      ),
                    ],
                  ],
                ),
              ),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Posts
                    _buildPostsTab(community),

                    // Tab 2: Members
                    _buildMembersTab(community, isAdmin),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton:
              (isAdmin || isMember)
                  ? FloatingActionButton(
                    onPressed: _navigateToCreatePost,
                    backgroundColor: AppColors.primaryGreen,
                    child: const Icon(Icons.add, color: Colors.white),
                  )
                  : null,
        );
      },
    );
  }

  Widget _buildPostsTab(Community community) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('posts')
              .where('communityId', isEqualTo: community.communityId)
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }

        final posts =
            snapshot.data?.docs
                .map((doc) => Post.fromFirestore(doc))
                .toList() ??
            [];

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Chưa có bài viết nào',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final user = FirebaseAuth.instance.currentUser;
            final isAdmin =
                _currentCommunity != null &&
                user != null &&
                _currentCommunity!.isAdmin(user.uid);

            return PostItem(
              post: post,
              showGroupAdminDelete: isAdmin,
              onGroupAdminDelete:
                  isAdmin ? () => _deletePost(post.postId!) : null,
            );
          },
        );
      },
    );
  }

  Widget _buildMembersTab(Community community, bool isAdmin) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pending requests (admin only)
          if (isAdmin && community.pendingRequests.isNotEmpty) ...[
            const Text(
              'Yêu cầu tham gia',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...community.pendingRequests.map((userId) {
              return FutureBuilder<UserModel?>(
                future: _userService.getUserById(userId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final user = snapshot.data!;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                ? NetworkImage(user.avatarUrl!)
                                : null,
                        child:
                            user.avatarUrl == null || user.avatarUrl!.isEmpty
                                ? Text(user.name[0].toUpperCase())
                                : null,
                      ),
                      title: Text(user.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => _approveRequest(userId),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _rejectRequest(userId),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }).toList(),
            const Divider(height: 32),
          ],

          // Members list
          const Text(
            'Thành viên',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...community.memberIds.map((userId) {
            return FutureBuilder<UserModel?>(
              future: _userService.getUserById(userId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final user = snapshot.data!;
                final isCommunityAdmin = community.isAdmin(userId);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                              ? NetworkImage(user.avatarUrl!)
                              : null,
                      child:
                          user.avatarUrl == null || user.avatarUrl!.isEmpty
                              ? Text(user.name[0].toUpperCase())
                              : null,
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(user.name)),
                        if (isCommunityAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Admin',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing:
                        isAdmin && userId != community.adminId
                            ? PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'toggleAdmin':
                                    _toggleMemberAdmin(
                                      userId,
                                      !isCommunityAdmin,
                                    );
                                    break;
                                  case 'remove':
                                    _removeMember(userId);
                                    break;
                                }
                              },
                              itemBuilder:
                                  (context) => [
                                    PopupMenuItem(
                                      value: 'toggleAdmin',
                                      child: Row(
                                        children: [
                                          Icon(
                                            isCommunityAdmin
                                                ? Icons.remove_moderator
                                                : Icons.admin_panel_settings,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            isCommunityAdmin
                                                ? 'Hạ chức admin'
                                                : 'Thăng chức admin',
                                          ),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.remove_circle_outline,
                                            size: 20,
                                            color: Colors.red,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Xóa khỏi nhóm',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                            )
                            : null,
                  ),
                );
              },
            );
          }).toList(),
        ],
      ),
    );
  }
}
