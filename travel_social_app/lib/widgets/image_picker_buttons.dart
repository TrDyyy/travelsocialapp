import 'package:flutter/material.dart';
import 'package:travel_social_app/utils/constants.dart';

/// Widget nút chọn ảnh (Camera + Gallery)
/// Dùng cho: Comments, Reviews, Places, Posts
class ImagePickerButtons extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final bool enabled;
  final Color iconColor;

  const ImagePickerButtons({
    super.key,
    required this.onCamera,
    required this.onGallery,
    this.enabled = true,
    this.iconColor = AppColors.primaryGreen,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.photo_camera, color: iconColor),
          onPressed: enabled ? onCamera : null,
        ),
        IconButton(
          icon: Icon(Icons.photo_library, color: iconColor),
          onPressed: enabled ? onGallery : null,
        ),
      ],
    );
  }
}
