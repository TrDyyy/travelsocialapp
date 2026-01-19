import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../services/admin_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/toast_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Trang quản lý Reactions (Biểu cảm)
class ReactionsManagementPage extends StatefulWidget {
  const ReactionsManagementPage({super.key});

  @override
  State<ReactionsManagementPage> createState() =>
      _ReactionsManagementPageState();
}

class _ReactionsManagementPageState extends State<ReactionsManagementPage> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _reactions = [];
  Map<String, String> _userNames = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadReactions();
  }

  Future<void> _loadReactions() async {
    setState(() => _isLoading = true);
    try {
      final reactions = await _adminService.getCollectionData(
        'reactions',
        limit: 200,
      );

      // Load user names
      final userIds =
          reactions
              .map((r) => r['userId']?.toString())
              .where((id) => id != null && id.isNotEmpty)
              .toSet();

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
            userNames[userId!] =
                userData?['name'] ?? userData?['email'] ?? 'Không rõ';
          }
        } catch (e) {
          print('Error loading user $userId: $e');
        }
      }

      setState(() {
        _reactions = reactions;
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

  List<Map<String, dynamic>> get _filteredReactions {
    if (_searchQuery.isEmpty) return _reactions;
    return _reactions.where((reaction) {
      final reactionType =
          (reaction['reactionType'] ?? '').toString().toLowerCase();
      final targetType =
          (reaction['targetType'] ?? '').toString().toLowerCase();
      final userId = (reaction['userId'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return reactionType.contains(query) ||
          targetType.contains(query) ||
          userId.contains(query);
    }).toList();
  }

  String _getReactionIcon(String? type) {
    switch (type) {
      case 'like':
        return '👍';
      case 'love':
        return '❤️';
      case 'haha':
        return '😄';
      case 'wow':
        return '😮';
      case 'sad':
        return '😢';
      case 'angry':
        return '😡';
      default:
        return '👍';
    }
  }

  String _getReactionText(String? type) {
    switch (type) {
      case 'like':
        return 'Thích';
      case 'love':
        return 'Yêu thích';
      case 'haha':
        return 'Haha';
      case 'wow':
        return 'Wow';
      case 'sad':
        return 'Buồn';
      case 'angry':
        return 'Phẫn nộ';
      default:
        return type ?? '-';
    }
  }

  String _getTargetTypeText(String? type) {
    switch (type) {
      case 'message':
        return 'Tin nhắn';
      case 'post':
        return 'Bài viết';
      case 'comment':
        return 'Bình luận';
      case 'review':
        return 'Đánh giá';
      default:
        return type ?? '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text(
          'Quản lý Biểu cảm',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReactions,
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
                      : _buildReactionsTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText:
            'Tìm kiếm theo loại biểu cảm, loại đối tượng hoặc người dùng...',
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

  Widget _buildReactionsTable() {
    if (_filteredReactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_emotions_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Không có biểu cảm nào',
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
              DataColumn2(
                label: Text('Loại biểu cảm'),
                size: ColumnSize.S,
                fixedWidth: 150,
              ),
              DataColumn2(label: Text('Người dùng'), size: ColumnSize.L),
              DataColumn2(
                label: Text('Loại đối tượng'),
                size: ColumnSize.S,
                fixedWidth: 120,
              ),
              DataColumn2(label: Text('ID đối tượng'), size: ColumnSize.L),
              DataColumn2(
                label: Text('Ngày tạo'),
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
                _filteredReactions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final reaction = entry.value;

                  final createdAt = reaction['createdAt'];
                  final createdAtStr =
                      createdAt != null && createdAt is Timestamp
                          ? '${createdAt.toDate().day.toString().padLeft(2, '0')}/${createdAt.toDate().month.toString().padLeft(2, '0')}/${createdAt.toDate().year} ${createdAt.toDate().hour.toString().padLeft(2, '0')}:${createdAt.toDate().minute.toString().padLeft(2, '0')}'
                          : '-';

                  final reactionType = reaction['reactionType'];

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
                      // Loại biểu cảm
                      DataCell(
                        Row(
                          children: [
                            Text(
                              _getReactionIcon(reactionType),
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 8),
                            Text(_getReactionText(reactionType)),
                          ],
                        ),
                      ),
                      // Người dùng
                      DataCell(
                        Text(
                          _userNames[reaction['userId']] ??
                              reaction['userId'] ??
                              '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Loại đối tượng
                      DataCell(
                        Text(_getTargetTypeText(reaction['targetType'])),
                      ),
                      // ID đối tượng
                      DataCell(
                        Text(
                          reaction['targetId'] ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Ngày tạo
                      DataCell(Text(createdAtStr)),
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
                              onPressed: () => _showDetailDialog(reaction),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              color: Colors.red,
                              tooltip: 'Xóa',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _confirmDelete(reaction),
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

  void _showDetailDialog(Map<String, dynamic> reaction) {
    final createdAt = reaction['createdAt'];
    final createdAtStr =
        createdAt != null && createdAt is Timestamp
            ? '${createdAt.toDate().day.toString().padLeft(2, '0')}/${createdAt.toDate().month.toString().padLeft(2, '0')}/${createdAt.toDate().year} ${createdAt.toDate().hour.toString().padLeft(2, '0')}:${createdAt.toDate().minute.toString().padLeft(2, '0')}'
            : '-';

    final userId = reaction['userId'] ?? '';
    final userName = _userNames[userId] ?? 'Không rõ';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.emoji_emotions, color: AppColors.primaryGreen),
                const SizedBox(width: 12),
                const Expanded(child: Text('Chi tiết Biểu cảm')),
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
                    _buildDetailRow(
                      'Loại biểu cảm',
                      '${_getReactionIcon(reaction['reactionType'])} ${_getReactionText(reaction['reactionType'])}',
                    ),
                    const Divider(height: 24),
                    _buildDetailRow('Người dùng', userName),
                    _buildDetailRow('User ID', userId),
                    const Divider(height: 24),
                    _buildDetailRow(
                      'Loại đối tượng',
                      _getTargetTypeText(reaction['targetType']),
                    ),
                    _buildDetailRow(
                      'ID đối tượng',
                      reaction['targetId'] ?? '-',
                    ),
                    const Divider(height: 24),
                    _buildDetailRow('Ngày tạo', createdAtStr),
                    _buildDetailRow('ID', reaction['id'] ?? '-'),
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

  void _confirmDelete(Map<String, dynamic> reaction) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: Text(
              'Bạn có chắc muốn xóa biểu cảm ${_getReactionText(reaction['reactionType'])} của ${_userNames[reaction['userId']] ?? reaction['userId']}?',
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
                    'reactions',
                    reaction['id'],
                  );

                  if (result) {
                    if (mounted)
                      ToastHelper.showSuccess(context, 'Xóa thành công');
                    _loadReactions();
                  } else {
                    if (mounted) ToastHelper.showError(context, 'Lỗi khi xóa');
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
