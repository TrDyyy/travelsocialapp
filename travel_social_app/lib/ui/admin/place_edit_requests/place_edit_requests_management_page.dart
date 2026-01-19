import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/admin_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/toast_helper.dart';

class PlaceEditRequestsManagementPage extends StatefulWidget {
  const PlaceEditRequestsManagementPage({super.key});

  @override
  State<PlaceEditRequestsManagementPage> createState() =>
      _PlaceEditRequestsManagementPageState();
}

class _PlaceEditRequestsManagementPageState
    extends State<PlaceEditRequestsManagementPage> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _requests = [];
  Map<String, String> _userNames = {};
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
      final requests = await _adminService.getCollectionData(
        'placeEditRequests',
        limit: 500,
      );

      // Load user names
      final userIds =
          requests
              .map((r) => r['proposedBy'] as String?)
              .where((id) => id != null && id.isNotEmpty)
              .toSet();

      final userNamesMap = <String, String>{};
      for (final userId in userIds) {
        try {
          final userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .get();
          if (userDoc.exists) {
            final userData = userDoc.data();
            userNamesMap[userId!] = userData?['name'] ?? userId;
          }
        } catch (e) {
          // Keep userId if error
        }
      }

      setState(() {
        _requests = requests;
        _userNames = userNamesMap;
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
      final name =
          (req['placeName'] ?? req['name'] ?? '').toString().toLowerCase();
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
        title: const Text('Quản lý yêu cầu địa điểm'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRequests),
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
                hintText: 'Tìm kiếm...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.primaryGreen,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primaryGreen),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
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
                            'Không có dữ liệu',
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
            minWidth: 1600,
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
              DataColumn2(label: Text('Nội dung'), size: ColumnSize.M),
              DataColumn2(
                label: Text('Tọa độ'),
                size: ColumnSize.S,
                fixedWidth: 160,
              ),
              DataColumn2(
                label: Text('Ngày duyệt'),
                size: ColumnSize.S,
                fixedWidth: 110,
              ),
              DataColumn2(
                label: Text('Ngày tạo yêu cầu'),
                size: ColumnSize.S,
                fixedWidth: 140,
              ),
              DataColumn2(
                label: Text('Hành động'),
                size: ColumnSize.S,
                fixedWidth: 100,
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
                          request['placeName'] ?? request['name'] ?? '',
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
                            request['typeName'] ?? request['typeId'] ?? 'N/A',
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
                          _userNames[request['proposedBy']] ??
                              request['proposedBy'] ??
                              '',
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

                      // Tọa độ
                      DataCell(
                        Builder(
                          builder: (context) {
                            final location = request['location'];
                            if (location is GeoPoint) {
                              return Text(
                                '(${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)})',
                                style: const TextStyle(fontSize: 12),
                              );
                            }
                            return const Text(
                              '-',
                              style: TextStyle(fontSize: 12),
                            );
                          },
                        ),
                      ),

                      // Ngày duyệt
                      DataCell(
                        Builder(
                          builder: (context) {
                            final approvedAt = request['approvedAt'];
                            if (approvedAt is Timestamp) {
                              return Text(
                                DateFormat(
                                  'dd/MM/yyyy',
                                ).format(approvedAt.toDate()),
                                style: const TextStyle(fontSize: 12),
                              );
                            }
                            return const Text(
                              '-',
                              style: TextStyle(fontSize: 12),
                            );
                          },
                        ),
                      ),

                      // Ngày tạo yêu cầu
                      DataCell(
                        Builder(
                          builder: (context) {
                            final createAt = request['createAt'];
                            if (createAt is Timestamp) {
                              return Text(
                                DateFormat(
                                  'dd/MM/yyyy',
                                ).format(createAt.toDate()),
                                style: const TextStyle(fontSize: 12),
                              );
                            }
                            return const Text(
                              '-',
                              style: TextStyle(fontSize: 12),
                            );
                          },
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
                              icon: const Icon(Icons.delete, size: 18),
                              color: AppColors.error,
                              tooltip: 'Xóa',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _confirmDelete(request),
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

    if (status.contains('Đã duyệt') ||
        status.toLowerCase().contains('approved')) {
      color = Colors.green;
      icon = Icons.check_circle;
      label = 'Đã duyệt';
    } else if (status.contains('Từ chối') ||
        status.toLowerCase().contains('reject')) {
      color = AppColors.error;
      icon = Icons.cancel;
      label = 'Từ chối';
    } else {
      color = Colors.orange;
      icon = Icons.pending;
      label = 'Chờ duyệt';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
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
                            request['placeName'] ?? request['name'] ?? 'N/A',
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

                          _buildDetailRow('Địa chỉ', request['address']),
                          _buildDetailRow(
                            'Loại hình',
                            request['typeName'] ?? request['typeId'],
                          ),
                          _buildDetailRow(
                            'Người đề xuất',
                            request['proposedBy'],
                          ),
                          _buildDetailRow('Trạng thái', request['status']),
                          _buildDetailRow('Nội dung', request['content']),
                          _buildDetailRow('Tọa độ', () {
                            final location = request['location'];
                            if (location is GeoPoint) {
                              return '(${location.latitude}, ${location.longitude})';
                            }
                            return 'N/A';
                          }()),
                          _buildDetailRow('Ngày duyệt', () {
                            final approvedAt = request['approvedAt'];
                            if (approvedAt is Timestamp) {
                              return DateFormat(
                                'dd/MM/yyyy HH:mm',
                              ).format(approvedAt.toDate());
                            }
                            return 'Chưa duyệt';
                          }()),
                          _buildDetailRow('Ngày tạo', () {
                            final createAt = request['createAt'];
                            if (createAt is Timestamp) {
                              return DateFormat(
                                'dd/MM/yyyy HH:mm',
                              ).format(createAt.toDate());
                            }
                            return 'N/A';
                          }()),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
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

  void _confirmDelete(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: Text(
              'Bạn có chắc muốn xóa yêu cầu "${request['placeName'] ?? request['name'] ?? 'này'}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);

                  final result = await _adminService.deleteDocument(
                    'placeEditRequests',
                    request['id'],
                  );

                  if (result) {
                    if (mounted) {
                      ToastHelper.showSuccess(context, 'Xóa thành công');
                    }
                    _loadRequests();
                  } else {
                    if (mounted) {
                      ToastHelper.showError(context, 'Lỗi khi xóa');
                    }
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
