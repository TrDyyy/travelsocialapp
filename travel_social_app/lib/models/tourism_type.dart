import 'package:cloud_firestore/cloud_firestore.dart';

/// Model cho loại hình du lịch
class TourismType {
  final String typeId;
  final String name;
  final String description;

  TourismType({
    required this.typeId,
    required this.name,
    required this.description,
  });

  /// Tạo TourismType từ Firestore document
  factory TourismType.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TourismType(
      typeId: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
    );
  }

  /// Chuyển TourismType thành Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {'name': name, 'description': description};
  }

  /// Copy with
  TourismType copyWith({String? typeId, String? name, String? description}) {
    return TourismType(
      typeId: typeId ?? this.typeId,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }
}
