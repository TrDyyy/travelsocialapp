import 'package:cloud_firestore/cloud_firestore.dart';

/// Model cho sở thích người dùng
class UserPreferences {
  final String userId;
  final List<String> favoriteTypes; // List of typeIds
  final Map<String, int> typeInteractionCounts; // typeId -> count
  final DateTime? lastUpdated;

  UserPreferences({
    required this.userId,
    this.favoriteTypes = const [],
    this.typeInteractionCounts = const {},
    this.lastUpdated,
  });

  /// Convert to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'favoriteTypes': favoriteTypes,
      'typeInteractionCounts': typeInteractionCounts,
      'lastUpdated':
          lastUpdated != null
              ? Timestamp.fromDate(lastUpdated!)
              : FieldValue.serverTimestamp(),
    };
  }

  /// Create from Firestore
  factory UserPreferences.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserPreferences(
      userId: data['userId'] ?? '',
      favoriteTypes: List<String>.from(data['favoriteTypes'] ?? []),
      typeInteractionCounts: Map<String, int>.from(
        data['typeInteractionCounts'] ?? {},
      ),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }

  /// Copy with
  UserPreferences copyWith({
    String? userId,
    List<String>? favoriteTypes,
    Map<String, int>? typeInteractionCounts,
    DateTime? lastUpdated,
  }) {
    return UserPreferences(
      userId: userId ?? this.userId,
      favoriteTypes: favoriteTypes ?? this.favoriteTypes,
      typeInteractionCounts:
          typeInteractionCounts ?? this.typeInteractionCounts,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
