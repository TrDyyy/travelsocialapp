import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// ✨ UNIFIED REUSABLE WIDGET: Editable Media Grid ✨
/// Hiển thị grid/list ảnh + video cho chế độ edit
/// Hiển thị cả media cũ (network) và media mới (file) với badge "Đã lưu"
///
/// Dùng cho: Edit Post, Edit Review, Edit Comment
///
/// Display modes:
/// - 'horizontal': Horizontal scrollable list (cho comment)
/// - 'grid': 3-column grid view (cho post/review)
///
/// Video support:
/// - Set supportVideo: true để hỗ trợ video (mặc định: false)
/// - Auto detect video by extension (.mp4, .mov, .avi, .mkv)
class EditableImageGrid extends StatelessWidget {
  final List<String> existingImageUrls;
  final List<File> newImages;
  final Function(int) onRemoveExisting;
  final Function(int) onRemoveNew;
  final double height;
  final double imageSize;
  final String? title; // Optional title for grid mode
  final String displayMode; // 'horizontal' or 'grid'
  final bool supportVideo; // Enable video support (default: false)

  const EditableImageGrid({
    super.key,
    required this.existingImageUrls,
    required this.newImages,
    required this.onRemoveExisting,
    required this.onRemoveNew,
    this.height = 80,
    this.imageSize = 80,
    this.title,
    this.displayMode = 'horizontal',
    this.supportVideo = false,
  });

  bool _isVideo(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.mp4') ||
        ext.endsWith('.mov') ||
        ext.endsWith('.avi') ||
        ext.endsWith('.mkv');
  }

  @override
  Widget build(BuildContext context) {
    final totalImages = existingImageUrls.length + newImages.length;

    if (totalImages == 0) return const SizedBox.shrink();

    if (displayMode == 'grid') {
      return _buildGridView(totalImages);
    } else {
      return _buildHorizontalList(totalImages);
    }
  }

  Widget _buildHorizontalList(int totalImages) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: totalImages,
        itemBuilder: (context, index) => _buildImageItem(index, totalImages),
      ),
    );
  }

  Widget _buildGridView(int totalImages) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Text(
            '$title ($totalImages)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        if (title != null) const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: totalImages,
          itemBuilder: (context, index) => _buildImageItem(index, totalImages),
        ),
      ],
    );
  }

  Widget _buildImageItem(int index, int totalImages) {
    final isExistingImage = index < existingImageUrls.length;
    final mediaPath =
        isExistingImage
            ? existingImageUrls[index]
            : newImages[index - existingImageUrls.length].path;
    final isVideo = supportVideo && _isVideo(mediaPath);

    // Wrap trong Container với fixed size để tránh layout error
    return Container(
      width: displayMode == 'grid' ? null : imageSize,
      height: displayMode == 'grid' ? null : imageSize,
      margin: displayMode == 'grid' ? null : const EdgeInsets.only(right: 8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Media content
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildMediaContent(isExistingImage, index, isVideo),
          ),

          // Video play icon overlay
          if (isVideo)
            const Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white,
                size: 40,
              ),
            ),

          // Badge "Đã lưu" cho media cũ
          if (isExistingImage)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Đã lưu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Nút xóa
          Positioned(
            top: 4,
            right: displayMode == 'grid' ? 4 : 12,
            child: GestureDetector(
              onTap:
                  () =>
                      isExistingImage
                          ? onRemoveExisting(index)
                          : onRemoveNew(index - existingImageUrls.length),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaContent(bool isExisting, int index, bool isVideo) {
    if (isExisting) {
      // Existing media from network
      final url = existingImageUrls[index];
      if (isVideo) {
        return _buildVideoThumbnail(url, isNetwork: true);
      } else {
        return Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder:
              (context, error, stackTrace) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.image_not_supported),
              ),
        );
      }
    } else {
      // New media from file
      final file = newImages[index - existingImageUrls.length];
      if (isVideo) {
        return _buildVideoThumbnail(file.path, isNetwork: false, file: file);
      } else {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
  }

  Widget _buildVideoThumbnail(
    String path, {
    required bool isNetwork,
    File? file,
  }) {
    if (!supportVideo) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(Icons.videocam, color: Colors.white, size: 40),
        ),
      );
    }

    // For video files, show thumbnail with proper error handling
    if (!isNetwork && file != null) {
      return _VideoThumbnailWidget(file: file);
    }

    // For network videos, just show placeholder
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(Icons.videocam, color: Colors.white, size: 40),
      ),
    );
  }
}

/// Stateful widget để quản lý VideoPlayerController lifecycle
class _VideoThumbnailWidget extends StatefulWidget {
  final File file;

  const _VideoThumbnailWidget({required this.file});

  @override
  State<_VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<_VideoThumbnailWidget> {
  VideoPlayerController? _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.file(widget.file);

      // Add error listener
      _controller!.addListener(() {
        if (_controller!.value.hasError) {
          if (mounted) {
            setState(() {
              _hasError = true;
            });
          }
          debugPrint(
            'Video player error: ${_controller!.value.errorDescription}',
          );
        }
      });

      await _controller!.initialize();
      await _controller!.seekTo(Duration.zero);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show error placeholder
    if (_hasError) {
      return Container(
        color: Colors.black87,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 32),
            SizedBox(height: 4),
            Text(
              'Lỗi video',
              style: TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      );
    }

    // Show loading or video thumbnail
    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }

    return VideoPlayer(_controller!);
  }
}
