import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/call.dart';
import '../models/chat.dart';
import '../models/user_model.dart';
import '../config/call_config.dart';
import 'notification_service.dart';
import 'chat_service.dart';

/// Service quản lý cuộc gọi
class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final ChatService _chatService = ChatService();
  late final CollectionReference _callsRef;

  CallService() {
    _callsRef = _firestore.collection('calls');
  }

  /// Tạo cuộc gọi mới
  Future<Call> initiateCall({
    required String chatId,
    required String callerId,
    required List<String> receiverIds,
    required CallType callType,
  }) async {
    try {
      // Validate Agora configuration
      if (!CallConfig.isConfigured) {
        throw Exception(
          'Agora App ID chưa được cấu hình. Vui lòng cập nhật CallConfig.agoraAppId trong lib/config/call_config.dart',
        );
      }

      // Tạo channel name unique
      final channelName =
          '${CallConfig.channelPrefix}${chatId}_${DateTime.now().millisecondsSinceEpoch}';

      final call = Call(
        id: '',
        chatId: chatId,
        callerId: callerId,
        receiverIds: receiverIds,
        callType: callType,
        callStatus: CallStatus.ringing,
        createdAt: DateTime.now(),
        agoraChannelName: channelName,
        agoraToken: null,
      );

      final docRef = await _callsRef.add(call.toFirestore());
      debugPrint('✅ Created call: ${docRef.id}');

      // Gửi notification cho receivers
      await _sendCallNotifications(docRef.id, callerId, receiverIds, callType);

      // KHÔNG gửi message ngay - chỉ gửi khi call kết thúc

      return call.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('❌ Error initiating call: $e');
      rethrow;
    }
  }

  /// Trả lời cuộc gọi
  Future<void> answerCall(String callId, String userId) async {
    try {
      await _callsRef.doc(callId).update({
        'callStatus': CallStatus.answered.name,
        'answeredAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Answered call: $callId');
    } catch (e) {
      debugPrint('❌ Error answering call: $e');
      rethrow;
    }
  }

  /// Từ chối cuộc gọi
  Future<void> rejectCall(String callId, String userId) async {
    try {
      // Lấy thông tin call trước khi reject
      final call = await getCallById(callId);

      await _callsRef.doc(callId).update({
        'callStatus': CallStatus.rejected.name,
        'endedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Rejected call: $callId');

      // Gửi system message - người nhận từ chối
      if (call != null) {
        await _sendCallSystemMessage(
          chatId: call.chatId,
          callerId: call.callerId,
          callType: call.callType,
          status: 'rejected',
        );
      }
    } catch (e) {
      debugPrint('❌ Error rejecting call: $e');
      rethrow;
    }
  }

  /// Kết thúc cuộc gọi
  Future<void> endCall(String callId, {int? duration}) async {
    try {
      // Lấy thông tin call trước khi end
      final call = await getCallById(callId);

      await _callsRef.doc(callId).update({
        'callStatus': CallStatus.ended.name,
        'endedAt': FieldValue.serverTimestamp(),
        if (duration != null) 'duration': duration,
      });
      debugPrint('✅ Ended call: $callId');

      // Chỉ gửi message khi:
      // 1. Call được answer và có duration (completed)
      // 2. Call bị hủy trước khi answer (cancelled)
      if (call != null) {
        String? statusText;

        if (call.callStatus == CallStatus.answered &&
            duration != null &&
            duration > 0) {
          // Cuộc gọi hoàn tất với thời lượng
          statusText = 'completed';
        } else if (call.callStatus == CallStatus.ringing) {
          // Người gọi hủy trước khi người nhận nghe máy
          statusText = 'cancelled';
        }
        // Nếu call.callStatus là answered nhưng duration = 0, không gửi message (call tắt ngay)

        if (statusText != null) {
          await _sendCallSystemMessage(
            chatId: call.chatId,
            callerId: call.callerId,
            callType: call.callType,
            status: statusText,
            duration: duration,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error ending call: $e');
      rethrow;
    }
  }

  /// Đánh dấu nhỡ cuộc gọi
  Future<void> markCallAsMissed(String callId) async {
    try {
      await _callsRef.doc(callId).update({
        'callStatus': CallStatus.missed.name,
        'endedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Marked call as missed: $callId');
    } catch (e) {
      debugPrint('❌ Error marking call as missed: $e');
    }
  }

  /// Lấy cuộc gọi theo ID
  Future<Call?> getCallById(String callId) async {
    try {
      final doc = await _callsRef.doc(callId).get();
      if (!doc.exists) return null;
      return Call.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ Error getting call: $e');
      return null;
    }
  }

  /// Stream cuộc gọi theo ID
  Stream<Call?> getCallStream(String callId) {
    return _callsRef.doc(callId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Call.fromFirestore(doc);
    });
  }

  /// Stream cuộc gọi đến cho user
  Stream<List<Call>> getIncomingCallsStream(String userId) {
    return _callsRef
        .where('receiverIds', arrayContains: userId)
        .where('callStatus', isEqualTo: CallStatus.ringing.name)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Call.fromFirestore(doc)).toList();
        });
  }

  /// Lấy lịch sử cuộc gọi của chat
  Stream<List<Call>> getChatCallHistory(String chatId) {
    return _callsRef
        .where('chatId', isEqualTo: chatId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Call.fromFirestore(doc)).toList();
        });
  }

  /// Kiểm tra xem có thể gọi không (số người < 4)
  bool canMakeCall(Chat chat) {
    if (chat.chatType == ChatType.community) return false;
    if (chat.chatType == ChatType.private) return true;
    if (chat.chatType == ChatType.group) {
      return chat.members.length <= 4;
    }
    return false;
  }

  /// Gửi notification cho receivers
  Future<void> _sendCallNotifications(
    String callId,
    String callerId,
    List<String> receiverIds,
    CallType callType,
  ) async {
    try {
      // Lấy thông tin caller
      final callerDoc =
          await _firestore.collection('users').doc(callerId).get();
      if (!callerDoc.exists) return;

      final caller = UserModel.fromFirestore(callerDoc);
      final callTypeText =
          callType == CallType.voice ? 'gọi thoại' : 'gọi video';

      // Gửi notification cho từng receiver
      for (final receiverId in receiverIds) {
        await _notificationService.sendNotificationToUser(
          receiverId,
          '${caller.name} đang $callTypeText',
          'Vuốt để trả lời',
          data: {
            'type': 'incoming_call',
            'callId': callId,
            'callType': callType.name,
            'callerId': callerId,
            'callerName': caller.name,
            'callerAvatar': caller.avatarUrl ?? '',
          },
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending call notifications: $e');
    }
  }

  /// Check if user is in another call
  Future<bool> isUserBusy(String userId) async {
    try {
      // Kiểm tra cuộc gọi đang trả lời
      final answeredCalls =
          await _callsRef
              .where('receiverIds', arrayContains: userId)
              .where('callStatus', isEqualTo: CallStatus.answered.name)
              .get();

      if (answeredCalls.docs.isNotEmpty) return true;

      // Kiểm tra cuộc gọi đang gọi đi
      final outgoingCalls =
          await _callsRef
              .where('callerId', isEqualTo: userId)
              .where('callStatus', isEqualTo: CallStatus.ringing.name)
              .get();

      return outgoingCalls.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking user busy: $e');
      return false;
    }
  }

  /// Gửi system message vào chat khi có sự kiện call
  Future<void> _sendCallSystemMessage({
    required String chatId,
    required String callerId,
    required CallType callType,
    required String status,
    int? duration,
  }) async {
    try {
      final callTypeText = callType == CallType.voice ? 'thoại' : 'video';
      String messageText;

      switch (status) {
        case 'outgoing':
          messageText = '📞 Cuộc gọi $callTypeText đi';
          break;
        case 'cancelled':
          messageText = '📞 Cuộc gọi $callTypeText bị hủy';
          break;
        case 'rejected':
          messageText = '📞 Cuộc gọi $callTypeText bị từ chối';
          break;
        case 'completed':
          if (duration != null && duration > 0) {
            final minutes = duration ~/ 60;
            final seconds = duration % 60;
            final durationText =
                minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';
            messageText = '📞 Cuộc gọi $callTypeText • $durationText';
          } else {
            messageText = '📞 Cuộc gọi $callTypeText';
          }
          break;
        default:
          messageText = '📞 Cuộc gọi $callTypeText';
      }

      // Gửi message hệ thống
      await _chatService.sendMessage(
        chatId: chatId,
        senderId: callerId,
        messageText: messageText,
      );

      debugPrint('✅ Sent call system message: $messageText');
    } catch (e) {
      debugPrint('❌ Error sending call system message: $e');
      // Don't rethrow - system message is not critical
    }
  }
}
