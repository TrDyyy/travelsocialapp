import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/admin_service.dart';
import '../../../services/notification_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/toast_helper.dart';

/// Widget hiển thị danh sách yêu cầu đang chờ
class PendingRequestsList extends StatefulWidget {
  final int limit;

  const PendingRequestsList({super.key, this.limit = 50});

  @override
  State<PendingRequestsList> createState() => _PendingRequestsListState();
}

class _PendingRequestsListState extends State<PendingRequestsList> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
    });

    final requests = await _adminService.getPendingRequests();
    print('📋 Pending requests widget loaded: ${requests.length} requests');

    if (requests.isNotEmpty) {
      print('📄 Sample request data: ${requests.first}');
    }

    setState(() {
      _requests = requests.take(widget.limit).toList();
      _isLoading = false;
    });
  }

  Future<void> _approveRequest(String requestId) async {
    final confirmed = await showDialog<bool>(
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                ),
                child: const Text('Duyệt'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      // Lấy thông tin request TRƯỚC khi duyệt
      final request = _requests.firstWhere(
        (r) => r['id'] == requestId,
        orElse: () => {},
      );
      debugPrint('📋 Request data: $request');

      final userId = request['userId'] ?? request['proposedBy'];
      final placeName = request['placeName'] ?? request['name'] ?? 'Địa điểm';

      debugPrint('👤 User ID: $userId');
      debugPrint('📍 Place Name: $placeName');

      if (userId == null || userId.isEmpty) {
        debugPrint('❌ Cannot send notification: userId is null');
        if (!mounted) return;
        ToastHelper.showWarning(
          context,
          'Không thể gửi thông báo: thiếu thông tin người dùng',
        );
        return;
      }

      final placeId = await _adminService.approveRequest(requestId);
      debugPrint('🆔 Created place ID: $placeId');

      if (placeId != null && mounted) {
        // Gửi thông báo FCM với placeId vừa tạo
        try {
          debugPrint('📤 Sending notification to user: $userId');
          await NotificationService().sendNotificationToUser(
            userId,
            'Kết quả duyệt địa điểm',
            'Địa điểm "$placeName" bạn đăng ký đã được duyệt!',
            data: {
              'type': 'place_approval',
              'placeId': placeId,
              'status': 'approved',
            },
          );
          debugPrint(
            '✅ Sent approval notification to user: $userId for place: $placeId',
          );
        } catch (e) {
          debugPrint('❌ Error sending approval notification: $e');
          debugPrint('Stack trace: ${StackTrace.current}');
        }
        if (!mounted) return;
        ToastHelper.showSuccess(context, 'Đã duyệt yêu cầu thành công');
        _loadRequests();
      }
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Từ chối yêu cầu'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Lý do từ chối:'),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Nhập lý do...',
                    border: OutlineInputBorder(),
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

    if (confirmed == true) {
      // Lấy thông tin request TRƯỚC khi từ chối
      final request = _requests.firstWhere(
        (r) => r['id'] == requestId,
        orElse: () => {},
      );
      final userId = request['userId'] ?? request['proposedBy'];
      final placeName = request['placeName'] ?? request['name'] ?? 'Địa điểm';
      final requestPlaceId = request['googlePlaceId'] ?? '';

      if (userId == null || userId.isEmpty) {
        debugPrint('❌ Cannot send notification: userId is null');
        if (!mounted) return;
        ToastHelper.showWarning(
          context,
          'Không thể gửi thông báo: thiếu thông tin người dùng',
        );
        return;
      }

      final success = await _adminService.rejectRequest(
        requestId,
        reasonController.text,
      );
      if (success && mounted) {
        // Gửi thông báo FCM
        try {
          await NotificationService().sendNotificationToUser(
            userId,
            'Kết quả duyệt địa điểm',
            'Địa điểm "$placeName" bạn đăng ký không được duyệt.',
            data: {
              'type': 'place_approval',
              'placeId': requestPlaceId,
              'status': 'rejected',
              'reason': reasonController.text,
            },
          );
          debugPrint('✅ Sent rejection notification to user: $userId');
        } catch (e) {
          debugPrint('❌ Error sending rejection notification: $e');
        }
        if (!mounted) return;
        ToastHelper.showError(context, 'Đã từ chối yêu cầu');
        _loadRequests();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_requests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.check_circle, size: 64, color: AppColors.primaryGreen),
              SizedBox(height: 16),
              Text(
                'Không có yêu cầu nào đang chờ',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final request = _requests[index];
        return _buildRequestCard(request);
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final createAt = request['createAt'] as Timestamp?;
    final date = createAt?.toDate();

    // Support multiple field name variations
    final placeName = request['placeName'] ?? request['name'] ?? 'Địa điểm mới';
    final address = request['address'] ?? 'N/A';
    final content = request['content'] ?? request['description'] ?? 'N/A';
    final images = request['images'] as List? ?? [];
    final proposedBy = request['proposedBy'] ?? request['userId'] ?? 'N/A';
    final proposedByText = 'Đăng ký bởi: $proposedBy';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryGreen,
          child: const Icon(Icons.place, color: Colors.white, size: 20),
        ),
        title: Text(
          placeName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          date != null
              ? 'Đăng ký: ${DateFormat('dd/MM/yyyy HH:mm').format(date)}'
              : 'Không có ngày',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Địa chỉ', address),
              const SizedBox(height: 6),
              _buildInfoRow('Mô tả', content),
              const SizedBox(height: 6),
              _buildInfoRow('Số ảnh', '${images.length} ảnh'),
              const SizedBox(height: 6),
              _buildInfoRow('Trạng thái', request['status'] ?? 'N/A'),
              const SizedBox(height: 12),

              // Images grid
              if (images.isNotEmpty) _buildImagesGrid(images),

              if (images.isNotEmpty) const SizedBox(height: 12),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _rejectRequest(request['id']),
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.error,
                    ),
                    label: const Text(
                      'Từ chối',
                      style: TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _approveRequest(request['id']),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Duyệt', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildImagesGrid(List images) {
    // Limit to max 6 images to avoid overflow
    final displayImages = images.take(6).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1.0,
      ),
      itemCount: displayImages.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            displayImages[index],
            fit: BoxFit.cover,
            errorBuilder:
                (context, error, stackTrace) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.error, size: 20),
                ),
          ),
        );
      },
    );
  }
}
