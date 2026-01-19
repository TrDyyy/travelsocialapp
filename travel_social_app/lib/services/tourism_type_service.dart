import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/tourism_type.dart';

/// Service quản lý Tourism Types
class TourismTypeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Lấy tất cả tourism types
  Future<List<TourismType>> getTourismTypes() async {
    try {
      final snapshot = await _firestore.collection('tourismTypes').get();
      return snapshot.docs
          .map((doc) => TourismType.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting tourism types: $e');
      return [];
    }
  }

  /// Lấy tourism type theo ID
  Future<TourismType?> getTourismTypeById(String typeId) async {
    try {
      final doc = await _firestore.collection('tourismTypes').doc(typeId).get();
      if (doc.exists) {
        return TourismType.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting tourism type: $e');
      return null;
    }
  }

  /// Stream tất cả tourism types
  Stream<List<TourismType>> getTourismTypesStream() {
    return _firestore
        .collection('tourismTypes')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => TourismType.fromFirestore(doc))
                  .toList(),
        );
  }
}
