import 'package:flutter/material.dart';
import 'dart:async';
import '../models/call.dart';
import '../services/call_service.dart';

/// Provider quản lý state của cuộc gọi
class CallProvider with ChangeNotifier {
  final CallService _callService = CallService();

  Call? _currentCall;
  StreamSubscription<Call?>? _callSubscription;
  StreamSubscription<List<Call>>? _incomingCallsSubscription;

  Call? get currentCall => _currentCall;
  bool get hasActiveCall => _currentCall != null;

  /// Khởi tạo cuộc gọi
  Future<Call?> initiateCall({
    required String chatId,
    required String callerId,
    required List<String> receiverIds,
    required CallType callType,
  }) async {
    try {
      // Kiểm tra xem user có đang bận không
      final isBusy = await _callService.isUserBusy(callerId);
      if (isBusy) {
        throw Exception('Bạn đang trong cuộc gọi khác');
      }

      final call = await _callService.initiateCall(
        chatId: chatId,
        callerId: callerId,
        receiverIds: receiverIds,
        callType: callType,
      );

      _currentCall = call;
      _listenToCallUpdates(call.id);
      notifyListeners();

      return call;
    } catch (e) {
      debugPrint('❌ Error in CallProvider.initiateCall: $e');
      rethrow;
    }
  }

  /// Trả lời cuộc gọi
  Future<void> answerCall(String callId, String userId) async {
    try {
      await _callService.answerCall(callId, userId);

      final call = await _callService.getCallById(callId);
      if (call != null) {
        _currentCall = call;
        _listenToCallUpdates(callId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error in CallProvider.answerCall: $e');
      rethrow;
    }
  }

  /// Từ chối cuộc gọi
  Future<void> rejectCall(String callId, String userId) async {
    try {
      await _callService.rejectCall(callId, userId);
      _clearCurrentCall();
    } catch (e) {
      debugPrint('❌ Error in CallProvider.rejectCall: $e');
      rethrow;
    }
  }

  /// Kết thúc cuộc gọi
  Future<void> endCall(String callId, {int? duration}) async {
    try {
      await _callService.endCall(callId, duration: duration);
      _clearCurrentCall();
    } catch (e) {
      debugPrint('❌ Error in CallProvider.endCall: $e');
      rethrow;
    }
  }

  /// Lắng nghe cập nhật cuộc gọi
  void _listenToCallUpdates(String callId) {
    _callSubscription?.cancel();
    _callSubscription = _callService.getCallStream(callId).listen((call) {
      debugPrint(
        '🔔 CallProvider: Received call update - id: ${call?.id}, status: ${call?.callStatus}',
      );

      if (call == null) {
        debugPrint('❌ CallProvider: Call is null, clearing...');
        _clearCurrentCall();
        return;
      }

      _currentCall = call;
      debugPrint('✅ CallProvider: Updated currentCall, notifying listeners...');

      // Tự động clear khi cuộc gọi kết thúc
      if (call.callStatus == CallStatus.ended ||
          call.callStatus == CallStatus.rejected ||
          call.callStatus == CallStatus.missed) {
        debugPrint(
          '⏰ CallProvider: Call ended/rejected/missed, will clear in 2 seconds',
        );
        Future.delayed(const Duration(seconds: 2), () {
          _clearCurrentCall();
        });
      }

      notifyListeners();
    });
  }

  /// Clear cuộc gọi hiện tại
  void _clearCurrentCall() {
    _currentCall = null;
    _callSubscription?.cancel();
    _callSubscription = null;
    notifyListeners();
  }

  /// Lắng nghe cuộc gọi đến
  void listenToIncomingCalls(String userId) {
    _incomingCallsSubscription?.cancel();
    _incomingCallsSubscription = _callService
        .getIncomingCallsStream(userId)
        .listen((calls) {
          if (calls.isNotEmpty && _currentCall == null) {
            // Có cuộc gọi đến và không đang trong cuộc gọi khác
            final incomingCall = calls.first;
            _currentCall = incomingCall;
            _listenToCallUpdates(incomingCall.id);
            notifyListeners();
          }
        });
  }

  /// Dừng lắng nghe cuộc gọi đến
  void stopListeningToIncomingCalls() {
    _incomingCallsSubscription?.cancel();
    _incomingCallsSubscription = null;
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    _incomingCallsSubscription?.cancel();
    super.dispose();
  }
}
