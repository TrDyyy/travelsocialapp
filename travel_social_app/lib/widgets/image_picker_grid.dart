import 'dart:io';
import 'package:flutter/material.dart';

/// Widget hiển thị grid ảnh đã chọn với nút xóa
/// Dùng cho: Comments, Reviews, Places, Posts
class ImagePickerGrid extends StatelessWidget {
  final List<File> images;
  final Function(int) onRemove;
  final double height;
  final double imageSize;

  const ImagePickerGrid({
    super.key,
    required this.images,
    required this.onRemove,
    this.height = 80,
    this.imageSize = 80,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Stack(
            children: [
              Container(
                width: imageSize,
                height: imageSize,
                margin: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(images[index], fit: BoxFit.cover),
                ),
              ),
              // Nút xóa
              Positioned(
                top: 4,
                right: 12,
                child: GestureDetector(
                  onTap: () => onRemove(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
