import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../models/user_badge.dart';
import '../../../services/points_tracking_service.dart';
import '../../../utils/constants.dart';

/// Màn hình hiển thị huy hiệu và điểm
class BadgeScreen extends StatefulWidget {
  const BadgeScreen({super.key});

  @override
  State<BadgeScreen> createState() => _BadgeScreenState();
}

class _BadgeScreenState extends State<BadgeScreen>
    with SingleTickerProviderStateMixin {
  final PointsTrackingService _pointsService = PointsTrackingService();
  late TabController _tabController;

  UserBadge? _currentBadge;
  int _totalPoints = 0;
  int _todayPoints = 0;
  int _userRank = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserBadgeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserBadgeData() async {
    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final points = await _pointsService.getUserPoints(userId);
        final badge = await _pointsService.getUserBadge(userId);
        final rank = await _pointsService.getUserRank(userId);
        final todayPoints = await _pointsService.getTodayPoints(userId);

        if (mounted) {
          setState(() {
            _totalPoints = points;
            _currentBadge = badge ?? UserBadge.allBadges.first;
            _userRank = rank;
            _todayPoints = todayPoints;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading badge data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text(
          'Huy hiệu hành trình',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Huy hiệu'),
            Tab(text: 'Hoạt động'),
            Tab(text: 'Bảng xếp hạng'),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              )
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildBadgeTab(),
                  _buildActivityTab(),
                  _buildLeaderboardTab(),
                ],
              ),
    );
  }

  // Tab 1: Huy hiệu
  Widget _buildBadgeTab() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Vui lòng đăng nhập'));
    }

    final nextBadge = _currentBadge?.getNextBadge();
    final pointsToNext = _currentBadge?.getPointsToNextBadge(_totalPoints);

    return RefreshIndicator(
      onRefresh: _loadUserBadgeData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current badge card
            _buildCurrentBadgeCard(),
            SizedBox(height: AppSizes.padding(context, SizeCategory.large)),

            // Stats summary - REALTIME
            StreamBuilder<DocumentSnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final userData =
                      snapshot.data!.data() as Map<String, dynamic>?;
                  final totalPoints = userData?['totalPoints'] ?? _totalPoints;

                  // Get realtime rank
                  return FutureBuilder<int>(
                    future: _pointsService.getUserRank(userId),
                    initialData: _userRank,
                    builder: (context, rankSnapshot) {
                      final rank = rankSnapshot.data ?? _userRank;
                      return _buildStatsCard(
                        totalPoints: totalPoints,
                        rank: rank,
                      );
                    },
                  );
                }
                return _buildStatsCard(
                  totalPoints: _totalPoints,
                  rank: _userRank,
                );
              },
            ),
            SizedBox(height: AppSizes.padding(context, SizeCategory.large)),

            // Progress to next badge
            if (nextBadge != null) ...[
              _buildProgressCard(nextBadge, pointsToNext!),
              SizedBox(height: AppSizes.padding(context, SizeCategory.large)),
            ],

            // All badges collection
            Text(
              'Tất cả huy hiệu',
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.large),
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimaryColor(context),
              ),
            ),
            SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
            _buildAllBadgesGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentBadgeCard() {
    if (_currentBadge == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.large)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(int.parse('0xFF${_currentBadge!.color.substring(1)}')),
            Color(
              int.parse('0xFF${_currentBadge!.color.substring(1)}'),
            ).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.large),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(
              int.parse('0xFF${_currentBadge!.color.substring(1)}'),
            ).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Badge icon
          Container(
            padding: EdgeInsets.all(
              AppSizes.padding(context, SizeCategory.medium),
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              _currentBadge!.icon,
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.xxxlarge) * 2,
              ),
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),

          // Badge name
          Text(
            _currentBadge!.name,
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.xlarge),
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimaryColor(context),
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.small)),

          // Badge description
          Text(
            _currentBadge!.description,
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.medium),
              color: AppTheme.getTextPrimaryColor(context),
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),

          // Level
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSizes.padding(context, SizeCategory.medium),
              vertical: AppSizes.padding(context, SizeCategory.small),
            ),
            decoration: BoxDecoration(
              color: AppTheme.getInputBackgroundColor(context).withOpacity(0.2),
              borderRadius: BorderRadius.circular(
                AppSizes.radius(context, SizeCategory.large),
              ),
            ),
            child: Text(
              'Cấp độ ${_currentBadge!.level}',
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.medium),
                fontWeight: FontWeight.w600,
                color: AppTheme.getTextPrimaryColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard({required int totalPoints, required int rank}) {
    return Container(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.stars,
              label: 'Tổng điểm',
              value: NumberFormat('#,###').format(totalPoints),
              color: Colors.amber,
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: AppTheme.getBorderColor(context),
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.emoji_events,
              label: 'Xếp hạng',
              value: '#$rank',
              color: AppColors.primaryGreen,
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: AppTheme.getBorderColor(context),
          ),
          Expanded(
            child: StreamBuilder<int>(
              stream: _getTodayPointsStream(
                FirebaseAuth.instance.currentUser!.uid,
              ),
              initialData: _todayPoints,
              builder: (context, snapshot) {
                return _buildStatItem(
                  icon: Icons.today,
                  label: 'Hôm nay',
                  value: '+${snapshot.data ?? _todayPoints}',
                  color: Colors.blue,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: AppSizes.icon(context, SizeCategory.large),
        ),
        SizedBox(height: AppSizes.padding(context, SizeCategory.small)),
        Text(
          value,
          style: TextStyle(
            fontSize: AppSizes.font(context, SizeCategory.large),
            fontWeight: FontWeight.bold,
            color: AppTheme.getTextPrimaryColor(context),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: AppSizes.font(context, SizeCategory.small),
            color: AppTheme.getTextSecondaryColor(context),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard(UserBadge nextBadge, int pointsNeeded) {
    // Tính progress dựa trên khoảng giữa badge hiện tại và badge tiếp theo
    final currentRequired = _currentBadge?.requiredPoints ?? 0;
    final nextRequired = nextBadge.requiredPoints;
    final progress =
        currentRequired >= nextRequired
            ? 1.0
            : ((_totalPoints - currentRequired) /
                    (nextRequired - currentRequired))
                .clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                nextBadge.icon,
                style: TextStyle(
                  fontSize: AppSizes.font(context, SizeCategory.xlarge),
                ),
              ),
              SizedBox(width: AppSizes.padding(context, SizeCategory.small)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Huy hiệu tiếp theo: ${nextBadge.name}',
                      style: TextStyle(
                        fontSize: AppSizes.font(context, SizeCategory.medium),
                        fontWeight: FontWeight.bold,
                        color: AppTheme.getTextPrimaryColor(context),
                      ),
                    ),
                    Text(
                      'Còn ${NumberFormat('#,###').format(pointsNeeded)} điểm',
                      style: TextStyle(
                        fontSize: AppSizes.font(context, SizeCategory.small),
                        color: AppTheme.getTextSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
          ClipRRect(
            borderRadius: BorderRadius.circular(
              AppSizes.radius(context, SizeCategory.large),
            ),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: AppTheme.getBorderColor(context),
              valueColor: AlwaysStoppedAnimation<Color>(
                Color(int.parse('0xFF${nextBadge.color.substring(1)}')),
              ),
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.small)),
          Text(
            '${(progress * 100).toStringAsFixed(1)}% hoàn thành',
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.small),
              color: AppTheme.getTextSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllBadgesGrid() {
    // Lọc bỏ badge "Cần cải thiện" (level 0)
    final displayBadges =
        UserBadge.allBadges.where((b) => b.level > 0).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: displayBadges.length,
      itemBuilder: (context, index) {
        final badge = displayBadges[index];
        final isUnlocked = _totalPoints >= badge.requiredPoints;

        return _buildBadgeItem(badge, isUnlocked);
      },
    );
  }

  Widget _buildBadgeItem(UserBadge badge, bool isUnlocked) {
    return Container(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.small)),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
        border: Border.all(
          color:
              isUnlocked
                  ? Color(int.parse('0xFF${badge.color.substring(1)}'))
                  : AppTheme.getBorderColor(context),
          width: isUnlocked ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: isUnlocked ? 1.0 : 0.3,
            child: Text(
              badge.icon,
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.xxxlarge),
              ),
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.small)),
          Text(
            badge.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.small),
              fontWeight: FontWeight.w600,
              color:
                  isUnlocked
                      ? AppTheme.getTextPrimaryColor(context)
                      : AppTheme.getTextSecondaryColor(context),
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.small) * 0.5),
          Text(
            NumberFormat('#,###').format(badge.requiredPoints),
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.small) * 0.9,
              color: AppTheme.getTextSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  // Tab 2: Hoạt động
  Widget _buildActivityTab() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Vui lòng đăng nhập'));
    }

    return Column(
      children: [
        // Today points summary - REALTIME
        StreamBuilder<int>(
          stream: _getTodayPointsStream(userId),
          initialData: _todayPoints,
          builder: (context, snapshot) {
            final todayPts = snapshot.data ?? 0;
            return Container(
              width: double.infinity,
              margin: EdgeInsets.all(
                AppSizes.padding(context, SizeCategory.medium),
              ),
              padding: EdgeInsets.all(
                AppSizes.padding(context, SizeCategory.medium),
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryGreen,
                    AppTheme.getInputBackgroundColor(context),
                  ],
                ),
                borderRadius: BorderRadius.circular(
                  AppSizes.radius(context, SizeCategory.medium),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.today,
                    color: Colors.white,
                    size: AppSizes.icon(context, SizeCategory.xlarge),
                  ),
                  SizedBox(
                    height: AppSizes.padding(context, SizeCategory.small),
                  ),
                  Text(
                    '+$todayPts điểm',
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.xxxlarge),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Hoạt động hôm nay',
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.medium),
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // Activity history
        Expanded(
          child: StreamBuilder<List<PointHistory>>(
            stream: _pointsService.getUserPointHistory(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
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
                        Icons.history,
                        size: AppSizes.icon(context, SizeCategory.xxxlarge),
                        color: AppTheme.getTextSecondaryColor(context),
                      ),
                      SizedBox(
                        height: AppSizes.padding(context, SizeCategory.medium),
                      ),
                      Text(
                        'Chưa có hoạt động',
                        style: TextStyle(
                          fontSize: AppSizes.font(context, SizeCategory.medium),
                          color: AppTheme.getTextSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final activities = snapshot.data!;
              return ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.padding(context, SizeCategory.medium),
                ),
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  return _buildActivityItem(activity);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(PointHistory activity) {
    final isPositive = activity.points > 0;
    final icon = _getActivityIcon(activity.action);

    return Container(
      margin: EdgeInsets.only(
        bottom: AppSizes.padding(context, SizeCategory.small),
      ),
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.small),
        ),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(
              AppSizes.padding(context, SizeCategory.small),
            ),
            decoration: BoxDecoration(
              color: (isPositive ? AppColors.primaryGreen : Colors.red)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(
                AppSizes.radius(context, SizeCategory.small),
              ),
            ),
            child: Icon(
              icon,
              color: isPositive ? AppColors.primaryGreen : Colors.red,
              size: AppSizes.icon(context, SizeCategory.medium),
            ),
          ),
          SizedBox(width: AppSizes.padding(context, SizeCategory.medium)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.description,
                  style: TextStyle(
                    fontSize: AppSizes.font(context, SizeCategory.medium),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.getTextPrimaryColor(context),
                  ),
                ),
                SizedBox(
                  height: AppSizes.padding(context, SizeCategory.small) * 0.5,
                ),
                Text(
                  DateFormat('dd/MM/yyyy • HH:mm').format(activity.timestamp),
                  style: TextStyle(
                    fontSize: AppSizes.font(context, SizeCategory.small),
                    color: AppTheme.getTextSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}${activity.points}',
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.large),
              fontWeight: FontWeight.bold,
              color: isPositive ? AppColors.primaryGreen : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String action) {
    switch (action) {
      case 'placeRequestApproved':
        return Icons.add_location;
      case 'reviewPlace':
        return Icons.rate_review;
      case 'createPost':
        return Icons.post_add;
      case 'commentOnPost':
        return Icons.comment;
      case 'likePost':
        return Icons.thumb_up;
      case 'dailyLoginBonus':
        return Icons.login;
      default:
        return Icons.star;
    }
  }

  // Stream để cập nhật realtime điểm hôm nay
  Stream<int> _getTodayPointsStream(String userId) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    return FirebaseFirestore.instance
        .collection('point_history')
        .where('userId', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .snapshots()
        .map((snapshot) {
          int total = 0;
          for (final doc in snapshot.docs) {
            total += (doc.data()['points'] as int?) ?? 0;
          }
          return total;
        });
  }

  // Tab 3: Bảng xếp hạng
  Widget _buildLeaderboardTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _pointsService.getLeaderboard(limit: 50),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Chưa có dữ liệu'));
        }

        final leaderboard = snapshot.data!;
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;

        return ListView.builder(
          padding: EdgeInsets.all(
            AppSizes.padding(context, SizeCategory.medium),
          ),
          itemCount: leaderboard.length,
          itemBuilder: (context, index) {
            final user = leaderboard[index];
            final isCurrentUser = user['userId'] == currentUserId;
            final rank = index + 1;

            return _buildLeaderboardItem(user, rank, isCurrentUser);
          },
        );
      },
    );
  }

  Widget _buildLeaderboardItem(
    Map<String, dynamic> user,
    int rank,
    bool isCurrentUser,
  ) {
    final badgeData = user['currentBadge'];
    final badge =
        badgeData != null
            ? UserBadge.fromMap(badgeData as Map<String, dynamic>)
            : null;

    Color rankColor = AppTheme.getTextSecondaryColor(context);
    if (rank == 1) rankColor = const Color(0xFFFFD700); // Gold
    if (rank == 2) rankColor = const Color(0xFFC0C0C0); // Silver
    if (rank == 3) rankColor = const Color(0xFFCD7F32); // Bronze

    return Container(
      margin: EdgeInsets.only(
        bottom: AppSizes.padding(context, SizeCategory.small),
      ),
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
      decoration: BoxDecoration(
        color:
            isCurrentUser
                ? AppColors.primaryGreen.withOpacity(0.1)
                : AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.small),
        ),
        border: Border.all(
          color:
              isCurrentUser
                  ? AppColors.primaryGreen
                  : AppTheme.getBorderColor(context),
          width: isCurrentUser ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: AppSizes.font(context, SizeCategory.medium),
                  fontWeight: FontWeight.bold,
                  color: rankColor,
                ),
              ),
            ),
          ),
          SizedBox(width: AppSizes.padding(context, SizeCategory.medium)),

          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryGreen.withOpacity(0.2),
            backgroundImage:
                (user['avatarUrl'] != null &&
                        (user['avatarUrl'] as String).isNotEmpty)
                    ? NetworkImage(user['avatarUrl'])
                    : null,
            child:
                (user['avatarUrl'] == null ||
                        (user['avatarUrl'] as String).isEmpty)
                    ? Text(
                      (user['name'] as String)[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    )
                    : null,
          ),
          SizedBox(width: AppSizes.padding(context, SizeCategory.medium)),

          // Name and badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user['name'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: AppSizes.font(context, SizeCategory.medium),
                          fontWeight: FontWeight.w600,
                          color: AppTheme.getTextPrimaryColor(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      SizedBox(
                        width:
                            AppSizes.padding(context, SizeCategory.small) * 0.5,
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.padding(
                            context,
                            SizeCategory.small,
                          ),
                          vertical:
                              AppSizes.padding(context, SizeCategory.small) *
                              0.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radius(context, SizeCategory.small),
                          ),
                        ),
                        child: Text(
                          'Bạn',
                          style: TextStyle(
                            fontSize:
                                AppSizes.font(context, SizeCategory.small) *
                                0.9,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (badge != null)
                  Text(
                    '${badge.icon} ${badge.name}',
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.small),
                      color: AppTheme.getTextSecondaryColor(context),
                    ),
                  ),
              ],
            ),
          ),

          // Points
          Text(
            NumberFormat('#,###').format(user['totalPoints'] ?? 0),
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.large),
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}
