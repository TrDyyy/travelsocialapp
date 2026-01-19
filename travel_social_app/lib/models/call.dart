import 'package:cloud_firestore/cloud_firestore.dart';

/// Loại cuộc gọi
enum CallType {
  voice, // Gọi thoại
  video, // Gọi video
}

/// Trạng thái cuộc gọi
enum CallStatus {
  ringing, // Đang đổ chuông
  answered, // Đã trả lời
  rejected, // Bị từ chối
  ended, // Đã kết thúc
  missed, // Nhỡ cuộc gọi
  busy, // Bận
}

/// Model cho cuộc gọi
class Call {
  final String id;
  final String chatId;
  final String callerId; // Người gọi
  final List<String> receiverIds; // Người nhận (có thể nhiều người)
  final CallType callType;
  final CallStatus callStatus;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final String? agoraChannelName; // Tên channel Agora
  final String? agoraToken; // Token Agora
  final int? duration; // Thời lượng cuộc gọi (giây)

  Call({
    required this.id,
    required this.chatId,
    required this.callerId,
    required this.receiverIds,
    required this.callType,
    required this.callStatus,
    required this.createdAt,
    this.answeredAt,
    this.endedAt,
    this.agoraChannelName,
    this.agoraToken,
    this.duration,
  });

  /// Convert to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'callerId': callerId,
      'receiverIds': receiverIds,
      'callType': callType.name,
      'callStatus': callStatus.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'answeredAt': answeredAt != null ? Timestamp.fromDate(answeredAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'agoraChannelName': agoraChannelName,
      'agoraToken': agoraToken,
      'duration': duration,
    };
  }

  /// Create from Firestore
  factory Call.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Call(
      id: doc.id,
      chatId: data['chatId'] ?? '',
      callerId: data['callerId'] ?? '',
      receiverIds: List<String>.from(data['receiverIds'] ?? []),
      callType: CallType.values.firstWhere(
        (e) => e.name == data['callType'],
        orElse: () => CallType.voice,
      ),
      callStatus: CallStatus.values.firstWhere(
        (e) => e.name == data['callStatus'],
        orElse: () => CallStatus.ringing,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      answeredAt:
          data['answeredAt'] != null
              ? (data['answeredAt'] as Timestamp).toDate()
              : null,
      endedAt:
          data['endedAt'] != null
              ? (data['endedAt'] as Timestamp).toDate()
              : null,
      agoraChannelName: data['agoraChannelName'],
      agoraToken: data['agoraToken'],
      duration: data['duration'],
    );
  }

  /// Copy with
  Call copyWith({
    String? id,
    String? chatId,
    String? callerId,
    List<String>? receiverIds,
    CallType? callType,
    CallStatus? callStatus,
    DateTime? createdAt,
    DateTime? answeredAt,
    DateTime? endedAt,
    String? agoraChannelName,
    String? agoraToken,
    int? duration,
  }) {
    return Call(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      callerId: callerId ?? this.callerId,
      receiverIds: receiverIds ?? this.receiverIds,
      callType: callType ?? this.callType,
      callStatus: callStatus ?? this.callStatus,
      createdAt: createdAt ?? this.createdAt,
      answeredAt: answeredAt ?? this.answeredAt,
      endedAt: endedAt ?? this.endedAt,
      agoraChannelName: agoraChannelName ?? this.agoraChannelName,
      agoraToken: agoraToken ?? this.agoraToken,
      duration: duration ?? this.duration,
    );
  }

  /// Get call type icon
  String get callTypeIcon {
    switch (callType) {
      case CallType.voice:
        return '📞';
      case CallType.video:
        return '📹';
    }
  }

  /// Get call status text
  String get callStatusText {
    switch (callStatus) {
      case CallStatus.ringing:
        return 'Đang đổ chuông...';
      case CallStatus.answered:
        return 'Đã trả lời';
      case CallStatus.rejected:
        return 'Bị từ chối';
      case CallStatus.ended:
        return 'Đã kết thúc';
      case CallStatus.missed:
        return 'Nhỡ cuộc gọi';
      case CallStatus.busy:
        return 'Bận';
    }
  }

  /// Format duration
  String get formattedDuration {
    if (duration == null) return '';
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
