import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../models/violation_request.dart';
import '../../../services/admin_violation_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/toast_helper.dart';
import 'violation_detail_page.dart';

/// Page hiển thị danh sách tất cả violation requests dạng bảng
/// Chỉ để xem và xóa, không có approve/reject (dùng violation_management_page cho việc đó)
class ViolationRequestsListPage extends StatefulWidget {
  const ViolationRequestsListPage({super.key});

  @override
  State<ViolationRequestsListPage> createState() =>
      _ViolationRequestsListPageState();
}

class _ViolationRequestsListPageState extends State<ViolationRequestsListPage> {
  final AdminViolationService _service = AdminViolationService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  List<ViolationRequest> _requests = [];

  // Cache user info
  final Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);

    try {
      final requests = await _service.getViolationRequests(limit: 1000);

      // Load user data
      await _loadUserData(requests);

      if (!mounted) return;
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ToastHelper.showError(context, 'Lỗi tải dữ liệu: $e');
    }
  }

  Future<void> _loadUserData(List<ViolationRequest> requests) async {
    final userIds = <String>{};

    for (var req in requests) {
      userIds.add(req.reporterId);
      if (req.violatedObjectOwnerId != null) {
        userIds.add(req.violatedObjectOwnerId!);
      }
      if (req.adminId != null) {
        userIds.add(req.adminId!);
      }
    }

    for (var userId in userIds) {
      if (!_userCache.containsKey(userId)) {
        try {
          final userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .get();

          if (userDoc.exists) {
            _userCache[userId] = userDoc.data() ?? {};
          }
        } catch (e) {
          debugPrint('Error loading user $userId: $e');
        }
      }
    }
  }

  String _getUserDisplayName(String? userId) {
    if (userId == null || userId.isEmpty) return '-';

    final userData = _userCache[userId];
    if (userData == null) return userId;

    return userData['name']?.toString() ??
        userData['displayName']?.toString() ??
        userData['fullName']?.toString() ??
        userData['username']?.toString() ??
        userData['email']?.toString() ??
        userId;
  }

  Future<void> _deleteRequest(ViolationRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.getSurfaceColor(context),
            title: Text(
              'Xác nhận xóa',
              style: TextStyle(color: AppTheme.getTextPrimaryColor(context)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bạn có chắc muốn xóa yêu cầu vi phạm này?',
                  style: TextStyle(
                    color: AppTheme.getTextPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Loại: ${request.objectType.displayName}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Vi phạm: ${request.violationType}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Trạng thái: ${request.status}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Hủy',
                  style: TextStyle(
                    color: AppTheme.getTextSecondaryColor(context),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Xóa'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    if (!mounted) return;

    // Save navigator before async
    final navigator = Navigator.of(context);

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          ),
    );

    try {
      await FirebaseFirestore.instance
          .collection('violationRequests')
          .doc(request.requestId)
          .delete();

      navigator.pop(); // close loading

      if (!mounted) return;
      ToastHelper.showSuccess(context, '✅ Đã xóa yêu cầu vi phạm');
      _loadRequests(); // reload
    } catch (e) {
      navigator.pop(); // close loading

      if (!mounted) return;
      ToastHelper.showError(context, '❌ Lỗi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredRequests =
        _requests.where((req) {
          if (_searchQuery.isEmpty) return true;
          final searchLower = _searchQuery.toLowerCase();

          return req.violationType.toLowerCase().contains(searchLower) ||
              req.violationReason.toLowerCase().contains(searchLower) ||
              req.objectType.displayName.toLowerCase().contains(searchLower) ||
              req.status.toLowerCase().contains(searchLower) ||
              _getUserDisplayName(
                req.reporterId,
              ).toLowerCase().contains(searchLower);
        }).toList();

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Danh sách yêu cầu vi phạm'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRequests),
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
              style: TextStyle(color: AppTheme.getTextPrimaryColor(context)),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm...',
                hintStyle: TextStyle(
                  color: AppTheme.getTextSecondaryColor(context),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppTheme.getIconSecondaryColor(context),
                ),
                filled: true,
                fillColor: AppTheme.getInputBackgroundColor(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppSizes.radius(context, SizeCategory.medium),
                  ),
                  borderSide: BorderSide(
                    color: AppTheme.getInputBorderColor(context),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppSizes.radius(context, SizeCategory.medium),
                  ),
                  borderSide: BorderSide(
                    color: AppTheme.getInputBorderColor(context),
                  ),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Data table
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                      ),
                    )
                    : filteredRequests.isEmpty
                    ? Center(
                      child: Text(
                        'Không có dữ liệu',
                        style: TextStyle(
                          color: AppTheme.getTextSecondaryColor(context),
                        ),
                      ),
                    )
                    : _buildDataTable(filteredRequests),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(List<ViolationRequest> requests) {
    return Padding(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.small)),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: DataTable2(
            columnSpacing: 12,
            horizontalMargin: 12,
            minWidth: 1200,
            headingRowColor: MaterialStateProperty.all(
              AppColors.primaryGreen.withOpacity(0.2),
            ),
            headingTextStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontSize: 14,
            ),
            dataTextStyle: TextStyle(
              fontSize: 13,
              color: AppTheme.getTextPrimaryColor(context),
            ),
            columns: const [
              DataColumn2(label: Text('Trạng thái'), size: ColumnSize.S),
              DataColumn2(label: Text('Loại đối tượng'), size: ColumnSize.M),
              DataColumn2(label: Text('Loại vi phạm'), size: ColumnSize.M),
              DataColumn2(label: Text('Người báo cáo'), size: ColumnSize.M),
              DataColumn2(label: Text('Lý do'), size: ColumnSize.L),
              DataColumn2(label: Text('Ngày tạo'), size: ColumnSize.M),
              DataColumn2(label: Text('Ngày xét duyệt'), size: ColumnSize.M),
              DataColumn2(label: Text('Admin'), size: ColumnSize.M),
              DataColumn2(
                label: Text('Hành động'),
                size: ColumnSize.S,
                fixedWidth: 120,
              ),
            ],
            rows:
                requests.asMap().entries.map((entry) {
                  final index = entry.key;
                  final request = entry.value;

                  return DataRow2(
                    color: MaterialStateProperty.resolveWith((states) {
                      if (states.contains(MaterialState.hovered)) {
                        return AppColors.primaryGreen.withOpacity(0.06);
                      }
                      return index.isEven
                          ? AppTheme.getBackgroundColor(context)
                          : AppTheme.getSurfaceColor(context);
                    }),
                    cells: [
                      // Status chip
                      DataCell(
                        _buildStatusChip(request.status),
                        onTap: () => _viewDetail(request),
                      ),

                      // Object type
                      DataCell(
                        Text(request.objectType.displayName),
                        onTap: () => _viewDetail(request),
                      ),

                      // Violation type
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            request.violationType,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        onTap: () => _viewDetail(request),
                      ),

                      // Reporter
                      DataCell(
                        Text(_getUserDisplayName(request.reporterId)),
                        onTap: () => _viewDetail(request),
                      ),

                      // Reason (truncated)
                      DataCell(
                        SizedBox(
                          width: 250,
                          child: Text(
                            request.violationReason,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        onTap: () => _viewDetail(request),
                      ),

                      // Created at
                      DataCell(
                        Text(_formatDate(request.createdAt)),
                        onTap: () => _viewDetail(request),
                      ),

                      // Reviewed at
                      DataCell(
                        Text(
                          request.reviewedAt != null
                              ? _formatDate(request.reviewedAt!)
                              : '-',
                        ),
                        onTap: () => _viewDetail(request),
                      ),

                      // Admin
                      DataCell(
                        Text(
                          request.adminId != null
                              ? _getUserDisplayName(request.adminId)
                              : '-',
                        ),
                        onTap: () => _viewDetail(request),
                      ),

                      // Actions
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility, size: 18),
                              color: AppColors.primaryGreen,
                              onPressed: () => _viewDetail(request),
                              tooltip: 'Xem',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              color: Colors.red,
                              onPressed: () => _deleteRequest(request),
                              tooltip: 'Xóa',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    String displayText;

    switch (status) {
      case 'pending':
        bg = Colors.orange;
        displayText = 'Chờ xử lý';
        break;
      case 'approved':
        bg = Colors.green;
        displayText = 'Đã duyệt';
        break;
      case 'rejected':
        bg = Colors.red;
        displayText = 'Từ chối';
        break;
      default:
        bg = Colors.grey;
        displayText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bg.withOpacity(0.5)),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _viewDetail(ViolationRequest request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViolationDetailPage(request: request),
      ),
    ).then((result) {
      // Reload if something changed
      if (result == true) {
        _loadRequests();
      }
    });
  }
}
