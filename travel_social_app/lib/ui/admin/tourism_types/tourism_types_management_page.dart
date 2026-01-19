import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/admin_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/toast_helper.dart';

class TourismTypesManagementPage extends StatefulWidget {
  const TourismTypesManagementPage({super.key});

  @override
  State<TourismTypesManagementPage> createState() =>
      _TourismTypesManagementPageState();
}

class _TourismTypesManagementPageState
    extends State<TourismTypesManagementPage> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _types = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    setState(() => _isLoading = true);
    try {
      final types = await _adminService.getCollectionData(
        'tourismTypes',
        limit: 100,
      );
      setState(() {
        _types = types;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastHelper.showError(context, 'Lỗi tải dữ liệu: $e');
      }
    }
  }

  List<Map<String, dynamic>> get _filteredTypes {
    if (_searchQuery.isEmpty) return _types;
    return _types.where((type) {
      final name = (type['name'] ?? '').toString().toLowerCase();
      final description = (type['description'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || description.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getSurfaceColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        title: const Text('Quản lý loại hình du lịch'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTypes),
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

          // Data table
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                      ),
                    )
                    : _filteredTypes.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Không có loại hình nào',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add),
        label: const Text('Tạo mới'),
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
            minWidth: 800,
            headingRowColor: MaterialStateProperty.all(
              AppColors.primaryGreen.withOpacity(0.2),
            ),
            headingTextStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontSize: 15,
            ),
            columns: const [
              DataColumn2(label: Text('Tên loại hình'), size: ColumnSize.L),
              DataColumn2(label: Text('Mã loại hình'), size: ColumnSize.M),
              DataColumn2(label: Text('Mô tả'), size: ColumnSize.L),
              DataColumn2(
                label: Text('Hành động'),
                size: ColumnSize.S,
                fixedWidth: 150,
              ),
            ],
            rows:
                _filteredTypes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final type = entry.value;

                  return DataRow(
                    color: MaterialStateProperty.resolveWith<Color?>(
                      (states) => index.isEven ? Colors.grey.shade50 : null,
                    ),
                    cells: [
                      // Tên loại hình
                      DataCell(
                        Text(
                          type['name'] ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),

                      // Mã loại hình
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            type['id'] ?? '-',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),

                      // Mô tả
                      DataCell(
                        Text(
                          type['description'] ?? '-',
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
                              tooltip: 'Xem',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _showDetailDialog(type),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              color: Colors.blue,
                              tooltip: 'Sửa',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _showEditDialog(type),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              color: Colors.red,
                              tooltip: 'Xóa',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _confirmDelete(type),
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

  void _showAddDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.add_circle, color: AppColors.primaryGreen),
                SizedBox(width: 12),
                Text('Thêm loại hình du lịch'),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên loại hình *',
                      border: OutlineInputBorder(),
                      hintText: 'VD: Ẩm thực, Du lịch, Giải trí...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả',
                      border: OutlineInputBorder(),
                      hintText: 'Mô tả chi tiết về loại hình này',
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    if (!mounted) return;
                    ToastHelper.showWarning(
                      context,
                      'Vui lòng nhập tên loại hình',
                    );
                    return;
                  }

                  final navigator = Navigator.of(context);

                  navigator.pop();

                  if (!mounted) return;

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (context) =>
                            const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    final data = {
                      'name': nameController.text.trim(),
                      'description': descriptionController.text.trim(),
                      'createdAt': FieldValue.serverTimestamp(),
                    };

                    await _adminService.addDocument('tourismTypes', data);

                    if (!mounted) return;
                    navigator.pop();
                    ToastHelper.showSuccess(
                      context,
                      'Đã thêm loại hình thành công',
                    );
                    _loadTypes();
                  } catch (e) {
                    if (!mounted) return;
                    navigator.pop();
                    ToastHelper.showError(context, 'Lỗi: ${e.toString()}');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                ),
                child: const Text('Thêm'),
              ),
            ],
          ),
    );
  }

  void _showEditDialog(Map<String, dynamic> type) {
    final nameController = TextEditingController(text: type['name']);
    final descriptionController = TextEditingController(
      text: type['description'],
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.edit, color: Colors.blue),
                SizedBox(width: 12),
                Text('Sửa loại hình du lịch'),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên loại hình *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    if (!mounted) return;
                    ToastHelper.showWarning(
                      context,
                      'Vui lòng nhập tên loại hình',
                    );
                    return;
                  }

                  final navigator = Navigator.of(context);

                  navigator.pop();

                  if (!mounted) return;

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (context) =>
                            const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    final data = {
                      'name': nameController.text.trim(),
                      'description': descriptionController.text.trim(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    };

                    await _adminService.updateDocument(
                      'tourismTypes',
                      type['id'],
                      data,
                    );

                    if (!mounted) return;
                    navigator.pop();
                    ToastHelper.showSuccess(context, 'Đã cập nhật thành công');
                    _loadTypes();
                  } catch (e) {
                    if (!mounted) return;
                    navigator.pop();
                    ToastHelper.showError(context, 'Lỗi: ${e.toString()}');
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text('Cập nhật'),
              ),
            ],
          ),
    );
  }

  void _showDetailDialog(Map<String, dynamic> type) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.category, color: AppColors.primaryGreen),
                const SizedBox(width: 12),
                Expanded(child: Text(type['name'] ?? 'Chi tiết')),
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
                  children: [
                    _buildDetailRow('Mã loại hình', type['id']),
                    _buildDetailRow('Tên loại hình', type['name']),
                    _buildDetailRow('Mô tả', type['description']),
                    _buildDetailRow(
                      'Ngày tạo',
                      type['createdAt'] is Timestamp
                          ? (type['createdAt'] as Timestamp)
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

  void _confirmDelete(Map<String, dynamic> type) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bạn có chắc muốn xóa loại hình "${type['name']}"?'),
                const SizedBox(height: 12),
                const Text(
                  '⚠️ Chú ý: Các địa điểm đang dùng loại hình này sẽ bị ảnh hưởng!',
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
                  final navigator = Navigator.of(context);

                  navigator.pop();

                  if (!mounted) return;

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (context) =>
                            const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    await _adminService.deleteDocument(
                      'tourismTypes',
                      type['id'],
                    );

                    if (!mounted) return;
                    navigator.pop();
                    ToastHelper.showSuccess(context, 'Đã xóa thành công');
                    _loadTypes();
                  } catch (e) {
                    if (!mounted) return;
                    navigator.pop();
                    ToastHelper.showError(context, 'Lỗi: ${e.toString()}');
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
