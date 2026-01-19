import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../services/admin_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/toast_helper.dart';

class PlaceRequestsPage extends StatefulWidget {
  const PlaceRequestsPage({super.key});

  @override
  State<PlaceRequestsPage> createState() => _PlaceRequestsPageState();
}

class _PlaceRequestsPageState extends State<PlaceRequestsPage> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await _adminService.getPendingRequests();
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastHelper.showError(context, 'Lỗi tải dữ liệu: $e');
      }
    }
  }

  List<Map<String, dynamic>> get _filteredRequests {
    if (_searchQuery.isEmpty) return _requests;
    return _requests.where((req) {
      final name = (req['name'] ?? '').toString().toLowerCase();
      final address = (req['address'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || address.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getSurfaceColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        title: const Text('Yêu cầu thêm địa điểm'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm kiếm theo tên hoặc địa chỉ...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.primaryGreen,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primaryGreen,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Stats banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.primaryGreen.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(
                  Icons.pending_actions,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tổng cộng ${_filteredRequests.length} yêu cầu chờ duyệt',
                  style: const TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
                    : _filteredRequests.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Không có yêu cầu nào',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : _buildDataTable(),
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
              AppColors.primaryGreen.withOpacity(0.35),
            ),
            headingTextStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.black,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
            dataTextStyle: const TextStyle(fontSize: 14, color: Colors.black87),
            columns: const [
              DataColumn2(
                label: Text('Hình ảnh'),
                size: ColumnSize.S,
                fixedWidth: 80,
              ),
              DataColumn2(label: Text('Tên địa điểm'), size: ColumnSize.M),
              DataColumn2(label: Text('Địa chỉ'), size: ColumnSize.L),
              DataColumn2(
                label: Text('Loại hình'),
                size: ColumnSize.S,
                fixedWidth: 100,
              ),
              DataColumn2(
                label: Text('Người đề xuất'),
                size: ColumnSize.S,
                fixedWidth: 140,
              ),
              DataColumn2(
                label: Text('Trạng thái'),
                size: ColumnSize.S,
                fixedWidth: 110,
              ),
              DataColumn2(label: Text('Nội dung'), size: ColumnSize.L),
              DataColumn2(
                label: Text('Hành động'),
                size: ColumnSize.S,
                fixedWidth: 160,
              ),
            ],
            rows:
                _filteredRequests.asMap().entries.map((entry) {
                  final index = entry.key;
                  final request = entry.value;
                  final images = request['images'] as List<dynamic>? ?? [];
                  final firstImage =
                      images.isNotEmpty ? images[0] as String : '';

                  return DataRow2(
                    color: MaterialStateProperty.resolveWith((states) {
                      if (states.contains(MaterialState.hovered)) {
                        return AppColors.primaryGreen.withOpacity(0.06);
                      }
                      return index.isEven ? Colors.white : Colors.grey.shade100;
                    }),
                    cells: [
                      // Image
                      DataCell(
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child:
                              firstImage.isNotEmpty
                                  ? Image.network(
                                    firstImage,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              width: 50,
                                              height: 50,
                                              color: Colors.grey.shade300,
                                              child: const Icon(
                                                Icons.broken_image,
                                                size: 20,
                                              ),
                                            ),
                                  )
                                  : Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.image, size: 20),
                                  ),
                        ),
                      ),

                      // Name
                      DataCell(
                        Text(
                          request['name'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),

                      // Address
                      DataCell(
                        Text(
                          request['address'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Loại hình
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            request['typeName'] ?? request['typeIds'] ?? 'N/A',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      // Người đề xuất
                      DataCell(
                        Text(
                          request['proposedBy'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Trạng thái
                      DataCell(
                        _buildStatusChip(request['status'] ?? 'Đã tiếp nhận'),
                      ),

                      // Nội dung
                      DataCell(
                        Text(
                          request['content'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Hành động
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility, size: 18),
                              color: AppColors.primaryGreen,
                              tooltip: 'Xem chi tiết',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _showDetailDialog(request),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.check_circle, size: 18),
                              color: Colors.green,
                              tooltip: 'Duyệt',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _approveRequest(request['id']),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.cancel, size: 18),
                              color: AppColors.error,
                              tooltip: 'Từ chối',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _rejectRequest(request['id']),
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
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'Đã duyệt':
        color = const Color(0xFF4CAF50); // Green
        icon = Icons.check_circle;
        label = 'Đã duyệt';
        break;
      case 'Từ chối':
        color = const Color(0xFFF44336); // Red
        icon = Icons.cancel;
        label = 'Từ chối';
        break;
      default:
        color = const Color(0xFFFF9800); // Orange
        icon = Icons.pending;
        label = 'Chờ duyệt';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(Map<String, dynamic> request) {
    final images = request['images'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            request['name'] ?? 'N/A',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Images grid
                          if (images.isNotEmpty) ...[
                            const Text(
                              'Hình ảnh',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                    childAspectRatio: 1,
                                  ),
                              itemCount: images.length,
                              itemBuilder: (context, index) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    images[index],
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              color: Colors.grey.shade300,
                                              child: const Icon(
                                                Icons.broken_image,
                                              ),
                                            ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                          ],

                          _buildInfoRow('Địa chỉ', request['address']),
                          _buildInfoRow('Loại', request['typeId']),
                          _buildInfoRow('Mô tả', request['description']),
                          _buildInfoRow('Trạng thái', request['status']),
                        ],
                      ),
                    ),
                  ),

                  // Actions
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _approveRequest(request['id']);
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Duyệt'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _rejectRequest(request['id']);
                            },
                            icon: const Icon(Icons.cancel),
                            label: const Text('Từ chối'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
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

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
          Text(
            value?.toString() ?? 'N/A',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Future<void> _approveRequest(String requestId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xác nhận duyệt'),
            content: const Text('Bạn có chắc muốn duyệt yêu cầu này?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Duyệt'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final placeId = await _adminService.approveRequest(requestId);
      if (mounted) {
        if (placeId != null) {
          ToastHelper.showSuccess(context, 'Đã duyệt thành công');
          _loadRequests();
        } else {
          ToastHelper.showError(context, 'Lỗi duyệt yêu cầu');
        }
      }
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Từ chối yêu cầu'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Lý do từ chối:'),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Nhập lý do...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                child: const Text('Từ chối'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final success = await _adminService.rejectRequest(
        requestId,
        reasonController.text,
      );
      if (mounted) {
        if (success) {
          ToastHelper.showWarning(context, 'Đã từ chối!');
          _loadRequests();
        } else {
          ToastHelper.showError(context, 'Lỗi từ chối yêu cầu');
        }
      }
    }
  }
}
