import 'package:flutter/material.dart';
import '../../../../utils/constants.dart';

/// Helper widget cho lazy loading images với rate limit protection
class LazyNetworkImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const LazyNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  State<LazyNetworkImage> createState() => _LazyNetworkImageState();
}

class _LazyNetworkImageState extends State<LazyNetworkImage> {
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
