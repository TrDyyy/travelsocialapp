import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:travel_social_app/ui/admin/helper/admin_services_helper.dart'
    as helper;
import 'package:travel_social_app/ui/auth/splash_screen.dart';
import '../../services/admin_service.dart';
import '../../utils/constants.dart';
import 'widgets/dashboard_stats.dart';
import 'widgets/pending_requests_list.dart';
import 'collections/collections_page.dart';
import 'statistics/statistics_page.dart';
import 'place_requests/place_requests_page.dart';
import 'places/add_place_screen.dart';
import 'posts/posts_management_page.dart';
import 'stats/user_activity_stats_page.dart';
import 'violations/violation_management_page.dart';
import 'violations/violation_statistics_page.dart';

/// Admin Dashboard - Trang quản trị chính
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AdminService _adminService = AdminService();
  bool _isAdmin = false;
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final isAdmin = await _adminService.isAdmin(user.uid);
      setState(() {
        _isAdmin = isAdmin;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isAdmin = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wrap admin dashboard with its own MaterialApp using adminTheme
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.adminTheme,
      // Wrap with ScaffoldMessenger to enable SnackBars
      home: ScaffoldMessenger(
        child: Builder(builder: (context) => _buildScaffold()),
      ),
    );
  }

  Widget _buildScaffold() {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'Truy cập bị từ chối',
            style: TextStyle(color: AppTheme.getTextPrimaryColor(context)),
          ),
          backgroundColor: AppColors.error,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 100, color: AppColors.error),
              SizedBox(height: AppSizes.padding(context, SizeCategory.large)),
              Text(
                'Bạn không có quyền truy cập',
                style: TextStyle(
                  fontSize: AppSizes.font(context, SizeCategory.large),
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getTextPrimaryColor(context),
                ),
              ),
              SizedBox(height: AppSizes.padding(context, SizeCategory.small)),
              Text(
                'Chỉ Admin mới có thể vào trang này',
                style: TextStyle(
                  color: AppTheme.getTextSecondaryColor(context),
                ),
              ),
              SizedBox(height: AppSizes.padding(context, SizeCategory.large)),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.getButtonPrimaryColor(context),
                  foregroundColor: AppColors.darkTextPrimary,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.padding(context, SizeCategory.large),
                    vertical: AppSizes.padding(context, SizeCategory.medium),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSizes.radius(context, SizeCategory.medium),
                    ),
                  ),
                ),
                child: const Text('Quay lại'),
              ),
            ],
          ),
        ),
      );
    }

    // Responsive layout
    final isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Admin Panel',
          style: TextStyle(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: AppColors.darkTextPrimary,
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _checkAdminAccess();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            color: AppColors.darkTextPrimary,
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SplashScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: isWideScreen ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  Widget _buildWideLayout() {
    // Layout cho web/tablet (sidebar + content)
    return Row(
      children: [
        // Sidebar
        Container(width: 250, color: Colors.white, child: _buildSidebarMenu()),
        // Content
        Expanded(child: _buildMainContent()),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    // Layout cho mobile (bottom nav + content)
    return Column(
      children: [Expanded(child: _buildMainContent()), _buildBottomNav()],
    );
  }

  Widget _buildSidebarMenu() {
    return ListView(
      children: [
        DrawerHeader(
          decoration: const BoxDecoration(color: AppColors.primaryGreen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.darkTextPrimary,
                child: Icon(
                  Icons.admin_panel_settings,
                  size: 40,
                  color: AppColors.primaryGreen,
                ),
              ),
              SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
              Text(
                FirebaseAuth.instance.currentUser?.displayName ?? 'Admin',
                style: TextStyle(
                  color: AppColors.darkTextPrimary,
                  fontSize: AppSizes.font(context, SizeCategory.large),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Quản trị viên',
                style: TextStyle(
                  color: AppColors.darkTextPrimary,
                  fontSize: AppSizes.font(context, SizeCategory.medium),
                ),
              ),
            ],
          ),
        ),
        _buildMenuItem(0, Icons.dashboard_rounded, 'Tổng quan'),
        _buildMenuItem(1, Icons.folder_copy_rounded, 'Dữ liệu'),
        _buildMenuItem(2, Icons.analytics_rounded, 'Thống kê'),
        _buildMenuItem(3, Icons.article_rounded, 'Bài viết'),
        _buildMenuItem(4, Icons.report_problem_rounded, 'Báo cáo Vi phạm'),
        _buildMenuItem(5, Icons.timeline_rounded, 'Hoạt động người dùng'),
      ],
    );
  }

  Widget _buildMenuItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primaryGreen : AppColors.darkBackground,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppColors.primaryGreen : AppColors.darkBackground,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: AppSizes.font(context, SizeCategory.medium),
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppColors.primaryGreen,
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primaryGreen,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_rounded),
          label: 'Tổng quan',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.folder_copy_rounded),
          label: 'Dữ liệu',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics_rounded),
          label: 'Thống kê',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.article_rounded),
          label: 'Bài viết',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.report_problem_rounded),
          label: 'Vi phạm',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.timeline_rounded),
          label: 'Hoạt động',
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return const DashboardOverview();
      case 1:
        return const CollectionsPage();
      case 2:
        return const StatisticsPage();
      case 3:
        return const PostsManagementPage();
      case 4:
        return const ViolationManagementPage();
      case 5:
        return const UserActivityStatsPage();
      default:
        return const DashboardOverview();
    }
  }
}

