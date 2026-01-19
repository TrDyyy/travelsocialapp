import 'package:cloud_firestore/cloud_firestore.dart';

/// Model cho yêu cầu chỉnh sửa/đăng ký địa điểm
class PlaceEditRequest {
  final String? requestId;
  final String? placeId; // ObjectId của địa điểm (null nếu là đăng ký mới)
  final String? googlePlaceId; // Google Place ID để đảm bảo chính xác
  final String proposedBy; // ObjectId của user đề xuất
  final String content; // Nội dung mô tả
  final List<String> images; // Danh sách URL hình ảnh
  final String status; // "Đã tiếp nhận", "Đã duyệt", "Từ chối"
  final DateTime createAt;

  // Thông tin địa điểm đề xuất (dùng khi tạo mới)
  final String? placeName;
  final GeoPoint? location;
  final String? address;
  final List<String>? typeIds; // Danh sách các loại hình du lịch (ObjectIds)
  final String? typeName; // Tên loại hình chính (để hiển thị)

  PlaceEditRequest({
    this.requestId,
    this.placeId,
    this.googlePlaceId,
    required this.proposedBy,
    required this.content,
    required this.images,
    this.status = 'Đã tiếp nhận',
    DateTime? createAt,
    this.placeName,
    this.location,
    this.address,
    this.typeIds,
    this.typeName,
  }) : createAt = createAt ?? DateTime.now();

  /// Tạo từ Firestore document
  factory PlaceEditRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PlaceEditRequest(
      requestId: doc.id,
      placeId: data['placeId'],
      googlePlaceId: data['googlePlaceId'],
      proposedBy: data['proposedBy'] ?? '',
      content: data['content'] ?? '',
      images: List<String>.from(data['images'] ?? []),
      status: data['status'] ?? 'Đã tiếp nhận',
      createAt: (data['createAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      placeName: data['placeName'],
      location: data['location'],
      address: data['address'],
      typeIds:
          data['typeIds'] != null ? List<String>.from(data['typeIds']) : null,
      typeName: data['typeName'],
    );
  }

  /// Chuyển đổi sang Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      if (placeId != null) 'placeId': placeId,
      if (googlePlaceId != null) 'googlePlaceId': googlePlaceId,
      'proposedBy': proposedBy,
      'content': content,
      'images': images,
      'status': status,
      'createAt': Timestamp.fromDate(createAt),
      if (placeName != null) 'placeName': placeName,
      if (location != null) 'location': location,
      if (address != null) 'address': address,
      if (typeIds != null) 'typeIds': typeIds,
      if (typeName != null) 'typeName': typeName,
    };
  }

  /// Copy with
  PlaceEditRequest copyWith({
    String? requestId,
    String? placeId,
    String? googlePlaceId,
    String? proposedBy,
    String? content,
    List<String>? images,
    String? status,
    DateTime? createAt,
    String? placeName,
    GeoPoint? location,
    String? address,
    List<String>? typeIds,
    String? typeName,
  }) {
    return PlaceEditRequest(
      requestId: requestId ?? this.requestId,
      placeId: placeId ?? this.placeId,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      proposedBy: proposedBy ?? this.proposedBy,
      content: content ?? this.content,
      images: images ?? this.images,
      status: status ?? this.status,
      createAt: createAt ?? this.createAt,
      placeName: placeName ?? this.placeName,
      location: location ?? this.location,
      address: address ?? this.address,
      typeIds: typeIds ?? this.typeIds,
      typeName: typeName ?? this.typeName,
    );
  }
}
