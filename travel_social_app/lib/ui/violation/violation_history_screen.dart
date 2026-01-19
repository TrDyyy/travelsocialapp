import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/violation_request.dart';
import '../../services/violation_request_service.dart';
import '../../utils/constants.dart';

/// Màn hình lịch sử báo cáo vi phạm của người dùng
class ViolationHistoryScreen extends StatefulWidget {
  const ViolationHistoryScreen({super.key});

  @override
  State<ViolationHistoryScreen> createState() => _ViolationHistoryScreenState();
}

class _ViolationHistoryScreenState extends State<ViolationHistoryScreen>
    with SingleTickerProviderStateMixin {
  final ViolationRequestService _service = ViolationRequestService();
  late TabController _tabController;

  String? _currentUserId;
  Map<String, int> _reportCounts = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadReportCounts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReportCounts() async {
    if (_currentUserId != null) {
      final counts = await _service.getReportCountsByStatus(_currentUserId!);
      setState(() {
        _reportCounts = counts;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lịch sử báo cáo vi phạm')),
        body: const Center(
          child: Text('Vui lòng đăng nhập để xem lịch sử báo cáo'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Lịch sử báo cáo vi phạm'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Tất cả', icon: const Icon(Icons.list, size: 20)),
            Tab(
              text:
                  'Chờ xử lý (${_reportCounts[ViolationConstants.statusPending] ?? 0})',
              icon: const Icon(Icons.pending, size: 20),
            ),
            Tab(
              text:
                  'Đã duyệt (${_reportCounts[ViolationConstants.statusApproved] ?? 0})',
              icon: const Icon(Icons.check_circle, size: 20),
            ),
            Tab(
              text:
                  'Từ chối (${_reportCounts[ViolationConstants.statusRejected] ?? 0})',
              icon: const Icon(Icons.cancel, size: 20),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportList(null),
          _buildReportList(ViolationConstants.statusPending),
          _buildReportList(ViolationConstants.statusApproved),
          _buildReportList(ViolationConstants.statusRejected),
        ],
      ),
    );
  }

  Widget _buildReportList(String? status) {
    return StreamBuilder<List<ViolationRequest>>(
      stream:
          status == null
              ? _service.getUserReportsStream(_currentUserId!)
              : _service
                  .getUserReportsStream(_currentUserId!)
                  .map(
                    (reports) =>
                        reports.where((r) => r.status == status).toList(),
                  ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text('Lỗi: ${snapshot.error}'),
              ],
            ),
          );
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return _buildEmptyState(status);
        }

        return RefreshIndicator(
          onRefresh: () async {
            await _loadReportCounts();
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              return _buildReportCard(reports[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String? status) {
    String message;
    IconData icon;

    switch (status) {
      case ViolationConstants.statusPending:
        message = 'Không có báo cáo đang chờ xử lý';
        icon = Icons.pending_outlined;
        break;
      case ViolationConstants.statusApproved:
        message = 'Chưa có báo cáo nào được duyệt';
        icon = Icons.check_circle_outline;
        break;
      case ViolationConstants.statusRejected:
        message = 'Chưa có báo cáo nào bị từ chối';
        icon = Icons.cancel_outlined;
        break;
      default:
        message = 'Bạn chưa gửi báo cáo vi phạm nào';
        icon = Icons.inbox_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: AppTheme.getTextSecondaryColor(context)),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.getTextSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(ViolationRequest report) {
    final statusColor = ViolationConstants.getStatusColor(report.status);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showReportDetails(report),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Object type + Status
              Row(
                children: [
                  _buildObjectTypeChip(report.objectType),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: Text(
                      ViolationConstants.getStatusLabel(report.status),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Violation type
              Row(
                children: [
                  const Icon(Icons.flag, size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ViolationConstants.getViolationTypeLabel(
                        report.violationType,
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Preview nội dung vi phạm
              if (report.violatedObjectPreview != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.getInputBackgroundColor(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    report.violatedObjectPreview!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.getTextSecondaryColor(context),
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(height: 8),

              // Reason
              if (report.violationReason.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Lý do: ${report.violationReason}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.getTextSecondaryColor(context),
                      fontSize: 13,
                    ),
                  ),
                ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Footer: Date + Actions
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: AppTheme.getTextSecondaryColor(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(report.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.getTextSecondaryColor(context),
                    ),
                  ),
                  const Spacer(),
                  if (report.status == ViolationConstants.statusPending)
                    TextButton.icon(
                      onPressed: () => _confirmDelete(report),
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('Xóa'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                    ),
                ],
              ),

              // Review note từ admin
              if (report.reviewNote != null && report.reviewNote!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings,
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Phản hồi từ Admin:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        report.reviewNote!,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.getTextPrimaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildObjectTypeChip(ViolatedObjectType type) {
    IconData icon;
    Color color;

    switch (type) {
      case ViolatedObjectType.place:
        icon = Icons.place;
        color = Colors.blue;
        break;
      case ViolatedObjectType.post:
        icon = Icons.article;
        color = Colors.purple;
        break;
      case ViolatedObjectType.comment:
        icon = Icons.comment;
        color = Colors.orange;
        break;
      case ViolatedObjectType.review:
        icon = Icons.star;
        color = Colors.amber;
        break;
      case ViolatedObjectType.user:
        icon = Icons.person;
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            type.displayName,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDetails(ViolationRequest report) {
    showDialog(
      context: context,
      builder: (context) => _ReportDetailsDialog(report: report),
    );
  }

  void _confirmDelete(ViolationRequest report) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xóa báo cáo?'),
            content: const Text(
              'Bạn có chắc muốn xóa báo cáo này? Hành động này không thể hoàn tác.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final success = await _service.deleteReport(
                    report.requestId!,
                    _currentUserId!,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success ? 'Đã xóa báo cáo' : 'Không thể xóa báo cáo',
                        ),
                        backgroundColor:
                            success ? AppColors.success : AppColors.error,
                      ),
                    );

                    if (success) {
                      _loadReportCounts();
                    }
                  }
                },
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Xóa'),
              ),
            ],
          ),
    );
  }
}

/// Dialog hiển thị chi tiết báo cáo
class _ReportDetailsDialog extends StatelessWidget {
  final ViolationRequest report;

  const _ReportDetailsDialog({required this.report});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final statusColor = ViolationConstants.getStatusColor(report.status);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primaryGreen),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Chi tiết báo cáo',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Object type
              _buildDetailRow(
                context,
                'Loại đối tượng',
                report.objectType.displayName,
              ),
              const SizedBox(height: 12),

              // Violation type
              _buildDetailRow(
                context,
                'Loại vi phạm',
                ViolationConstants.getViolationTypeLabel(report.violationType),
              ),
              const SizedBox(height: 12),

              // Status
              _buildDetailRow(
                context,
                'Trạng thái',
                ViolationConstants.getStatusLabel(report.status),
                valueColor: statusColor,
              ),
              const SizedBox(height: 12),

              // Created at
              _buildDetailRow(
                context,
                'Thời gian gửi',
                dateFormat.format(report.createdAt),
              ),

              if (report.reviewedAt != null) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  context,
                  'Thời gian xử lý',
                  dateFormat.format(report.reviewedAt!),
                ),
              ],

              const SizedBox(height: 16),

              // Reason
              Text(
                'Lý do báo cáo:',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.getInputBackgroundColor(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  report.violationReason,
                  style: const TextStyle(fontSize: 14),
                ),
              ),

              // Review note
              if (report.reviewNote != null &&
                  report.reviewNote!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Phản hồi từ Admin:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    report.reviewNote!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.getTextSecondaryColor(context),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.getTextPrimaryColor(context),
              fontWeight: valueColor != null ? FontWeight.bold : null,
            ),
          ),
        ),
      ],
    );
  }
}
