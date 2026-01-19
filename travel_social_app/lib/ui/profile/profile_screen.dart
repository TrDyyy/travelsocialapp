import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:travel_social_app/utils/constants.dart';
import '../../models/user_model.dart';
import '../../models/user_badge.dart';
import '../../models/friend.dart';
import '../../models/post.dart';
import '../../models/review.dart';
import '../../models/violation_request.dart';
import '../../services/friend_service.dart';
import '../../services/post_service.dart';
import '../../services/review_service.dart';
import '../../services/points_tracking_service.dart';
import '../../widgets/violation_report_dialog.dart';
import '../tabs/social/widgets/post_item.dart';
import '../violation/violation_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final FriendService _friendService = FriendService();
  final PostService _postService = PostService();
  final ReviewService _reviewService = ReviewService();
  final PointsTrackingService _pointsService = PointsTrackingService();

  late TabController _tabController;
  String? _currentUserId;
  UserModel? _profileUser;
  Friendship? _friendship;
  int _friendCount = 0;
  UserBadge? _userBadge;
  int _userRank = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadUserData();
    _loadFriendship();
    _loadFriendCount();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .get();
      if (doc.exists) {
        setState(() {
          _profileUser = UserModel.fromFirestore(doc);
        });
        // Load badge and rank
        _loadBadgeData();
      }
    } catch (e) {
      debugPrint('❌ Error loading user: $e');
    }
  }

  Future<void> _loadBadgeData() async {
    try {
      final badge = await _pointsService.getUserBadge(widget.userId);
      final rank = await _pointsService.getUserRank(widget.userId);
      if (mounted) {
        setState(() {
          _userBadge = badge ?? UserBadge.allBadges.first;
          _userRank = rank;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading badge: $e');
    }
  }

  Future<void> _loadFriendship() async {
    if (_currentUserId == null || _currentUserId == widget.userId) return;
    final friendship = await _friendService.getFriendship(
      _currentUserId!,
      widget.userId,
    );
    setState(() {
      _friendship = friendship;
    });
  }

  Future<void> _loadFriendCount() async {
    final count = await _friendService.getFriendCount(widget.userId);
    setState(() {
      _friendCount = count;
    });
  }

  Widget _buildFriendButton() {
    if (_currentUserId == null || _currentUserId == widget.userId) {
      return const SizedBox.shrink();
    }

    // Chưa có friendship
    if (_friendship == null) {
      return ElevatedButton.icon(
        onPressed: () async {
          final success = await _friendService.sendFriendRequest(
            _currentUserId!,
            widget.userId,
          );
          if (success != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã gửi lời mời kết bạn')),
            );
            _loadFriendship();
          }
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Kết bạn'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
        ),
      );
    }

    // Đã là bạn
    if (_friendship!.status == FriendshipStatus.accepted) {
      return OutlinedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Hủy kết bạn'),
                  content: const Text('Bạn có chắc muốn hủy kết bạn?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        final success = await _friendService.removeFriendship(
                          _friendship!.friendshipId!,
                        );
                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã hủy kết bạn')),
                          );
                          _loadFriendship();
                          _loadFriendCount();
                        }
                      },
                      child: const Text('Xác nhận'),
                    ),
                  ],
                ),
          );
        },
        icon: const Icon(Icons.check),
        label: const Text('Bạn bè'),
      );
    }

    // Pending - Người nhận (có thể chấp nhận/từ chối)
    if (_friendship!.status == FriendshipStatus.pending &&
        _friendship!.isReceiver(_currentUserId!)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () async {
              final success = await _friendService.acceptFriendRequest(
                _friendship!.friendshipId!,
              );
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã chấp nhận lời mời')),
                );
                _loadFriendship();
                _loadFriendCount();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Chấp nhận'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () async {
              final success = await _friendService.rejectFriendRequest(
                _friendship!.friendshipId!,
              );
              if (success && mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Đã từ chối')));
                _loadFriendship();
              }
            },
            child: const Text('Từ chối'),
          ),
        ],
      );
    }

    // Pending - Người gửi (có thể hủy)
    if (_friendship!.status == FriendshipStatus.pending) {
      return OutlinedButton.icon(
        onPressed: () async {
          final success = await _friendService.removeFriendship(
            _friendship!.friendshipId!,
          );
          if (success && mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Đã hủy lời mời')));
            _loadFriendship();
          }
        },
        icon: const Icon(Icons.close),
        label: const Text('Hủy lời mời'),
      );
    }

    return const SizedBox.shrink();
  }

  /// Báo cáo vi phạm user
  Future<void> _reportUser() async {
    if (_profileUser == null) return;

    await showDialog(
      context: context,
      builder:
          (context) => ViolationReportDialog(
            objectType: ViolatedObjectType.user,
            violatedObject: _profileUser!,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_profileUser?.name ?? 'Trang cá nhân'),
        actions: [
          // Menu báo cáo user (chỉ hiển thị khi xem profile người khác)
          if (_currentUserId != null && _currentUserId != widget.userId)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'report') {
                  _reportUser();
                }
              },
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag, color: AppColors.error),
                          SizedBox(width: 12),
                          Text('Báo cáo vi phạm'),
                        ],
                      ),
                    ),
                  ],
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .snapshots(),
        builder: (context, userSnapshot) {
          // Show loading only on initial load
          if (userSnapshot.connectionState == ConnectionState.waiting &&
              _profileUser == null) {
            return const Center(child: CircularProgressIndicator());
          }

          // Update _profileUser from stream if data available
          if (userSnapshot.hasData && userSnapshot.data!.exists) {
            final updatedUser = UserModel.fromFirestore(userSnapshot.data!);

            // Update badge if points changed
            if (_profileUser?.totalPoints != updatedUser.totalPoints) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _profileUser = updatedUser;
                  });
                  _loadBadgeData();
                }
              });
            } else if (_profileUser == null) {
              _profileUser = updatedUser;
            }
          }

          if (_profileUser == null) {
            return const Center(child: Text('Không tìm thấy người dùng'));
          }

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      // Avatar
                      CircleAvatar(
                        radius: 60,
                        backgroundImage:
                            _profileUser!.avatarUrl != null &&
                                    _profileUser!.avatarUrl!.isNotEmpty
                                ? NetworkImage(_profileUser!.avatarUrl!)
                                : null,
                        child:
                            _profileUser!.avatarUrl == null ||
                                    _profileUser!.avatarUrl!.isEmpty
                                ? Text(
                                  _profileUser!.name[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 40),
                                )
                                : null,
                      ),
                      const SizedBox(height: 16),

                      // Tên
                      Text(
                        _profileUser!.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Bio/Email
                      Text(
                        _profileUser!.email,
                        style: TextStyle(
                          color: AppTheme.getTextSecondaryColor(context),
                          fontSize: AppSizes.font(context, SizeCategory.medium),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Badge Display
                      if (_userBadge != null) _buildBadgeDisplay(),
                      const SizedBox(height: 16),

                      // Friend Button
                      _buildFriendButton(),
                      const SizedBox(height: 16),

                      // Stats
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.getSurfaceColor(context),
                          border: Border(
                            top: BorderSide(
                              color: AppTheme.getBorderColor(context),
                            ),
                            bottom: BorderSide(
                              color: AppTheme.getBorderColor(context),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem(
                              'Điểm',
                              NumberFormat(
                                '#,###',
                              ).format(_profileUser!.totalPoints),
                            ),
                            _buildStatItem('Xếp hạng', '#$_userRank'),
                            _buildStatItem('Bạn bè', _friendCount.toString()),
                          ],
                        ),
                      ),

                      // Violation History Link (only for current user)
                      if (_currentUserId == widget.userId) ...[
                        const SizedBox(height: 8),
                        ListTile(
                          leading: const Icon(
                            Icons.flag_outlined,
                            color: AppColors.error,
                          ),
                          title: const Text('Lịch sử báo cáo vi phạm'),
                          subtitle: const Text(
                            'Xem các báo cáo vi phạm bạn đã gửi',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => const ViolationHistoryScreen(),
                              ),
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyTabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: AppTheme.getTextPrimaryColor(context),
                      unselectedLabelColor: AppTheme.getTextSecondaryColor(
                        context,
                      ),
                      indicatorColor: AppTheme.getTextPrimaryColor(context),
                      tabs: const [
                        Tab(text: 'Bài viết'),
                        Tab(text: 'Đánh giá'),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                // Tab Posts
                StreamBuilder<List<Post>>(
                  stream: _postService.getUserPosts(widget.userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Chưa có bài viết nào'));
                    }

                    final posts = snapshot.data!;
                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        return PostItem(post: posts[index]);
                      },
                    );
                  },
                ),

                // Tab Reviews
                StreamBuilder<List<Review>>(
                  stream: _reviewService.getUserReviews(widget.userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Chưa có đánh giá nào'));
                    }

                    final reviews = snapshot.data!;
                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: reviews.length,
                      itemBuilder: (context, index) {
                        final review = reviews[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            title: Text(
                              'Đánh giá địa điểm',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: List.generate(5, (i) {
                                    return Icon(
                                      i < review.rating
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                      size: 16,
                                    );
                                  }),
                                ),
                                if (review.content.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    review.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                            trailing:
                                review.images != null &&
                                        review.images!.isNotEmpty
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        review.images!.first,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                    : null,
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
      ],
    );
  }

  Widget _buildBadgeDisplay() {
    if (_userBadge == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(int.parse('0xFF${_userBadge!.color.substring(1)}')),
            Color(
              int.parse('0xFF${_userBadge!.color.substring(1)}'),
            ).withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(
              int.parse('0xFF${_userBadge!.color.substring(1)}'),
            ).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Text(_userBadge!.icon, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 12),
          // Badge info
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _userBadge!.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Cấp độ ${_userBadge!.level}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppTheme.getSurfaceColor(context), child: tabBar);
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return false;
  }
}