/// Trang tổng quan
class DashboardOverview extends StatefulWidget {
  const DashboardOverview({super.key});

  @override
  State<DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends State<DashboardOverview> {
  // Key để force refresh DashboardStats
  int _refreshKey = 0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gradient background
          Container(
            padding: EdgeInsets.all(
              AppSizes.padding(context, SizeCategory.large),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryGreen.withOpacity(0.1),
                  AppTheme.getSurfaceColor(context),
                ],
              ),
              borderRadius: BorderRadius.circular(
                AppSizes.radius(context, SizeCategory.large),
              ),
              border: Border.all(
                color: AppColors.primaryGreen.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings_rounded,
                            color: AppColors.primaryGreen,
                            size: AppSizes.icon(context, SizeCategory.large),
                          ),
                          SizedBox(
                            width: AppSizes.padding(
                              context,
                              SizeCategory.medium,
                            ),
                          ),
                          Text(
                            'Bảng điều khiển',
                            style: TextStyle(
                              fontSize: AppSizes.font(
                                context,
                                SizeCategory.xlarge,
                              ),
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: AppSizes.padding(context, SizeCategory.small),
                      ),
                      Text(
                        'Quản lý và giám sát hệ thống Travel Social App',
                        style: TextStyle(
                          fontSize: AppSizes.font(context, SizeCategory.medium),
                          color: AppTheme.getTextSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddPlaceScreen(),
                      ),
                    );
                    // Refresh stats if place was added
                    if (result == true && mounted) {
                      setState(() {
                        _refreshKey++;
                      });
                    }
                  },
                  icon: const Icon(Icons.add_location_rounded),
                  label: const Text('Thêm địa điểm'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.darkTextPrimary,
                    elevation: 2,
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSizes.padding(context, SizeCategory.large),
                      vertical: AppSizes.padding(context, SizeCategory.medium),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSizes.radius(context, SizeCategory.medium),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.large)),

