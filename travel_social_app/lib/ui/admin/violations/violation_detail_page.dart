import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../models/violation_request.dart';
import '../../../services/admin_violation_service.dart';
import '../../../utils/toast_helper.dart';
import '../../../widgets/media_gallery_widget.dart';
import '../../../widgets/video_gallery_widget.dart';
import '../../../widgets/violated_content_viewer.dart';

class ViolationDetailPage extends StatefulWidget {
  final ViolationRequest request;

  const ViolationDetailPage({super.key, required this.request});

  @override
  State<ViolationDetailPage> createState() => _ViolationDetailPageState();
}

class _ViolationDetailPageState extends State<ViolationDetailPage> {
  final _service = AdminViolationService();
  final _formKey = GlobalKey<FormState>();

  // Decision
  String? _decision; // 'approve' or 'reject'
  final _reviewNoteController = TextEditingController();

  // Approve options
  bool _deleteContent = false;
  bool _penalizeUser = false;
  bool _sendNotification = true;
  bool _warnUser = false;
  bool _banIfRepeated = false;

  // User violation action level
  String _userActionLevel = 'warning'; // 'warning' | 'ban' | 'delete'
  bool _sendEmail = true;
  Map<String, dynamic>? _userViolationData;

  bool _isSubmitting = false;
  bool _isLoadingUserData = false;

  @override
  void initState() {
    super.initState();
    if (widget.request.objectType == 'user') {
      _loadUserViolationData();
    }
  }

