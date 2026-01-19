import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/admin_violation_service.dart';
import '../../../utils/constants.dart';

class ViolationStatisticsPage extends StatefulWidget {
  const ViolationStatisticsPage({super.key});

  @override
  State<ViolationStatisticsPage> createState() =>
      _ViolationStatisticsPageState();
}

class _ViolationStatisticsPageState extends State<ViolationStatisticsPage> {
  final AdminViolationService _violationService = AdminViolationService();

  Map<String, dynamic>? _stats;
  bool _isLoading = false;
  int _violationTypeTouchedIndex = -1;
  int _objectTypeTouchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    try {
      final stats = await _violationService.getViolationStats();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê Vi phạm'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _stats == null
              ? const Center(child: Text('Không có dữ liệu'))
              : RefreshIndicator(
                onRefresh: _loadStats,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOverviewCards(),
                      const SizedBox(height: 24),
                      _buildViolationTypeChart(),
                      const SizedBox(height: 24),
                      _buildObjectTypeChart(),
                      const SizedBox(height: 24),
                      _buildTopViolators(),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildOverviewCards() {
    final pending = _stats!['totalPending'] ?? 0;
    final approved = _stats!['totalApproved'] ?? 0;
    final rejected = _stats!['totalRejected'] ?? 0;
    final total = pending + approved + rejected;

    final isWideScreen = MediaQuery.of(context).size.width > 800;

    if (isWideScreen) {
      return Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Tổng số',
              total,
              Colors.blue,
              Icons.summarize,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'Đang chờ',
              pending,
              Colors.orange,
              Icons.hourglass_empty,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'Đã duyệt',
              approved,
              Colors.green,
              Icons.check_circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'Từ chối',
              rejected,
              Colors.red,
              Icons.cancel,
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          _buildStatCard('Tổng số', total, Colors.blue, Icons.summarize),
          const SizedBox(height: 12),
          _buildStatCard(
            'Đang chờ',
            pending,
            Colors.orange,
            Icons.hourglass_empty,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Đã duyệt',
            approved,
            Colors.green,
            Icons.check_circle,
          ),
          const SizedBox(height: 12),
          _buildStatCard('Từ chối', rejected, Colors.red, Icons.cancel),
        ],
      );
    }
  }

