import 'package:cloud_firestore/cloud_firestore.dart';

/// Model cho danh hiệu người dùng
class UserBadge {
  final String badgeId;
  final String name;
  final String description;
  final String icon; // Emoji or icon name
  final int requiredPoints; // Points required to reach this badge
  final String color; // Hex color code
  final int level; // Badge level (1-10)

  UserBadge({
    required this.badgeId,
    required this.name,
    required this.description,
    required this.icon,
    required this.requiredPoints,
    required this.color,
    required this.level,
  });

  // Predefined badges
  static final List<UserBadge> allBadges = [
    // Level 0: Negative points (penalty)
    UserBadge(
      badgeId: 'needs_improvement',
      name: 'Cần cải thiện',
      description: 'Hãy cố gắng đóng góp tích cực hơn',
      icon: '⚠️',
      requiredPoints: -999999, // Minimum possible
      color: '#FF4444',
      level: 0,
    ),
    // Level 1-3: Newbie
    UserBadge(
      badgeId: 'newbie',
      name: 'Người mới',
      description: 'Chào mừng đến với cộng đồng',
      icon: '🌱',
      requiredPoints: 0,
      color: '#A0D8B3',
      level: 1,
    ),
    UserBadge(
      badgeId: 'explorer',
      name: 'Nhà khám phá',
      description: 'Bắt đầu hành trình',
      icon: '🧭',
      requiredPoints: 500,
      color: '#7FCDCD',
      level: 2,
    ),
    UserBadge(
      badgeId: 'traveler',
      name: 'Du khách',
      description: 'Đang trên đường',
      icon: '🎒',
      requiredPoints: 1000,
      color: '#6FB6D9',
      level: 3,
    ),

    // Level 4-6: Intermediate
    UserBadge(
      badgeId: 'adventurer',
      name: 'Phiêu lưu gia',
      description: 'Dám thử thách',
      icon: '⛰️',
      requiredPoints: 2500,
      color: '#5B9BD5',
      level: 4,
    ),
    UserBadge(
      badgeId: 'guide',
      name: 'Hướng dẫn viên',
      description: 'Chia sẻ kinh nghiệm',
      icon: '🗺️',
      requiredPoints: 5000,
      color: '#4A7BA7',
      level: 5,
    ),
    UserBadge(
      badgeId: 'expert',
      name: 'Chuyên gia',
      description: 'Kiến thức sâu rộng',
      icon: '🎓',
      requiredPoints: 10000,
      color: '#3A5BA0',
      level: 6,
    ),

    // Level 7-9: Advanced
    UserBadge(
      badgeId: 'master',
      name: 'Bậc thầy',
      description: 'Thành thạo mọi lĩnh vực',
      icon: '👑',
      requiredPoints: 20000,
      color: '#FFD700',
      level: 7,
    ),
    UserBadge(
      badgeId: 'legend',
      name: 'Huyền thoại',
      description: 'Đóng góp xuất sắc',
      icon: '🏆',
      requiredPoints: 50000,
      color: '#FFA500',
      level: 8,
    ),
    UserBadge(
      badgeId: 'grandmaster',
      name: 'Đại tông sư',
      description: 'Đỉnh cao du lịch',
      icon: '⭐',
      requiredPoints: 100000,
      color: '#FF6B6B',
      level: 9,
    ),

    // Level 10: Ultimate
    UserBadge(
      badgeId: 'godlike',
      name: 'Thần thoại',
      description: 'Huyền thoại của cộng đồng',
      icon: '💎',
      requiredPoints: 200000,
      color: '#9D4EDD',
      level: 10,
    ),
  ];

  /// Get badge by ID
  static UserBadge? getBadgeById(String badgeId) {
    try {
      return allBadges.firstWhere((badge) => badge.badgeId == badgeId);
    } catch (e) {
      return null;
    }
  }

  /// Get badge by points (highest eligible badge)
  static UserBadge getBadgeByPoints(int points) {
    // Sort badges by requiredPoints descending
    final sortedBadges = List<UserBadge>.from(allBadges)
      ..sort((a, b) => b.requiredPoints.compareTo(a.requiredPoints));

    // Find first badge that user qualifies for
    for (final badge in sortedBadges) {
      if (points >= badge.requiredPoints) {
        return badge;
      }
    }

    // Default to newbie
    return allBadges.first;
  }

  /// Get next badge
  UserBadge? getNextBadge() {
    final currentIndex = allBadges.indexWhere((b) => b.badgeId == badgeId);
    if (currentIndex == -1 || currentIndex >= allBadges.length - 1) {
      return null; // Already at max badge
    }
    return allBadges[currentIndex + 1];
  }

  /// Points needed for next badge
  int? getPointsToNextBadge(int userPoints) {
    final nextBadge = getNextBadge();
    if (nextBadge == null) return null;
    final remaining = nextBadge.requiredPoints - userPoints;
    return remaining > 0 ? remaining : 0;
  }

  /// Copy badge (for consistency)
  UserBadge copyWith() {
    return UserBadge(
      badgeId: badgeId,
      name: name,
      description: description,
      icon: icon,
      requiredPoints: requiredPoints,
      color: color,
      level: level,
    );
  }

  /// Convert to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'badgeId': badgeId,
      'name': name,
      'description': description,
      'icon': icon,
      'requiredPoints': requiredPoints,
      'color': color,
      'level': level,
    };
  }

  /// Convert from Firestore
  factory UserBadge.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserBadge(
      badgeId: data['badgeId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      icon: data['icon'] ?? '🌱',
      requiredPoints: data['requiredPoints'] ?? 0,
      color: data['color'] ?? '#A0D8B3',
      level: data['level'] ?? 1,
    );
  }

  /// Convert from map
  factory UserBadge.fromMap(Map<String, dynamic> data) {
    return UserBadge(
      badgeId: data['badgeId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      icon: data['icon'] ?? '🌱',
      requiredPoints: data['requiredPoints'] ?? 0,
      color: data['color'] ?? '#A0D8B3',
      level: data['level'] ?? 1,
    );
  }

  @override
  String toString() {
    return 'UserBadge(badgeId: $badgeId, name: $name, level: $level, points: $requiredPoints)';
  }
}