  Future<void> _loadUserViolationData() async {
    setState(() {
      _isLoadingUserData = true;
    });

    try {
      final userId = widget.request.violatedObject['userId'] as String?;
      if (userId != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();

        if (userDoc.exists) {
          setState(() {
            _userViolationData = userDoc.data();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      setState(() {
        _isLoadingUserData = false;
      });
    }
  }

  @override
  void dispose() {
    _reviewNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Format timestamp for title
    final timestamp = widget.request.createdAt;
    final formattedTime =
        '${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Vi phạm - $formattedTime'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: () {
              setState(() {
                // Reload page
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              _buildStatusCard(isDark),
              const SizedBox(height: 24),

              // Reporter Info
              _buildSectionCard(
                isDark: isDark,
                title: 'Người báo cáo',
                icon: Icons.person_outline,
                iconColor: Colors.blue,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Người báo cáo:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    UserInfoCard(userId: widget.request.reporterId),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Violated Object Info
              _buildSectionCard(
                isDark: isDark,
                title: 'Đối tượng vi phạm',
                icon: Icons.report_problem_outlined,
                iconColor: Colors.orange,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Loại:', widget.request.objectType.name),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'ID:',
                      widget.request.violatedObjectId ?? 'N/A',
                    ),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      'Chủ sở hữu:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (widget.request.violatedObjectOwnerId != null)
                      UserInfoCard(
                        userId: widget.request.violatedObjectOwnerId!,
                      )
                    else
                      const Text('N/A', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Media Section
              _buildSectionCard(
                isDark: isDark,
                title: 'Media đính kèm',
                icon: Icons.perm_media,
                iconColor: Colors.purple,
                child: _buildMediaSection(),
              ),
              const SizedBox(height: 16),

              // Violated Content Viewer (Full content + metadata)
              ViolatedContentViewer(
                violatedObject: widget.request.violatedObject,
                objectType: widget.request.objectType.toFirestore(),
                violationType: widget.request.violationType,
              ),
              const SizedBox(height: 16),

              // Violation Details
              _buildSectionCard(
                isDark: isDark,
                title: 'Chi tiết vi phạm',
                icon: Icons.gavel,
                iconColor: Colors.red,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      'Loại vi phạm:',
                      widget.request.violationType,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Lý do báo cáo:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.request.violationReason,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Ngày báo cáo:',
                      widget.request.createdAt.toString().substring(0, 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Decision Form
              if (widget.request.status == 'pending') ...[
                _buildDecisionForm(isDark),
              ] else ...[
                _buildReviewedInfo(isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isDark) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (widget.request.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        statusText = 'Đang chờ xử lý';
        break;
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Đã duyệt';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Đã từ chối';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = 'Không xác định';
    }

    return Card(
      color: statusColor.withOpacity(isDark ? 0.2 : 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  if (widget.request.reviewedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Xử lý lúc: ${widget.request.reviewedAt!.toString().substring(0, 16)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  Widget _buildDecisionForm(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quyết định',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Decision radio buttons
            RadioListTile<String>(
              title: const Text('Duyệt vi phạm'),
              subtitle: const Text('Xác nhận có vi phạm và xử lý'),
              value: 'approve',
              groupValue: _decision,
              onChanged: (value) {
                setState(() {
                  _decision = value;
                });
              },
            ),
            RadioListTile<String>(
              title: const Text('Từ chối'),
              subtitle: const Text('Không phải vi phạm, bỏ qua'),
              value: 'reject',
              groupValue: _decision,
              onChanged: (value) {
                setState(() {
                  _decision = value;
                  // Clear approve options
                  _deleteContent = false;
                  _penalizeUser = false;
                  _warnUser = false;
                  _banIfRepeated = false;
                });
              },
            ),

            const Divider(),
            const SizedBox(height: 16),

            // Approve options
            if (_decision == 'approve') ...[
              // User violation - special handling
              if (widget.request.objectType == 'user') ...[
                _buildUserViolationOptions(isDark),
              ] else ...[
                // Content violation - normal handling
                const Text(
                  'Hành động khi duyệt:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Xóa nội dung vi phạm'),
                  subtitle: const Text('Xóa post/comment/review vi phạm'),
                  value: _deleteContent,
                  onChanged: (value) {
                    setState(() {
                      _deleteContent = value ?? false;
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('Trừ điểm người vi phạm'),
                  subtitle: const Text('Trừ điểm theo mức độ vi phạm'),
                  value: _penalizeUser,
                  onChanged: (value) {
                    setState(() {
                      _penalizeUser = value ?? false;
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('Cảnh báo người vi phạm'),
                  subtitle: const Text('Tăng số lần cảnh báo'),
                  value: _warnUser,
                  onChanged: (value) {
                    setState(() {
                      _warnUser = value ?? false;
                    });
                  },
                ),
                if (_warnUser) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: CheckboxListTile(
                      title: const Text('Cấm tài khoản nếu tái phạm'),
                      subtitle: const Text(
                        'Ban tài khoản nếu vi phạm quá 3 lần',
                      ),
                      value: _banIfRepeated,
                      onChanged: (value) {
                        setState(() {
                          _banIfRepeated = value ?? false;
                        });
                      },
                    ),
                  ),
                ],
                CheckboxListTile(
                  title: const Text('Gửi thông báo'),
                  subtitle: const Text(
                    'Thông báo cho người báo cáo & người vi phạm',
                  ),
                  value: _sendNotification,
                  onChanged: (value) {
                    setState(() {
                      _sendNotification = value ?? false;
                    });
                  },
                ),
              ],
              const Divider(),
              const SizedBox(height: 16),
            ],

            // Review note
            TextFormField(
              controller: _reviewNoteController,
              decoration: InputDecoration(
                labelText: 'Ghi chú (tùy chọn)',
                hintText: 'Nhập lý do duyệt/từ chối...',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.note),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Submit buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed:
                      _decision == null || _isSubmitting
                          ? null
                          : _submitDecision,
                  icon:
                      _isSubmitting
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.send),
                  label: Text(
                    _isSubmitting ? 'Đang xử lý...' : 'Gửi quyết định',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewedInfo(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kết quả xử lý',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 12),
            _buildInfoRow('Admin:', widget.request.adminId ?? 'N/A'),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Thời gian:',
              widget.request.reviewedAt?.toString().substring(0, 16) ?? 'N/A',
            ),
            if (widget.request.reviewNote != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Ghi chú:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(widget.request.reviewNote!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submitDecision() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
    });

    try {
      final adminId = FirebaseAuth.instance.currentUser!.uid;
      final reviewNote = _reviewNoteController.text.trim();

      if (_decision == 'approve') {
        // Handle user violation separately
        if (widget.request.objectType == 'user') {
          final userId = widget.request.violatedObject['userId'] as String?;
          if (userId == null) {
            throw Exception('User ID not found in violated object');
          }

          // Call handleUserViolation method
          await _service.handleUserViolation(
            userId: userId,
            violationType: widget.request.violationType,
            requestId: widget.request.requestId!,
            adminId: adminId,
            reviewNote: reviewNote,
            actionLevel: _userActionLevel,
          );

          // Call Cloud Function to send email if enabled
          if (_sendEmail) {
            try {
              if (_userActionLevel == 'warning') {
                // Call sendWarningEmail function
                // await FirebaseFunctions.instance
                //     .httpsCallable('sendWarningEmail')
                //     .call({
                //   'userId': userId,
                //   'violationType': widget.request.violationType,
                //   'violationReason': widget.request.violationReason,
                //   'adminNote': reviewNote,
                //   'warningCount': (_userViolationData?['warningCount'] ?? 0) + 1,
                // });
                debugPrint('TODO: Send warning email to $userId');
              } else if (_userActionLevel == 'ban') {
                // Call sendBanNotificationEmail function
                // await FirebaseFunctions.instance
                //     .httpsCallable('sendBanNotificationEmail')
                //     .call({
                //   'userId': userId,
                //   'violationType': widget.request.violationType,
                //   'banReason': widget.request.violationReason,
                //   'adminNote': reviewNote,
                //   'warningCount': (_userViolationData?['warningCount'] ?? 0) + 1,
                // });
                debugPrint('TODO: Send ban email to $userId');
              }
              // TODO: Call disableUserAuth for ban/delete actions
            } catch (emailError) {
              debugPrint('Warning: Failed to send email: $emailError');
              // Continue even if email fails
            }
          }

          if (!mounted) return;
          ToastHelper.showSuccess(
            context,
            _userActionLevel == 'warning'
                ? 'Đã cảnh cáo user thành công'
                : _userActionLevel == 'ban'
                ? 'Đã cấm tài khoản user'
                : 'Đã đánh dấu tài khoản để xóa',
          );
          Navigator.pop(context, true);
        } else {
          // Normal content violation handling
          await _service.approveViolation(
            requestId: widget.request.requestId!,
            adminId: adminId,
            reviewNote: reviewNote,
            deleteContent: _deleteContent,
            penalizeUser: _penalizeUser,
            sendNotification: _sendNotification,
            warnUser: _warnUser,
            banIfRepeated: _banIfRepeated,
          );

          if (!mounted) return;
          ToastHelper.showSuccess(context, 'Đã duyệt vi phạm thành công');
          Navigator.pop(context, true); // Return true to refresh list
        }
      } else if (_decision == 'reject') {
        await _service.rejectViolation(
          requestId: widget.request.requestId!,
          adminId: adminId,
          reviewNote: reviewNote,
        );

        if (!mounted) return;
        ToastHelper.showWarning(context, 'Đã từ chối vi phạm');
        Navigator.pop(context, true); // Return true to refresh list
      }
    } catch (e) {
      if (!mounted) return;
      ToastHelper.showError(context, 'Lỗi: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildMediaSection() {
    final hasImages = _hasImages();
    final hasVideos = _hasVideos();
    final imageUrls = hasImages ? _getImageUrls() : <String>[];
    final videoUrls = hasVideos ? _getVideoUrls() : <String>[];

    if (!hasImages && !hasVideos) {
      return Column(
        children: [
          Icon(Icons.image_not_supported, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'Không có media đính kèm',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats row
        Row(
          children: [
            if (hasImages) ...[
              Chip(
                avatar: const Icon(Icons.image, size: 16),
                label: Text('${imageUrls.length} ảnh'),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 8),
            ],
            if (hasVideos) ...[
              Chip(
                avatar: const Icon(Icons.videocam, size: 16),
                label: Text('${videoUrls.length} video'),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // Image Gallery
        if (hasImages) ...[
          MediaGalleryWidget(
            imageUrls: imageUrls,
            blurByDefault: true,
            warningMessage:
                'Hình ảnh được báo cáo vi phạm: ${widget.request.violationType}',
          ),
          if (hasVideos) const SizedBox(height: 16),
        ],

        // Video Gallery
        if (hasVideos) ...[
          VideoGalleryWidget(
            videoUrls: videoUrls,
            blurByDefault: true,
            warningMessage:
                'Video được báo cáo vi phạm: ${widget.request.violationType}',
          ),
        ],
      ],
    );
  }

  // Helper methods to extract media URLs from violatedObject based on object type
  bool _hasImages() {
    final obj = widget.request.violatedObject;
    switch (widget.request.objectType) {
      case ViolatedObjectType.post:
        final mediaUrls = obj['mediaUrls'];
        if (mediaUrls == null || mediaUrls is! List) return false;
        // Check if URL contains image extensions (before query params)
        return mediaUrls.any((url) {
          final urlStr = url.toString().toLowerCase();
          // Extract path before query parameters
          final path = urlStr.split('?').first;
          return path.endsWith('.jpg') ||
              path.endsWith('.jpeg') ||
              path.endsWith('.png') ||
              path.endsWith('.gif') ||
              path.endsWith('.webp') ||
              path.endsWith('.heic') ||
              path.endsWith('.bmp');
        });
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

  List<String> _getImageUrls() {
    final obj = widget.request.violatedObject;
    switch (widget.request.objectType) {
      case ViolatedObjectType.post:
        final mediaUrls = obj['mediaUrls'];
        if (mediaUrls == null || mediaUrls is! List) return [];
        return List<String>.from(
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
      case ViolatedObjectType.comment:
        final imageUrls = obj['imageUrls'];
        if (imageUrls == null || imageUrls is! List) return [];
        return List<String>.from(imageUrls);
      case ViolatedObjectType.review:
      case ViolatedObjectType.place:
        final images = obj['images'];
        if (images == null || images is! List) return [];
        return List<String>.from(images);
      case ViolatedObjectType.user:
        return [];
    }
  }

  bool _hasVideos() {
    final obj = widget.request.violatedObject;
    switch (widget.request.objectType) {
      case ViolatedObjectType.post:
        final mediaUrls = obj['mediaUrls'];
        if (mediaUrls == null || mediaUrls is! List) return false;
        return mediaUrls.any((url) {
          final urlStr = url.toString().toLowerCase();
          final path = urlStr.split('?').first;
          return path.endsWith('.mp4') ||
              path.endsWith('.mov') ||
              path.endsWith('.avi') ||
              path.endsWith('.mkv') ||
              path.endsWith('.webm') ||
              path.endsWith('.m4v') ||
              path.endsWith('.3gp');
        });
      case ViolatedObjectType.comment:
      case ViolatedObjectType.review:
      case ViolatedObjectType.place:
      case ViolatedObjectType.user:
        return false;
    }
  }

  List<String> _getVideoUrls() {
    final obj = widget.request.violatedObject;
    switch (widget.request.objectType) {
      case ViolatedObjectType.post:
        final mediaUrls = obj['mediaUrls'];
        if (mediaUrls == null || mediaUrls is! List) return [];
        return List<String>.from(
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
      case ViolatedObjectType.comment:
      case ViolatedObjectType.review:
      case ViolatedObjectType.place:
      case ViolatedObjectType.user:
        return [];
    }
  }

  /// Build user violation action options
  Widget _buildUserViolationOptions(bool isDark) {
    final warningCount = _userViolationData?['warningCount'] ?? 0;
    final isBanned = _userViolationData?['isBanned'] ?? false;
    final totalPoints = _userViolationData?['totalPoints'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User current status
        if (_isLoadingUserData)
          const Center(child: CircularProgressIndicator())
        else if (_userViolationData != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📊 Trạng thái hiện tại của user:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '⚠️ Cảnh báo: $warningCount lần',
                        style: TextStyle(
                          color: warningCount > 0 ? Colors.orange : Colors.grey,
                          fontWeight:
                              warningCount > 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '⭐ Điểm: $totalPoints',
                        style: TextStyle(
                          color: totalPoints < 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isBanned)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.block, color: Colors.red, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'User đã bị cấm trước đó',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        const Text(
          'Chọn mức độ xử lý:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),

        // Warning action
        RadioListTile<String>(
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text('Cảnh cáo', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          subtitle: const Text(
            '• Tăng số lần cảnh báo\n'
            '• Trừ điểm theo mức độ vi phạm\n'
            '• Gửi email cảnh báo\n'
            '• User vẫn có thể tiếp tục sử dụng app',
            style: TextStyle(fontSize: 12),
          ),
          value: 'warning',
          groupValue: _userActionLevel,
          onChanged: (value) {
            setState(() {
              _userActionLevel = value!;
            });
          },
          dense: true,
        ),

        // Ban action
        RadioListTile<String>(
          title: const Row(
            children: [
              Icon(Icons.block, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text(
                'Cấm tài khoản',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          subtitle: const Text(
            '• Vô hiệu hóa tài khoản (không thể đăng nhập)\n'
            '• Trừ điểm theo mức độ vi phạm\n'
            '• Gửi email thông báo cấm\n'
            '• Dữ liệu được giữ lại (soft delete)',
            style: TextStyle(fontSize: 12),
          ),
          value: 'ban',
          groupValue: _userActionLevel,
          onChanged: (value) {
            setState(() {
              _userActionLevel = value!;
            });
          },
          dense: true,
        ),

        // Delete action
        RadioListTile<String>(
          title: const Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text(
                'Xóa tài khoản',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          subtitle: const Text(
            '• Đánh dấu tài khoản để xóa\n'
            '• Vô hiệu hóa tài khoản ngay lập tức\n'
            '• Dữ liệu sẽ bị xóa sau khi xác nhận\n'
            '⚠️ HÀNH ĐỘNG NGHIÊM TRỌNG - CẨN THẬN!',
            style: TextStyle(fontSize: 12, color: Colors.red),
          ),
          value: 'delete',
          groupValue: _userActionLevel,
          onChanged: (value) {
            setState(() {
              _userActionLevel = value!;
            });
          },
          dense: true,
        ),

        const Divider(height: 24),

        // Email option
        CheckboxListTile(
          title: const Text(
            'Gửi email thông báo cho user',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _userActionLevel == 'warning'
                ? 'Email cảnh cáo về vi phạm'
                : _userActionLevel == 'ban'
                ? 'Email thông báo tài khoản bị cấm'
                : 'Email thông báo tài khoản bị xóa',
            style: const TextStyle(fontSize: 12),
          ),
          value: _sendEmail,
          onChanged: (value) {
            setState(() {
              _sendEmail = value ?? true;
            });
          },
        ),

        // Warning based on action level
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                _userActionLevel == 'delete'
                    ? Colors.red.withOpacity(0.1)
                    : _userActionLevel == 'ban'
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  _userActionLevel == 'delete'
                      ? Colors.red
                      : _userActionLevel == 'ban'
                      ? Colors.orange
                      : Colors.blue,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _userActionLevel == 'delete'
                    ? Icons.error
                    : _userActionLevel == 'ban'
                    ? Icons.warning
                    : Icons.info,
                color:
                    _userActionLevel == 'delete'
                        ? Colors.red
                        : _userActionLevel == 'ban'
                        ? Colors.orange
                        : Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _userActionLevel == 'delete'
                      ? 'Hành động này sẽ đánh dấu tài khoản để xóa vĩnh viễn. Vui lòng kiểm tra kỹ trước khi xác nhận!'
                      : _userActionLevel == 'ban'
                      ? 'User sẽ không thể đăng nhập vào app. Dữ liệu được giữ lại để có thể khôi phục nếu cần.'
                      : 'User sẽ nhận được cảnh báo. Nếu vi phạm nhiều lần có thể dẫn đến bị cấm.',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        _userActionLevel == 'delete'
                            ? Colors.red[900]
                            : _userActionLevel == 'ban'
                            ? Colors.orange[900]
                            : Colors.blue[900],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Widget to display user info card with avatar and details
class UserInfoCard extends StatelessWidget {
  final String userId;

  const UserInfoCard({super.key, required this.userId});

  Future<Map<String, dynamic>?> _fetchUserInfo() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

      if (!doc.exists) return null;

      return doc.data();
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchUserInfo(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Đang tải thông tin...'),
                ],
              ),
            ),
          );
        }

        final userData = snapshot.data;
        if (userData == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text(
                        'Không tìm thấy thông tin',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'User ID: $userId',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        final username = userData['name'] ?? 'Unknown';
        final email = userData['email'] ?? '';
        final avatarUrl = userData['avatarUrl'] ?? '';
        final totalPoints = userData['totalPoints'] ?? 0;
        final warningCount = userData['warningCount'] ?? 0;
        final isBanned = userData['isBanned'] ?? false;

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey[300],
                  child:
                      avatarUrl != null
                          ? ClipOval(
                            child: Image.network(
                              avatarUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Text(
                                  username[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          )
                          : Text(
                            username[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
                const SizedBox(width: 16),
                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              username,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isBanned)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'BẤN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                email,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.amber[700]),
                          const SizedBox(width: 4),
                          Text(
                            '$totalPoints điểm',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 16),
                          if (warningCount > 0) ...[
                            Icon(
                              Icons.warning,
                              size: 14,
                              color: Colors.orange[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$warningCount cảnh báo',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: $userId',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
