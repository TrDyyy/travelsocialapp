import 'package:cloud_firestore/cloud_firestore.dart';

/// Chat types
enum ChatType {
  private, // Riêng tư - 1-1 chat
  community, // Cộng đồng - nhiều người
  group, // Group chat - nhóm bạn bè
}

/// Chat model
class Chat {
  final String id;
  final ChatType chatType;
  final List<String> members; // User IDs
  final String? groupAdmin; // Chỉ dùng cho group chat
  final DateTime createdAt;
  final String? lastMessage; // Tin nhắn cuối cùng (optional)
  final DateTime? lastMessageTime; // Thời gian tin nhắn cuối (optional)
  final String? lastMessageSenderId; // Người gửi tin nhắn cuối (optional)
  final int?
  lastMessageImageCount; // Số lượng ảnh trong tin nhắn cuối (optional)
  final String? groupName; // Tên nhóm (group chat)
  final String? groupAvatar; // Avatar nhóm (group chat)
  final Map<String, String>?
  backgroundImages; // {userId: imageUrl} - Background cho từng user (private chat)
  final String?
  groupBackground; // Background chung (group chat - chỉ admin đổi)
  final bool? isPublic; // Community chat có public không (mặc định true)
  final List<String>? mutedBy; // List user IDs đã tắt thông báo

  Chat({
    required this.id,
    required this.chatType,
    required this.members,
    this.groupAdmin,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderId,
    this.lastMessageImageCount,
    this.groupName,
    this.groupAvatar,
    this.backgroundImages,
    this.groupBackground,
    this.isPublic,
    this.mutedBy,
  });

  /// Convert ChatType to String
  static String chatTypeToString(ChatType type) {
    switch (type) {
      case ChatType.private:
        return 'Riêng tư';
      case ChatType.community:
        return 'Cộng đồng';
      case ChatType.group:
        return 'Group chat';
    }
  }

  /// Convert String to ChatType
  static ChatType chatTypeFromString(String type) {
    switch (type) {
      case 'Riêng tư':
        return ChatType.private;
      case 'Cộng đồng':
        return ChatType.community;
      case 'Group chat':
        return ChatType.group;
      default:
        return ChatType.private;
    }
  }

  /// Create from Firestore
  factory Chat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Chat(
      id: doc.id,
      chatType: chatTypeFromString(data['chatType'] ?? 'Riêng tư'),
      members: List<String>.from(data['members'] ?? []),
      groupAdmin: data['groupAdmin'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastMessage: data['lastMessage'],
      lastMessageTime:
          data['lastMessageTime'] != null
              ? (data['lastMessageTime'] as Timestamp).toDate()
              : null,
      lastMessageSenderId: data['lastMessageSenderId'],
      lastMessageImageCount: data['lastMessageImageCount'],
      groupName: data['groupName'],
      groupAvatar: data['groupAvatar'],
      backgroundImages:
          data['backgroundImages'] != null
              ? Map<String, String>.from(data['backgroundImages'])
              : null,
      groupBackground: data['groupBackground'],
      isPublic: data['isPublic'],
      mutedBy:
          data['mutedBy'] != null ? List<String>.from(data['mutedBy']) : null,
    );
  }

  /// Convert to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'chatType': chatTypeToString(chatType),
      'members': members,
      'groupAdmin': groupAdmin,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessage': lastMessage,
      'lastMessageTime':
          lastMessageTime != null ? Timestamp.fromDate(lastMessageTime!) : null,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageImageCount': lastMessageImageCount,
      'groupName': groupName,
      'groupAvatar': groupAvatar,
      'backgroundImages': backgroundImages,
      'groupBackground': groupBackground,
      'isPublic': isPublic,
      'mutedBy': mutedBy,
    };
  }

  /// Copy with
  Chat copyWith({
    String? id,
    ChatType? chatType,
    List<String>? members,
    String? groupAdmin,
    DateTime? createdAt,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
    int? lastMessageImageCount,
    String? groupName,
    String? groupAvatar,
    Map<String, String>? backgroundImages,
    String? groupBackground,
    bool? isPublic,
    List<String>? mutedBy,
  }) {
    return Chat(
      id: id ?? this.id,
      chatType: chatType ?? this.chatType,
      members: members ?? this.members,
      groupAdmin: groupAdmin ?? this.groupAdmin,
      createdAt: createdAt ?? this.createdAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageImageCount:
          lastMessageImageCount ?? this.lastMessageImageCount,
      groupName: groupName ?? this.groupName,
      groupAvatar: groupAvatar ?? this.groupAvatar,
      backgroundImages: backgroundImages ?? this.backgroundImages,
      groupBackground: groupBackground ?? this.groupBackground,
      isPublic: isPublic ?? this.isPublic,
      mutedBy: mutedBy ?? this.mutedBy,
    );
  }

  /// Get other member ID (for private chat)
  String? getOtherMemberId(String currentUserId) {
    if (chatType != ChatType.private) return null;
    return members.firstWhere((id) => id != currentUserId, orElse: () => '');
  }
}
