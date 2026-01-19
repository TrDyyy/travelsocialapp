import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:travel_social_app/utils/constants.dart';

class UserActivityStatsPage extends StatefulWidget {
  const UserActivityStatsPage({Key? key}) : super(key: key);

  @override
  State<UserActivityStatsPage> createState() => _UserActivityStatsPageState();
}

class _UserActivityStatsPageState extends State<UserActivityStatsPage> {
  int _currentPage = 0;
  static const int _rowsPerPage = 10;
  bool _showBarChart = false;
  Map<String, String> _userNames = {};
  bool _isLoading = true;
  Map<String, int> _activityCounts = {};
  List<Map<String, dynamic>> _activityDetails = [];
  int _pieTouchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final snapshot =
        await FirebaseFirestore.instance
            .collection('user_activities')
            .orderBy('timestamp', descending: true)
            .limit(200)
            .get();
    final counts = <String, int>{};
    final details = <Map<String, dynamic>>[];
    final userIds = <String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final type = data['activityType'] ?? 'unknown';
      counts[type] = (counts[type] ?? 0) + 1;
      details.add({
        'userId': data['userId'] ?? '-',
        'activityType': type,
        'placeName': data['metadata']?['placeName'] ?? '',
        'timestamp': data['timestamp'],
        'metadata': data['metadata'],
      });
      if (data['userId'] != null) userIds.add(data['userId']);
    }
    // Lấy tên user cho tất cả userId xuất hiện
    final userNames = <String, String>{};
    for (final userId in userIds) {
      try {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();
        userNames[userId] = userDoc.data()?['name'] ?? userId;
      } catch (_) {
        userNames[userId] = userId;
      }
    }
    setState(() {
      _activityCounts = counts;
      _activityDetails = details;
      _userNames = userNames;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Map tên hành động sang tiếng Việt
    String getActionLabel(String type) {
      switch (type) {
        case 'viewPlace':
          return 'Xem địa điểm';
        case 'reviewPlace':
          return 'Đánh giá địa điểm';
        case 'postWithPlace':
          return 'Đăng bài với địa điểm';
        case 'searchPlace':
          return 'Tìm kiếm địa điểm';
        case 'getDirections':
          return 'Xem chỉ đường';
        case 'savePlace':
          return 'Lưu địa điểm';
        case 'sharePlace':
          return 'Chia sẻ địa điểm';
        case 'commentOnPost':
          return 'Bình luận bài viết';
        case 'likePost':
          return 'Thích bài viết';
        case 'joinGroup':
          return 'Tham gia nhóm';
        case 'clickRecommendation':
          return 'Xem gợi ý';
        default:
          return type;
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.darkTextPrimary,
        title: Text(
          'Thống kê hoạt động người dùng',
          style: TextStyle(
            fontSize: AppSizes.font(context, SizeCategory.large),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              size: AppSizes.icon(context, SizeCategory.large),
            ),
            tooltip: 'Làm mới',
            color: AppColors.darkTextPrimary,
            onPressed: _isLoading ? null : _loadStats,
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              )
              : SingleChildScrollView(
                padding: EdgeInsets.all(
                  AppSizes.padding(context, SizeCategory.large),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Biểu đồ số lượng hoạt động theo loại',
                          style: TextStyle(
                            fontSize: AppSizes.font(
                              context,
                              SizeCategory.large,
                            ),
                            fontWeight: FontWeight.bold,
                            color: AppTheme.getTextPrimaryColor(context),
                          ),
                        ),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              icon: Icon(
                                _showBarChart
                                    ? Icons.pie_chart
                                    : Icons.bar_chart,
                                size: AppSizes.icon(
                                  context,
                                  SizeCategory.medium,
                                ),
                              ),
                              label: Text(
                                _showBarChart ? 'Pie Chart' : 'Bar Chart',
                                style: TextStyle(
                                  fontSize: AppSizes.font(
                                    context,
                                    SizeCategory.medium,
                                  ),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: AppColors.darkTextPrimary,
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppSizes.padding(
                                    context,
                                    SizeCategory.medium,
                                  ),
                                  vertical: AppSizes.padding(
                                    context,
                                    SizeCategory.small,
                                  ),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _showBarChart = !_showBarChart;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(
                      height: AppSizes.padding(context, SizeCategory.large),
                    ),
                    SizedBox(
                      height: 400,
                      child:
                          _activityCounts.isEmpty
                              ? Center(
                                child: Text(
                                  'Không có dữ liệu hoạt động',
                                  style: TextStyle(
                                    color: AppTheme.getTextSecondaryColor(
                                      context,
                                    ),
                                    fontSize: AppSizes.font(
                                      context,
                                      SizeCategory.medium,
                                    ),
                                  ),
                                ),
                              )
                              : _showBarChart
                              ? _buildBarChart(getActionLabel)
                              : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: PieChart(
                                            PieChartData(
                                              sections:
                                                  _activityCounts.entries.map((
                                                    e,
                                                  ) {
                                                    final idx = _activityCounts
                                                        .keys
                                                        .toList()
                                                        .indexOf(e.key);
                                                    final isTouched =
                                                        _pieTouchedIndex == idx;
                                                    return PieChartSectionData(
                                                      value: e.value.toDouble(),
                                                      title: '',
                                                      color:
                                                          Colors.primaries[idx %
                                                              Colors
                                                                  .primaries
                                                                  .length],
                                                      radius:
                                                          isTouched ? 110 : 100,
                                                      titleStyle:
                                                          const TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.white,
                                                          ),
                                                    );
                                                  }).toList(),
                                              sectionsSpace: 3,
                                              centerSpaceRadius: 60,
                                              pieTouchData: PieTouchData(
                                                touchCallback: (
                                                  event,
                                                  response,
                                                ) {
                                                  if (response == null ||
                                                      response.touchedSection ==
                                                          null) {
                                                    setState(() {
                                                      _pieTouchedIndex = -1;
                                                    });
                                                    return;
                                                  }
                                                  setState(() {
                                                    _pieTouchedIndex =
                                                        response
                                                            .touchedSection!
                                                            .touchedSectionIndex;
                                                  });
                                                },
                                              ),
                                            ),
                                            swapAnimationDuration:
                                                const Duration(
                                                  milliseconds: 300,
                                                ),
                                          ),
                                        ),
                                        if (_pieTouchedIndex != -1)
                                          Padding(
                                            padding: EdgeInsets.only(
                                              top: AppSizes.padding(
                                                context,
                                                SizeCategory.medium,
                                              ),
                                            ),
                                            child: Builder(
                                              builder: (context) {
                                                final key =
                                                    _activityCounts.keys
                                                        .toList()[_pieTouchedIndex];
                                                final value =
                                                    _activityCounts[key] ?? 0;
                                                final total = _activityCounts
                                                    .values
                                                    .fold<int>(
                                                      0,
                                                      (a, b) => a + b,
                                                    );
                                                final percent =
                                                    total > 0
                                                        ? (value / total * 100)
                                                            .toStringAsFixed(1)
                                                        : '0';
                                                return Container(
                                                  decoration: BoxDecoration(
                                                    color:
                                                        AppTheme.getSurfaceColor(
                                                          context,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          AppSizes.radius(
                                                            context,
                                                            SizeCategory.medium,
                                                          ),
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black12,
                                                        blurRadius: 4,
                                                      ),
                                                    ],
                                                  ),
                                                  padding: EdgeInsets.all(
                                                    AppSizes.padding(
                                                      context,
                                                      SizeCategory.medium,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    '${getActionLabel(key)}\nSố lượng: $value\nChiếm: $percent%',
                                                    style: TextStyle(
                                                      fontSize: AppSizes.font(
                                                        context,
                                                        SizeCategory.medium,
                                                      ),
                                                      color:
                                                          AppTheme.getTextPrimaryColor(
                                                            context,
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
                                  const SizedBox(width: 24),
                                  Expanded(
                                    flex: 1,
                                    child: StatefulBuilder(
                                      builder: (context, setLegendState) {
                                        int touchedIndex = -1;
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Chú thích:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: AppSizes.font(
                                                  context,
                                                  SizeCategory.medium,
                                                ),
                                                color:
                                                    AppTheme.getTextPrimaryColor(
                                                      context,
                                                    ),
                                              ),
                                            ),
                                            ..._activityCounts.keys.map((key) {
                                              final idx = _activityCounts.keys
                                                  .toList()
                                                  .indexOf(key);
                                              final color =
                                                  Colors.primaries[idx %
                                                      Colors.primaries.length];
                                              final total = _activityCounts
                                                  .values
                                                  .fold<int>(
                                                    0,
                                                    (a, b) => a + b,
                                                  );
                                              final value =
                                                  _activityCounts[key] ?? 0;
                                              final percent =
                                                  total > 0
                                                      ? (value / total * 100)
                                                          .toStringAsFixed(1)
                                                      : '0';
                                              return MouseRegion(
                                                onEnter:
                                                    (_) => setLegendState(() {
                                                      touchedIndex = idx;
                                                    }),
                                                onExit:
                                                    (_) => setLegendState(() {
                                                      touchedIndex = -1;
                                                    }),
                                                child: Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: AppSizes.padding(
                                                      context,
                                                      SizeCategory.small,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: AppSizes.icon(
                                                          context,
                                                          SizeCategory.small,
                                                        ),
                                                        height: AppSizes.icon(
                                                          context,
                                                          SizeCategory.small,
                                                        ),
                                                        color: color,
                                                      ),
                                                      SizedBox(
                                                        width: AppSizes.padding(
                                                          context,
                                                          SizeCategory.small,
                                                        ),
                                                      ),
                                                      Text(
                                                        getActionLabel(key),
                                                        style: TextStyle(
                                                          fontSize:
                                                              AppSizes.font(
                                                                context,
                                                                SizeCategory
                                                                    .medium,
                                                              ),
                                                          color:
                                                              AppTheme.getTextPrimaryColor(
                                                                context,
                                                              ),
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: AppSizes.padding(
                                                          context,
                                                          SizeCategory.small,
                                                        ),
                                                      ),
                                                      Text(
                                                        '($value)',
                                                        style: TextStyle(
                                                          fontSize:
                                                              AppSizes.font(
                                                                context,
                                                                SizeCategory
                                                                    .medium,
                                                              ),
                                                          color:
                                                              AppTheme.getTextSecondaryColor(
                                                                context,
                                                              ),
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: AppSizes.padding(
                                                          context,
                                                          SizeCategory.small,
                                                        ),
                                                      ),
                                                      if (touchedIndex == idx)
                                                        Text(
                                                          'Chiếm $percent%',
                                                          style: TextStyle(
                                                            fontSize:
                                                                AppSizes.font(
                                                                  context,
                                                                  SizeCategory
                                                                      .medium,
                                                                ),
                                                            color:
                                                                AppColors
                                                                    .primaryGreen,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Bảng chi tiết hoạt động gần đây',
                      style: TextStyle(
                        fontSize: AppSizes.font(context, SizeCategory.large),
                        fontWeight: FontWeight.bold,
                        color: AppTheme.getTextPrimaryColor(context),
                      ),
                    ),
                    SizedBox(
                      height: AppSizes.padding(context, SizeCategory.medium),
                    ),
                    SizedBox(
                      height: 400,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final verticalScrollController = ScrollController();
                          final horizontalScrollController = ScrollController();
                          return SizedBox(
                            height: constraints.maxHeight,
                            child: Scrollbar(
                              controller: verticalScrollController,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                controller: verticalScrollController,
                                scrollDirection: Axis.vertical,
                                child: Scrollbar(
                                  controller: horizontalScrollController,
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: horizontalScrollController,
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: constraints.maxWidth,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          DataTable(
                                            columns: const [
                                              DataColumn(
                                                label: Text('Loại hoạt động'),
                                              ),
                                              DataColumn(
                                                label: Text('Người dùng'),
                                              ),
                                              DataColumn(
                                                label: Text('Địa điểm'),
                                              ),
                                              DataColumn(
                                                label: Text('Thời gian'),
                                              ),
                                              DataColumn(
                                                label: Text('Metadata'),
                                              ),
                                            ],
                                            rows:
                                                _activityDetails.skip(_currentPage * _rowsPerPage).take(_rowsPerPage).map((
                                                  act,
                                                ) {
                                                  final ts = act['timestamp'];
                                                  String timeStr = '-';
                                                  if (ts is Timestamp) {
                                                    final date = ts.toDate();
                                                    timeStr =
                                                        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                                                  }
                                                  final userId =
                                                      act['userId'] ?? '-';
                                                  final userName =
                                                      _userNames[userId] ??
                                                      userId;
                                                  final actionLabel =
                                                      getActionLabel(
                                                        act['activityType'] ??
                                                            '-',
                                                      );
                                                  return DataRow(
                                                    cells: [
                                                      DataCell(
                                                        Text(actionLabel),
                                                      ),
                                                      DataCell(Text(userName)),
                                                      DataCell(
                                                        Text(
                                                          act['placeName'] ??
                                                              '-',
                                                        ),
                                                      ),
                                                      DataCell(Text(timeStr)),
                                                      DataCell(
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons
                                                                .remove_red_eye,
                                                            color: Colors.green,
                                                          ),
                                                          tooltip:
                                                              'Xem metadata',
                                                          onPressed: () {
                                                            showDialog(
                                                              context: context,
                                                              builder: (ctx) {
                                                                return AlertDialog(
                                                                  title: const Text(
                                                                    'Metadata',
                                                                  ),
                                                                  content: SingleChildScrollView(
                                                                    child: Text(
                                                                      act['metadata'] !=
                                                                              null
                                                                          ? act['metadata']
                                                                              .toString()
                                                                          : 'Không có dữ liệu',
                                                                    ),
                                                                  ),
                                                                  actions: [
                                                                    TextButton(
                                                                      onPressed:
                                                                          () =>
                                                                              Navigator.of(
                                                                                ctx,
                                                                              ).pop(),
                                                                      child: const Text(
                                                                        'Đóng',
                                                                      ),
                                                                    ),
                                                                  ],
                                                                );
                                                              },
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                }).toList(),
                                          ),
                                          const SizedBox(height: 8),
                                          if (_activityDetails.length >
                                              _rowsPerPage)
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.chevron_left,
                                                  ),
                                                  onPressed:
                                                      _currentPage > 0
                                                          ? () => setState(
                                                            () =>
                                                                _currentPage--,
                                                          )
                                                          : null,
                                                ),
                                                Text(
                                                  'Trang ${_currentPage + 1} / ${(_activityDetails.length / _rowsPerPage).ceil()}',
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.chevron_right,
                                                  ),
                                                  onPressed:
                                                      (_currentPage + 1) *
                                                                  _rowsPerPage <
                                                              _activityDetails
                                                                  .length
                                                          ? () => setState(
                                                            () =>
                                                                _currentPage++,
                                                          )
                                                          : null,
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
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

  Widget _buildBarChart(String Function(String) getActionLabel) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = constraints.maxWidth;
        final calculatedWidth = _activityCounts.length * 100.0;
        final chartWidth =
            calculatedWidth > minWidth ? calculatedWidth : minWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartWidth,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY:
                    _activityCounts.values.isEmpty
                        ? 10
                        : _activityCounts.values
                                .reduce((a, b) => a > b ? a : b)
                                .toDouble() *
                            1.2,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 80,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _activityCounts.keys.length) {
                          final key = _activityCounts.keys.elementAt(index);
                          final label = getActionLabel(key);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: RotatedBox(
                              quarterTurns: 1,
                              child: Text(
                                label,
                                style: const TextStyle(fontSize: 11),
                                textAlign: TextAlign.center,
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
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
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
                borderData: FlBorderData(show: false),
                barGroups:
                    _activityCounts.entries.toList().asMap().entries.map((
                      entry,
                    ) {
                      final idx = entry.key;
                      final color =
                          Colors.primaries[idx % Colors.primaries.length];
                      return BarChartGroupData(
                        x: idx,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value.value.toDouble(),
                            color: color,
                            width: 40,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(6),
                              topRight: Radius.circular(6),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
