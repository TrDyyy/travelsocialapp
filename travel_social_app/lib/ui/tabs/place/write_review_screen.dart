import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/review.dart';
import '../../../models/place.dart';
import '../../../services/review_service.dart';
import '../../../services/activity_tracking_service.dart';
import '../../../services/points_tracking_service.dart';
import '../../../utils/constants.dart';
import '../../../widgets/editable_image_grid.dart';
import 'checkin_dialog.dart';

/// Màn hình viết đánh giá địa điểm
class WriteReviewScreen extends StatefulWidget {
  final Place place;
  final Review? existingReview; // Nếu có thì là edit, không có thì là tạo mới

  const WriteReviewScreen({
    super.key,
    required this.place,
    this.existingReview,
  });

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _reviewService = ReviewService();
  final _activityService = ActivityTrackingService();
  final _pointsService = PointsTrackingService();
  final _imagePicker = ImagePicker();

  double _rating = 5.0;
  List<File> _selectedImages = []; // Ảnh mới chọn
  List<String> _existingImageUrls = []; // Ảnh cũ từ review
  List<String> _imagesToDelete = []; // Ảnh cũ cần xóa
  bool _isLoading = false;
  bool _isCheckedIn = false; // Check-in status
  DateTime? _checkedInAt; // Check-in timestamp

