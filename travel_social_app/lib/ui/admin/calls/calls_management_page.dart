import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../services/admin_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/toast_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Trang quản lý Calls (Chỉ xem)
class CallsManagementPage extends StatefulWidget {
  const CallsManagementPage({super.key});

  @override
  State<CallsManagementPage> createState() => _CallsManagementPageState();
}

class _CallsManagementPageState extends State<CallsManagementPage> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _calls = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCalls();
  }

  Future<void> _loadCalls() async {
    setState(() => _isLoading = true);
    try {
      final calls = await _adminService.getCollectionData('calls', limit: 200);
      setState(() {
        _calls = calls;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastHelper.showError(context, 'Lỗi tải dữ liệu: $e');
      }
    }
  }

  List<Map<String, dynamic>> get _filteredCalls {
    if (_searchQuery.isEmpty) return _calls;
    return _calls.where((call) {
      final callType = (call['callType'] ?? '').toString().toLowerCase();
      final callStatus = (call['callStatus'] ?? '').toString().toLowerCase();
      final callerId = (call['callerId'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return callType.contains(query) ||
          callStatus.contains(query) ||
          callerId.contains(query);
    }).toList();
  }

  String _getCallTypeText(String? type) {
    switch (type) {
      case 'voice':
        return 'Thoại';
      case 'video':
        return 'Video';
      default:
        return type ?? '-';
    }
  }

  String _getCallStatusText(String? status) {
    switch (status) {
      case 'ringing':
        return 'Đang gọi';
      case 'answered':
        return 'Đã trả lời';
      case 'rejected':
        return 'Từ chối';
      case 'missed':
        return 'Nhớ';
      case 'ended':
        return 'Đã kết thúc';
      default:
        return status ?? '-';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'answered':
      case 'ended':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'missed':
        return Colors.orange;
      case 'ringing':
        return Colors.blue;
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
          'Quản lý Cuộc gọi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadCalls),
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
                      : _buildCallsTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Tìm kiếm theo loại, trạng thái, người gọi...',
        hintStyle: TextStyle(color: AppTheme.getTextSecondaryColor(context)),
        prefixIcon: Icon(
          Icons.search,
          color: AppTheme.getIconPrimaryColor(context),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
          borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
          borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
          borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        filled: true,
        fillColor: AppTheme.getInputBackgroundColor(context),
      ),
      style: TextStyle(color: AppTheme.getTextPrimaryColor(context)),
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }

  Widget _buildCallsTable() {
    if (_filteredCalls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.call, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Không có cuộc gọi nào',
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
            minWidth: 1400,
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
              DataColumn2(
                label: Text('Loại'),
                size: ColumnSize.S,
                fixedWidth: 100,
              ),
              DataColumn2(
                label: Text('Trạng thái'),
                size: ColumnSize.S,
                fixedWidth: 120,
              ),
              DataColumn2(label: Text('Người gọi'), size: ColumnSize.M),
              DataColumn2(label: Text('Người nhận'), size: ColumnSize.M),
              DataColumn2(
                label: Text('Thời lượng'),
                size: ColumnSize.S,
                fixedWidth: 100,
              ),
              DataColumn2(
                label: Text('Ngày tạo'),
                size: ColumnSize.M,
                fixedWidth: 120,
              ),
              DataColumn2(
                label: Text('Thời gian trả lời'),
                size: ColumnSize.M,
                fixedWidth: 150,
              ),
              DataColumn2(
                label: Text('Thời gian kết thúc'),
                size: ColumnSize.M,
                fixedWidth: 150,
              ),
              DataColumn2(
                label: Text('Hành động'),
                size: ColumnSize.S,
                fixedWidth: 100,
              ),
            ],
            rows:
                _filteredCalls.asMap().entries.map((entry) {
                  final index = entry.key;
                  final call = entry.value;

                  final createdAt = call['createdAt'];
                  final createdAtStr =
                      createdAt != null && createdAt is Timestamp
                          ? '${createdAt.toDate().day.toString().padLeft(2, '0')}/${createdAt.toDate().month.toString().padLeft(2, '0')}/${createdAt.toDate().year}'
                          : '-';

                  final answeredAt = call['answeredAt'];
                  final answeredAtStr =
                      answeredAt != null && answeredAt is Timestamp
                          ? '${answeredAt.toDate().day.toString().padLeft(2, '0')}/${answeredAt.toDate().month.toString().padLeft(2, '0')}/${answeredAt.toDate().year} ${answeredAt.toDate().hour.toString().padLeft(2, '0')}:${answeredAt.toDate().minute.toString().padLeft(2, '0')}'
                          : '-';

                  final endedAt = call['endedAt'];
                  final endedAtStr =
                      endedAt != null && endedAt is Timestamp
                          ? '${endedAt.toDate().day.toString().padLeft(2, '0')}/${endedAt.toDate().month.toString().padLeft(2, '0')}/${endedAt.toDate().year} ${endedAt.toDate().hour.toString().padLeft(2, '0')}:${endedAt.toDate().minute.toString().padLeft(2, '0')}'
                          : '-';

                  final callType = call['callType'];
                  final callStatus = call['callStatus'];
                  final receiverIds = call['receiverIds'] as List? ?? [];
                  final duration = call['duration'];

                  String durationStr = '-';
                  if (duration != null && duration > 0) {
                    final minutes = (duration / 60).floor();
                    final seconds = duration % 60;
                    durationStr = '${minutes}m ${seconds}s';
                  }

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
                      // Loại
                      DataCell(
                        Row(
                          children: [
                            Icon(
                              callType == 'video' ? Icons.videocam : Icons.call,
                              size: 18,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(_getCallTypeText(callType)),
                          ],
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
                            color: _getStatusColor(callStatus).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getCallStatusText(callStatus),
                            style: TextStyle(
                              fontSize: 12,
                              color: _getStatusColor(callStatus),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Người gọi
                      DataCell(
                        Text(
                          call['callerId'] ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Người nhận
                      DataCell(
                        Text(
                          receiverIds.isNotEmpty ? receiverIds.join(', ') : '-',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Thời lượng
                      DataCell(Text(durationStr)),
                      // Ngày tạo
                      DataCell(Text(createdAtStr)),
                      // Thời gian trả lời
                      DataCell(Text(answeredAtStr)),
                      // Thời gian kết thúc
                      DataCell(Text(endedAtStr)),
                      // Hành động
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility, size: 18),
                              color: Colors.blue,
                              tooltip: 'Xem chi tiết',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _showDetailDialog(call),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              color: AppColors.error,
                              tooltip: 'Xóa',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _confirmDelete(call),
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

  void _showDetailDialog(Map<String, dynamic> call) {
    final createdAt =
        call['createdAt'] != null && call['createdAt'] is Timestamp
            ? (call['createdAt'] as Timestamp).toDate().toString()
            : '-';
    final answeredAt =
        call['answeredAt'] != null && call['answeredAt'] is Timestamp
            ? (call['answeredAt'] as Timestamp).toDate().toString()
            : '-';
    final endedAt =
        call['endedAt'] != null && call['endedAt'] is Timestamp
            ? (call['endedAt'] as Timestamp).toDate().toString()
            : '-';
    final receiverIds = call['receiverIds'] as List? ?? [];
    final duration = call['duration'];

    String durationStr = 'Chưa có';
    if (duration != null && duration > 0) {
      final minutes = (duration / 60).floor();
      final seconds = duration % 60;
      durationStr = '${minutes} phút ${seconds} giây';
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  call['callType'] == 'video' ? Icons.videocam : Icons.call,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 8),
                const Expanded(child: Text('Chi tiết cuộc gọi')),
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
                    _buildDetailRow('ID', call['id']),
                    const Divider(),
                    _buildDetailRow(
                      'Loại cuộc gọi',
                      _getCallTypeText(call['callType']),
                    ),
                    _buildDetailRow(
                      'Trạng thái',
                      _getCallStatusText(call['callStatus']),
                    ),
                    const Divider(),
                    _buildDetailRow('Người gọi', call['callerId']),
                    _buildDetailRow('Số người nhận', '${receiverIds.length}'),
                    if (receiverIds.isNotEmpty) ...[
                      const Text(
                        'Danh sách người nhận:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...receiverIds.map((receiverId) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $receiverId'),
                        );
                      }).toList(),
                    ],
                    const Divider(),
                    _buildDetailRow('ID Chat', call['chatId']),
                    _buildDetailRow('Agora Channel', call['agoraChannelName']),
                    _buildDetailRow(
                      'Agora Token',
                      call['agoraToken'] != null ? 'Có' : 'Không',
                    ),
                    const Divider(),
                    _buildDetailRow('Thời lượng', durationStr),
                    _buildDetailRow('Thời gian tạo', createdAt),
                    _buildDetailRow('Thời gian trả lời', answeredAt),
                    _buildDetailRow('Thời gian kết thúc', endedAt),
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

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(value?.toString() ?? 'N/A'),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> call) {
    final callType = _getCallTypeText(call['callType']);
    final callStatus = _getCallStatusText(call['callStatus']);
    final callerId = call['callerId'] ?? 'Không rõ';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bạn có chắc muốn xóa cuộc gọi này?'),
                const SizedBox(height: 12),
                Text('📞 Loại: $callType'),
                Text('📊 Trạng thái: $callStatus'),
                Text('👤 Người gọi: $callerId'),
                const SizedBox(height: 12),
                const Text(
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
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  navigator.pop();

                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Đang xóa...'),
                        ],
                      ),
                      duration: Duration(seconds: 30),
                    ),
                  );

                  try {
                    await _adminService.deleteDocument('calls', call['id']);
                    scaffoldMessenger.hideCurrentSnackBar();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('✅ Đã xóa cuộc gọi!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadCalls();
                  } catch (e) {
                    scaffoldMessenger.hideCurrentSnackBar();
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('❌ Lỗi: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
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
