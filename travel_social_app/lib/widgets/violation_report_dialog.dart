import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/violation_request.dart';
import '../services/violation_request_service.dart';
import '../utils/constants.dart';

/// Dialog popup để người dùng báo cáo vi phạm
class ViolationReportDialog extends StatefulWidget {
  final ViolatedObjectType objectType;
  final dynamic
  violatedObject; // Object thực tế (Place, Post, Comment, Review, User)
  final VoidCallback? onReportSuccess;

  const ViolationReportDialog({
    super.key,
    required this.objectType,
    required this.violatedObject,
    this.onReportSuccess,
  });

  @override
  State<ViolationReportDialog> createState() => _ViolationReportDialogState();
}

class _ViolationReportDialogState extends State<ViolationReportDialog> {
  final ViolationRequestService _service = ViolationRequestService();
  final TextEditingController _reasonController = TextEditingController();

  String? _selectedViolationType;
  bool _isSubmitting = false;
  bool _hasCheckedReported = false;
  bool _alreadyReported = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyReported();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  /// Kiểm tra xem user đã báo cáo object này chưa
  Future<void> _checkIfAlreadyReported() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    String? objectId;
    switch (widget.objectType) {
      case ViolatedObjectType.place:
        objectId = widget.violatedObject.placeId;
        break;
      case ViolatedObjectType.post:
        objectId = widget.violatedObject.postId;
        break;
      case ViolatedObjectType.comment:
        objectId = widget.violatedObject.commentId;
        break;
      case ViolatedObjectType.review:
        objectId = widget.violatedObject.reviewId;
        break;
      case ViolatedObjectType.user:
        objectId = widget.violatedObject.userId;
        break;
    }

    if (objectId != null) {
      final hasReported = await _service.hasUserReportedObject(
        currentUser.uid,
        widget.objectType,
        objectId,
      );

      setState(() {
        _alreadyReported = hasReported;
        _hasCheckedReported = true;
      });
    } else {
      setState(() {
        _hasCheckedReported = true;
      });
    }
  }

  /// Tạo violated object map từ object được truyền vào
  Map<String, dynamic> _createViolatedObjectMap() {
    switch (widget.objectType) {
      case ViolatedObjectType.place:
        return ViolationRequestService.createViolatedObjectFromPlace(
          widget.violatedObject,
        );
      case ViolatedObjectType.post:
        return ViolationRequestService.createViolatedObjectFromPost(
          widget.violatedObject,
        );
      case ViolatedObjectType.comment:
        return ViolationRequestService.createViolatedObjectFromComment(
          widget.violatedObject,
        );
      case ViolatedObjectType.review:
        return ViolationRequestService.createViolatedObjectFromReview(
          widget.violatedObject,
        );
      case ViolatedObjectType.user:
        return ViolationRequestService.createViolatedObjectFromUser(
          widget.violatedObject,
        );
    }
  }

  /// Xử lý gửi báo cáo
  Future<void> _handleSubmit() async {
    if (_selectedViolationType == null) {
      _showError('Vui lòng chọn loại vi phạm');
      return;
    }

    // Nếu chọn "Khác", phải có lý do
    if (_selectedViolationType == ViolationConstants.typeOther &&
        _reasonController.text.trim().isEmpty) {
      _showError('Vui lòng mô tả chi tiết lý do vi phạm');
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showError('Vui lòng đăng nhập để báo cáo vi phạm');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final request = ViolationRequest(
        reporterId: currentUser.uid,
        objectType: widget.objectType,
        violatedObject: _createViolatedObjectMap(),
        violationType: _selectedViolationType!,
        violationReason:
            _reasonController.text.trim().isEmpty
                ? ViolationConstants.getViolationTypeDescription(
                  _selectedViolationType!,
                )
                : _reasonController.text.trim(),
      );

      final requestId = await _service.createViolationReport(request);

      if (requestId != null) {
        if (mounted) {
          Navigator.pop(context);
          _showSuccess('Đã gửi báo cáo vi phạm. Admin sẽ xem xét sớm nhất.');
          widget.onReportSuccess?.call();
        }
      } else {
        _showError('Không thể gửi báo cáo. Vui lòng thử lại.');
      }
    } catch (e) {
      _showError('Đã xảy ra lỗi: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child:
            !_hasCheckedReported
                ? const Center(child: CircularProgressIndicator())
                : _alreadyReported
                ? _buildAlreadyReportedContent()
                : _buildReportForm(),
      ),
    );
  }

  Widget _buildAlreadyReportedContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.info_outline, size: 64, color: AppColors.warning),
        const SizedBox(height: 16),
        Text(
          'Đã báo cáo',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          'Bạn đã báo cáo ${widget.objectType.displayName.toLowerCase()} này trước đó. Admin đang xem xét.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
          child: const Text('Đóng'),
        ),
      ],
    );
  }

  Widget _buildReportForm() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.report_problem, color: AppColors.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Báo cáo vi phạm',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Báo cáo ${widget.objectType.displayName.toLowerCase()} này nếu bạn thấy có vi phạm quy định cộng đồng',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.getTextSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 24),

          // Loại vi phạm
          Text(
            'Loại vi phạm *',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...ViolationConstants.allViolationTypes.map((type) {
            return RadioListTile<String>(
              value: type,
              groupValue: _selectedViolationType,
              onChanged:
                  _isSubmitting
                      ? null
                      : (value) {
                        setState(() {
                          _selectedViolationType = value;
                        });
                      },
              title: Text(ViolationConstants.getViolationTypeLabel(type)),
              activeColor: AppColors.primaryGreen,
              contentPadding: EdgeInsets.zero,
            );
          }),

          const SizedBox(height: 16),

          // Lý do chi tiết
          Text(
            _selectedViolationType == ViolationConstants.typeOther
                ? 'Mô tả chi tiết *'
                : 'Mô tả chi tiết (tùy chọn)',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonController,
            maxLines: 4,
            maxLength: 500,
            enabled: !_isSubmitting,
            decoration: InputDecoration(
              hintText: 'Mô tả cụ thể lý do bạn cho rằng đây là vi phạm...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: AppTheme.getInputBackgroundColor(context),
            ),
          ),

          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _isSubmitting ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Hủy'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child:
                      _isSubmitting
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Text('Gửi báo cáo'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
