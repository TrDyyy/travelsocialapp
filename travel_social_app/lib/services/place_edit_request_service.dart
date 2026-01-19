import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../models/place_edit_request.dart';

/// Service xử lý yêu cầu chỉnh sửa địa điểm
class PlaceEditRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference get _requestsRef =>
      _firestore.collection('placeEditRequests');

  /// Upload nhiều ảnh lên Firebase Storage
  Future<List<String>> uploadImages(
    List<File> imageFiles,
    String placeId,
  ) async {
    List<String> downloadUrls = [];

    for (int i = 0; i < imageFiles.length; i++) {
      try {
        final file = imageFiles[i];
        final fileName =
            'places/$placeId/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final ref = _storage.ref().child(fileName);

        // Upload file
        final uploadTask = await ref.putFile(file);

        // Lấy download URL
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        downloadUrls.add(downloadUrl);

        debugPrint('✅ Uploaded image ${i + 1}/${imageFiles.length}');
      } catch (e) {
        debugPrint('❌ Error uploading image $i: $e');
      }
    }

    return downloadUrls;
  }

  /// Tạo yêu cầu đăng ký địa điểm mới
  Future<String?> createRequest(PlaceEditRequest request) async {
    try {
      final docRef = await _requestsRef.add(request.toFirestore());
      debugPrint('✅ Created request: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating request: $e');
      return null;
    }
  }

  /// Lấy danh sách yêu cầu của user
  Future<List<PlaceEditRequest>> getUserRequests(String userId) async {
    try {
      final querySnapshot =
          await _requestsRef
              .where('proposedBy', isEqualTo: userId)
              .orderBy('createAt', descending: true)
              .get();

      return querySnapshot.docs
          .map((doc) => PlaceEditRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting user requests: $e');
      return [];
    }
  }

  /// Cập nhật trạng thái yêu cầu
  Future<bool> updateRequestStatus(String requestId, String status) async {
    try {
      await _requestsRef.doc(requestId).update({'status': status});
      return true;
    } catch (e) {
      debugPrint('❌ Error updating request status: $e');
      return false;
    }
  }

  /// Xóa yêu cầu
  Future<bool> deleteRequest(String requestId) async {
    try {
      await _requestsRef.doc(requestId).delete();
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting request: $e');
      return false;
    }
  }
}
