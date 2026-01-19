import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/place.dart';
import '../../../services/checkin_service.dart';
import '../../../utils/constants.dart';

/// Dialog check-in tại địa điểm
class CheckInDialog extends StatefulWidget {
  final Place place;
  final Function(bool isCheckedIn, List<File> images) onCheckInComplete;

  const CheckInDialog({
    super.key,
    required this.place,
    required this.onCheckInComplete,
  });

  @override
  State<CheckInDialog> createState() => _CheckInDialogState();
}

class _CheckInDialogState extends State<CheckInDialog> {
  final _checkInService = CheckInService();
  final _imagePicker = ImagePicker();

  bool _isChecking = false;
  bool _checkInSuccess = false;
  String? _message;
  double? _distance;
  final List<File> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _performCheckIn();
  }

  Future<void> _performCheckIn() async {
    setState(() {
      _isChecking = true;
      _message = 'Đang xác minh vị trí...';
    });

    final result = await _checkInService.canCheckIn(widget.place);

    setState(() {
      _isChecking = false;
      _checkInSuccess = result.success;
      _message = result.message;
      _distance = result.distance;
    });
  }

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

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _confirmCheckIn() {
    widget.onCheckInComplete(_checkInSuccess, _selectedImages);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
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
                      const Text(
                        'Check in thành công',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.place.name,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Status
            if (_isChecking)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang xác minh vị trí...'),
                ],
              )
            else
              Column(
                children: [
                  // Icon và message
                  Icon(
                    _checkInSuccess ? Icons.check_circle : Icons.error,
                    size: 64,
                    color:
                        _checkInSuccess
                            ? AppColors.primaryGreen
                            : AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _message ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          _checkInSuccess ? Colors.grey[700] : AppColors.error,
                    ),
                  ),
                  if (_distance != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Khoảng cách: ${_distance!.toStringAsFixed(0)}m',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),

            // Upload ảnh section (chỉ hiện khi check-in thành công)
            if (_checkInSuccess && !_isChecking) ...[
              const SizedBox(height: 24),
              const Text(
                'Nếu tiện hãy gửi cho tôi hình ảnh và cảm nhận về nơi này',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),

              // Image picker buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.photo_library, size: 20),
                      label: const Text('Thư viện'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                        side: BorderSide(color: AppColors.primaryGreen),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt, size: 20),
                      label: const Text('Camera'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                        side: BorderSide(color: AppColors.primaryGreen),
                      ),
                    ),
                  ),
                ],
              ),

              // Selected images grid
              if (_selectedImages.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImages[index],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: InkWell(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],

            const Spacer(),

            // Action buttons
            if (!_isChecking)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _checkInSuccess
                          ? _confirmCheckIn
                          : () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _checkInSuccess ? AppColors.primaryGreen : Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _checkInSuccess ? 'Cung cấp minh chứng địa điểm' : 'Đóng',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
