import 'package:cloud_firestore/cloud_firestore.dart';

/// Model cho preference profile - mỗi user có DUY NHẤT 1 profile
/// Document ID chính là userId để đảm bảo unique
class PreferenceProfile {
  final String userId; // Document ID
  final List<String> favoriteTypes; // List of typeIds yêu thích
  final DateTime createdAt;
  final DateTime updatedAt;

  PreferenceProfile({
    required this.userId,
    this.favoriteTypes = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'favoriteTypes': favoriteTypes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create from Firestore
  factory PreferenceProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PreferenceProfile(
      userId: doc.id, // Document ID chính là userId
      favoriteTypes: List<String>.from(data['favoriteTypes'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Copy with
  PreferenceProfile copyWith({
    String? userId,
    List<String>? favoriteTypes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PreferenceProfile(
      userId: userId ?? this.userId,
      favoriteTypes: favoriteTypes ?? this.favoriteTypes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
