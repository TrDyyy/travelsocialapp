import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/admin_service.dart';
import '../../../utils/constants.dart';

/// Trang thống kê với nhiều loại thống kê
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final AdminService _adminService = AdminService();

  // Trạng thái loading
  bool _isLoading = true;

  // Loại thống kê được chọn
  String _selectedStatsType = 'dashboard';

  // Dữ liệu thống kê
  Map<String, dynamic> _userStats = {};
  Map<String, dynamic> _communityStats = {};
  Map<String, dynamic> _postStats = {};
  Map<String, dynamic> _activityStats = {};
  Map<String, dynamic> _placeStats = {};

  // Touch index cho pie charts
  int _pieTouchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadAllStatistics();
  }

  Future<void> _loadAllStatistics() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      debugPrint('📊 Loading statistics...');

      final userStats = await _adminService.getUserDetailedStats();
      debugPrint('👥 User stats: $userStats');

      final communityStats = await _adminService.getCommunityStats();
      debugPrint('🏘️ Community stats: $communityStats');

      final postStats = await _adminService.getPostStats();
      debugPrint('📝 Post stats: $postStats');

      final activityStats = await _adminService.getActivityStats();
      debugPrint('📈 Activity stats: $activityStats');

      final placeStats = await _adminService.getPlaceStats();
      debugPrint('📍 Place stats: $placeStats');

      if (!mounted) return;
      setState(() {
        _userStats = userStats;
        _communityStats = communityStats;
        _postStats = postStats;
        _activityStats = activityStats;
        _placeStats = placeStats;
        _isLoading = false;
      });

      debugPrint('✅ Statistics loaded successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading statistics: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: Column(
        children: [
          _buildHeader(),
          _buildStatsTypeSelector(),
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                      ),
                    )
                    : _buildSelectedStatsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.large)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.getSurfaceColor(context),
            AppColors.primaryGreen.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.primaryGreen,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thống kê hệ thống',
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.xlarge),
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getTextPrimaryColor(context),
                    ),
                  ),
                  Text(
                    'Phân tích và báo cáo tổng quan',
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.small),
                      color: AppTheme.getTextSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGreen.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _loadAllStatistics,
              tooltip: 'Làm mới dữ liệu',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTypeSelector() {
    final types = [
      {'id': 'dashboard', 'name': 'Tổng quan', 'icon': Icons.dashboard_rounded},
      {'id': 'users', 'name': 'Người dùng', 'icon': Icons.people_rounded},
      {'id': 'communities', 'name': 'Cộng đồng', 'icon': Icons.groups_rounded},
      {'id': 'posts', 'name': 'Bài viết', 'icon': Icons.article_rounded},
      {
        'id': 'activities',
        'name': 'Hoạt động',
        'icon': Icons.analytics_rounded,
      },
      {'id': 'places', 'name': 'Địa điểm', 'icon': Icons.place_rounded},
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: AppSizes.padding(context, SizeCategory.medium) * 1.5,
        horizontal: AppSizes.padding(context, SizeCategory.large),
      ),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.getTextSecondaryColor(context).withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              types.map((type) {
                final isSelected = _selectedStatsType == type['id'];
                return Padding(
                  padding: EdgeInsets.only(
                    right: AppSizes.padding(context, SizeCategory.medium),
                  ),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedStatsType = type['id'] as String;
                        _pieTouchedIndex = -1;
                      });
                    },
                    borderRadius: BorderRadius.circular(25),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient:
                            isSelected
                                ? LinearGradient(
                                  colors: [
                                    AppColors.primaryGreen,
                                    AppColors.primaryGreen.withOpacity(0.8),
                                  ],
                                )
                                : null,
                        color:
                            isSelected
                                ? null
                                : AppTheme.getSurfaceColor(context),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color:
                              isSelected
                                  ? AppColors.primaryGreen
                                  : AppTheme.getTextSecondaryColor(
                                    context,
                                  ).withOpacity(0.2),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow:
                            isSelected
                                ? [
                                  BoxShadow(
                                    color: AppColors.primaryGreen.withOpacity(
                                      0.3,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                                : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            type['icon'] as IconData,
                            size: 20,
                            color:
                                isSelected
                                    ? Colors.white
                                    : AppTheme.getTextPrimaryColor(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            type['name'] as String,
                            style: TextStyle(
                              color:
                                  isSelected
                                      ? Colors.white
                                      : AppTheme.getTextPrimaryColor(context),
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildSelectedStatsView() {
    switch (_selectedStatsType) {
      case 'dashboard':
        return _buildDashboardView();
      case 'users':
        return _buildUserStatsView();
      case 'communities':
        return _buildCommunityStatsView();
      case 'posts':
        return _buildPostStatsView();
      case 'activities':
        return _buildActivityStatsView();
      case 'places':
        return _buildPlaceStatsView();
      default:
        return _buildDashboardView();
    }
  }

  // ================ DASHBOARD VIEW ================
  Widget _buildDashboardView() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.large)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tổng quan số liệu',
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.large),
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimaryColor(context),
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.large)),
          _buildDashboardCards(),
        ],
      ),
    );
  }

  Widget _buildDashboardCards() {
    return Column(
      children: [
        // Row 1
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Người dùng',
                _userStats['total']?.toString() ?? '0',
                Icons.people,
                Colors.blue,
              ),
            ),
            SizedBox(width: AppSizes.padding(context, SizeCategory.large)),
            Expanded(
              child: _buildSummaryCard(
                'Cộng đồng',
                _communityStats['total']?.toString() ?? '0',
                Icons.groups,
                Colors.purple,
              ),
            ),
            SizedBox(width: AppSizes.padding(context, SizeCategory.large)),
            Expanded(
              child: _buildSummaryCard(
                'Bài viết',
                _postStats['total']?.toString() ?? '0',
                Icons.article,
                Colors.orange,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSizes.padding(context, SizeCategory.large)),
        // Row 2
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Yêu cầu chờ',
                _activityStats['pendingRequests']?.toString() ?? '0',
                Icons.pending_actions,
                Colors.red,
              ),
            ),
            SizedBox(width: AppSizes.padding(context, SizeCategory.large)),
            Expanded(
              child: _buildSummaryCard(
                'User hoạt động',
                _userStats['active']?.toString() ?? '0',
                Icons.trending_up,
                Colors.green,
              ),
            ),
            SizedBox(width: AppSizes.padding(context, SizeCategory.large)),
            Expanded(
              child: _buildSummaryCard(
                'Tổng thành viên CD',
                _communityStats['totalMembers']?.toString() ?? '0',
                Icons.group_add,
                Colors.teal,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSizes.padding(context, SizeCategory.large)),
        // Row 3
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Tổng reactions',
                _postStats['totalReactions']?.toString() ?? '0',
                Icons.favorite,
                Colors.pink,
              ),
            ),
            SizedBox(width: AppSizes.padding(context, SizeCategory.large)),
            Expanded(
              child: _buildSummaryCard(
                'Reviews',
                _activityStats['totalReviews']?.toString() ?? '0',
                Icons.rate_review,
                Colors.amber,
              ),
            ),
            SizedBox(width: AppSizes.padding(context, SizeCategory.large)),
            Expanded(child: SizedBox()), // Empty space
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Card(
      color: AppTheme.getSurfaceColor(context),
      elevation: 4,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.2), width: 1),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.getSurfaceColor(context),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.getTextSecondaryColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.trending_up,
                    size: 12,
                    color: AppTheme.getTextSecondaryColor(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.getTextSecondaryColor(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ================ USER STATS VIEW ================
  Widget _buildUserStatsView() {
    final byRank = _userStats['byRank'] as Map<String, int>? ?? {};

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.large)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thống kê Người dùng',
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.large),
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimaryColor(context),
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.large)),

          // Summary cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen = constraints.maxWidth > 900;
              if (isWideScreen) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Tổng người dùng',
                        _userStats['total']?.toString() ?? '0',
                        Icons.people,
                        Colors.blue,
                      ),
                    ),
                    SizedBox(
                      width: AppSizes.padding(context, SizeCategory.large),
                    ),
                    Expanded(
                      child: _buildSummaryCard(
                        'User hoạt động',
                        _userStats['active']?.toString() ?? '0',
                        Icons.trending_up,
                        Colors.green,
                        subtitle: '30 ngày qua',
                      ),
                    ),
                    SizedBox(
                      width: AppSizes.padding(context, SizeCategory.large),
                    ),
                    Expanded(
                      child: _buildSummaryCard(
                        'User mới',
                        _userStats['newThisMonth']?.toString() ?? '0',
                        Icons.person_add,
                        Colors.orange,
                        subtitle: 'Tháng này',
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildSummaryCard(
                      'Tổng người dùng',
                      _userStats['total']?.toString() ?? '0',
                      Icons.people,
                      Colors.blue,
                    ),
                    SizedBox(
                      height: AppSizes.padding(context, SizeCategory.large),
                    ),
                    _buildSummaryCard(
                      'User hoạt động',
                      _userStats['active']?.toString() ?? '0',
                      Icons.trending_up,
                      Colors.green,
                      subtitle: '30 ngày qua',
                    ),
                    SizedBox(
                      height: AppSizes.padding(context, SizeCategory.large),
                    ),
                    _buildSummaryCard(
                      'User mới',
                      _userStats['newThisMonth']?.toString() ?? '0',
                      Icons.person_add,
                      Colors.orange,
                      subtitle: 'Tháng này',
                    ),
                  ],
                );
              }
            },
          ),

          SizedBox(height: AppSizes.padding(context, SizeCategory.xlarge)),

          // Biểu đồ phân bổ theo hạng
          if (byRank.isNotEmpty) ...[
            Text(
              'Phân bổ theo Hạng',
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.large),
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimaryColor(context),
              ),
            ),
            SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
            _buildUserRankChart(byRank),
          ],
        ],
      ),
    );
  }

  Widget _buildUserRankChart(Map<String, int> byRank) {
    return Card(
      color: AppTheme.getSurfaceColor(context),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.large),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.large)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWideScreen = constraints.maxWidth > 800;

            if (isWideScreen) {
              // Hiển thị ngang: Pie chart + Legend + Table
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pie chart
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Text(
                          'Biểu đồ tròn',
                          style: TextStyle(
                            fontSize: AppSizes.font(
                              context,
                              SizeCategory.medium,
                            ),
                            fontWeight: FontWeight.bold,
                            color: AppTheme.getTextPrimaryColor(context),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(height: 350, child: _buildPieChart(byRank)),
                        const SizedBox(height: 16),
                        _buildChartLegend(byRank),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: AppSizes.padding(context, SizeCategory.large),
                  ),
                  // Table
                  Expanded(flex: 1, child: _buildStatsTable(byRank)),
                ],
              );
            } else {
              // Hiển thị dọc
              return Column(
                children: [
                  Text(
                    'Biểu đồ tròn',
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.medium),
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getTextPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(height: 350, child: _buildPieChart(byRank)),
                  const SizedBox(height: 16),
                  _buildChartLegend(byRank),
                  SizedBox(
                    height: AppSizes.padding(context, SizeCategory.large),
                  ),
                  _buildStatsTable(byRank),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildChartLegend(Map<String, int> data) {
    final total = data.values.fold<int>(0, (a, b) => a + b);

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children:
          data.entries.toList().asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final color = Colors.primaries[idx % Colors.primaries.length];
            final percent = total > 0 ? (item.value / total * 100) : 0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.key,
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.small),
                      fontWeight: FontWeight.w500,
                      color: AppTheme.getTextPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${item.value} - ${percent.toStringAsFixed(1)}%)',
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.small),
                      color: AppTheme.getTextSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildPieChart(Map<String, int> data) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 64,
              color: AppTheme.getTextSecondaryColor(context).withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Không có dữ liệu',
              style: TextStyle(
                color: AppTheme.getTextSecondaryColor(context),
                fontSize: AppSizes.font(context, SizeCategory.medium),
              ),
            ),
          ],
        ),
      );
    }

    final total = data.values.fold<int>(0, (a, b) => a + b);

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sections: _buildPieChartSections(data),
            sectionsSpace: 2,
            centerSpaceRadius: 80,
            pieTouchData: PieTouchData(
              touchCallback: (event, response) {
                if (response == null || response.touchedSection == null) {
                  setState(() => _pieTouchedIndex = -1);
                  return;
                }
                setState(() {
                  _pieTouchedIndex =
                      response.touchedSection!.touchedSectionIndex;
                });
              },
            ),
          ),
          duration: const Duration(milliseconds: 300),
        ),
        // Center text showing total
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              total.toString(),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimaryColor(context),
              ),
            ),
            Text(
              'Tổng số',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.getTextSecondaryColor(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildPieChartSections(Map<String, int> data) {
    final total = data.values.fold<int>(0, (a, b) => a + b);

    return data.entries.toList().asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;
      final isTouched = _pieTouchedIndex == idx;
      final color = Colors.primaries[idx % Colors.primaries.length];
      final percent = total > 0 ? (item.value / total * 100) : 0;

      return PieChartSectionData(
        color: color,
        value: item.value.toDouble(),
        title: isTouched ? '${percent.toStringAsFixed(1)}%' : '',
        radius: isTouched ? 130 : 110,
        titleStyle: TextStyle(
          fontSize: isTouched ? 18 : 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [const Shadow(color: Colors.black45, blurRadius: 4)],
        ),
        badgeWidget:
            isTouched
                ? Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    item.value.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                )
                : null,
        badgePositionPercentageOffset: 1.3,
      );
    }).toList();
  }

  Widget _buildStatsTable(Map<String, int> data) {
    final total = data.values.fold<int>(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bảng dữ liệu',
          style: TextStyle(
            fontSize: AppSizes.font(context, SizeCategory.medium),
            fontWeight: FontWeight.bold,
            color: AppTheme.getTextPrimaryColor(context),
          ),
        ),
        SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: AppTheme.getTextSecondaryColor(context).withOpacity(0.2),
            ),
            borderRadius: BorderRadius.circular(
              AppSizes.radius(context, SizeCategory.medium),
            ),
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
            },
            border: TableBorder.symmetric(
              inside: BorderSide(
                color: AppTheme.getTextSecondaryColor(context).withOpacity(0.2),
              ),
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(
                      AppSizes.radius(context, SizeCategory.medium),
                    ),
                    topRight: Radius.circular(
                      AppSizes.radius(context, SizeCategory.medium),
                    ),
                  ),
                ),
                children: [
                  _buildTableHeader('Hạng'),
                  _buildTableHeader('Số lượng'),
                  _buildTableHeader('Tỷ lệ'),
                ],
              ),
              ...data.entries.map((entry) {
                final percent = total > 0 ? (entry.value / total * 100) : 0;
                return TableRow(
                  children: [
                    _buildTableCell(entry.key),
                    _buildTableCell(entry.value.toString()),
                    _buildTableCell('${percent.toStringAsFixed(1)}%'),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
      child: Text(
        text,
        style: TextStyle(
          fontSize: AppSizes.font(context, SizeCategory.medium),
          fontWeight: FontWeight.bold,
          color: AppTheme.getTextPrimaryColor(context),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
      child: Text(
        text,
        style: TextStyle(
          fontSize: AppSizes.font(context, SizeCategory.small),
          color: AppTheme.getTextPrimaryColor(context),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ================ COMMUNITY STATS VIEW ================
  Widget _buildCommunityStatsView() {
    final byMonth = _communityStats['byMonth'] as Map<String, int>? ?? {};

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.large)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thống kê Cộng đồng',
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.large),
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimaryColor(context),
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.large)),

          // Summary cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen = constraints.maxWidth > 900;
              if (isWideScreen) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Tổng cộng đồng',
                        _communityStats['total']?.toString() ?? '0',
                        Icons.groups,
                        Colors.purple,
                      ),
                    ),
                    SizedBox(
                      width: AppSizes.padding(context, SizeCategory.large),
                    ),
                    Expanded(
                      child: _buildSummaryCard(
                        'CD mới',
                        _communityStats['newThisMonth']?.toString() ?? '0',
                        Icons.fiber_new,
                        Colors.orange,
                        subtitle: 'Tháng này',
                      ),
                    ),
                    SizedBox(
                      width: AppSizes.padding(context, SizeCategory.large),
                    ),
                    Expanded(
                      child: _buildSummaryCard(
                        'Tổng thành viên',
                        _communityStats['totalMembers']?.toString() ?? '0',
                        Icons.group_add,
                        Colors.teal,
                        subtitle:
                            'TB: ${(_communityStats['avgMembers'] ?? 0).toStringAsFixed(1)}/CD',
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildSummaryCard(
                      'Tổng cộng đồng',
                      _communityStats['total']?.toString() ?? '0',
                      Icons.groups,
                      Colors.purple,
                    ),
                    SizedBox(
                      height: AppSizes.padding(context, SizeCategory.large),
                    ),
                    _buildSummaryCard(
                      'CD mới',
                      _communityStats['newThisMonth']?.toString() ?? '0',
                      Icons.fiber_new,
                      Colors.orange,
                      subtitle: 'Tháng này',
                    ),
                    SizedBox(
                      height: AppSizes.padding(context, SizeCategory.large),
                    ),
                    _buildSummaryCard(
                      'Tổng thành viên',
                      _communityStats['totalMembers']?.toString() ?? '0',
                      Icons.group_add,
                      Colors.teal,
                      subtitle:
                          'TB: ${(_communityStats['avgMembers'] ?? 0).toStringAsFixed(1)}/CD',
                    ),
                  ],
                );
              }
            },
          ),

          SizedBox(height: AppSizes.padding(context, SizeCategory.xlarge)),

          // Biểu đồ xu hướng
          if (byMonth.isNotEmpty) ...[
            Text(
              'Xu hướng tạo Cộng đồng (6 tháng gần nhất)',
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.large),
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimaryColor(context),
              ),
            ),
            SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
            _buildLineChartCard(byMonth, 'Số cộng đồng mới'),
          ],
        ],
      ),
    );
  }

  // ================ POST STATS VIEW ================
  Widget _buildPostStatsView() {
    final byWeek = _postStats['byWeek'] as Map<String, int>? ?? {};

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.large)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thống kê Bài viết',
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.large),
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimaryColor(context),
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.large)),

          // Summary cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen = constraints.maxWidth > 900;
              if (isWideScreen) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Tổng bài viết',
                        _postStats['total']?.toString() ?? '0',
                        Icons.article,
                        Colors.blue,
                      ),
                    ),
                    SizedBox(
                      width: AppSizes.padding(context, SizeCategory.large),
                    ),
                    Expanded(
                      child: _buildSummaryCard(
                        'Bài viết mới',
                        _postStats['newThisMonth']?.toString() ?? '0',
                        Icons.fiber_new,
                        Colors.orange,
                        subtitle: 'Tháng này',
                      ),
                    ),
                    SizedBox(
                      width: AppSizes.padding(context, SizeCategory.large),
                    ),
                    Expanded(
                      child: _buildSummaryCard(
                        'Tổng reactions',
                        _postStats['totalReactions']?.toString() ?? '0',
                        Icons.favorite,
                        Colors.pink,
                        subtitle:
                            'TB: ${(_postStats['avgReactions'] ?? 0).toStringAsFixed(1)}/bài',
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildSummaryCard(
                      'Tổng bài viết',
                      _postStats['total']?.toString() ?? '0',
                      Icons.article,
                      Colors.blue,
                    ),
                    SizedBox(
                      height: AppSizes.padding(context, SizeCategory.large),
                    ),
                    _buildSummaryCard(
                      'Bài viết mới',
                      _postStats['newThisMonth']?.toString() ?? '0',
                      Icons.fiber_new,
                      Colors.orange,
                      subtitle: 'Tháng này',
                    ),
                    SizedBox(
                      height: AppSizes.padding(context, SizeCategory.large),
                    ),
                    _buildSummaryCard(
                      'Tổng reactions',
                      _postStats['totalReactions']?.toString() ?? '0',
                      Icons.favorite,
                      Colors.pink,
                      subtitle:
                          'TB: ${(_postStats['avgReactions'] ?? 0).toStringAsFixed(1)}/bài',
                    ),
                  ],
                );
              }
            },
          ),

          SizedBox(height: AppSizes.padding(context, SizeCategory.xlarge)),

          // Biểu đồ xu hướng
          if (byWeek.isNotEmpty) ...[
            Text(
              'Xu hướng đăng Bài viết (6 tuần gần nhất)',
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.large),
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimaryColor(context),
              ),
            ),
            SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
            _buildLineChartCard(byWeek, 'Số bài viết mới'),
          ],
        ],
      ),
    );
  }

  // ================ ACTIVITY STATS VIEW ================
  Widget _buildActivityStatsView() {
    final requestsByWeek =
        _activityStats['requestsByWeek'] as Map<String, int>? ?? {};

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.large)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thống kê Hoạt động',
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.large),
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimaryColor(context),
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.large)),

          // Summary cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen = constraints.maxWidth > 1200;
              final crossAxisCount = isWideScreen ? 4 : 2;

              final cards = [
                _buildSummaryCard(
                  'Tổng yêu cầu',
                  _activityStats['totalRequests']?.toString() ?? '0',
                  Icons.assignment,
                  Colors.blue,
                  subtitle: '6 tháng qua',
                ),
                _buildSummaryCard(
                  'Chờ duyệt',
                  _activityStats['pendingRequests']?.toString() ?? '0',
                  Icons.pending_actions,
                  Colors.orange,
                  subtitle: 'Cần xử lý',
                ),
                _buildSummaryCard(
                  'Đã duyệt',
                  _activityStats['approvedRequests']?.toString() ?? '0',
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildSummaryCard(
                  'Từ chối',
                  _activityStats['rejectedRequests']?.toString() ?? '0',
                  Icons.cancel,
                  Colors.red,
                ),
                _buildSummaryCard(
                  'Tổng reviews',
                  _activityStats['totalReviews']?.toString() ?? '0',
                  Icons.rate_review,
                  Colors.amber,
                  subtitle: 'Đánh giá địa điểm',
                ),
              ];

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: AppSizes.padding(
                    context,
                    SizeCategory.large,
                  ),
                  mainAxisSpacing: AppSizes.padding(
                    context,
                    SizeCategory.large,
                  ),
                  childAspectRatio: 1.5,
                ),
                itemCount: cards.length,
                itemBuilder: (context, index) => cards[index],
              );
            },
          ),

          SizedBox(height: AppSizes.padding(context, SizeCategory.xlarge)),

          // Biểu đồ xu hướng yêu cầu
          if (requestsByWeek.isNotEmpty) ...[
            Text(
              'Xu hướng Yêu cầu tham gia (6 tuần gần nhất)',
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.large),
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimaryColor(context),
              ),
            ),
            SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
            _buildLineChartCard(requestsByWeek, 'Số yêu cầu'),
          ],
        ],
      ),
    );
  }

  // ================ SHARED COMPONENTS ================
  Widget _buildLineChartCard(Map<String, int> data, String yAxisLabel) {
    if (data.isEmpty) {
      return Card(
        color: AppTheme.getSurfaceColor(context),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.large),
          ),
        ),
        child: Container(
          height: 400,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.show_chart,
                size: 64,
                color: AppTheme.getTextSecondaryColor(context).withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Không có dữ liệu',
                style: TextStyle(
                  color: AppTheme.getTextSecondaryColor(context),
                  fontSize: AppSizes.font(context, SizeCategory.medium),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: AppTheme.getSurfaceColor(context),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.large),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.large)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.trending_up,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Biểu đồ xu hướng',
                        style: TextStyle(
                          fontSize: AppSizes.font(context, SizeCategory.medium),
                          fontWeight: FontWeight.bold,
                          color: AppTheme.getTextPrimaryColor(context),
                        ),
                      ),
                      Text(
                        yAxisLabel,
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
            const SizedBox(height: 20),
            SizedBox(
              height: 350,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final minWidth = constraints.maxWidth;
                  final calculatedWidth = data.length * 80.0;
                  final chartWidth =
                      calculatedWidth > minWidth ? calculatedWidth : minWidth;

                  return ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                      },
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: chartWidth,
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: true,
                              horizontalInterval: 1,
                              verticalInterval: 1,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: AppTheme.getTextSecondaryColor(
                                    context,
                                  ).withOpacity(0.1),
                                  strokeWidth: 1,
                                );
                              },
                              getDrawingVerticalLine: (value) {
                                return FlLine(
                                  color: AppTheme.getTextSecondaryColor(
                                    context,
                                  ).withOpacity(0.1),
                                  strokeWidth: 1,
                                );
                              },
                            ),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index >= 0 &&
                                        index < data.keys.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          data.keys.elementAt(index),
                                          style: TextStyle(
                                            fontSize: AppSizes.font(
                                              context,
                                              SizeCategory.small,
                                            ),
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.getTextPrimaryColor(
                                              context,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 45,
                                  interval: 1,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: TextStyle(
                                        fontSize: AppSizes.font(
                                          context,
                                          SizeCategory.small,
                                        ),
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.getTextPrimaryColor(
                                          context,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(
                                color: AppTheme.getTextSecondaryColor(
                                  context,
                                ).withOpacity(0.2),
                              ),
                            ),
                            lineTouchData: LineTouchData(
                              enabled: true,
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    final monthKey = data.keys.elementAt(
                                      spot.x.toInt(),
                                    );
                                    return LineTooltipItem(
                                      '$monthKey\n${spot.y.toInt()} $yAxisLabel',
                                      TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots:
                                    data.entries
                                        .toList()
                                        .asMap()
                                        .entries
                                        .map(
                                          (entry) => FlSpot(
                                            entry.key.toDouble(),
                                            entry.value.value.toDouble(),
                                          ),
                                        )
                                        .toList(),
                                isCurved: true,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primaryGreen,
                                    AppColors.primaryGreen.withOpacity(0.7),
                                  ],
                                ),
                                barWidth: 4,
                                isStrokeCapRound: true,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (
                                    spot,
                                    percent,
                                    barData,
                                    index,
                                  ) {
                                    return FlDotCirclePainter(
                                      radius: 6,
                                      color: Colors.white,
                                      strokeWidth: 3,
                                      strokeColor: AppColors.primaryGreen,
                                    );
                                  },
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primaryGreen.withOpacity(0.3),
                                      AppColors.primaryGreen.withOpacity(0.05),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                                shadow: Shadow(
                                  color: AppColors.primaryGreen.withOpacity(
                                    0.3,
                                  ),
                                  blurRadius: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================ PLACE STATS VIEW ================
  Widget _buildPlaceStatsView() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.large)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thống kê địa điểm',
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.large),
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimaryColor(context),
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.large)),

          // Summary cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Tổng địa điểm',
                  _placeStats['total']?.toString() ?? '0',
                  Icons.place,
                  Colors.red,
                ),
              ),
              SizedBox(width: AppSizes.padding(context, SizeCategory.large)),
              Expanded(
                child: _buildSummaryCard(
                  'Đánh giá TB',
                  (_placeStats['avgRating'] ?? 0).toStringAsFixed(1),
                  Icons.star,
                  Colors.amber,
                ),
              ),
              SizedBox(width: AppSizes.padding(context, SizeCategory.large)),
              Expanded(
                child: _buildSummaryCard(
                  'Loại hình',
                  (_placeStats['placesByType'] as Map?)?.length.toString() ??
                      '0',
                  Icons.category,
                  Colors.purple,
                ),
              ),
            ],
          ),

          SizedBox(height: AppSizes.padding(context, SizeCategory.xlarge)),

          // Top 3 loại hình
          _buildPlaceTypesSection(),

          SizedBox(height: AppSizes.padding(context, SizeCategory.xlarge)),

          // Top 3 địa điểm rating cao
          _buildTopPlacesSection(),

          SizedBox(height: AppSizes.padding(context, SizeCategory.xlarge)),

          // Thống kê theo tỉnh thành
          _buildPlacesByProvinceSection(),
        ],
      ),
    );
  }

  Widget _buildPlaceTypesSection() {
    final top3Types = _placeStats['top3Types'] as List? ?? [];

    if (top3Types.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.large)),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.category_rounded,
                  color: Colors.purple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Top 3 loại hình phổ biến',
                style: TextStyle(
                  fontSize: AppSizes.font(context, SizeCategory.medium),
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getTextPrimaryColor(context),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.large)),
          ...top3Types.asMap().entries.map((entry) {
            final index = entry.key;
            final type = entry.value;
            final name = type['name'] ?? '';
            final count = type['count'] ?? 0;

            final colors = [Colors.purple, Colors.deepPurple, Colors.indigo];
            final color = colors[index % colors.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: AppSizes.font(
                              context,
                              SizeCategory.small,
                            ),
                            fontWeight: FontWeight.w600,
                            color: AppTheme.getTextPrimaryColor(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            widthFactor: count / (_placeStats['total'] ?? 1),
                            alignment: Alignment.centerLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count địa điểm',
                      style: TextStyle(
                        fontSize: AppSizes.font(context, SizeCategory.small),
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTopPlacesSection() {
    final top3Places = _placeStats['top3Places'] as List? ?? [];

    if (top3Places.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.large)),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.star_rounded, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Top 3 địa điểm đánh giá cao',
                style: TextStyle(
                  fontSize: AppSizes.font(context, SizeCategory.medium),
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getTextPrimaryColor(context),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.large)),
          ...top3Places.asMap().entries.map((entry) {
            final index = entry.key;
            final place = entry.value;
            final name = place['name'] ?? '';
            final rating = (place['rating'] ?? 0).toDouble();
            final reviewCount = place['reviewCount'] ?? 0;
            final address = place['address'] ?? '';

            final medalColors = [Colors.amber, Colors.grey, Colors.brown];
            final medalIcons = [
              Icons.workspace_premium,
              Icons.workspace_premium,
              Icons.workspace_premium,
            ];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: medalColors[index].withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: medalColors[index].withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(medalIcons[index], color: medalColors[index], size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: AppSizes.font(
                              context,
                              SizeCategory.small,
                            ),
                            fontWeight: FontWeight.bold,
                            color: AppTheme.getTextPrimaryColor(context),
                          ),
                        ),
                        if (address.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            address,
                            style: TextStyle(
                              fontSize: AppSizes.font(
                                context,
                                SizeCategory.small,
                              ),
                              color: AppTheme.getTextSecondaryColor(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: AppSizes.font(
                                  context,
                                  SizeCategory.small,
                                ),
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '($reviewCount đánh giá)',
                              style: TextStyle(
                                fontSize: AppSizes.font(
                                  context,
                                  SizeCategory.small,
                                ),
                                color: AppTheme.getTextSecondaryColor(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildPlacesByProvinceSection() {
    final placesByType = _placeStats['placesByType'] as Map? ?? {};

    if (placesByType.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort by count descending
    final sortedTypes =
        placesByType.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.large)),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.category_rounded,
                  color: Colors.deepPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Phân bổ địa điểm theo loại hình du lịch',
                style: TextStyle(
                  fontSize: AppSizes.font(context, SizeCategory.medium),
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getTextPrimaryColor(context),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.large)),

          // Table
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.getTextSecondaryColor(context).withOpacity(0.2),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.05),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          'Loại hình du lịch',
                          style: TextStyle(
                            fontSize: AppSizes.font(
                              context,
                              SizeCategory.medium,
                            ),
                            fontWeight: FontWeight.bold,
                            color: AppTheme.getTextPrimaryColor(context),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Số địa điểm',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: AppSizes.font(
                              context,
                              SizeCategory.medium,
                            ),
                            fontWeight: FontWeight.bold,
                            color: AppTheme.getTextPrimaryColor(context),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '%',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: AppSizes.font(
                              context,
                              SizeCategory.medium,
                            ),
                            fontWeight: FontWeight.bold,
                            color: AppTheme.getTextPrimaryColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Rows
                ...sortedTypes.map((entry) {
                  final typeName = entry.key;
                  final count = entry.value;
                  final percentage = (count / (_placeStats['total'] ?? 1) * 100)
                      .toStringAsFixed(1);

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppTheme.getTextSecondaryColor(
                            context,
                          ).withOpacity(0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color:
                                      Colors.primaries[sortedTypes.indexOf(
                                            entry,
                                          ) %
                                          Colors.primaries.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  typeName,
                                  style: TextStyle(
                                    fontSize: AppSizes.font(
                                      context,
                                      SizeCategory.medium,
                                    ),
                                    color: AppTheme.getTextPrimaryColor(
                                      context,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            count.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: AppSizes.font(
                                context,
                                SizeCategory.medium,
                              ),
                              fontWeight: FontWeight.w600,
                              color: AppTheme.getTextPrimaryColor(context),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            '$percentage%',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: AppSizes.font(
                                context,
                                SizeCategory.medium,
                              ),
                              color: AppTheme.getTextSecondaryColor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
