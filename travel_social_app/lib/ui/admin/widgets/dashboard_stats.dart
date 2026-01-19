import 'package:flutter/material.dart';
import '../../../services/admin_service.dart';
import '../../../utils/constants.dart';
import '../users/user_violations_page.dart';

/// Widget hiển thị thống kê tổng quan
class DashboardStats extends StatefulWidget {
  const DashboardStats({super.key});

  @override
  State<DashboardStats> createState() => _DashboardStatsState();
}

class _DashboardStatsState extends State<DashboardStats> {
  final AdminService _adminService = AdminService();
  Map<String, int> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _adminService.getDashboardStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isWideScreen = MediaQuery.of(context).size.width > 800;
    final crossAxisCount = isWideScreen ? 4 : 2;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSizes.padding(context, SizeCategory.medium),
      crossAxisSpacing: AppSizes.padding(context, SizeCategory.medium),
      childAspectRatio: 1.2,
      children: [
        _buildStatCard(
          'Người dùng',
          _stats['users'] ?? 0,
          Icons.people,
          Colors.blue,
        ),
        _buildStatCard(
          'Địa điểm',
          _stats['places'] ?? 0,
          Icons.place,
          Colors.green,
        ),
        _buildStatCard(
          'Bài viết',
          _stats['posts'] ?? 0,
          Icons.public,
          Colors.orange,
        ),
        _buildStatCard(
          'Đề xuất địa điểm',
          _stats['placeEditRequests'] ?? 0,
          Icons.edit_location,
          Colors.amber,
        ),
        _buildStatCard(
          'User bị cấm',
          _stats['bannedUsers'] ?? 0,
          Icons.block,
          Colors.red,
          onTap: () => _navigateToUserViolations('banned'),
        ),
        _buildStatCard(
          'User có cảnh báo',
          _stats['usersWithWarnings'] ?? 0,
          Icons.warning,
          Colors.deepOrange,
          onTap: () => _navigateToUserViolations('warning'),
        ),
      ],
    );
  }

  void _navigateToUserViolations(String filterType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserViolationsPage(filterType: filterType),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    int count,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    final card = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.getSurfaceColor(context), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.large),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(
              AppSizes.padding(context, SizeCategory.medium),
            ),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: AppSizes.icon(context, SizeCategory.xlarge),
              color: color,
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.xxlarge),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.small)),
          Text(
            title,
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.medium),
              color: AppTheme.getTextSecondaryColor(context),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.large),
        ),
        child: card,
      );
    }

    return card;
  }
}
