import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../services/admin_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/toast_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Trang quản lý Friendships (Quan hệ bạn bè)
class FriendshipsManagementPage extends StatefulWidget {
  const FriendshipsManagementPage({super.key});

  @override
  State<FriendshipsManagementPage> createState() =>
      _FriendshipsManagementPageState();
}

class _FriendshipsManagementPageState extends State<FriendshipsManagementPage> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _friendships = [];
  Map<String, String> _userNames = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFriendships();
  }

  Future<void> _loadFriendships() async {
    setState(() => _isLoading = true);
    try {
      final friendships = await _adminService.getCollectionData(
        'friendships',
        limit: 200,
      );

      // Load user names
      final userIds = <String>{};
      for (var friendship in friendships) {
        if (friendship['userId1'] != null) userIds.add(friendship['userId1']);
        if (friendship['userId2'] != null) userIds.add(friendship['userId2']);
      }

      final userNames = <String, String>{};
      for (var userId in userIds) {
        try {
          final userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .get();
          if (userDoc.exists) {
            final userData = userDoc.data();
            userNames[userId] =
                userData?['name'] ?? userData?['email'] ?? 'Không rõ';
          }
        } catch (e) {
          print('Error loading user $userId: $e');
        }
      }

      setState(() {
        _friendships = friendships;
        _userNames = userNames;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastHelper.showError(context, 'Lỗi tải dữ liệu: $e');
      }
    }
  }

  List<Map<String, dynamic>> get _filteredFriendships {
    if (_searchQuery.isEmpty) return _friendships;
    return _friendships.where((friendship) {
      final userId1 = (friendship['userId1'] ?? '').toString().toLowerCase();
      final userId2 = (friendship['userId2'] ?? '').toString().toLowerCase();
      final status = (friendship['status'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return userId1.contains(query) ||
          userId2.contains(query) ||
          status.contains(query);
    }).toList();
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'pending':
        return 'Chờ chấp nhận';
      case 'accepted':
        return 'Đã chấp nhận';
      case 'rejected':
        return 'Đã từ chối';
      case 'blocked':
        return 'Đã chặn';
      default:
        return status ?? '-';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'blocked':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text(
          'Quản lý Quan hệ Bạn bè',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFriendships,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
        child: Column(
          children: [
            _buildSearchBar(),
            SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
            Expanded(
              child:
                  _isLoading
                      ? Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryGreen,
                        ),
                      )
                      : _buildFriendshipsTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Tìm kiếm theo người dùng, trạng thái...',
        prefixIcon: Icon(Icons.search, color: AppColors.primaryGreen),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        filled: true,
        fillColor: AppTheme.getSurfaceColor(context),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  Widget _buildFriendshipsTable() {
    if (_filteredFriendships.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Không có mối quan hệ nào',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Container(
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
              AppColors.primaryGreen.withOpacity(0.35),
            ),
            headingTextStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.black,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
            dataTextStyle: const TextStyle(fontSize: 15, color: Colors.black87),
            columns: const [
              DataColumn2(label: Text('Người dùng 1'), size: ColumnSize.L),
              DataColumn2(label: Text('Người dùng 2'), size: ColumnSize.L),
              DataColumn2(
                label: Text('Trạng thái'),
                size: ColumnSize.S,
                fixedWidth: 150,
              ),
              DataColumn2(
                label: Text('Ngày tạo'),
                size: ColumnSize.M,
                fixedWidth: 150,
              ),
              DataColumn2(
                label: Text('Cập nhật'),
                size: ColumnSize.M,
                fixedWidth: 150,
              ),
              DataColumn2(
                label: Text('Hành động'),
                size: ColumnSize.S,
                fixedWidth: 140,
              ),
            ],
            rows:
                _filteredFriendships.asMap().entries.map((entry) {
                  final index = entry.key;
                  final friendship = entry.value;

                  final createdAt = friendship['createdAt'];
                  final createdAtStr =
                      createdAt != null && createdAt is Timestamp
                          ? '${createdAt.toDate().day.toString().padLeft(2, '0')}/${createdAt.toDate().month.toString().padLeft(2, '0')}/${createdAt.toDate().year}'
                          : '-';

                  final updatedAt = friendship['updatedAt'];
                  final updatedAtStr =
                      updatedAt != null && updatedAt is Timestamp
                          ? '${updatedAt.toDate().day.toString().padLeft(2, '0')}/${updatedAt.toDate().month.toString().padLeft(2, '0')}/${updatedAt.toDate().year}'
                          : '-';

                  final status = friendship['status'];

                  return DataRow(
                    color: MaterialStateProperty.resolveWith<Color?>((
                      Set<MaterialState> states,
                    ) {
                      if (index.isEven) {
                        return Colors.grey.shade50;
                      }
                      return null;
                    }),
                    cells: [
                      // Người dùng 1
                      DataCell(
                        Text(
                          _userNames[friendship['userId1']] ??
                              friendship['userId1'] ??
                              '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Người dùng 2
                      DataCell(
                        Text(
                          _userNames[friendship['userId2']] ??
                              friendship['userId2'] ??
                              '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Trạng thái
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText(status),
                            style: TextStyle(
                              fontSize: 12,
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Ngày tạo
                      DataCell(Text(createdAtStr)),
                      // Cập nhật
                      DataCell(Text(updatedAtStr)),
                      // Hành động
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_red_eye, size: 18),
                              color: Colors.blue,
                              tooltip: 'Xem chi tiết',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _showDetailDialog(friendship),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              color: Colors.red,
                              tooltip: 'Xóa',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _confirmDelete(friendship),
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

  void _showDetailDialog(Map<String, dynamic> friendship) {
    final createdAt = friendship['createdAt'];
    final createdAtStr =
        createdAt != null && createdAt is Timestamp
            ? '${createdAt.toDate().day.toString().padLeft(2, '0')}/${createdAt.toDate().month.toString().padLeft(2, '0')}/${createdAt.toDate().year} ${createdAt.toDate().hour.toString().padLeft(2, '0')}:${createdAt.toDate().minute.toString().padLeft(2, '0')}'
            : '-';

    final updatedAt = friendship['updatedAt'];
    final updatedAtStr =
        updatedAt != null && updatedAt is Timestamp
            ? '${updatedAt.toDate().day.toString().padLeft(2, '0')}/${updatedAt.toDate().month.toString().padLeft(2, '0')}/${updatedAt.toDate().year} ${updatedAt.toDate().hour.toString().padLeft(2, '0')}:${updatedAt.toDate().minute.toString().padLeft(2, '0')}'
            : '-';

    final userId1 = friendship['userId1'] ?? '';
    final userId2 = friendship['userId2'] ?? '';
    final user1Name = _userNames[userId1] ?? 'Không rõ';
    final user2Name = _userNames[userId2] ?? 'Không rõ';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.people, color: AppColors.primaryGreen),
                const SizedBox(width: 12),
                const Expanded(child: Text('Chi tiết Quan hệ Bạn bè')),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDetailRow('Người dùng 1', user1Name),
                    _buildDetailRow('User ID 1', userId1),
                    const Divider(height: 24),
                    _buildDetailRow('Người dùng 2', user2Name),
                    _buildDetailRow('User ID 2', userId2),
                    const Divider(height: 24),
                    _buildDetailRow(
                      'Trạng thái',
                      _getStatusText(friendship['status']),
                    ),
                    _buildDetailRow('Ngày tạo', createdAtStr),
                    _buildDetailRow('Cập nhật lần cuối', updatedAtStr),
                    _buildDetailRow('ID', friendship['id'] ?? '-'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> friendship) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: Text(
              'Bạn có chắc muốn xóa mối quan hệ giữa ${friendship['userId1']} và ${friendship['userId2']}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  navigator.pop();

                  if (!mounted) return;

                  final result = await _adminService.deleteFriendship(
                    friendship['id'],
                  );

                  if (!mounted) return;

                  if (result) {
                    ToastHelper.showSuccess(context, 'Xóa thành công');
                    _loadFriendships();
                  } else {
                    ToastHelper.showError(context, 'Lỗi khi xóa');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Xóa'),
              ),
            ],
          ),
    );
  }
}
