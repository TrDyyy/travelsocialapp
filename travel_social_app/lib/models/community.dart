import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:travel_social_app/models/tourism_type.dart';

/// Model cho Community (Cộng đồng)
class Community {
  final String? communityId;
  final String name;
  final String description;
  final String adminId; // User ID của admin
  final List<String> memberIds; // Danh sách member IDs
  final List<String> pendingRequests; // Danh sách userId đang chờ duyệt
  final List<TourismType> tourismTypes; // Các thể loại du lịch mục tiêu
  final String? coverImageUrl; // Ảnh bìa community (Detached cover)
  final String? avatarUrl; // Avatar community
  final List<String> rules; // Quy định của community
  final int memberCount;
  final int postCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Community({
    this.communityId,
    required this.name,
    required this.description,
    required this.adminId,
    this.memberIds = const [],
    this.pendingRequests = const [],
    this.tourismTypes = const [],
    this.coverImageUrl,
    this.avatarUrl,
    this.rules = const [],
    this.memberCount = 1, // Admin là member đầu tiên
    this.postCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// Tạo từ Firestore Document
  factory Community.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Community(
      communityId: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      adminId: data['adminId'] ?? '',
      memberIds:
          data['memberIds'] != null ? List<String>.from(data['memberIds']) : [],
      pendingRequests:
          data['pendingRequests'] != null
              ? List<String>.from(data['pendingRequests'])
              : [],
      tourismTypes:
          data['tourismTypes'] != null
              ? (data['tourismTypes'] as List).map((item) {
                // Hỗ trợ cả 2 format: String (typeId) hoặc Map (full object)
                if (item is String) {
                  return TourismType(
                    typeId: item,
                    name: '', // Will be loaded separately if needed
                    description: '',
                  );
                } else if (item is Map<String, dynamic>) {
                  return TourismType(
                    typeId: item['typeId'] ?? '',
                    name: item['name'] ?? '',
                    description: item['description'] ?? '',
                  );
                }
                return TourismType(typeId: '', name: '', description: '');
              }).toList()
              : [],
      coverImageUrl: data['coverImageUrl'],
      avatarUrl: data['avatarUrl'],
      rules: data['rules'] != null ? List<String>.from(data['rules']) : [],
      memberCount: data['memberCount'] ?? 1,
      postCount: data['postCount'] ?? 0,
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
      updatedAt:
          data['updatedAt'] != null
              ? (data['updatedAt'] as Timestamp).toDate()
              : null,
    );
  }

  /// Chuyển sang Map để lưu Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'adminId': adminId,
      'memberIds': memberIds,
      'pendingRequests': pendingRequests,
      'tourismTypes':
          tourismTypes
              .map(
                (e) => {
                  'typeId': e.typeId,
                  'name': e.name,
                  'description': e.description,
                },
              )
              .toList(),
      'coverImageUrl': coverImageUrl,
      'avatarUrl': avatarUrl,
      'rules': rules,
      'memberCount': memberCount,
      'postCount': postCount,
      'createdAt':
          createdAt != null
              ? Timestamp.fromDate(createdAt!)
              : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Copy with
  Community copyWith({
    String? communityId,
    String? name,
    String? description,
    String? adminId,
    List<String>? memberIds,
    List<String>? pendingRequests,
    List<TourismType>? tourismTypes,
    String? coverImageUrl,
    String? avatarUrl,
    List<String>? rules,
    int? memberCount,
    int? postCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Community(
      communityId: communityId ?? this.communityId,
      name: name ?? this.name,
      description: description ?? this.description,
      adminId: adminId ?? this.adminId,
      memberIds: memberIds ?? this.memberIds,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      tourismTypes: tourismTypes ?? this.tourismTypes,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rules: rules ?? this.rules,
      memberCount: memberCount ?? this.memberCount,
      postCount: postCount ?? this.postCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if user is admin
  bool isAdmin(String userId) => adminId == userId;

  /// Check if user is member
  bool isMember(String userId) => memberIds.contains(userId) || isAdmin(userId);

  /// Check if user has pending request
  bool hasPendingRequest(String userId) => pendingRequests.contains(userId);
}