  Widget _buildStatCard(String label, int value, Color color, IconData icon) {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViolationTypeChart() {
    final byType = _stats!['byViolationType'] as Map<String, int>;

    if (byType.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('Chưa có dữ liệu loại vi phạm')),
        ),
      );
    }

    final sections = _buildViolationTypePieChartSections(byType);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phân bố theo Loại Vi phạm',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 400,
              child: Column(
                children: [
                  SizedBox(
                    height: 250,
                    child: PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 60,
                        sectionsSpace: 2,
                        pieTouchData: PieTouchData(
                          touchCallback: (
                            FlTouchEvent event,
                            pieTouchResponse,
                          ) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                _violationTypeTouchedIndex = -1;
                                return;
                              }
                              _violationTypeTouchedIndex =
                                  pieTouchResponse
                                      .touchedSection!
                                      .touchedSectionIndex;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  if (_violationTypeTouchedIndex >= 0) ...[
                    const SizedBox(height: 16),
                    _buildViolationTypeDetail(
                      byType,
                      _violationTypeTouchedIndex,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildViolationTypeLegend(byType),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildViolationTypePieChartSections(
    Map<String, int> byType,
  ) {
    final entries = byType.entries.toList();
    final total = entries.fold(0, (sum, e) => sum + e.value);

    return entries.asMap().entries.map((entry) {
      final index = entry.key;
      final typeEntry = entry.value;
      final isTouched = index == _violationTypeTouchedIndex;
      final radius = isTouched ? 110.0 : 100.0;
      final fontSize = isTouched ? 16.0 : 14.0;

      final percentage = (typeEntry.value / total * 100).toStringAsFixed(1);
      final color = Colors.primaries[index % Colors.primaries.length];

      return PieChartSectionData(
        value: typeEntry.value.toDouble(),
        title: '$percentage%',
        radius: radius,
        color: color,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildViolationTypeDetail(Map<String, int> byType, int index) {
    final entries = byType.entries.toList();
    if (index >= entries.length) return const SizedBox.shrink();

    final entry = entries[index];
    final total = byType.values.fold(0, (sum, v) => sum + v);
    final percentage = (entry.value / total * 100).toStringAsFixed(1);
    final label = ViolationConstants.getViolationTypeLabel(entry.key);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          Text(
            '${entry.value} báo cáo ($percentage%)',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildViolationTypeLegend(Map<String, int> byType) {
    final entries = byType.entries.toList();
    final total = entries.fold(0, (sum, e) => sum + e.value);

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children:
          entries.asMap().entries.map((entry) {
            final index = entry.key;
            final typeEntry = entry.value;
            final percentage = (typeEntry.value / total * 100).toStringAsFixed(
              1,
            );
            final color = Colors.primaries[index % Colors.primaries.length];
            final label = ViolationConstants.getViolationTypeLabel(
              typeEntry.key,
            );

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() => _violationTypeTouchedIndex = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _violationTypeTouchedIndex == index
                            ? color.withOpacity(0.2)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color),
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
                        '$label: ${typeEntry.value} ($percentage%)',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              _violationTypeTouchedIndex == index
                                  ? color
                                  : Colors.black87,
                          fontWeight:
                              _violationTypeTouchedIndex == index
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildObjectTypeChart() {
    final byType = _stats!['byObjectType'] as Map<String, int>;

    if (byType.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('Chưa có dữ liệu loại đối tượng')),
        ),
      );
    }

    final sections = _buildObjectTypePieChartSections(byType);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phân bố theo Loại Đối tượng',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 350,
              child: Column(
                children: [
                  SizedBox(
                    height: 250,
                    child: PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 60,
                        sectionsSpace: 2,
                        pieTouchData: PieTouchData(
                          touchCallback: (
                            FlTouchEvent event,
                            pieTouchResponse,
                          ) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                _objectTypeTouchedIndex = -1;
                                return;
                              }
                              _objectTypeTouchedIndex =
                                  pieTouchResponse
                                      .touchedSection!
                                      .touchedSectionIndex;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  if (_objectTypeTouchedIndex >= 0) ...[
                    const SizedBox(height: 16),
                    _buildObjectTypeDetail(byType, _objectTypeTouchedIndex),
                  ],
                  const SizedBox(height: 16),
                  _buildObjectTypeLegend(byType),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildObjectTypePieChartSections(
    Map<String, int> byType,
  ) {
    final entries = byType.entries.toList();
    final total = entries.fold(0, (sum, e) => sum + e.value);

    return entries.asMap().entries.map((entry) {
      final index = entry.key;
      final typeEntry = entry.value;
      final isTouched = index == _objectTypeTouchedIndex;
      final radius = isTouched ? 110.0 : 100.0;
      final fontSize = isTouched ? 16.0 : 14.0;

      final percentage = (typeEntry.value / total * 100).toStringAsFixed(1);
      final color = Colors.primaries[index % Colors.primaries.length];

      return PieChartSectionData(
        value: typeEntry.value.toDouble(),
        title: '$percentage%',
        radius: radius,
        color: color,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildObjectTypeDetail(Map<String, int> byType, int index) {
    final entries = byType.entries.toList();
    if (index >= entries.length) return const SizedBox.shrink();

    final entry = entries[index];
    final total = byType.values.fold(0, (sum, v) => sum + v);
    final percentage = (entry.value / total * 100).toStringAsFixed(1);
    final label = _getObjectTypeLabel(entry.key);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          Text(
            '${entry.value} báo cáo ($percentage%)',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildObjectTypeLegend(Map<String, int> byType) {
    final entries = byType.entries.toList();
    final total = entries.fold(0, (sum, e) => sum + e.value);

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children:
          entries.asMap().entries.map((entry) {
            final index = entry.key;
            final typeEntry = entry.value;
            final percentage = (typeEntry.value / total * 100).toStringAsFixed(
              1,
            );
            final color = Colors.primaries[index % Colors.primaries.length];
            final label = _getObjectTypeLabel(typeEntry.key);

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() => _objectTypeTouchedIndex = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _objectTypeTouchedIndex == index
                            ? color.withOpacity(0.2)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color),
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
                        '$label: ${typeEntry.value} ($percentage%)',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              _objectTypeTouchedIndex == index
                                  ? color
                                  : Colors.black87,
                          fontWeight:
                              _objectTypeTouchedIndex == index
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildTopViolators() {
    final topViolators = _stats!['topViolators'] as List<dynamic>;

    if (topViolators.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('Chưa có dữ liệu người vi phạm')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top 5 Người dùng bị báo cáo nhiều nhất',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...topViolators.asMap().entries.map((entry) {
              final index = entry.key;
              final violator = entry.value as Map<String, dynamic>;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      index == 0
                          ? Colors.red[50]
                          : index == 1
                          ? Colors.orange[50]
                          : index == 2
                          ? Colors.yellow[50]
                          : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        index == 0
                            ? Colors.red
                            : index == 1
                            ? Colors.orange
                            : index == 2
                            ? Colors.yellow[700]!
                            : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color:
                            index == 0
                                ? Colors.red
                                : index == 1
                                ? Colors.orange
                                : index == 2
                                ? Colors.yellow[700]
                                : Colors.grey[400],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            violator['username'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            violator['email'] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${violator['userId']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${violator['count']} lần',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[900],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getObjectTypeLabel(String type) {
    switch (type) {
      case 'place':
        return '📍 Địa điểm';
      case 'post':
        return '📝 Bài viết';
      case 'comment':
        return '💬 Bình luận';
      case 'review':
        return '⭐ Đánh giá';
      case 'user':
        return '👤 Người dùng';
      default:
        return type;
    }
  }
}
