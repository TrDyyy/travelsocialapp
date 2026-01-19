import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:travel_social_app/ui/admin/helper/admin_services_helper.dart'
    as helper;
import 'dart:async';
import '../../../services/admin_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/toast_helper.dart';

class NotificationsManagementPage extends StatefulWidget {
  const NotificationsManagementPage({super.key});

  @override
  State<NotificationsManagementPage> createState() =>
      _NotificationsManagementPageState();
}

class _NotificationsManagementPageState
    extends State<NotificationsManagementPage> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _notifications = [];
  Map<String, String> _userNames = {};
  bool _isLoading = true;
  String _searchQuery = '';
  StreamSubscription? _notificationsSubscription;

  // Phân trang
  int _currentPage = 0;
  final int _rowsPerPage = 30;
  int _totalCount = 0;
  List<DocumentSnapshot?> _lastDocuments = [
    null,
  ]; // Track last document of each page for next page

  // Sắp xếp
  bool _sortAscending = false; // Mặc định DESC (mới nhất trước)

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    super.dispose();
  }

  /// Setup realtime listener cho notifications
  void _setupRealtimeListener() {
    _notificationsSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .orderBy('createdAt', descending: !_sortAscending)
        .limit(_rowsPerPage)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            _loadNotificationsFromSnapshot(snapshot);
          }
        });
  }

  Future<void> _loadNotificationsFromSnapshot(QuerySnapshot snapshot) async {
    final notifications =
        snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {'id': doc.id, ...data};
        }).toList();

    // Load user names
    final userIds =
        notifications
            .map((n) => n['userId']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .toSet();

    final userNames = <String, String>{..._userNames}; // Giữ lại cache cũ
    for (var userId in userIds) {
      if (!userNames.containsKey(userId)) {
        try {
          final userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .get();
          if (userDoc.exists) {
            final userData = userDoc.data();
            userNames[userId!] =
                userData?['name'] ??
                userData?['displayName'] ??
                userData?['email'] ??
                'Người dùng';
          }
        } catch (e) {
          print('Error loading user $userId: $e');
        }
      }
    }

    if (mounted) {
      setState(() {
        _notifications = notifications;
        _userNames = userNames;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      // Load total count
      final countSnapshot =
          await FirebaseFirestore.instance
              .collection('notifications')
              .count()
              .get();
      _totalCount = countSnapshot.count ?? 0;

      // Load paginated data with sorting
      Query query = FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('createdAt', descending: !_sortAscending);

      // Apply pagination: start after last document of previous page
      if (_currentPage > 0 && _lastDocuments[_currentPage - 1] != null) {
        query = query.startAfterDocument(_lastDocuments[_currentPage - 1]!);
      }

      query = query.limit(_rowsPerPage);

      final snapshot = await query.get();

      // Save last document of current page for next page navigation
      if (snapshot.docs.isNotEmpty) {
        // Ensure we have space in the array
        while (_lastDocuments.length <= _currentPage) {
          _lastDocuments.add(null);
        }
        _lastDocuments[_currentPage] = snapshot.docs.last;
      }

      await _loadNotificationsFromSnapshot(snapshot);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastHelper.showError(context, 'Lỗi tải dữ liệu: $e');
      }
    }
  }

  void _toggleSort() {
    setState(() {
      _sortAscending = !_sortAscending;
      _currentPage = 0; // Reset về trang đầu
      _lastDocuments = [null]; // Reset pagination
    });
    _loadNotifications();
    // Cập nhật realtime listener
    _notificationsSubscription?.cancel();
    _setupRealtimeListener();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      setState(() {
        _currentPage++;
      });
      _loadNotifications();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _loadNotifications();
    }
  }

  int get _totalPages => (_totalCount / _rowsPerPage).ceil();

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_searchQuery.isEmpty) return _notifications;
    return _notifications.where((notification) {
      final title = (notification['title'] ?? '').toString().toLowerCase();
      final content =
          (notification['content'] ?? notification['body'] ?? '')
              .toString()
              .toLowerCase();
      final userId = notification['userId']?.toString() ?? '';
      final userName = (_userNames[userId] ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return title.contains(query) ||
          content.contains(query) ||
          userName.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getSurfaceColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,

        title: Row(
          children: [
            const Text('Quản lý thông báo'),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Tổng: $_totalCount',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        actions: [
          InkWell(
            onTap: showAddDialog,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Chip(
                label: Text(
                  'Gửi thông báo',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
                backgroundColor: AppColors.primaryGreen,
              ),
            ),
          ),

          // Sort button
          IconButton(
            icon: Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            ),
            tooltip: _sortAscending ? 'Cũ nhất trước' : 'Mới nhất trước',
            onPressed: _toggleSort,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm kiếm theo người nhận, tiêu đề, nội dung...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.primaryGreen,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                      ),
                    )
                    : _filteredNotifications.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Không có thông báo nào',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : Column(
                      children: [
                        Expanded(child: _buildDataTable()),
                        _buildPaginationBar(),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Trang ${_currentPage + 1} / $_totalPages',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              Text(
                'Hiển thị ${_currentPage * _rowsPerPage + 1}-${(_currentPage + 1) * _rowsPerPage > _totalCount ? _totalCount : (_currentPage + 1) * _rowsPerPage} / $_totalCount',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 24),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 0 ? _previousPage : null,
                color: AppColors.primaryGreen,
                tooltip: 'Trang trước',
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < _totalPages - 1 ? _nextPage : null,
                color: AppColors.primaryGreen,
                tooltip: 'Trang sau',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Material(
        elevation: 3,
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
              fontSize: 15,
            ),
            columns: const [
              DataColumn2(
                label: Text('Ngày tạo'),
                size: ColumnSize.S,
                fixedWidth: 110,
              ),
              DataColumn2(label: Text('Người nhận'), size: ColumnSize.M),
              DataColumn2(label: Text('Tiêu đề'), size: ColumnSize.L),
              DataColumn2(label: Text('Nội dung'), size: ColumnSize.L),
              DataColumn2(
                label: Text('Hành động'),
                size: ColumnSize.S,
                fixedWidth: 110,
              ),
            ],
            rows:
                _filteredNotifications.asMap().entries.map((entry) {
                  final index = entry.key;
                  final notification = entry.value;
                  final userId = notification['userId']?.toString() ?? '';
                  final userName = _userNames[userId] ?? 'Không rõ';
                  final createdAt = notification['createdAt'];

                  String dateStr = '-';
                  if (createdAt is Timestamp) {
                    final date = createdAt.toDate();
                    dateStr =
                        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                  }

                  return DataRow(
                    color: MaterialStateProperty.resolveWith<Color?>(
                      (states) => index.isEven ? Colors.grey.shade50 : null,
                    ),
                    cells: [
                      DataCell(Text(dateStr)),
                      DataCell(
                        Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(
                        Text(
                          notification['title'] ?? '-',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DataCell(
                        Text(
                          notification['content'] ??
                              notification['body'] ??
                              '-',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility, size: 18),
                              color: AppColors.primaryGreen,
                              tooltip: 'Xem',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _showDetailDialog(notification),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              color: Colors.red,
                              tooltip: 'Xóa',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _confirmDelete(notification),
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

  void showAddDialog() {
    helper.showAddNotificationDialog(context);
    // Reload notifications after dialog closes
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _loadNotifications();
      }
    });
  }

  void _showDetailDialog(Map<String, dynamic> notification) {
    final userId = notification['userId']?.toString() ?? '';
    final userName = _userNames[userId] ?? 'Không rõ';
    final imageUrl = notification['imageUrl']?.toString();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.notifications, color: AppColors.primaryGreen),
                const SizedBox(width: 12),
                const Expanded(child: Text('Chi tiết thông báo')),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Người nhận', userName),
                    _buildDetailRow('ID người nhận', userId),
                    const Divider(),
                    _buildDetailRow('Loại', notification['type'] ?? 'Không rõ'),
                    _buildDetailRow(
                      'Tiêu đề',
                      notification['title'] ?? 'Không có tiêu đề',
                    ),
                    _buildDetailRow(
                      'Nội dung',
                      notification['content'] ??
                          notification['body'] ??
                          'Không có nội dung',
                    ),
                    _buildDetailRow(
                      'Trạng thái',
                      (notification['isRead'] ?? false) ? 'Đã đọc' : 'Chưa đọc',
                    ),
                    if (imageUrl != null && imageUrl.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Hình ảnh',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) => Container(
                                width: double.infinity,
                                height: 150,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.broken_image),
                              ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildDetailRow(
                      'Ngày tạo',
                      notification['createdAt'] is Timestamp
                          ? (notification['createdAt'] as Timestamp)
                              .toDate()
                              .toString()
                              .split('.')[0]
                          : 'N/A',
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bạn có chắc muốn xóa thông báo này?'),
                SizedBox(height: 12),
                Text(
                  '⚠️ Hành động này không thể hoàn tác!',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Save navigator before async gap
                  final navigator = Navigator.of(context);

                  // Close confirmation dialog
                  navigator.pop();

                  if (!mounted) return;

                  // Show a modal loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (_) => const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGreen,
                          ),
                        ),
                  );

                  try {
                    await _adminService.deleteDocument(
                      'notifications',
                      notification['id'],
                    );
                    if (!mounted) return;

                    navigator.pop(); // close loading
                    ToastHelper.showSuccess(
                      context,
                      '✅ Đã xóa thông báo thành công!',
                    );
                    _loadNotifications();
                  } catch (e) {
                    if (!mounted) return;

                    navigator.pop(); // close loading
                    ToastHelper.showError(context, '❌ Lỗi: ${e.toString()}');
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Xóa'),
              ),
            ],
          ),
    );
  }
}
