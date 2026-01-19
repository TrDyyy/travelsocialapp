import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/admin_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/toast_helper.dart';

class ReviewsManagementPage extends StatefulWidget {
  const ReviewsManagementPage({super.key});

  @override
  State<ReviewsManagementPage> createState() => _ReviewsManagementPageState();
}

class _ReviewsManagementPageState extends State<ReviewsManagementPage> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _reviews = [];
  Map<String, String> _placeNames = {}; // Cache place names
  Map<String, String> _userNames = {}; // Cache user names
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    try {
      final reviews = await _adminService.getCollectionData(
        'reviews',
        limit: 200,
      );

      // Load place names and user names
      final placeIds =
          reviews
              .map((r) => r['placeId']?.toString())
              .where((id) => id != null && id.isNotEmpty)
              .toSet();
      final userIds =
          reviews
              .map((r) => r['userId']?.toString())
              .where((id) => id != null && id.isNotEmpty)
              .toSet();

      final placeNames = <String, String>{};
      final userNames = <String, String>{};

      // Fetch place names
      for (var placeId in placeIds) {
        try {
          final placeDoc =
              await FirebaseFirestore.instance
                  .collection('places')
                  .doc(placeId)
                  .get();
          if (placeDoc.exists) {
            placeNames[placeId!] = placeDoc.data()?['name'] ?? 'Không rõ';
          }
        } catch (e) {
          print('Error loading place $placeId: $e');
        }
      }

      // Fetch user names
      for (var userId in userIds) {
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

      setState(() {
        _reviews = reviews;
        _placeNames = placeNames;
        _userNames = userNames;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastHelper.showError(context, 'Lỗi tải dữ liệu: $e');
      }
    }
  }

  List<Map<String, dynamic>> get _filteredReviews {
    if (_searchQuery.isEmpty) return _reviews;
    return _reviews.where((review) {
      final content = (review['content'] ?? '').toString().toLowerCase();
      final placeId = review['placeId']?.toString() ?? '';
      final placeName = (_placeNames[placeId] ?? '').toLowerCase();
      final userId = review['userId']?.toString() ?? '';
      final userName = (_userNames[userId] ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return content.contains(query) ||
          placeName.contains(query) ||
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
        title: const Text('Quản lý đánh giá'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReviews),
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
                hintText: 'Tìm kiếm theo địa điểm, người dùng, nội dung...',
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
                  Icons.rate_review,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tổng cộng ${_filteredReviews.length} đánh giá',
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
                    : _filteredReviews.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.rate_review_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Không có đánh giá nào',
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
              DataColumn2(label: Text('Địa điểm'), size: ColumnSize.L),
              DataColumn2(label: Text('Người đăng'), size: ColumnSize.M),
              DataColumn2(
                label: Text('Đánh giá'),
                size: ColumnSize.S,
                fixedWidth: 90,
              ),
              DataColumn2(label: Text('Nội dung'), size: ColumnSize.L),
              DataColumn2(
                label: Text('Hình ảnh'),
                size: ColumnSize.S,
                fixedWidth: 70,
              ),
              DataColumn2(
                label: Text('Check-in'),
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
                _filteredReviews.asMap().entries.map((entry) {
                  final index = entry.key;
                  final review = entry.value;
                  final placeId = review['placeId']?.toString() ?? '';
                  final userId = review['userId']?.toString() ?? '';
                  final placeName = _placeNames[placeId] ?? 'Không rõ';
                  final userName = _userNames[userId] ?? 'Không rõ';
                  final rating = (review['rating'] ?? 0).toDouble();
                  final hasCheckedIn = review['hasCheckedIn'] == true;
                  final images = review['images'] as List<dynamic>? ?? [];
                  final createdAt = review['createdAt'];

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
                      // Ngày tạo
                      DataCell(Text(dateStr)),

                      // Địa điểm
                      DataCell(
                        Row(
                          children: [
                            const Icon(
                              Icons.place,
                              size: 16,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                placeName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Người đăng
                      DataCell(
                        Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Đánh giá
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
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Nội dung
                      DataCell(
                        Text(
                          review['content'] ?? '-',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Hình ảnh
                      DataCell(
                        images.isNotEmpty
                            ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    images[0].toString(),
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              width: 40,
                                              height: 40,
                                              color: Colors.grey.shade300,
                                              child: const Icon(
                                                Icons.broken_image,
                                                size: 20,
                                              ),
                                            ),
                                  ),
                                ),
                                if (images.length > 1) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '+${images.length - 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ],
                            )
                            : const Text('-'),
                      ),

                      // Check-in
                      DataCell(
                        hasCheckedIn
                            ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 14,
                                    color: Colors.green,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Có',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : const Text('-'),
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
                              onPressed: () => _showDetailDialog(review),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              color: Colors.red,
                              tooltip: 'Xóa',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _confirmDelete(review),
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

  void _showDetailDialog(Map<String, dynamic> review) {
    final placeId = review['placeId']?.toString() ?? '';
    final userId = review['userId']?.toString() ?? '';
    final placeName = _placeNames[placeId] ?? 'Không rõ';
    final userName = _userNames[userId] ?? 'Không rõ';
    final rating = (review['rating'] ?? 0).toDouble();
    final images = review['images'] as List<dynamic>? ?? [];
    final hasCheckedIn = review['hasCheckedIn'] == true;
    final checkInTime = review['checkInTime'];
    final createdAt = review['createdAt'];
    final reactionCount = review['reactionCount'] ?? 0;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.rate_review, color: AppColors.primaryGreen),
                const SizedBox(width: 12),
                const Expanded(child: Text('Chi tiết đánh giá')),
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
                    // Địa điểm
                    _buildDetailSection(
                      icon: Icons.place,
                      title: 'Địa điểm',
                      content: placeName,
                    ),

                    // Người đánh giá
                    _buildDetailSection(
                      icon: Icons.person,
                      title: 'Người đánh giá',
                      content: userName,
                    ),

                    // Đánh giá
                    const Text(
                      'Đánh giá',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 24,
                        );
                      }),
                    ),
                    const SizedBox(height: 16),

                    // Nội dung
                    _buildDetailSection(
                      icon: Icons.comment,
                      title: 'Nội dung',
                      content: review['content'] ?? 'Không có nội dung',
                    ),

                    // Hình ảnh
                    if (images.isNotEmpty) ...[
                      const Text(
                        'Hình ảnh',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            images.map((img) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  img.toString(),
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) => Container(
                                        width: 100,
                                        height: 100,
                                        color: Colors.grey.shade300,
                                        child: const Icon(Icons.broken_image),
                                      ),
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Check-in
                    _buildDetailRow(
                      'Đã check-in',
                      hasCheckedIn ? 'Có' : 'Không',
                    ),

                    if (hasCheckedIn && checkInTime != null) ...[
                      _buildDetailRow(
                        'Thời gian check-in',
                        checkInTime is Timestamp
                            ? checkInTime.toDate().toString().split('.')[0]
                            : checkInTime.toString(),
                      ),
                    ],

                    // Reactions
                    _buildDetailRow('Lượt tương tác', reactionCount.toString()),

                    // Ngày tạo
                    _buildDetailRow(
                      'Ngày tạo',
                      createdAt is Timestamp
                          ? createdAt.toDate().toString().split('.')[0]
                          : 'N/A',
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildDetailSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> review) {
    final placeId = review['placeId']?.toString() ?? '';
    final placeName = _placeNames[placeId] ?? 'Không rõ';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bạn có chắc muốn xóa đánh giá này?'),
                const SizedBox(height: 8),
                Text(
                  'Địa điểm: $placeName',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
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
                    await _adminService.deleteDocument('reviews', review['id']);

                    if (!mounted) return;
                    navigator.pop();
                    ToastHelper.showSuccess(
                      context,
                      'Đã xóa đánh giá thành công',
                    );
                    _loadReviews();
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
