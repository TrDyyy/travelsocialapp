import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../services/admin_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/toast_helper.dart';
import 'add_place_screen.dart';
import 'edit_place_screen.dart';

class PlacesManagementPage extends StatefulWidget {
  const PlacesManagementPage({super.key});

  @override
  State<PlacesManagementPage> createState() => _PlacesManagementPageState();
}

class _PlacesManagementPageState extends State<PlacesManagementPage> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _places = [];
  bool _isLoading = true;
  String _searchQuery = '';
  Map<String, String> _typeIdToName = {};

  @override
  void initState() {
    super.initState();
    _loadPlaces();
    _loadTourismTypes();
  }

  Future<void> _loadTourismTypes() async {
    try {
      final map = await _adminService.getTourismTypeNames();
      if (mounted) {
        setState(() {
          _typeIdToName = map;
        });
      }
    } catch (_) {
      // Ignore errors, fallback to showing raw typeId
    }
  }

  Future<void> _loadPlaces() async {
    setState(() => _isLoading = true);
    try {
      final places = await _adminService.getCollectionData(
        'places',
        limit: 200,
      );
      setState(() {
        _places = places;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastHelper.showError(context, 'Lỗi tải dữ liệu: $e');
      }
    }
  }

  List<Map<String, dynamic>> get _filteredPlaces {
    if (_searchQuery.isEmpty) return _places;
    return _places.where((place) {
      final name = (place['name'] ?? '').toString().toLowerCase();
      final address = (place['address'] ?? '').toString().toLowerCase();
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
        title: const Text('Quản lý địa điểm'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddPlaceScreen()),
              );
              if (result == true) _loadPlaces();
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPlaces),
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
                hintText: 'Tìm kiếm địa điểm...',
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
                  Icons.place,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tổng cộng ${_filteredPlaces.length} địa điểm',
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
                    : _filteredPlaces.isEmpty
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
                            'Không có địa điểm nào',
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
            minWidth: 1000,
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
                label: Text('Hình ảnh'),
                size: ColumnSize.S,
                fixedWidth: 70,
              ),
              DataColumn2(label: Text('Tên địa điểm'), size: ColumnSize.L),
              DataColumn2(label: Text('Địa chỉ'), size: ColumnSize.L),
              DataColumn2(
                label: Text('Loại hình'),
                size: ColumnSize.S,
                fixedWidth: 120,
              ),
              DataColumn2(
                label: Text('Trạng thái'),
                size: ColumnSize.S,
                fixedWidth: 100,
              ),
              DataColumn2(
                label: Text('Lượt xem'),
                size: ColumnSize.S,
                fixedWidth: 90,
              ),
              DataColumn2(
                label: Text('Đánh giá'),
                size: ColumnSize.S,
                fixedWidth: 90,
              ),
              DataColumn2(
                label: Text('Hành động'),
                size: ColumnSize.S,
                fixedWidth: 110,
              ),
            ],
            rows:
                _filteredPlaces.asMap().entries.map((entry) {
                  final index = entry.key;
                  final place = entry.value;
                  final images = place['images'] as List<dynamic>? ?? [];
                  final firstImage =
                      images.isNotEmpty ? images[0] as String : '';
                  final rating = (place['rating'] ?? 0).toDouble();
                  final status = (place['status'] ?? 'unknown').toString();
                  final viewCount = place['viewCount'] ?? 0;

                  Color statusColor;
                  switch (status) {
                    case 'active':
                      statusColor = Colors.green;
                      break;
                    case 'pending':
                      statusColor = Colors.orange;
                      break;
                    case 'blocked':
                      statusColor = Colors.red;
                      break;
                    default:
                      statusColor = Colors.grey;
                  }

                  return DataRow2(
                    color: MaterialStateProperty.resolveWith((states) {
                      if (states.contains(MaterialState.hovered)) {
                        return AppColors.primaryGreen.withOpacity(0.06);
                      }
                      return index.isEven ? Colors.white : Colors.grey.shade100;
                    }),
                    cells: [
                      // Ảnh
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

                      // Tên địa điểm
                      DataCell(
                        Text(
                          place['name'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),

                      // Địa chỉ
                      DataCell(
                        Text(
                          place['address'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Loại hình (map typeId -> typeName)
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
                            _typeIdToName[place['typeId']] ??
                                (place['typeId'] ?? 'N/A').toString(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      // Trạng thái (status)
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ),

                      // Lượt xem (viewCount)
                      DataCell(
                        Text(
                          viewCount.toString(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),

                      // Đánh giá (rating)
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
                              onPressed: () => _showDetailDialog(place),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              color: Colors.orange,
                              tooltip: 'Sửa',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            EditPlaceScreen(place: place),
                                  ),
                                );
                                if (result == true) _loadPlaces();
                              },
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              color: AppColors.error,
                              tooltip: 'Xóa',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _deletePlace(place['id']),
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

  void _showDetailDialog(Map<String, dynamic> place) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(place['name'] ?? 'Chi tiết'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInfoRow('Địa chỉ', place['address']),
                  _buildInfoRow('Loại', place['typeId']),
                  _buildInfoRow('Mô tả', place['description']),
                  _buildInfoRow('Đánh giá', '${place['rating']} ⭐'),
                  _buildInfoRow('Lượt xem', '${place['viewCount'] ?? 0}'),
                ],
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

  Widget _buildInfoRow(String label, dynamic value) {
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
            ),
          ),
          const SizedBox(height: 4),
          Text(value?.toString() ?? 'N/A'),
        ],
      ),
    );
  }

  Future<void> _deletePlace(String placeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: const Text('Bạn có chắc muốn xóa địa điểm này?'),
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
                child: const Text('Xóa'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final success = await _adminService.deleteDocument('places', placeId);
      if (mounted) {
        if (success) {
          ToastHelper.showSuccess(context, 'Đã xóa!');
          _loadPlaces();
        } else {
          ToastHelper.showError(context, 'Lỗi xóa địa điểm');
        }
      }
    }
  }
}
