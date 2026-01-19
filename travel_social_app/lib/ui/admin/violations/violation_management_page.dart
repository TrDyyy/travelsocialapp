import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/violation_request.dart';
import '../../../services/admin_violation_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/toast_helper.dart';
import 'violation_detail_page.dart';

class ViolationManagementPage extends StatefulWidget {
  const ViolationManagementPage({super.key});

  @override
  State<ViolationManagementPage> createState() =>
      _ViolationManagementPageState();
}

class _ViolationManagementPageState extends State<ViolationManagementPage>
    with SingleTickerProviderStateMixin {
  final AdminViolationService _violationService = AdminViolationService();

  late TabController _tabController;
  String? _selectedObjectType;
  String? _selectedViolationType;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<ViolationRequest> _requests = [];
  bool _isLoading = false;
  bool _hasMore = true;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _resetAndLoad();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      if (!_isLoading && _hasMore) {
        _loadMore();
      }
    }
  }

  void _resetAndLoad() {
    setState(() {
      _requests = [];
      _hasMore = true;
    });
    _loadRequests();
  }

  String get _currentStatus {
    switch (_tabController.index) {
      case 0:
        return ViolationConstants.statusPending;
      case 1:
        return ViolationConstants.statusApproved;
      case 2:
        return ViolationConstants.statusRejected;
      default:
        return ViolationConstants.statusPending;
    }
  }

  Future<void> _loadRequests() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final requests = await _violationService.getViolationRequests(
        status: _currentStatus,
        objectType: _selectedObjectType,
        violationType: _selectedViolationType,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _requests = requests;
          _hasMore = requests.length >= 20;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading requests: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    // Pagination logic would go here
    // For now, just a placeholder
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Vi phạm'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '⏳ Đang chờ'),
            Tab(text: '✅ Đã duyệt'),
            Tab(text: '❌ Từ chối'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRequestList(),
                _buildRequestList(),
                _buildRequestList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Tìm kiếm (User ID)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _resetAndLoad();
                          },
                        )
                        : null,
              ),
              onSubmitted: (value) {
                setState(() => _searchQuery = value);
                _resetAndLoad();
              },
            ),
            const SizedBox(height: 16),
            // Filters row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedObjectType,
                    decoration: const InputDecoration(
                      labelText: 'Loại đối tượng',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Tất cả'),
                      ),
                      ...['place', 'post', 'comment', 'review', 'user'].map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(_getObjectTypeLabel(type)),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedObjectType = value);
                      _resetAndLoad();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedViolationType,
                    decoration: const InputDecoration(
                      labelText: 'Loại vi phạm',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Tất cả'),
                      ),
                      ...ViolationConstants.allViolationTypes.map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(
                            ViolationConstants.getViolationTypeLabel(type),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedViolationType = value);
                      _resetAndLoad();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestList() {
    if (_isLoading && _requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Không có báo cáo nào',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _resetAndLoad(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _requests.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final request = _requests[index];
          return _buildRequestCard(request);
        },
      ),
    );
  }

  Widget _buildRequestCard(ViolationRequest request) {
    final objectTypeLabel = request.objectType.displayName;
    final violationLabel = ViolationConstants.getViolationTypeLabel(
      request.violationType,
    );
    final statusColor = ViolationConstants.getStatusColor(request.status);
    final statusLabel = ViolationConstants.getStatusLabel(request.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToDetail(request),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Violation type + Status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      violationLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              // Object type
              _buildInfoRow(
                icon: Icons.category,
                label: 'Báo cáo:',
                value: objectTypeLabel,
              ),
              const SizedBox(height: 8),
              // Reporter
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  const Text(
                    'Người báo:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: UserDisplayWidget(
                      userId: request.reporterId,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Violator
              if (request.violatedObjectOwnerId != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Người vi phạm:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: UserDisplayWidget(
                        userId: request.violatedObjectOwnerId!,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              // Preview content
              if (request.violatedObjectPreview != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    request.violatedObjectPreview!.length > 150
                        ? '${request.violatedObjectPreview!.substring(0, 150)}...'
                        : request.violatedObjectPreview!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // Media preview (images/videos)
              if (_hasMedia(request)) ...[
                const SizedBox(height: 12),
                _buildMediaPreview(request),
                const SizedBox(height: 8),
              ],
              // Reason
              _buildInfoRow(
                icon: Icons.note,
                label: 'Lý do:',
                value:
                    request.violationReason.length > 100
                        ? '${request.violationReason.substring(0, 100)}...'
                        : request.violationReason,
              ),
              const SizedBox(height: 8),
              // Time
              _buildInfoRow(
                icon: Icons.access_time,
                label: 'Thời gian:',
                value: _formatDateTime(request.createdAt),
              ),
              // Action buttons for pending requests
              if (request.status == ViolationConstants.statusPending) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _navigateToDetail(request),
                      icon: const Icon(Icons.visibility),
                      label: const Text('Xem chi tiết'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _quickApprove(request),
                      icon: const Icon(Icons.check),
                      label: const Text('Duyệt'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _quickReject(request),
                      icon: const Icon(Icons.close),
                      label: const Text('Từ chối'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, color: valueColor ?? Colors.black87),
          ),
        ),
      ],
    );
  }

  String _getObjectTypeLabel(String type) {
    switch (type) {
      case 'place':
        return '📍 Địa điểm';
      case 'post':
        return '📝 Bài viết';
      case 'comment':
        return '💬 Bình luận';
      case 'review':
        return '⭐ Đánh giá';
      case 'user':
        return '👤 Người dùng';
      default:
        return type;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _navigateToDetail(ViolationRequest request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViolationDetailPage(request: request),
      ),
    ).then((_) => _resetAndLoad()); // Refresh sau khi quay lại
  }

  bool _hasMedia(ViolationRequest request) {
    final obj = request.violatedObject;
    switch (request.objectType) {
      case ViolatedObjectType.post:
        final mediaUrls = obj['mediaUrls'];
        return mediaUrls != null && mediaUrls is List && mediaUrls.isNotEmpty;
      case ViolatedObjectType.comment:
        final imageUrls = obj['imageUrls'];
        return imageUrls != null && imageUrls is List && imageUrls.isNotEmpty;
      case ViolatedObjectType.review:
      case ViolatedObjectType.place:
        final images = obj['images'];
        return images != null && images is List && images.isNotEmpty;
      case ViolatedObjectType.user:
        return false;
    }
  }

  Widget _buildMediaPreview(ViolationRequest request) {
    final obj = request.violatedObject;
    int imageCount = 0;
    int videoCount = 0;

    // Debug: print object type and keys
    debugPrint('🔍 Media Preview Debug:');
    debugPrint('  Object Type: ${request.objectType}');
    debugPrint('  ViolatedObject keys: ${obj.keys.toList()}');

    switch (request.objectType) {
      case ViolatedObjectType.post:
        final mediaUrls = obj['mediaUrls'];
        debugPrint('  mediaUrls: $mediaUrls');
        if (mediaUrls != null && mediaUrls is List) {
          imageCount =
              mediaUrls.where((url) {
                final urlStr = url.toString().toLowerCase();
                final path = urlStr.split('?').first;
                return path.endsWith('.jpg') ||
                    path.endsWith('.jpeg') ||
                    path.endsWith('.png') ||
                    path.endsWith('.gif') ||
                    path.endsWith('.webp') ||
                    path.endsWith('.heic') ||
                    path.endsWith('.bmp');
              }).length;
          videoCount =
              mediaUrls.where((url) {
                final urlStr = url.toString().toLowerCase();
                final path = urlStr.split('?').first;
                return path.endsWith('.mp4') ||
                    path.endsWith('.mov') ||
                    path.endsWith('.avi') ||
                    path.endsWith('.mkv') ||
                    path.endsWith('.webm') ||
                    path.endsWith('.m4v') ||
                    path.endsWith('.3gp');
              }).length;
          debugPrint('  Found: $imageCount images, $videoCount videos');
        }
        break;
      case ViolatedObjectType.comment:
        final imageUrls = obj['imageUrls'];
        if (imageUrls != null && imageUrls is List) {
          imageCount = imageUrls.length;
        }
        break;
      case ViolatedObjectType.review:
      case ViolatedObjectType.place:
        final images = obj['images'];
        if (images != null && images is List) {
          imageCount = images.length;
        }
        break;
      case ViolatedObjectType.user:
        break;
    }

    // Get actual media URLs for preview
    List<String> imageUrls = [];
    List<String> videoUrls = [];

    switch (request.objectType) {
      case ViolatedObjectType.post:
        final mediaUrls = obj['mediaUrls'];
        if (mediaUrls != null && mediaUrls is List) {
          imageUrls = List<String>.from(
            mediaUrls.where((url) {
              final urlStr = url.toString().toLowerCase();
              final path = urlStr.split('?').first;
              return path.endsWith('.jpg') ||
                  path.endsWith('.jpeg') ||
                  path.endsWith('.png') ||
                  path.endsWith('.gif') ||
                  path.endsWith('.webp') ||
                  path.endsWith('.heic') ||
                  path.endsWith('.bmp');
            }),
          );
          videoUrls = List<String>.from(
            mediaUrls.where((url) {
              final urlStr = url.toString().toLowerCase();
              final path = urlStr.split('?').first;
              return path.endsWith('.mp4') ||
                  path.endsWith('.mov') ||
                  path.endsWith('.avi') ||
                  path.endsWith('.mkv') ||
                  path.endsWith('.webm') ||
                  path.endsWith('.m4v') ||
                  path.endsWith('.3gp');
            }),
          );
        }
        break;
      case ViolatedObjectType.comment:
        final imgs = obj['imageUrls'];
        if (imgs != null && imgs is List) {
          imageUrls = List<String>.from(imgs);
        }
        break;
      case ViolatedObjectType.review:
      case ViolatedObjectType.place:
        final imgs = obj['images'];
        if (imgs != null && imgs is List) {
          imageUrls = List<String>.from(imgs);
        }
        break;
      default:
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and count
          Row(
            children: [
              const Icon(Icons.warning_amber, size: 18, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'Media đính kèm:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              if (imageCount > 0)
                Chip(
                  label: Text(
                    '$imageCount ảnh',
                    style: const TextStyle(fontSize: 11),
                  ),
                  avatar: const Icon(Icons.image, size: 14),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              if (videoCount > 0) ...[
                const SizedBox(width: 4),
                Chip(
                  label: Text(
                    '$videoCount video',
                    style: const TextStyle(fontSize: 11),
                  ),
                  avatar: const Icon(Icons.videocam, size: 14),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Media thumbnails preview
          if (imageUrls.isNotEmpty || videoUrls.isNotEmpty)
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Image thumbnails
                  ...imageUrls
                      .take(5)
                      .map(
                        (url) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                ),
                              ),
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stack) => Container(
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                      ),
                                    ),
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                  // Video thumbnails
                  ...videoUrls
                      .take(3)
                      .map(
                        (url) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.5),
                                ),
                              ),
                              child: const Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.play_circle_outline,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  Positioned(
                                    bottom: 4,
                                    right: 4,
                                    child: Icon(
                                      Icons.videocam,
                                      color: Colors.red,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  // Show more indicator
                  if (imageUrls.length + videoUrls.length > 8)
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey[400]!),
                      ),
                      child: Center(
                        child: Text(
                          '+${imageUrls.length + videoUrls.length - 8}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Không tìm thấy media URLs (Debug: images=${imageUrls.length}, videos=${videoUrls.length})',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _quickApprove(ViolationRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xác nhận duyệt'),
            content: const Text(
              'Bạn có chắc muốn duyệt báo cáo này?\n\n'
              'Hành động mặc định:\n'
              '• Xóa nội dung vi phạm\n'
              '• Trừ điểm người vi phạm\n'
              '• Gửi thông báo\n\n'
              'Để tùy chỉnh, vui lòng vào "Xem chi tiết".',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Xác nhận'),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final success = await _violationService.approveViolation(
        requestId: request.requestId!,
        adminId: 'current_admin_id', // TODO: Get from auth
        reviewNote: 'Duyệt nhanh từ danh sách',
        deleteContent: true,
        penalizeUser: true,
        sendNotification: true,
        warnUser: true,
        banIfRepeated: true,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading

        if (success) {
          ToastHelper.showSuccess(context, 'Đã duyệt báo cáo');
          _resetAndLoad();
        } else {
          ToastHelper.showError(context, 'Lỗi khi duyệt');
        }
      }
    }
  }

  Future<void> _quickReject(ViolationRequest request) async {
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Từ chối báo cáo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lý do từ chối:'),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    hintText: 'Nhập lý do (không bắt buộc)...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Từ chối'),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final success = await _violationService.rejectViolation(
        requestId: request.requestId!,
        adminId: 'current_admin_id', // TODO: Get from auth
        reviewNote:
            noteController.text.isNotEmpty
                ? noteController.text
                : 'Nội dung không vi phạm quy định',
      );

      if (mounted) {
        Navigator.pop(context);

        if (success) {
          ToastHelper.showWarning(context, 'Đã từ chối báo cáo');
          _resetAndLoad();
        } else {
          ToastHelper.showError(context, 'Lỗi khi từ chối');
        }
      }
    }

    noteController.dispose();
  }
}

/// Widget to display user info with name fetched from Firestore
class UserDisplayWidget extends StatelessWidget {
  final String userId;
  final Color? color;

  const UserDisplayWidget({super.key, required this.userId, this.color});

  Future<Map<String, String>> _fetchUserInfo() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

      if (!doc.exists) {
        return {'name': 'Không tìm thấy', 'email': ''};
      }

      final data = doc.data()!;
      return {'name': data['name'] ?? 'Unknown', 'email': data['email'] ?? ''};
    } catch (e) {
      debugPrint('❌ Error fetching user info: $e');
      return {'name': 'Lỗi tải thông tin', 'email': ''};
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _fetchUserInfo(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(color ?? Colors.grey),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Đang tải...',
                style: TextStyle(
                  fontSize: 13,
                  color: color ?? Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          );
        }

        final userInfo = snapshot.data ?? {'name': userId, 'email': ''};
        final name = userInfo['name']!;
        final email = userInfo['email']!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color ?? Colors.black87,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (email.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                email,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        );
      },
    );
  }
}
