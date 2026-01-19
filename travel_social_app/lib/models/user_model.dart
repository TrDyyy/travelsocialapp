import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_badge.dart';

/// Model cho người dùng
class UserModel {
  final String userId;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? bio;
  final String role; // 'user', 'admin'
  final int points; // Deprecated - use totalPoints
  final int totalPoints; // MAIN: Total points earned from all activities
  final int level; // User level (1-10)
  final UserBadge? currentBadge; // Current badge/rank based on totalPoints
  final DateTime? dateBirth;
  final String? phoneNumber;
  final DateTime createdAt;

  /// Getter cho cấp bậc (rank) của người dùng
  String get rank => currentBadge?.name ?? 'Chưa có';

  UserModel({
    required this.userId,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.bio,
    this.role = 'user',
    this.points = 0,
    this.totalPoints = 0,
    this.level = 1,
    this.currentBadge,
    this.dateBirth,
    this.phoneNumber,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Tạo từ Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse points - xử lý cả String và int
    int pointsValue = 0;
    if (data['points'] != null) {
      if (data['points'] is int) {
        pointsValue = data['points'] as int;
      } else if (data['points'] is String) {
        pointsValue = int.tryParse(data['points'] as String) ?? 0;
      } else if (data['points'] is double) {
        pointsValue = (data['points'] as double).toInt();
      }
    }

    // Parse totalPoints (new field)
    // Đối với account cũ: migrate từ 'points' sang 'totalPoints'
    int totalPointsValue = data['totalPoints'] ?? pointsValue;

    UserBadge? badge;
    if (data['currentBadge'] != null) {
      badge = UserBadge.fromMap(data['currentBadge']);
    } else if (totalPointsValue > 0) {
      // Account cũ có điểm nhưng chưa có badge → tự động gán badge phù hợp
      badge = UserBadge.getBadgeByPoints(totalPointsValue);
    }

    return UserModel(
      userId: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      avatarUrl: data['avatarUrl'],
      bio: data['bio'],
      role: data['role'] ?? 'user',
      points: pointsValue,
      totalPoints: totalPointsValue,
      level: data['level'] ?? 1,
      currentBadge: badge,
      dateBirth:
          data['dateBirth'] != null
              ? (data['dateBirth'] as Timestamp).toDate()
              : null,
      phoneNumber: data['phoneNumber'],
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  /// Chuyển đổi sang Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'role': role,
      'points': points,
      'totalPoints': totalPoints,
      'level': level,
      'currentBadge': currentBadge?.toFirestore(),
      'dateBirth': dateBirth != null ? Timestamp.fromDate(dateBirth!) : null,
      'phoneNumber': phoneNumber,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Copy with
  UserModel copyWith({
    String? userId,
    String? name,
    String? email,
    String? avatarUrl,
    String? bio,
    String? role,
    int? points,
    int? totalPoints,
    int? level,
    UserBadge? currentBadge,
    DateTime? dateBirth,
    String? phoneNumber,
    DateTime? createdAt,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      role: role ?? this.role,
      points: points ?? this.points,
      totalPoints: totalPoints ?? this.totalPoints,
      level: level ?? this.level,
      currentBadge: currentBadge ?? this.currentBadge,
      dateBirth: dateBirth ?? this.dateBirth,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
