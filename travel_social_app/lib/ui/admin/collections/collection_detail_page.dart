import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/admin_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/toast_helper.dart';
import 'widgets/lazy_network_image.dart';
import 'widgets/collection_config.dart';

/// Trang chi tiết Collection với CRUD operations
class CollectionDetailPage extends StatefulWidget {
  final String collectionName;

  const CollectionDetailPage({super.key, required this.collectionName});

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;
  String _searchQuery = '';

  // Cache để lưu thông tin user (userId -> user data)
  final Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final docs = await _adminService.getCollectionData(
      widget.collectionName,
      limit: 100,
    );

    // Load user data cho các userId trong documents
    await _loadUserData(docs);

    if (!mounted) return;
    setState(() {
      _documents = docs;
      _isLoading = false;
    });
  }

  /// Load thông tin user từ các userId trong documents
  Future<void> _loadUserData(List<Map<String, dynamic>> docs) async {
    final userIds = <String>{};

    // Thu thập tất cả userId từ documents
    for (var doc in docs) {
      if (doc['userId'] != null) userIds.add(doc['userId'].toString());
      if (doc['userId1'] != null) userIds.add(doc['userId1'].toString());
      if (doc['userId2'] != null) userIds.add(doc['userId2'].toString());
      if (doc['callerId'] != null) userIds.add(doc['callerId'].toString());
      if (doc['adminId'] != null) userIds.add(doc['adminId'].toString());
      if (doc['proposedBy'] != null) userIds.add(doc['proposedBy'].toString());
      if (doc['senderId'] != null) userIds.add(doc['senderId'].toString());
      if (doc['groupAdmin'] != null) userIds.add(doc['groupAdmin'].toString());
      if (doc['reporterId'] != null) userIds.add(doc['reporterId'].toString());

      // Xử lý receiverIds, members, memberIds (array)
      for (var arrayField in ['receiverIds', 'members', 'memberIds']) {
        if (doc[arrayField] is List) {
          for (var id in doc[arrayField]) {
            if (id != null) userIds.add(id.toString());
          }
        }
      }
    }

    debugPrint('🔍 Found ${userIds.length} unique userIds to load');

    // Load thông tin user cho các userId chưa có trong cache
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
            debugPrint('✅ Loaded user $userId: ${_userCache[userId]?['name']}');
          } else {
            debugPrint('⚠️ User $userId not found in users collection');
            // Thêm vào cache với empty data để tránh load lại
            _userCache[userId] = {'name': 'User không tồn tại ($userId)'};
          }
        } catch (e) {
          debugPrint('❌ Error loading user $userId: $e');
          // Thêm vào cache với error message
          _userCache[userId] = {'name': 'Lỗi load user ($userId)'};
        }
      }
    }
  }

  /// Lấy tên hiển thị từ userId
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

  /// Lấy danh sách tên từ array userIds
  String _getUserNames(List<dynamic>? userIds) {
    if (userIds == null || userIds.isEmpty) return '-';
    return userIds.map((id) => _getUserDisplayName(id.toString())).join(', ');
  }

  Future<void> _deleteDocument(String docId) async {
    final doc = _documents.firstWhere(
      (d) => d['id'] == docId,
      orElse: () => {},
    );

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
                  'Bạn có chắc muốn xóa document này?',
                  style: TextStyle(
                    color: AppTheme.getTextPrimaryColor(context),
                  ),
                ),
                SizedBox(
                  height: AppSizes.padding(context, SizeCategory.medium),
                ),
                Text(
                  '⚠️ Các ảnh liên quan cũng sẽ bị xóa khỏi Storage',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: AppSizes.font(context, SizeCategory.small),
                    fontWeight: FontWeight.w500,
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

    // Show modal loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          ),
    );

    try {
      await _deleteImagesFromStorage(doc);
      await _adminService.deleteDocument(widget.collectionName, docId);

      if (!mounted) return;
      Navigator.of(context).pop(); // close loading

      ToastHelper.showSuccess(context, '✅ Xóa thành công (bao gồm cả ảnh)');
      _loadDocuments();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading

      ToastHelper.showError(context, '❌ Lỗi: $e');
    }
  }

  Future<void> _deleteImagesFromStorage(Map<String, dynamic> doc) async {
    try {
      final storage = FirebaseStorage.instance;
      final List<String> imageUrls = [];

      doc.forEach((key, value) {
        if (value is String && _isFirebaseStorageUrl(value)) {
          imageUrls.add(value);
        } else if (value is List) {
          for (var item in value) {
            if (item is String && _isFirebaseStorageUrl(item)) {
              imageUrls.add(item);
            }
          }
        }
      });

      for (var url in imageUrls) {
        try {
          final ref = storage.refFromURL(url);
          await ref.delete();
        } catch (e) {
          debugPrint('⚠️ Could not delete image $url: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error deleting images from storage: $e');
    }
  }

  bool _isFirebaseStorageUrl(String url) {
    return url.startsWith('https://firebasestorage.googleapis.com/') ||
        url.startsWith('gs://');
  }

  @override
  Widget build(BuildContext context) {
    final filteredDocs =
        _documents.where((doc) {
          if (_searchQuery.isEmpty) return true;
          final searchLower = _searchQuery.toLowerCase();
          return doc.values.any(
            (value) => value.toString().toLowerCase().contains(searchLower),
          );
        }).toList();

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.collectionName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDocuments,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.darkTextPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Tạo mới'),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(
              AppSizes.padding(context, SizeCategory.medium),
            ),
            child: TextField(
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
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                      ),
                    )
                    : filteredDocs.isEmpty
                    ? Center(
                      child: Text(
                        'Không có dữ liệu',
                        style: TextStyle(
                          color: AppTheme.getTextSecondaryColor(context),
                        ),
                      ),
                    )
                    : _buildDataTable(filteredDocs),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(List<Map<String, dynamic>> docs) {
    if (docs.isEmpty) return const SizedBox();

    final firstDoc = docs.first;
    final preferredOrder = CollectionConfig.getPreferredOrder(
      widget.collectionName,
    );
    final columnTitles = CollectionConfig.getColumnTitles(
      widget.collectionName,
    );

    // Lọc các cột để hiển thị
    final existingKeys =
        firstDoc.keys
            .where(
              (k) =>
                  !CollectionConfig.shouldHideField(widget.collectionName, k),
            )
            .toList();

    final columns = <String>[
      ...preferredOrder.where(existingKeys.contains),
      ...existingKeys.where((k) => !preferredOrder.contains(k)),
    ];

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
            minWidth: 900,
            headingRowColor: MaterialStateProperty.all(
              AppColors.primaryGreen.withOpacity(0.2),
            ),
            headingTextStyle: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontSize: AppSizes.font(context, SizeCategory.medium),
            ),
            dataTextStyle: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.medium),
              color: AppTheme.getTextPrimaryColor(context),
            ),
            columns: [
              ...columns.map(
                (key) => DataColumn2(
                  label: Text(columnTitles[key] ?? key),
                  size:
                      (key == 'bio' ||
                              key == 'email' ||
                              key == 'address' ||
                              key == 'content' ||
                              key == 'description' ||
                              key == 'violationReason')
                          ? ColumnSize.L
                          : ColumnSize.M,
                ),
              ),
              const DataColumn2(
                label: Text('Hành động'),
                size: ColumnSize.S,
                fixedWidth: 120,
              ),
            ],
            rows:
                docs.map((doc) {
                  final docId = doc['id'] ?? '';
                  final rowIndex = docs.indexOf(doc);
                  return DataRow2(
                    color: MaterialStateProperty.resolveWith((states) {
                      if (states.contains(MaterialState.hovered)) {
                        return AppColors.primaryGreen.withOpacity(0.06);
                      }
                      return rowIndex.isEven
                          ? AppTheme.getBackgroundColor(context)
                          : AppTheme.getSurfaceColor(context);
                    }),
                    cells: [
                      ...columns.map(
                        (key) => _buildDataCell(key, doc[key], doc),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility, size: 18),
                              color: AppColors.primaryGreen,
                              onPressed: () => _showDetailDialog(doc),
                              tooltip: 'Xem',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              color: Colors.blue,
                              onPressed: () => _showEditDialog(doc),
                              tooltip: 'Sửa',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              color: Colors.red,
                              onPressed: () => _deleteDocument(docId),
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

  DataCell _buildDataCell(String key, dynamic value, Map<String, dynamic> doc) {
    // Avatar image
    if (key.toLowerCase().contains('avatar') &&
        value != null &&
        value.toString().isNotEmpty &&
        value.toString().startsWith('http')) {
      return DataCell(
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.grey.shade200,
          child: ClipOval(
            child: Image.network(
              value.toString(),
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.person, size: 18, color: Colors.grey[600]);
              },
            ),
          ),
        ),
        onTap: () => _showDetailDialog(doc),
      );
    }

    // Images/mediaUrls thumbnail
    if ((key == 'images' || key == 'mediaUrls') && value != null) {
      List images = value is List ? value : [value];
      final firstImage = images
          .map((e) => e?.toString() ?? '')
          .firstWhere((url) => url.startsWith('http'), orElse: () => '');

      if (firstImage.isNotEmpty) {
        return DataCell(
          InkWell(
            onTap: () => _showDetailDialog(doc),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                firstImage,
                width: 70,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 70,
                    height: 50,
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image,
                      size: 20,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      }
    }

    // Status chips for violations
    if (key == 'status' &&
        (widget.collectionName == 'violationRequests' ||
            widget.collectionName == 'userViolations')) {
      return _buildStatusChip(value);
    }

    // ActionLevel chip for userViolations
    if (key == 'actionLevel' && widget.collectionName == 'userViolations') {
      return _buildActionLevelChip(value);
    }

    // Role chip
    if (key == 'role') {
      return _buildRoleChip(value);
    }

    // Rank chip
    if (key == 'rank') {
      return DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _formatCellValue(key, value),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        onTap: () => _showDetailDialog(doc),
      );
    }

    // Points with star
    if (key == 'points') {
      return DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, size: 16, color: Colors.amber),
            const SizedBox(width: 4),
            Text(
              _formatCellValue(key, value),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        onTap: () => _showDetailDialog(doc),
      );
    }

    // Default text cell
    return DataCell(
      SizedBox(
        width:
            key == 'bio' || key == 'email'
                ? 260
                : key.toLowerCase().contains('id')
                ? 150
                : 120,
        child: Text(
          _formatCellValue(key, value),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ),
      onTap: () => _showDetailDialog(doc),
    );
  }

  DataCell _buildStatusChip(dynamic value) {
    final status = (value ?? 'pending').toString();
    Color bg;
    String displayText;

    switch (status) {
      case 'pending':
        bg = Colors.orange.shade100;
        displayText = 'Chờ xử lý';
        break;
      case 'approved':
        bg = Colors.green.shade100;
        displayText = 'Đã duyệt';
        break;
      case 'rejected':
        bg = Colors.red.shade100;
        displayText = 'Từ chối';
        break;
      case 'active':
        bg = Colors.red.shade100;
        displayText = 'Đang hiệu lực';
        break;
      case 'expired':
        bg = Colors.grey.shade100;
        displayText = 'Hết hạn';
        break;
      default:
        bg = Colors.grey.shade100;
        displayText = status;
    }

    return DataCell(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          displayText,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.darkTextPrimary,
          ),
        ),
      ),
    );
  }

  DataCell _buildActionLevelChip(dynamic value) {
    final actionLevel = (value ?? 'warning').toString();
    Color bg;
    String displayText;
    IconData icon;

    switch (actionLevel) {
      case 'warning':
        bg = Colors.orange.shade100;
        displayText = 'Cảnh báo';
        icon = Icons.warning;
        break;
      case 'ban':
        bg = Colors.red.shade100;
        displayText = 'Cấm';
        icon = Icons.block;
        break;
      case 'delete':
        bg = Colors.red.shade300;
        displayText = 'Xóa';
        icon = Icons.delete_forever;
        break;
      default:
        bg = Colors.grey.shade100;
        displayText = actionLevel;
        icon = Icons.info;
    }

    return DataCell(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.darkTextPrimary),
            const SizedBox(width: 4),
            Text(
              displayText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.darkTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataCell _buildRoleChip(dynamic value) {
    final role = (value ?? 'user').toString();
    Color bg;

    switch (role) {
      case 'admin':
        bg = Colors.red.shade100;
        break;
      case 'mod':
        bg = Colors.blue.shade100;
        break;
      default:
        bg = Colors.green.shade100;
    }

    return DataCell(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          role,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.darkTextPrimary,
          ),
        ),
      ),
    );
  }

  String _formatCellValue(String key, dynamic value) {
    return CollectionConfig.formatCellValue(
      key,
      value,
      widget.collectionName,
      _getUserDisplayName,
      _getUserNames,
    );
  }

  // ==================== DIALOGS ====================

  void _showDetailDialog(Map<String, dynamic> doc) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 600 ? 500.0 : screenWidth * 0.9;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            child: Container(
              width: dialogWidth,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(
                      AppSizes.padding(context, SizeCategory.medium),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(
                          AppSizes.radius(context, SizeCategory.small),
                        ),
                        topRight: Radius.circular(
                          AppSizes.radius(context, SizeCategory.small),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Chi tiết Document',
                            style: TextStyle(
                              color: AppColors.darkTextPrimary,
                              fontSize: AppSizes.font(
                                context,
                                SizeCategory.large,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.darkTextPrimary,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Container(
                      color: AppTheme.getBackgroundColor(context),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(
                          AppSizes.padding(context, SizeCategory.medium),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children:
                              doc.entries.map((entry) {
                                return _buildDetailField(
                                  entry.key,
                                  entry.value,
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildDetailField(String key, dynamic value) {
    return Container(
      margin: EdgeInsets.only(
        bottom: AppSizes.padding(context, SizeCategory.medium),
      ),
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSizes.padding(context, SizeCategory.small),
              vertical: AppSizes.padding(context, SizeCategory.small) / 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(
                AppSizes.radius(context, SizeCategory.small),
              ),
            ),
            child: Text(
              key,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: AppSizes.font(context, SizeCategory.medium),
                color: AppColors.primaryGreen,
              ),
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.small)),
          _buildValueWidget(key, value),
        ],
      ),
    );
  }

  Widget _buildValueWidget(String key, dynamic value) {
    // Image URL
    if ((key.toLowerCase().contains('image') ||
            key.toLowerCase().contains('avatar') ||
            key.toLowerCase().contains('photo') ||
            key.toLowerCase().contains('url')) &&
        value is String &&
        value.isNotEmpty) {
      final isValidUrl =
          value.startsWith('http://') ||
          value.startsWith('https://') ||
          value.startsWith('gs://');

      if (isValidUrl) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LazyNetworkImage(
              imageUrl: value,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(
                AppSizes.radius(context, SizeCategory.medium),
              ),
            ),
            SizedBox(height: AppSizes.padding(context, SizeCategory.small)),
            Container(
              padding: EdgeInsets.all(
                AppSizes.padding(context, SizeCategory.small),
              ),
              decoration: BoxDecoration(
                color: AppTheme.getInputBackgroundColor(context),
                borderRadius: BorderRadius.circular(
                  AppSizes.radius(context, SizeCategory.small),
                ),
              ),
              child: SelectableText(
                value,
                style: TextStyle(
                  fontSize: AppSizes.font(context, SizeCategory.small),
                  color: AppTheme.getTextSecondaryColor(context),
                ),
              ),
            ),
          ],
        );
      }
    }

    // List of images
    if (value is List && value.isNotEmpty) {
      final isImageField =
          key.toLowerCase().contains('image') ||
          key.toLowerCase().contains('avatar') ||
          key.toLowerCase().contains('photo');

      final firstItem = value.first;
      final hasImageUrls =
          firstItem is String &&
          (firstItem.startsWith('http://') ||
              firstItem.startsWith('https://') ||
              firstItem.startsWith('gs://'));

      if (isImageField && hasImageUrls) {
        return _buildImageGrid(value.cast<String>());
      }

      // Otherwise show as list
      return Container(
        padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
        decoration: BoxDecoration(
          color: AppTheme.getInputBackgroundColor(context),
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              value.asMap().entries.map((e) {
                return Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: AppSizes.padding(context, SizeCategory.small) / 2,
                  ),
                  child: Text(
                    '${e.key + 1}. ${e.value}',
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.medium),
                      color: AppTheme.getTextPrimaryColor(context),
                    ),
                  ),
                );
              }).toList(),
        ),
      );
    }

    // Map
    if (value is Map) {
      return Container(
        padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
        decoration: BoxDecoration(
          color: AppTheme.getInputBackgroundColor(context),
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              value.entries.map((e) {
                return Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: AppSizes.padding(context, SizeCategory.small) / 2,
                  ),
                  child: Text(
                    '${e.key}: ${e.value}',
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.medium),
                      color: AppTheme.getTextPrimaryColor(context),
                    ),
                  ),
                );
              }).toList(),
        ),
      );
    }

    // Default text
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
      decoration: BoxDecoration(
        color: AppTheme.getInputBackgroundColor(context),
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
      ),
      child: SelectableText(
        value.toString(),
        style: TextStyle(
          fontSize: AppSizes.font(context, SizeCategory.medium),
          color: AppTheme.getTextPrimaryColor(context),
        ),
      ),
    );
  }

  Widget _buildImageGrid(List<String> images) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSizes.padding(context, SizeCategory.small),
        mainAxisSpacing: AppSizes.padding(context, SizeCategory.small),
        childAspectRatio: 1.0,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return LazyNetworkImage(
          imageUrl: images[index],
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
        );
      },
    );
  }

  dynamic _parseFieldValue(String fieldName, String value) {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty || trimmedValue.toLowerCase() == 'null') {
      return null;
    }

    switch (fieldName.toLowerCase()) {
      case 'phonenumber':
      case 'phone':
        return trimmedValue;

      case 'datebirth':
        try {
          DateTime? date;
          if (trimmedValue.contains('-')) {
            date = DateTime.tryParse(trimmedValue);
          } else if (trimmedValue.contains('/')) {
            final parts = trimmedValue.split('/');
            if (parts.length == 3) {
              date = DateTime(
                int.parse(parts[2]),
                int.parse(parts[1]),
                int.parse(parts[0]),
              );
            }
          }
          return date != null ? Timestamp.fromDate(date) : null;
        } catch (e) {
          return null;
        }

      case 'createdat':
      case 'created_at':
        try {
          final date = DateTime.tryParse(trimmedValue);
          return date != null
              ? Timestamp.fromDate(date)
              : Timestamp.fromDate(DateTime.now());
        } catch (e) {
          return Timestamp.fromDate(DateTime.now());
        }

      case 'points':
        return int.tryParse(trimmedValue) ?? 0;

      default:
        return trimmedValue;
    }
  }

  void _showCreateDialog() {
    final formKey = GlobalKey<FormState>();
    final Map<String, TextEditingController> controllers = {};

    final sampleFields =
        _documents.isNotEmpty
            ? _documents.first.keys.where((k) => k != 'id').toList()
            : ['name', 'description'];

    for (var field in sampleFields) {
      controllers[field] = TextEditingController();
    }

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(
                      AppSizes.padding(context, SizeCategory.large),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(
                          AppSizes.radius(context, SizeCategory.large),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.add_circle,
                          color: AppColors.darkTextPrimary,
                        ),
                        SizedBox(
                          width: AppSizes.padding(context, SizeCategory.medium),
                        ),
                        Expanded(
                          child: Text(
                            'Tạo document mới',
                            style: TextStyle(
                              color: AppColors.darkTextPrimary,
                              fontSize: AppSizes.font(
                                context,
                                SizeCategory.large,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.darkTextPrimary,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: AppTheme.getBackgroundColor(context),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(
                          AppSizes.padding(context, SizeCategory.large),
                        ),
                        child: Form(
                          key: formKey,
                          child: Column(
                            children:
                                sampleFields.map((field) {
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: AppSizes.padding(
                                        context,
                                        SizeCategory.medium,
                                      ),
                                    ),
                                    child: TextFormField(
                                      controller: controllers[field],
                                      style: TextStyle(
                                        color: AppTheme.getTextPrimaryColor(
                                          context,
                                        ),
                                      ),
                                      decoration: InputDecoration(
                                        labelText: field,
                                        labelStyle: TextStyle(
                                          color: AppTheme.getTextSecondaryColor(
                                            context,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor:
                                            AppTheme.getInputBackgroundColor(
                                              context,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppSizes.radius(
                                              context,
                                              SizeCategory.medium,
                                            ),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppSizes.radius(
                                              context,
                                              SizeCategory.medium,
                                            ),
                                          ),
                                          borderSide: BorderSide(
                                            color: AppTheme.getInputBorderColor(
                                              context,
                                            ),
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (!field.toLowerCase().contains(
                                              'phone',
                                            ) &&
                                            !field.toLowerCase().contains(
                                              'datebirth',
                                            ) &&
                                            (value == null ||
                                                value.trim().isEmpty)) {
                                          return 'Vui lòng nhập $field';
                                        }
                                        return null;
                                      },
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(
                      AppSizes.padding(context, SizeCategory.large),
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.getSurfaceColor(context),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(
                          AppSizes.radius(context, SizeCategory.large),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.getTextPrimaryColor(
                                context,
                              ),
                              side: BorderSide(
                                color: AppTheme.getBorderColor(context),
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: AppSizes.padding(
                                  context,
                                  SizeCategory.medium,
                                ),
                              ),
                            ),
                            child: const Text('Hủy'),
                          ),
                        ),
                        SizedBox(
                          width: AppSizes.padding(context, SizeCategory.medium),
                        ),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                final data = <String, dynamic>{};
                                controllers.forEach((key, controller) {
                                  data[key] = _parseFieldValue(
                                    key,
                                    controller.text,
                                  );
                                });

                                final docId = await _adminService.addDocument(
                                  widget.collectionName,
                                  data,
                                );

                                if (context.mounted) {
                                  Navigator.pop(context);

                                  if (docId != null) {
                                    ToastHelper.showSuccess(
                                      context,
                                      '✅ Tạo thành công!',
                                    );
                                    _loadDocuments();
                                  } else {
                                    ToastHelper.showError(
                                      context,
                                      '❌ Lỗi tạo document',
                                    );
                                  }
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: AppColors.darkTextPrimary,
                              padding: EdgeInsets.symmetric(
                                vertical: AppSizes.padding(
                                  context,
                                  SizeCategory.medium,
                                ),
                              ),
                            ),
                            child: const Text('Tạo'),
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

  void _showEditDialog(Map<String, dynamic> doc) {
    final formKey = GlobalKey<FormState>();
    final Map<String, TextEditingController> controllers = {};
    final docId = doc['id'] as String;

    doc.forEach((key, value) {
      if (key != 'id' && value is! Map && value is! List) {
        String displayValue = '';

        if (value == null) {
          displayValue = '';
        } else if (value is Timestamp) {
          final date = value.toDate();
          displayValue =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        } else {
          displayValue = value.toString();
        }

        controllers[key] = TextEditingController(text: displayValue);
      }
    });

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(
                      AppSizes.padding(context, SizeCategory.large),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(
                          AppSizes.radius(context, SizeCategory.large),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit,
                          color: AppColors.darkTextPrimary,
                        ),
                        SizedBox(
                          width: AppSizes.padding(context, SizeCategory.medium),
                        ),
                        Expanded(
                          child: Text(
                            'Chỉnh sửa document',
                            style: TextStyle(
                              color: AppColors.darkTextPrimary,
                              fontSize: AppSizes.font(
                                context,
                                SizeCategory.large,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.darkTextPrimary,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: AppTheme.getBackgroundColor(context),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(
                          AppSizes.padding(context, SizeCategory.large),
                        ),
                        child: Form(
                          key: formKey,
                          child: Column(
                            children:
                                controllers.entries.map((entry) {
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: AppSizes.padding(
                                        context,
                                        SizeCategory.medium,
                                      ),
                                    ),
                                    child: TextFormField(
                                      controller: entry.value,
                                      style: TextStyle(
                                        color: AppTheme.getTextPrimaryColor(
                                          context,
                                        ),
                                      ),
                                      decoration: InputDecoration(
                                        labelText: entry.key,
                                        labelStyle: TextStyle(
                                          color: AppTheme.getTextSecondaryColor(
                                            context,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor:
                                            AppTheme.getInputBackgroundColor(
                                              context,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppSizes.radius(
                                              context,
                                              SizeCategory.medium,
                                            ),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppSizes.radius(
                                              context,
                                              SizeCategory.medium,
                                            ),
                                          ),
                                          borderSide: BorderSide(
                                            color: AppTheme.getInputBorderColor(
                                              context,
                                            ),
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (!entry.key.toLowerCase().contains(
                                              'phone',
                                            ) &&
                                            !entry.key.toLowerCase().contains(
                                              'datebirth',
                                            ) &&
                                            (value == null ||
                                                value.trim().isEmpty)) {
                                          return 'Vui lòng nhập ${entry.key}';
                                        }
                                        return null;
                                      },
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(
                      AppSizes.padding(context, SizeCategory.large),
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.getSurfaceColor(context),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(
                          AppSizes.radius(context, SizeCategory.large),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.getTextPrimaryColor(
                                context,
                              ),
                              side: BorderSide(
                                color: AppTheme.getBorderColor(context),
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: AppSizes.padding(
                                  context,
                                  SizeCategory.medium,
                                ),
                              ),
                            ),
                            child: const Text('Hủy'),
                          ),
                        ),
                        SizedBox(
                          width: AppSizes.padding(context, SizeCategory.medium),
                        ),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                final data = <String, dynamic>{};
                                controllers.forEach((key, controller) {
                                  data[key] = _parseFieldValue(
                                    key,
                                    controller.text,
                                  );
                                });

                                final success = await _adminService
                                    .updateDocument(
                                      widget.collectionName,
                                      docId,
                                      data,
                                    );

                                if (context.mounted) {
                                  Navigator.pop(context);

                                  if (success) {
                                    ToastHelper.showSuccess(
                                      context,
                                      '✅ Cập nhật thành công!',
                                    );
                                    _loadDocuments();
                                  } else {
                                    ToastHelper.showError(
                                      context,
                                      '❌ Lỗi cập nhật document',
                                    );
                                  }
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: AppColors.darkTextPrimary,
                              padding: EdgeInsets.symmetric(
                                vertical: AppSizes.padding(
                                  context,
                                  SizeCategory.medium,
                                ),
                              ),
                            ),
                            child: const Text('Lưu'),
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
}
