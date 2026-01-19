import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/media_service.dart';

/// Widget hiển thị media (ảnh/video) với zoom và swipe
class MediaViewer extends StatefulWidget {
  final List<String> mediaUrls;
  final int initialIndex;

  const MediaViewer({
    super.key,
    required this.mediaUrls,
    this.initialIndex = 0,
  });

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late PageController _pageController;
  late int _currentIndex;
  final _mediaService = MediaService();
  List<MediaItem> _mediaItems = [];
  Map<int, VideoPlayerController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _mediaItems = _mediaService.parseMediaUrls(widget.mediaUrls);

    // Initialize video controller for initial video if exists
    if (_mediaItems[_currentIndex].isVideo) {
      _initVideoController(_currentIndex);
    }

    // Preload next and previous videos for smooth swiping
    _preloadAdjacentVideos(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Dispose all video controllers
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initVideoController(int index) {
    if (_videoControllers.containsKey(index)) return;

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(_mediaItems[index].url),
    );

    controller.initialize().then((_) {
      if (mounted) {
        // Seek to first frame để hiển thị thumbnail
        controller.seekTo(Duration.zero);
        setState(() {});
      }
    });

    _videoControllers[index] = controller;
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Pause previous video if exists
    _videoControllers.forEach((key, controller) {
      if (key != index && controller.value.isPlaying) {
        controller.pause();
      }
    });

    // Initialize new video controller if needed
    if (_mediaItems[index].isVideo && !_videoControllers.containsKey(index)) {
      _initVideoController(index);
    }

    // Preload adjacent videos for smooth experience
    _preloadAdjacentVideos(index);
  }

  void _preloadAdjacentVideos(int currentIndex) {
    // Preload next video
    final nextIndex = currentIndex + 1;
    if (nextIndex < _mediaItems.length &&
        _mediaItems[nextIndex].isVideo &&
        !_videoControllers.containsKey(nextIndex)) {
      _initVideoController(nextIndex);
    }

    // Preload previous video
    final prevIndex = currentIndex - 1;
    if (prevIndex >= 0 &&
        _mediaItems[prevIndex].isVideo &&
        !_videoControllers.containsKey(prevIndex)) {
      _initVideoController(prevIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Media viewer
          PageView.builder(
            controller: _pageController,
            itemCount: _mediaItems.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final mediaItem = _mediaItems[index];

              return Center(
                child:
                    mediaItem.isImage
                        ? InteractiveViewer(
                          child: Image.network(
                            mediaItem.url,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.image_not_supported,
                                color: Colors.white,
                                size: 50,
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              );
                            },
                          ),
                        )
                        : _buildVideoPlayer(index),
              );
            },
          ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // Page indicator
          if (_mediaItems.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${_mediaItems.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer(int index) {
    final controller = _videoControllers[index];

    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (controller.value.isPlaying) {
            controller.pause();
          } else {
            controller.play();
          }
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video player (hiển thị frame đầu tiên khi pause)
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
          // Dark overlay khi pause để làm nổi play button
          if (!controller.value.isPlaying) Container(color: Colors.black26),
          // Play/Pause button overlay
          if (!controller.value.isPlaying)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 60,
              ),
            ),
          // Progress indicator
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white30,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