          // Stats cards - use key to force refresh
          DashboardStats(key: ValueKey(_refreshKey)),
          SizedBox(height: AppSizes.padding(context, SizeCategory.large)),
          // Quick action cards
          SafeArea(
            child: Text(
              'Hành động nhanh',
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.xxlarge),
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
          LayoutBuilder(
            builder: (context, constraints) {
              // Responsive layout: 4 columns on wide screens, 2x2 on medium, 1 column on narrow
              final isWideScreen = constraints.maxWidth > 1000;
              final isMediumScreen = constraints.maxWidth > 600;

              if (isWideScreen) {
                // 4 cards in a row
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.notifications_rounded,
                        title: 'Thông báo',
                        subtitle: 'Gửi thông báo mới',
                        color: const Color(0xFFFF9800),
                        onTap: () => helper.showAddNotificationDialog(context),
                      ),
                    ),
                    SizedBox(
                      width: AppSizes.padding(context, SizeCategory.medium),
                    ),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.people_rounded,
                        title: 'Quản lý người dùng',
                        subtitle: 'Xem và chỉnh sửa',
                        color: const Color(0xFF2196F3),
                        onTap: () => helper.navigateToUsersManagement(context),
                      ),
                    ),
                    SizedBox(
                      width: AppSizes.padding(context, SizeCategory.medium),
                    ),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.place_rounded,
                        title: 'Địa điểm du lịch',
                        subtitle: 'Quản lý địa điểm',
                        color: const Color(0xFF9C27B0),
                        onTap: () => helper.navigateToPlacesManagement(context),
                      ),
                    ),
                    SizedBox(
                      width: AppSizes.padding(context, SizeCategory.medium),
                    ),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.report_problem_rounded,
                        title: 'Báo cáo Vi phạm',
                        subtitle: 'Xử lý vi phạm',
                        color: const Color(0xFFE91E63),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => const ViolationManagementPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              } else if (isMediumScreen) {
                // 2x2 grid
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.notifications_rounded,
                            title: 'Thông báo',
                            subtitle: 'Gửi thông báo mới',
                            color: const Color(0xFFFF9800),
                            onTap:
                                () => helper.showAddNotificationDialog(context),
                          ),
                        ),
                        SizedBox(
                          width: AppSizes.padding(context, SizeCategory.medium),
                        ),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.people_rounded,
                            title: 'Quản lý người dùng',
                            subtitle: 'Xem và chỉnh sửa',
                            color: const Color(0xFF2196F3),
                            onTap:
                                () => helper.navigateToUsersManagement(context),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: AppSizes.padding(context, SizeCategory.medium),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.place_rounded,
                            title: 'Địa điểm du lịch',
                            subtitle: 'Quản lý địa điểm',
                            color: const Color(0xFF9C27B0),
                            onTap:
                                () =>
                                    helper.navigateToPlacesManagement(context),
                          ),
                        ),
                        SizedBox(
                          width: AppSizes.padding(context, SizeCategory.medium),
                        ),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.report_problem_rounded,
                            title: 'Báo cáo Vi phạm',
                            subtitle: 'Xử lý vi phạm',
                            color: const Color(0xFFE91E63),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          const ViolationManagementPage(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                // Vertical list
                return Column(
                  children: [
                    _QuickActionCard(
                      icon: Icons.notifications_rounded,
                      title: 'Thông báo',
                      subtitle: 'Gửi thông báo mới',
                      color: const Color(0xFFFF9800),
                      onTap: () => helper.showAddNotificationDialog(context),
                    ),
                    SizedBox(
                      height: AppSizes.padding(context, SizeCategory.medium),
                    ),
                    _QuickActionCard(
                      icon: Icons.people_rounded,
                      title: 'Quản lý người dùng',
                      subtitle: 'Xem và chỉnh sửa',
                      color: const Color(0xFF2196F3),
                      onTap: () => helper.navigateToUsersManagement(context),
                    ),
                    SizedBox(
                      height: AppSizes.padding(context, SizeCategory.medium),
                    ),
                    _QuickActionCard(
                      icon: Icons.place_rounded,
                      title: 'Địa điểm du lịch',
                      subtitle: 'Quản lý địa điểm',
                      color: const Color(0xFF9C27B0),
                      onTap: () => helper.navigateToPlacesManagement(context),
                    ),
                    SizedBox(
                      height: AppSizes.padding(context, SizeCategory.medium),
                    ),
                    _QuickActionCard(
                      icon: Icons.report_problem_rounded,
                      title: 'Báo cáo Vi phạm',
                      subtitle: 'Xử lý vi phạm',
                      color: const Color(0xFFE91E63),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => const ViolationManagementPage(),
                          ),
                        );
                      },
                    ),
                  ],
                );
              }
            },
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.large)),
          // Recent requests
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Yêu cầu gần đây',
                style: TextStyle(
                  fontSize: AppSizes.font(context, SizeCategory.large),
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getTextPrimaryColor(context),
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'Xem tất cả →',
                  style: TextStyle(color: AppColors.primaryGreen),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
          const PendingRequestsList(limit: 5),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        AppSizes.radius(context, SizeCategory.large),
      ),
      child: Container(
        padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.large)),
        decoration: BoxDecoration(
          color: AppTheme.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.large),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(
                AppSizes.padding(context, SizeCategory.medium),
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(
                  AppSizes.radius(context, SizeCategory.medium),
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: AppSizes.icon(context, SizeCategory.large),
              ),
            ),
            SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
            Text(
              title,
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.large),
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimaryColor(context),
              ),
            ),
            SizedBox(height: AppSizes.padding(context, SizeCategory.small)),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.medium),
                color: AppTheme.getTextSecondaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
