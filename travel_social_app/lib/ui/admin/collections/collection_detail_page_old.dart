import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/admin_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/toast_helper.dart';

/// Helper widget cho lazy loading images với rate limit protection
class _LazyNetworkImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const _LazyNetworkImage({
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  State<_LazyNetworkImage> createState() => _LazyNetworkImageState();
}

class _LazyNetworkImageState extends State<_LazyNetworkImage> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    // Calculate safe cache width (avoid infinity)
    int? getCacheWidth() {
      if (widget.width == null) return 800;
      if (widget.width!.isInfinite) return 800;
      return widget.width!.toInt();
    }

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
      child: Image.network(
        widget.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
        cacheWidth: getCacheWidth(),
        errorBuilder: (context, error, stackTrace) {
          // Dùng WidgetsBinding để schedule setState sau khi build xong
          if (!_hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                });
              }
            });
          }

          final isRateLimit = error.toString().contains('429');

          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: AppTheme.getInputBackgroundColor(context),
              border: Border.all(color: AppTheme.getBorderColor(context)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isRateLimit ? Icons.hourglass_empty : Icons.broken_image,
                  color:
                      isRateLimit
                          ? AppColors.warning
                          : AppTheme.getIconSecondaryColor(context),
                  size:
                      widget.height != null && widget.height! < 150
                          ? 24
                          : AppSizes.icon(context, SizeCategory.xlarge),
                ),
                if (widget.height == null || widget.height! >= 150) ...[
                  SizedBox(
                    height: AppSizes.padding(context, SizeCategory.small),
                  ),
                  Text(
                    isRateLimit ? 'Quá nhiều yêu cầu' : 'Lỗi tải ảnh',
                    style: TextStyle(
                      color: AppTheme.getTextSecondaryColor(context),
                      fontSize: AppSizes.font(context, SizeCategory.small),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: widget.width,
            height: widget.height,
            color: AppTheme.getInputBackgroundColor(context),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryGreen,
                value:
                    loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

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
      // Kiểm tra các field có thể chứa userId
      if (doc['userId'] != null) userIds.add(doc['userId'].toString());
      if (doc['userId1'] != null) userIds.add(doc['userId1'].toString());
      if (doc['userId2'] != null) userIds.add(doc['userId2'].toString());
      if (doc['callerId'] != null) userIds.add(doc['callerId'].toString());
      if (doc['adminId'] != null) userIds.add(doc['adminId'].toString());
      if (doc['proposedBy'] != null) userIds.add(doc['proposedBy'].toString());
      if (doc['senderId'] != null) userIds.add(doc['senderId'].toString());
      if (doc['groupAdmin'] != null) userIds.add(doc['groupAdmin'].toString());

      // Xử lý receiverIds (array)
      if (doc['receiverIds'] is List) {
        for (var id in doc['receiverIds']) {
          if (id != null) userIds.add(id.toString());
        }
      }

      // Xử lý members (array)
      if (doc['members'] is List) {
        for (var id in doc['members']) {
          if (id != null) userIds.add(id.toString());
        }
      }

      // Xử lý memberIds (array)
      if (doc['memberIds'] is List) {
        for (var id in doc['memberIds']) {
          if (id != null) userIds.add(id.toString());
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
            final userData = userDoc.data() ?? {};
            _userCache[userId] = userData;

            // Debug: In ra tất cả các field của user
            debugPrint('✅ Loaded user: $userId');
            debugPrint('   User data fields: ${userData.keys.toList()}');
            debugPrint('   displayName: ${userData['displayName']}');
            debugPrint('   fullName: ${userData['fullName']}');
            debugPrint('   username: ${userData['username']}');
            debugPrint('   name: ${userData['name']}');
          } else {
            debugPrint('❌ User not found: $userId');
          }
        } catch (e) {
          debugPrint('❌ Error loading user $userId: $e');
        }
      }
    }

    debugPrint('📦 User cache size: ${_userCache.length}');
  }

  /// Lấy tên hiển thị từ userId
  String _getUserDisplayName(String? userId) {
    if (userId == null || userId.isEmpty) return '-';

    final userData = _userCache[userId];
    if (userData == null) {
      debugPrint('⚠️ User not in cache: $userId');
      return userId; // Fallback to userId
    }

    // Ưu tiên: name > displayName > fullName > username > email > userId
    final displayName =
        userData['name']?.toString() ??
        userData['displayName']?.toString() ??
        userData['fullName']?.toString() ??
        userData['username']?.toString() ??
        userData['email']?.toString() ??
        userId;

    debugPrint('👤 Displaying user $userId as: $displayName');
    return displayName;
  }

  /// Lấy danh sách tên từ array userIds
  String _getUserNames(List<dynamic>? userIds) {
    if (userIds == null || userIds.isEmpty) return '-';

    final names =
        userIds.map((id) {
          return _getUserDisplayName(id.toString());
        }).toList();

    return names.join(', ');
  }

  Future<void> _deleteDocument(String docId) async {
    // Tìm document để lấy thông tin ảnh trước khi xóa
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

    if (confirmed == true) {
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
        // Xóa các ảnh trước
        await _deleteImagesFromStorage(doc);

        // Sau đó xóa document
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
  }

  /// Xóa tất cả ảnh từ Storage dựa trên document data
  Future<void> _deleteImagesFromStorage(Map<String, dynamic> doc) async {
    try {
      final storage = FirebaseStorage.instance;
      final List<String> imageUrls = [];

      // Tìm tất cả các fields chứa URL ảnh
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

      // Xóa từng ảnh
      for (var url in imageUrls) {
        try {
          final ref = storage.refFromURL(url);
          await ref.delete();
          debugPrint('✅ Deleted image: $url');
        } catch (e) {
          debugPrint('⚠️ Could not delete image $url: $e');
          // Tiếp tục xóa các ảnh khác ngay cả khi có lỗi
        }
      }

      if (imageUrls.isNotEmpty) {
        debugPrint('✅ Deleted ${imageUrls.length} image(s) from Storage');
      }
    } catch (e) {
      debugPrint('❌ Error deleting images from storage: $e');
      // Không throw error để vẫn tiếp tục xóa document
    }
  }

  /// Kiểm tra xem URL có phải là Firebase Storage URL không
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

    // Lấy tất cả các keys từ document đầu tiên
    final firstDoc = docs.first;

    // Cấu hình cột tùy theo collection
    late final List<String> preferredOrder;
    final Map<String, String> columnTitles = {
      'id': 'ID',
      'name':
          widget.collectionName == 'tourismTypes'
              ? 'Tên loại hình'
              : widget.collectionName == 'communities'
              ? 'Tên cộng đồng'
              : 'Tên người dùng',
      'email': 'Email',
      'avatarUrl': 'Ảnh đại diện',
      'bio': 'Giới thiệu',
      'rank': 'Hạng',
      'dateBirth': 'Ngày sinh',
      'role': 'Vai trò',
      'points': 'Điểm',
      'phoneNumber': 'SĐT',
      'createdAt': 'Ngày tạo',
      // placeEditRequests
      'placeName': 'Tên địa điểm',
      'address': 'Địa chỉ',
      'typeName': 'Loại hình',
      'proposedBy': 'Người đề xuất',
      'status': 'Trạng thái',
      'content': 'Nội dung',
      'location': 'Tọa độ',
      'approvedAt': 'Ngày duyệt',
      'createAt': 'Ngày tạo yêu cầu',
      // tourismTypes
      'typeId': 'Mã loại hình',
      'description': 'Mô tả',
      // reviews
      // 'userId': 'Người đánh giá', // Đã Việt hóa chung: 'Người đăng' cho posts, 'Người đánh giá' cho reviews
      'checkedInAt': 'Thời gian check-in',
      'isCheckedIn': 'Đã check-in',
      'rating': 'Đánh giá',
      'images': 'Hình ảnh',
      // posts
      'reviewId': 'Mã bài viết',
      'userId': 'Người đăng',
      'placeId': 'Địa điểm',
      'type': 'Loại bài',
      // 'content': 'Nội dung', // Đã Việt hóa chung cho cả reviews và posts
      'mediaUrls': 'Hình ảnh',
      'likeCount': 'Lượt thích',
      'commentCount': 'Bình luận',
      // 'createdAt': 'Ngày tạo', // Đã Việt hóa chung cho tất cả collections
      'updatedAt': 'Ngày cập nhật',
      // notifications
      'title': 'Tiêu đề',
      'body': 'Nội dung',
      'isRead': 'Đã đọc',
      'imageUrl': 'Ảnh',
      'data': 'Dữ liệu kỹ thuật',
      // communities
      'adminId': 'Quản trị viên',
      'memberCount': 'Số thành viên',
      'postCount': 'Số bài viết',
      'memberIds': 'Danh sách thành viên',
      'pendingRequests': 'Yêu cầu chờ',
      'tourismTypes': 'Loại hình du lịch',
      'rules': 'Quy tắc',
      'coverImageUrl': 'Ảnh bìa',
      // chats
      'chatType': 'Loại',
      'groupName': 'Tên nhóm',
      'groupAvatar': 'Ảnh đại diện',
      'groupBackground': 'Ảnh nền',
      'groupAdmin': 'Quản trị viên',
      'isPublic': 'Công khai',
      'members': 'Thành viên',
      'lastMessage': 'Tin nhắn cuối',
      'lastMessageSenderId': 'Người gửi cuối',
      'lastMessageTime': 'Thời gian tin nhắn',
      'lastMessageImageCount': 'Số ảnh',
      'backgroundImages': 'Ảnh nền chat',
      // calls
      'callType': 'Loại',
      'callStatus': 'Trạng thái',
      'callerId': 'Người gọi',
      'receiverIds': 'Người nhận',
      'duration': 'Thời lượng',
      'answeredAt': 'Thời gian trả lời',
      'endedAt': 'Thời gian kết thúc',
      'agoraChannelName': 'Kênh Agora',
      'agoraToken': 'Token Agora',
      // friendships
      'userId1': 'Người dùng 1',
      'userId2': 'Người dùng 2',
      // reactions
      'reactionType': 'Loại biểu cảm',
      'targetType': 'Loại đối tượng',
      'targetId': 'ID đối tượng',
      // violationRequests
      'objectType': 'Loại đối tượng',
      'violationType': 'Loại vi phạm',
      'reporterId': 'Người báo cáo',
      'violationReason': 'Lý do vi phạm',
      'reviewedAt': 'Thời gian xét duyệt',
      'reviewNote': 'Ghi chú admin',
      // userViolations
      'actionLevel': 'Mức độ xử lý',
      'warningCount': 'Số lần cảnh báo',
      'penaltyPoints': 'Điểm trừ phạt',
      'bannedUntil': 'Cấm đến',
      'violatedObjectId': 'ID đối tượng vi phạm',
    };

    if (widget.collectionName == 'chats') {
      // Chỉ hiển thị các cột cần thiết cho chats
      preferredOrder = [
        'groupAvatar',
        'groupName',
        'chatType',
        'isPublic',
        'members',
        'lastMessage',
        'createdAt',
      ];
    } else if (widget.collectionName == 'calls') {
      preferredOrder = [
        'callType',
        'callStatus',
        'callerId',
        'receiverIds',
        'duration',
        'createdAt',
        'answeredAt',
        'endedAt',
      ];
    } else if (widget.collectionName == 'friendships') {
      preferredOrder = [
        'userId1',
        'userId2',
        'status',
        'createdAt',
        'updatedAt',
      ];
    } else if (widget.collectionName == 'reactions') {
      preferredOrder = [
        'reactionType',
        'userId',
        'targetType',
        'targetId',
        'createdAt',
      ];
    } else if (widget.collectionName == 'violationRequests') {
      preferredOrder = [
        'status',
        'objectType',
        'violationType',
        'reporterId',
        'violationReason',
        'createdAt',
        'reviewedAt',
        'adminId',
      ];
    } else if (widget.collectionName == 'userViolations') {
      preferredOrder = [
        'userId',
        'violationType',
        'status',
        'actionLevel',
        'warningCount',
        'penaltyPoints',
        'createdAt',
        'adminId',
      ];
    } else if (widget.collectionName == 'communities') {
      // Chỉ hiển thị các cột cần thiết cho communities
      preferredOrder = [
        'avatarUrl',
        'name',
        'description',
        'memberCount',
        'postCount',
        'createdAt',
      ];
    } else if (widget.collectionName == 'notifications') {
      // Chỉ hiển thị các cột cần thiết cho notifications
      preferredOrder = ['createdAt', 'imageUrl', 'title', 'body'];
    } else if (widget.collectionName == 'placeEditRequests') {
      // Chỉ hiển thị các cột thân thiện theo thứ tự yêu cầu
      preferredOrder = [
        'images',
        'placeName',
        'address',
        'typeName',
        'proposedBy',
        'status',
        'content',
        'location',
        'approvedAt',
        'createAt',
      ];
    } else if (widget.collectionName == 'posts') {
      preferredOrder = [
        'reviewId',
        'userId',
        'placeId',
        'type',
        'content',
        'mediaUrls',
        'likeCount',
        'commentCount',
        'createdAt',
        'updatedAt',
      ];
    } else if (widget.collectionName == 'tourismTypes') {
      // Giao diện quản lý loại hình du lịch
      preferredOrder = [
        'name', // tên loại hình
        'typeId',
        'description',
      ];
    } else {
      // Mặc định (users, collections khác)
      preferredOrder = [
        'name',
        'email',
        'role',
        'rank',
        'avatarUrl',
        'points',
        'bio',
        'createdAt',
        'phoneNumber',
      ];
    }

    // Ẩn cột kỹ thuật khỏi UI
    final existingKeys =
        firstDoc.keys.where((k) {
          // Ẩn cột chung cho tất cả collections
          if (k == 'id' || k == 'placeId' || k == 'typeIds') return false;

          // Ẩn cột riêng cho users
          if (widget.collectionName == 'users') {
            if (k == 'lastTokenUpdate' || k == 'fcmToken') return false;
          }

          // Ẩn cột riêng cho notifications
          if (widget.collectionName == 'notifications') {
            if (k == 'data' || k == 'isRead' || k == 'userId' || k == 'type')
              return false;
          }

          // Ẩn cột riêng cho communities
          if (widget.collectionName == 'communities') {
            if (k == 'adminId' ||
                k == 'coverImageUrl' ||
                k == 'memberIds' ||
                k == 'pendingRequests' ||
                k == 'tourismTypes' ||
                k == 'rules' ||
                k == 'updatedAt')
              return false;
          }

          // Ẩn cột riêng cho chats
          if (widget.collectionName == 'chats') {
            if (k == 'groupAdmin' ||
                k == 'groupBackground' ||
                k == 'lastMessageSenderId' ||
                k == 'lastMessageTime' ||
                k == 'lastMessageImageCount' ||
                k == 'backgroundImages')
              return false;
          }

          // Ẩn cột riêng cho calls
          if (widget.collectionName == 'calls') {
            if (k == 'agoraChannelName' || k == 'agoraToken' || k == 'chatId')
              return false;
          }

          // Ẩn cột riêng cho violationRequests
          if (widget.collectionName == 'violationRequests') {
            if (k == 'violatedObject' || k == 'reviewNote') return false;
          }

          // Ẩn cột riêng cho userViolations
          if (widget.collectionName == 'userViolations') {
            if (k == 'bannedUntil' || k == 'violatedObjectId') return false;
          }

          return true;
        }).toList();
    final columns = <String>[
      ...preferredOrder.where(existingKeys.contains),
      ...existingKeys.where((k) => !preferredOrder.contains(k)),
    ];

    String formatCellValue(String key, dynamic value) {
      if (value == null || value == 'null') return '-';

      // Timestamp -> ngày
      if (value is Timestamp) {
        final d = value.toDate();
        return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      }

      final lowerKey = key.toLowerCase();

      // Hiển thị tên user thay vì userId cho tất cả các trường liên quan đến user
      if (lowerKey == 'userid' ||
          lowerKey == 'userid1' ||
          lowerKey == 'userid2' ||
          lowerKey == 'callerid' ||
          lowerKey == 'adminid' ||
          lowerKey == 'proposedby' ||
          lowerKey == 'senderid' ||
          lowerKey == 'groupadmin') {
        return _getUserDisplayName(value.toString());
      }

      // Hiển thị danh sách tên user cho array
      if ((lowerKey == 'receiverids' ||
              lowerKey == 'members' ||
              lowerKey == 'memberids') &&
          value is List) {
        return _getUserNames(value);
      }

      // Hiển thị toạ độ GeoPoint cho placeEditRequests
      if (widget.collectionName == 'placeEditRequests' && value is GeoPoint) {
        return '(${value.latitude.toStringAsFixed(4)}, ${value.longitude.toStringAsFixed(4)})';
      }

      // URL ảnh / avatar / link: rút gọn
      if (lowerKey.contains('url') || lowerKey.contains('avatar')) {
        final s = value.toString();
        if (s.startsWith('http')) {
          return 'Link ảnh';
        }
      }

      final str = value.toString();
      if (str.length > 40) {
        return '${str.substring(0, 40)}...';
      }
      return str;
    }

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
              color: Colors.black, // 👈 chữ màu đen
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
                              key == 'description')
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
                      // sọc ziczac cho dễ nhìn
                      return rowIndex.isEven
                          ? AppTheme.getBackgroundColor(context)
                          : AppTheme.getSurfaceColor(context);
                    }),
                    cells: [
                      ...columns.map((key) {
                        final value = doc[key];

                        // Avatar hiển thị hình tròn nhỏ cho avatarUrl
                        if (key.toLowerCase().contains('avatar') &&
                            value != null &&
                            value.toString().isNotEmpty &&
                            value.toString().startsWith('http')) {
                          return DataCell(
                            CircleAvatar(
                              radius: 18,
                              backgroundImage: NetworkImage(value.toString()),
                              backgroundColor: Colors.grey.shade200,
                            ),
                            onTap: () => _showDetailDialog(doc),
                          );
                        }

                        // Hiển thị ảnh thumbnail cho trường images (placeEditRequests) và mediaUrls (posts)
                        if ((key == 'images' || key == 'mediaUrls') &&
                            value != null) {
                          List images = [];
                          if (value is List) {
                            images = value;
                          } else {
                            images = [value];
                          }

                          final firstImage = images
                              .map((e) => e?.toString() ?? '')
                              .firstWhere(
                                (url) => url.startsWith('http'),
                                orElse: () => '',
                              );

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

                        // Chip màu cho role
                        if (key == 'role') {
                          final role = (value ?? 'user').toString();
                          Color bg;
                          Color fg = AppColors.darkTextPrimary;
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                role,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: fg,
                                ),
                              ),
                            ),
                            onTap: () => _showDetailDialog(doc),
                          );
                        }

                        // Chip màu cho status (violationRequests, userViolations)
                        if (key == 'status' &&
                            (widget.collectionName == 'violationRequests' ||
                                widget.collectionName == 'userViolations')) {
                          final status = (value ?? 'pending').toString();
                          Color bg;
                          Color fg = AppColors.darkTextPrimary;
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                displayText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: fg,
                                ),
                              ),
                            ),
                            onTap: () => _showDetailDialog(doc),
                          );
                        }

                        // Chip màu cho actionLevel (userViolations)
                        if (key == 'actionLevel' &&
                            widget.collectionName == 'userViolations') {
                          final actionLevel = (value ?? 'warning').toString();
                          Color bg;
                          Color fg = AppColors.darkTextPrimary;
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icon, size: 14, color: fg),
                                  const SizedBox(width: 4),
                                  Text(
                                    displayText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: fg,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            onTap: () => _showDetailDialog(doc),
                          );
                        }

                        // Chip nhẹ cho rank
                        if (key == 'rank') {
                          return DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                formatCellValue(key, value),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            onTap: () => _showDetailDialog(doc),
                          );
                        }

                        // Điểm: làm nổi bật
                        if (key == 'points') {
                          final text = formatCellValue(key, value);
                          return DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  text,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _showDetailDialog(doc),
                          );
                        }

                        // Đặc biệt: tourismTypes.description - nếu trống thì không cho xuống dòng, tránh cell bị cao
                        if (widget.collectionName == 'tourismTypes' &&
                            key == 'description') {
                          final text = formatCellValue(key, value);
                          final isEmpty = text == '-' || text.trim().isEmpty;
                          return DataCell(
                            SizedBox(
                              width: 320,
                              child: Text(
                                text,
                                overflow: TextOverflow.ellipsis,
                                maxLines: isEmpty ? 1 : 2,
                              ),
                            ),
                            onTap: () => _showDetailDialog(doc),
                          );
                        }
                        return DataCell(
                          SizedBox(
                            width:
                                key == 'bio' || key == 'email'
                                    ? 260
                                    : key.toLowerCase().contains('id')
                                    ? 150
                                    : 120,
                            child: Text(
                              formatCellValue(key, value),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                          onTap: () => _showDetailDialog(doc),
                        );
                      }),
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
                  // Header
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

                  // Content
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
          // Field label
          Row(
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
            ],
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.small)),

          // Field value
          _buildValueWidget(key, value),
        ],
      ),
    );
  }

  Widget _buildValueWidget(String key, dynamic value) {
    // Debug log
    if (key.toLowerCase().contains('image') ||
        key.toLowerCase().contains('avatar') ||
        key.toLowerCase().contains('photo')) {
      debugPrint('🖼️ Image field detected: $key = $value');
    }

    // Check if it's an image URL (for avatarUrl, images, etc.)
    if ((key.toLowerCase().contains('image') ||
            key.toLowerCase().contains('avatar') ||
            key.toLowerCase().contains('photo') ||
            key.toLowerCase().contains('url')) &&
        value is String &&
        value.isNotEmpty) {
      // Check if it's a valid URL
      final isValidUrl =
          value.startsWith('http://') ||
          value.startsWith('https://') ||
          value.startsWith('gs://'); // Firebase Storage

      if (isValidUrl) {
        debugPrint('✅ Displaying image: $value');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LazyNetworkImage(
              imageUrl: value,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(
                AppSizes.radius(context, SizeCategory.medium),
              ),
            ),
            SizedBox(height: AppSizes.padding(context, SizeCategory.small)),
            // Show URL below image for debugging
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

    // Check if it's a list of images
    if (value is List && value.isNotEmpty) {
      // Check if it's an image field
      final isImageField =
          key.toLowerCase().contains('image') ||
          key.toLowerCase().contains('avatar') ||
          key.toLowerCase().contains('photo');

      // Check if first item is image URL
      final firstItem = value.first;
      final hasImageUrls =
          firstItem is String &&
          (firstItem.startsWith('http://') ||
              firstItem.startsWith('https://') ||
              firstItem.startsWith('gs://'));

      if (isImageField && hasImageUrls) {
        debugPrint('✅ Displaying image grid with ${value.length} images');
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

    // Check if it's a Map
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

    // Default: show as text
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
    debugPrint('📸 Building image grid for ${images.length} images');
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
        debugPrint('📷 Loading image $index: ${images[index]}');
        return _LazyNetworkImage(
          imageUrl: images[index],
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
        );
      },
    );
  }

  /// Parse giá trị từ TextField về đúng kiểu dữ liệu
  dynamic _parseFieldValue(String fieldName, String value) {
    // Trim whitespace
    final trimmedValue = value.trim();

    // Nếu rỗng hoặc là "null", trả về null
    if (trimmedValue.isEmpty || trimmedValue.toLowerCase() == 'null') {
      return null;
    }

    // Xử lý các trường đặc biệt
    switch (fieldName.toLowerCase()) {
      case 'phonenumber':
      case 'phone':
        // Phone: null hoặc string
        return trimmedValue;

      case 'datebirth':
        // DateBirth: null hoặc timestamp
        try {
          // Parse date string (format: yyyy-MM-dd hoặc dd/MM/yyyy)
          DateTime? date;
          if (trimmedValue.contains('-')) {
            date = DateTime.tryParse(trimmedValue);
          } else if (trimmedValue.contains('/')) {
            final parts = trimmedValue.split('/');
            if (parts.length == 3) {
              date = DateTime(
                int.parse(parts[2]), // year
                int.parse(parts[1]), // month
                int.parse(parts[0]), // day
              );
            }
          }
          return date != null ? Timestamp.fromDate(date) : null;
        } catch (e) {
          return null;
        }

      case 'createdat':
      case 'created_at':
        // CreatedAt: timestamp với format hiện tại hoặc tạo mới
        try {
          // Nếu có giá trị, parse nó
          final date = DateTime.tryParse(trimmedValue);
          return date != null
              ? Timestamp.fromDate(date)
              : Timestamp.fromDate(DateTime.now());
        } catch (e) {
          return Timestamp.fromDate(DateTime.now());
        }

      case 'points':
        // Points: int
        return int.tryParse(trimmedValue) ?? 0;

      default:
        // Các field khác: giữ nguyên string
        return trimmedValue;
    }
  }

  /// Dialog tạo document mới
  void _showCreateDialog() {
    final formKey = GlobalKey<FormState>();
    final Map<String, TextEditingController> controllers = {};

    // Lấy schema từ document đầu tiên (nếu có)
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
                  // Header
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

                  // Form
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
                                  // Helper text cho các field đặc biệt
                                  String? helperText;
                                  if (field.toLowerCase().contains('phone')) {
                                    helperText = 'Để trống nếu không có';
                                  } else if (field.toLowerCase().contains(
                                        'datebirth',
                                      ) ||
                                      field.toLowerCase().contains('date')) {
                                    helperText =
                                        'Format: yyyy-MM-dd hoặc dd/MM/yyyy. Để trống nếu không có';
                                  } else if (field.toLowerCase().contains(
                                    'created',
                                  )) {
                                    helperText =
                                        'Format: yyyy-MM-dd hoặc để trống để dùng thời gian hiện tại';
                                  }

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
                                        helperText: helperText,
                                        helperStyle: TextStyle(
                                          fontSize: AppSizes.font(
                                            context,
                                            SizeCategory.small,
                                          ),
                                          color: AppTheme.getTextSecondaryColor(
                                            context,
                                          ),
                                        ),
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
                                        // Chỉ validate required cho các field bắt buộc
                                        final isRequired =
                                            !field.toLowerCase().contains(
                                              'phone',
                                            ) &&
                                            !field.toLowerCase().contains(
                                              'datebirth',
                                            );

                                        if (isRequired &&
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

                  // Actions
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
                                  // Parse giá trị về đúng kiểu dữ liệu
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

  /// Dialog chỉnh sửa document
  void _showEditDialog(Map<String, dynamic> doc) {
    final formKey = GlobalKey<FormState>();
    final Map<String, TextEditingController> controllers = {};
    final docId = doc['id'] as String;

    // Tạo controllers cho các fields (trừ id)
    doc.forEach((key, value) {
      if (key != 'id' && value is! Map && value is! List) {
        String displayValue = '';

        // Xử lý hiển thị các kiểu dữ liệu đặc biệt
        if (value == null) {
          displayValue = ''; // Để trống thay vì hiển thị "null"
        } else if (value is Timestamp) {
          // Convert Timestamp về format readable
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
                  // Header
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

                  // Form
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
                                  final field = entry.key;

                                  // Helper text cho các field đặc biệt
                                  String? helperText;
                                  if (field.toLowerCase().contains('phone')) {
                                    helperText = 'Để trống nếu không có';
                                  } else if (field.toLowerCase().contains(
                                        'datebirth',
                                      ) ||
                                      field.toLowerCase().contains('date')) {
                                    helperText =
                                        'Format: yyyy-MM-dd hoặc dd/MM/yyyy. Để trống nếu không có';
                                  } else if (field.toLowerCase().contains(
                                    'created',
                                  )) {
                                    helperText = 'Format: yyyy-MM-dd';
                                  }

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
                                        helperText: helperText,
                                        helperStyle: TextStyle(
                                          fontSize: AppSizes.font(
                                            context,
                                            SizeCategory.small,
                                          ),
                                          color: AppTheme.getTextSecondaryColor(
                                            context,
                                          ),
                                        ),
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
                                        // Chỉ validate required cho các field bắt buộc
                                        final isRequired =
                                            !field.toLowerCase().contains(
                                              'phone',
                                            ) &&
                                            !field.toLowerCase().contains(
                                              'datebirth',
                                            );

                                        if (isRequired &&
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

                  // Actions
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
                                  // Parse giá trị về đúng kiểu dữ liệu
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

// Cấu hình size cột riêng cho từng collection
final Map<String, Map<String, ColumnSize>> columnSizeConfig = {
  'users': {
    'name': ColumnSize.M,
    'email': ColumnSize.L,
    'role': ColumnSize.S,
    'rank': ColumnSize.S,
    'avatarUrl': ColumnSize.S,
    'points': ColumnSize.S,
    'bio': ColumnSize.L,
    'createdAt': ColumnSize.S,
    'phoneNumber': ColumnSize.M,
  },
  'tourismTypes': {
    'name': ColumnSize.M,
    'typeId': ColumnSize.M,
    'description': ColumnSize.L,
  },
  'placeEditRequests': {
    'placeName': ColumnSize.M,
    'address': ColumnSize.L,
    'typeName': ColumnSize.S,
    'proposedBy': ColumnSize.S,
    'status': ColumnSize.S,
    'content': ColumnSize.L,
    'location': ColumnSize.S,
    'approvedAt': ColumnSize.S,
    'createAt': ColumnSize.S,
    'images': ColumnSize.S,
  },
  'posts': {
    'reviewId': ColumnSize.S,
    'userId': ColumnSize.M,
    'placeId': ColumnSize.M,
    'type': ColumnSize.S,
    'content': ColumnSize.L,
    'mediaUrls': ColumnSize.S,
    'likeCount': ColumnSize.S,
    'commentCount': ColumnSize.S,
    'createdAt': ColumnSize.S,
    'updatedAt': ColumnSize.S,
  },
  // Thêm các collection khác nếu cần
};
