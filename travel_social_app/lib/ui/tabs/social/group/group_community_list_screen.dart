import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../models/community.dart';
import '../../../../services/community_service.dart';
import '../../../../utils/constants.dart';
import 'group_detail_screen.dart';
import 'create_group_screen.dart';

/// Màn hình danh sách Group Communities
class GroupCommunityListScreen extends StatefulWidget {
  const GroupCommunityListScreen({super.key});

  @override
  State<GroupCommunityListScreen> createState() =>
      _GroupCommunityListScreenState();
}

class _GroupCommunityListScreenState extends State<GroupCommunityListScreen> {
  final CommunityService _communityService = CommunityService();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _navigateToCreateGroup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để tạo nhóm'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
    );
  }

  Future<void> _handleJoinRequest(Community community) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Nếu đã gửi request thì hủy
    if (community.hasPendingRequest(user.uid)) {
      final success = await _communityService.cancelJoinRequest(
        community.communityId!,
        user.uid,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã hủy yêu cầu tham gia')),
        );
      }
      return;
    }

    // Gửi request mới
    final success = await _communityService.requestJoinGroup(
      community.communityId!,
      user.uid,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi yêu cầu tham gia. Chờ admin duyệt.'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.getSurfaceColor(context),
        title: Text(
          'Cộng đồng',
          style: TextStyle(
            color: AppTheme.getTextPrimaryColor(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_circle_outline,
              color: AppTheme.getIconPrimaryColor(context),
            ),
            onPressed: _navigateToCreateGroup,
            tooltip: 'Tạo nhóm mới',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.all(
              AppSizes.padding(context, SizeCategory.medium),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Tìm kiếm nhóm...',
                prefixIcon: Icon(
                  Icons.search,
                  color: AppTheme.getIconPrimaryColor(context),
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
            ),
          ),

          // Groups list
          Expanded(
            child: StreamBuilder<List<Community>>(
              stream: _communityService.getAllGroupsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Lỗi: ${snapshot.error}'));
                }

                final groups = snapshot.data ?? [];
                final filteredGroups =
                    _searchQuery.isEmpty
                        ? groups
                        : groups
                            .where(
                              (g) =>
                                  g.name.toLowerCase().contains(_searchQuery) ||
                                  g.description.toLowerCase().contains(
                                    _searchQuery,
                                  ),
                            )
                            .toList();

                if (filteredGroups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_off,
                          size: AppSizes.icon(context, SizeCategory.xxxlarge),
                          color: AppTheme.getIconSecondaryColor(context),
                        ),
                        SizedBox(
                          height: AppSizes.padding(
                            context,
                            SizeCategory.medium,
                          ),
                        ),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Chưa có nhóm nào'
                              : 'Không tìm thấy nhóm',
                          style: TextStyle(
                            fontSize: AppSizes.font(
                              context,
                              SizeCategory.xlarge,
                            ),
                            color: AppTheme.getTextSecondaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Sort: joined groups first
                final sortedGroups = [...filteredGroups];
                if (user != null) {
                  sortedGroups.sort((a, b) {
                    final aIsMember = a.isMember(user.uid);
                    final bIsMember = b.isMember(user.uid);
                    if (aIsMember && !bIsMember) return -1;
                    if (!aIsMember && bIsMember) return 1;
                    return b.memberCount.compareTo(a.memberCount);
                  });
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sortedGroups.length,
                  itemBuilder: (context, index) {
                    final group = sortedGroups[index];
                    final isMember = user != null && group.isMember(user.uid);
                    final hasPending =
                        user != null && group.hasPendingRequest(user.uid);
                    final isAdmin = user != null && group.isAdmin(user.uid);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side:
                            isMember
                                ? const BorderSide(
                                  color: AppColors.primaryGreen,
                                  width: 2,
                                )
                                : BorderSide.none,
                      ),
                      child: InkWell(
                        onTap: () {
                          // Chỉ cho phép vào nếu là member
                          if (isMember) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        GroupDetailScreen(community: group),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Bạn cần tham gia nhóm để xem bài viết',
                                ),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Group avatar
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: AppColors.primaryGreen,
                                    backgroundImage:
                                        group.avatarUrl != null &&
                                                group.avatarUrl!.isNotEmpty
                                            ? NetworkImage(group.avatarUrl!)
                                            : null,
                                    child:
                                        group.avatarUrl == null ||
                                                group.avatarUrl!.isEmpty
                                            ? Text(
                                              group.name[0].toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                            : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                group.name,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isAdmin)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  left: 8,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryGreen,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
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
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.people,
                                              size: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${group.memberCount} thành viên',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Icon(
                                              Icons.article,
                                              size: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${group.postCount} bài viết',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                group.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              if (group.tourismTypes.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children:
                                      group.tourismTypes.map((type) {
                                        // Debug: in ra để xem dữ liệu
                                        debugPrint(
                                          '🏷️ Tourism Type - ID: ${type.typeId}, Name: "${type.name}", Desc: "${type.description}"',
                                        );

                                        // Hiển thị name nếu có, không thì hiển thị typeId
                                        final displayText =
                                            type.name.isNotEmpty
                                                ? type.name
                                                : type.typeId;

                                        return Chip(
                                          label: Text(
                                            displayText,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.primaryGreen,
                                            ),
                                          ),
                                          backgroundColor: AppColors
                                              .primaryGreen
                                              .withOpacity(0.15),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          labelPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          side: BorderSide(
                                            color: AppColors.primaryGreen
                                                .withOpacity(0.3),
                                            width: 1,
                                          ),
                                        );
                                      }).toList(),
                                ),
                              ],
                              if (!isMember) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _handleJoinRequest(group),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          hasPending
                                              ? Colors.grey
                                              : AppColors.primaryGreen,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    icon: Icon(
                                      hasPending
                                          ? Icons.hourglass_empty
                                          : Icons.group_add,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      hasPending
                                          ? 'Đang chờ duyệt'
                                          : 'Tham gia nhóm',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
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
