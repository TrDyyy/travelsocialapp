import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

enum MediaType { image, video }

class MediaItem {
  final String url;
  final MediaType type;
  final File? file; // For local files

  MediaItem({required this.url, required this.type, this.file});

  bool get isImage => type == MediaType.image;
  bool get isVideo => type == MediaType.video;
  bool get isLocal => file != null;
}

/// Service xử lý media (ảnh/video) chung cho toàn app
class MediaService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  static const int maxVideoSizeMB = 50;
  static const int maxImageSizeMB = 5;

  /// Pick images từ thư viện
  Future<List<File>> pickImages() async {
    try {
      final pickedFiles = await _imagePicker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
      );

      return pickedFiles.map((xFile) => File(xFile.path)).toList();
    } catch (e) {
      debugPrint('❌ Error picking images: $e');
      return [];
    }
  }

  /// Pick single image từ thư viện
  Future<File?> pickSingleImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1920,
      );

      return pickedFile != null ? File(pickedFile.path) : null;
    } catch (e) {
      debugPrint('❌ Error picking image: $e');
      return null;
    }
  }

  /// Take photo từ camera
  Future<File?> takePhoto() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
      );

      return pickedFile != null ? File(pickedFile.path) : null;
    } catch (e) {
      debugPrint('❌ Error taking photo: $e');
      return null;
    }
  }

  /// Pick video từ thư viện
  Future<File?> pickVideo() async {
    try {
      final pickedFile = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSizeInMB = await file.length() / (1024 * 1024);

        if (fileSizeInMB > maxVideoSizeMB) {
          debugPrint(
            '❌ Video size: ${fileSizeInMB.toStringAsFixed(1)}MB exceeds ${maxVideoSizeMB}MB',
          );
          throw Exception(
            'Video phải nhỏ hơn ${maxVideoSizeMB}MB (${fileSizeInMB.toStringAsFixed(1)}MB)',
          );
        }

        return file;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error picking video: $e');
      rethrow; // Throw lại để UI xử lý
    }
  }

  /// Record video từ camera
  Future<File?> recordVideo() async {
    try {
      final pickedFile = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSizeInMB = await file.length() / (1024 * 1024);

        if (fileSizeInMB > maxVideoSizeMB) {
          debugPrint(
            '❌ Video size: ${fileSizeInMB.toStringAsFixed(1)}MB exceeds ${maxVideoSizeMB}MB',
          );
          throw Exception(
            'Video phải nhỏ hơn ${maxVideoSizeMB}MB (${fileSizeInMB.toStringAsFixed(1)}MB)',
          );
        }

        return file;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error recording video: $e');
      rethrow; // Throw lại để UI xử lý
    }
  }

  /// Upload media files (images/videos) lên Firebase Storage
  Future<List<String>> uploadMedia(List<File> files, String folder) async {
    final List<String> urls = [];

    try {
      for (var file in files) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
        final ref = _storage.ref().child('$folder/$fileName');

        final uploadTask = await ref.putFile(file);
        final url = await uploadTask.ref.getDownloadURL();

        urls.add(url);
        debugPrint('✅ Uploaded: $url');
      }

      return urls;
    } catch (e) {
      debugPrint('❌ Error uploading media: $e');
      return urls;
    }
  }

  /// Xóa media từ Firebase Storage
  Future<void> deleteMedia(List<String> urls) async {
    try {
      for (var url in urls) {
        final ref = _storage.refFromURL(url);
        await ref.delete();
        debugPrint('✅ Deleted: $url');
      }
    } catch (e) {
      debugPrint('❌ Error deleting media: $e');
    }
  }

  /// Parse URLs thành MediaItems
  List<MediaItem> parseMediaUrls(List<String> urls) {
    return urls.map((url) {
      final isVideo =
          url.contains('.mp4') ||
          url.contains('.mov') ||
          url.contains('.avi') ||
          url.contains('.mkv');

      return MediaItem(
        url: url,
        type: isVideo ? MediaType.video : MediaType.image,
      );
    }).toList();
  }

  /// Validate video size
  Future<bool> isVideoSizeValid(File file) async {
    try {
      final fileSizeInMB = await file.length() / (1024 * 1024);
      return fileSizeInMB <= maxVideoSizeMB;
    } catch (e) {
      return false;
    }
  }

  /// Validate image size
  Future<bool> isImageSizeValid(File file) async {
    try {
      final fileSizeInMB = await file.length() / (1024 * 1024);
      return fileSizeInMB <= maxImageSizeMB;
    } catch (e) {
      return false;
    }
  }

  /// Upload community avatar
  Future<String?> uploadCommunityAvatar(File file, String userId) async {
    try {
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('community_avatars/$fileName');

      final uploadTask = await ref.putFile(file);
      final url = await uploadTask.ref.getDownloadURL();

      debugPrint('✅ Uploaded community avatar: $url');
      return url;
    } catch (e) {
      debugPrint('❌ Error uploading community avatar: $e');
      return null;
    }
  }
}