  @override
  void initState() {
    super.initState();
    if (widget.existingReview != null) {
      _rating = widget.existingReview!.rating;
      _contentController.text = widget.existingReview!.content;
      // Load ảnh cũ
      if (widget.existingReview!.images != null) {
        _existingImageUrls = List.from(widget.existingReview!.images!);
      }
      // Load check-in status
      _isCheckedIn = widget.existingReview!.isCheckedIn;
      _checkedInAt = widget.existingReview!.checkedInAt;
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  /// Chọn nhiều ảnh từ thư viện
  Future<void> _pickImages() async {
    try {
      final pickedFiles = await _imagePicker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
      );

      if (pickedFiles.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(
            pickedFiles.map((xFile) => File(xFile.path)).toList(),
          );
        });
      }
    } catch (e) {
      _showError('Không thể chọn ảnh: $e');
    }
  }

  /// Chụp ảnh từ camera
  Future<void> _takePhoto() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImages.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      _showError('Không thể chụp ảnh: $e');
    }
  }

  /// Xóa ảnh đã chọn
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  /// Xóa ảnh cũ (từ review đã tồn tại)
  void _removeExistingImage(int index) {
    setState(() {
      final imageUrl = _existingImageUrls.removeAt(index);
      _imagesToDelete.add(imageUrl); // Đánh dấu để xóa khỏi Storage
    });
  }

  /// Hiển thị dialog check-in
  Future<void> _showCheckInDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => CheckInDialog(
            place: widget.place,
            onCheckInComplete: (isCheckedIn, images) {
              setState(() {
                _isCheckedIn = isCheckedIn;
                _checkedInAt = isCheckedIn ? DateTime.now() : null;
                // Thêm ảnh check-in vào danh sách
                if (images.isNotEmpty) {
                  _selectedImages.addAll(images);
                }
              });
            },
          ),
    );
  }

  /// Submit đánh giá
  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Vui lòng đăng nhập để tiếp tục');
        return;
      }

      // Upload ảnh nếu có
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await _reviewService.uploadReviewImages(
          _selectedImages,
          '${widget.place.placeId}_${user.uid}',
        );

        if (imageUrls.isEmpty && _selectedImages.isNotEmpty) {
          throw Exception('Không thể upload ảnh');
        }
      }

      if (widget.existingReview != null) {
        // Xóa ảnh cũ đã bị remove khỏi Storage
        if (_imagesToDelete.isNotEmpty) {
          await _reviewService.deleteReviewImages(_imagesToDelete);
        }

        // Gộp ảnh cũ còn lại + ảnh mới
        final finalImages = [..._existingImageUrls, ...imageUrls];

        // Cập nhật đánh giá (bao gồm cả check-in status)
        // Luôn truyền images (có thể là [] để xóa hết ảnh)
        final success = await _reviewService.updateReview(
          widget.existingReview!.reviewId!,
          widget.place.placeId!,
          rating: _rating,
          content: _contentController.text.trim(),
          images: finalImages, // Truyền [] nếu xóa hết, không truyền null
          isCheckedIn: _isCheckedIn,
          checkedInAt: _checkedInAt,
        );

        if (success) {
          // Track review activity
          await _activityService.trackReviewPlace(
            placeId: widget.place.placeId!,
            placeTypeId: widget.place.typeId,
            rating: _rating,
          );

          if (mounted) {
            Navigator.pop(context, true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Đã cập nhật đánh giá!'),
                backgroundColor: AppColors.primaryGreen,
              ),
            );
          }
        } else {
          throw Exception('Không thể cập nhật đánh giá');
        }
      } else {
        // Tạo đánh giá mới
        final review = Review(
          userId: user.uid,
          placeId: widget.place.placeId!,
          rating: _rating,
          content: _contentController.text.trim(),
          images: imageUrls.isNotEmpty ? imageUrls : null,
          isCheckedIn: _isCheckedIn,
          checkedInAt: _checkedInAt,
        );

        final reviewId = await _reviewService.createReview(review);

        if (reviewId != null) {
          // Track review activity
          await _activityService.trackReviewPlace(
            placeId: widget.place.placeId!,
            placeTypeId: widget.place.typeId,
            rating: _rating,
          );

          // Award points for review
          await _pointsService.awardReview(
            userId: user.uid,
            placeId: widget.place.placeId!,
            reviewText: _contentController.text.trim(),
            imageCount: imageUrls.length,
            rating: _rating,
          );

          if (mounted) {
            Navigator.pop(context, true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Đã gửi đánh giá!'),
                backgroundColor: AppColors.primaryGreen,
              ),
            );
          }
        } else {
          throw Exception('Không thể tạo đánh giá');
        }
      }
    } catch (e) {
      _showError('Lỗi: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getSurfaceColor(context),
      appBar: AppBar(
        title: Text(
          widget.existingReview != null
              ? 'Chỉnh sửa đánh giá'
              : 'Viết đánh giá',
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            AppSizes.padding(context, SizeCategory.large),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thông tin địa điểm
              _buildPlaceInfo(),
              SizedBox(height: AppSizes.padding(context, SizeCategory.large)),

              // Rating
              _buildRatingSection(),
              SizedBox(height: AppSizes.padding(context, SizeCategory.large)),

              // Nội dung đánh giá
              _buildContentField(),
              SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),

              // Check-in section
              _buildCheckInSection(),
              SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),

              // Upload ảnh
              _buildImagePicker(),
              SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),

              // Grid hiển thị ảnh (cũ + mới)
              if (_existingImageUrls.isNotEmpty || _selectedImages.isNotEmpty)
                _buildImageGrid(),
              SizedBox(height: AppSizes.padding(context, SizeCategory.large)),

              // Nút gửi
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSizes.radius(context, SizeCategory.medium),
                      ),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : Text(
                            widget.existingReview != null
                                ? 'Cập nhật'
                                : 'Gửi đánh giá',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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

  Widget _buildPlaceInfo() {
    return Card(
      color: AppTheme.getSurfaceColor(context),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.location_on,
                color: AppColors.primaryGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.place.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getTextPrimaryColor(context),
                    ),
                  ),

                  const SizedBox(height: 4),
                  Text(
                    widget.place.address ?? 'Không có địa chỉ',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.getTextSecondaryColor(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Đánh giá của bạn',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(
              AppSizes.radius(context, SizeCategory.medium),
            ),
            border: Border.all(color: AppTheme.getBorderColor(context)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _rating = (index + 1).toDouble();
                      });
                    },
                    child: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 40,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                _getRatingText(_rating),
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getRatingText(double rating) {
    if (rating >= 5) return 'Xuất sắc';
    if (rating >= 4) return 'Rất tốt';
    if (rating >= 3) return 'Tốt';
    if (rating >= 2) return 'Trung bình';
    return 'Cần cải thiện';
  }

  Widget _buildContentField() {
    return TextFormField(
      controller: _contentController,
      maxLines: 5,
      decoration: InputDecoration(
        labelText: 'Trải nghiệm của bạn',
        hintText: 'Chia sẻ trải nghiệm của bạn về địa điểm này...',
        alignLabelWithHint: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
        ),
        filled: true,
        fillColor: AppTheme.getInputBackgroundColor(context),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Vui lòng nhập nội dung đánh giá';
        }
        if (value.trim().length < 10) {
          return 'Nội dung phải có ít nhất 10 ký tự';
        }
        return null;
      },
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thêm ảnh',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(
              AppSizes.radius(context, SizeCategory.medium),
            ),
            border: Border.all(
              color: AppColors.primaryGreen,
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildImagePickerButton(
                icon: Icons.photo_library,
                label: 'Thư viện',
                onTap: _pickImages,
              ),
              _buildImagePickerButton(
                icon: Icons.camera_alt,
                label: 'Camera',
                onTap: _takePhoto,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImagePickerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryGreen),
            ),
            child: Icon(icon, color: AppColors.primaryGreen, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInSection() {
    return Card(
      color: AppTheme.getSurfaceColor(context),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isCheckedIn ? Icons.verified : Icons.location_on,
                  color:
                      _isCheckedIn ? AppColors.primaryGreen : Colors.grey[600],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isCheckedIn
                            ? 'Đã check-in tại địa điểm'
                            : 'Check-in để tăng độ tin cậy',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color:
                              _isCheckedIn
                                  ? AppColors.primaryGreen
                                  : AppTheme.getTextPrimaryColor(context),
                        ),
                      ),
                      if (_isCheckedIn && _checkedInAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Thời gian: ${_formatDateTime(_checkedInAt!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Cho phép check-in nếu: (tạo mới) HOẶC (edit nhưng chưa check-in)
                if (!_isCheckedIn)
                  TextButton.icon(
                    onPressed: _showCheckInDialog,
                    icon: const Icon(Icons.add_location_alt),
                    label: const Text('Check-in'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                    ),
                  ),
              ],
            ),
            if (!_isCheckedIn)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Đánh giá có check-in sẽ được ưu tiên hiển thị',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildImageGrid() {
    return EditableImageGrid(
      existingImageUrls: _existingImageUrls,
      newImages: _selectedImages,
      onRemoveExisting: _removeExistingImage,
      onRemoveNew: _removeImage,
      title: 'Ảnh đã chọn',
      displayMode: 'grid',
    );
  }
}
