import 'package:cloud_firestore/cloud_firestore.dart';

/// Model cho địa điểm du lịch
class Place {
  final String? placeId; // Nullable vì khi tạo mới chưa có ID
  final String name;
  final String? address; // Thêm field địa chỉ
  final String? googlePlaceId; // Thêm Google Place ID để đảm bảo tính chính xác
  final GeoPoint location; // (latitude, longitude)
  final String description;
  final String typeId; // Reference đến TourismType
  final String createdBy; // Reference đến User
  final List<String>? images; // Danh sách URL hình ảnh
  final double? rating; // Đánh giá trung bình
  final int? reviewCount; // Số lượng đánh giá
  final DateTime? createdAt;

  Place({
    this.placeId, // Không required nữa
    required this.name,
    this.address,
    this.googlePlaceId,
    required this.location,
    required this.description,
    required this.typeId,
    required this.createdBy,
    this.images,
    this.rating,
    this.reviewCount,
    this.createdAt,
  });

  /// Lấy latitude
  double get latitude => location.latitude;

  /// Lấy longitude
  double get longitude => location.longitude;

  /// Tạo Place từ Firestore document
  factory Place.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Place(
      placeId: doc.id,
      name: data['name'] ?? '',
      address: data['address'],
      googlePlaceId: data['googlePlaceId'],
      location: data['location'] ?? const GeoPoint(0, 0),
      description: data['description'] ?? '',
      typeId: data['typeId'] ?? '',
      createdBy: data['createdBy'] ?? '',
      images: data['images'] != null ? List<String>.from(data['images']) : null,
      rating: data['rating']?.toDouble(),
      reviewCount: data['reviewCount']?.toInt(),
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
    );
  }

  /// Chuyển Place thành Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'googlePlaceId': googlePlaceId,
      'location': location,
      'description': description,
      'typeId': typeId,
      'createdBy': createdBy,
      'images': images,
      'rating': rating,
      'reviewCount': reviewCount,
      'createdAt':
          createdAt != null
              ? Timestamp.fromDate(createdAt!)
              : FieldValue.serverTimestamp(),
    };
  }

  /// Copy with
  Place copyWith({
    String? placeId,
    String? name,
    String? address,
    String? googlePlaceId,
    GeoPoint? location,
    String? description,
    String? typeId,
    String? createdBy,
    List<String>? images,
    double? rating,
    int? reviewCount,
    DateTime? createdAt,
  }) {
    return Place(
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      address: address ?? this.address,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      location: location ?? this.location,
      description: description ?? this.description,
      typeId: typeId ?? this.typeId,
      createdBy: createdBy ?? this.createdBy,
      images: images ?? this.images,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
