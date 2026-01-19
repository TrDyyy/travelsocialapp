import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ai_context_service.dart';

/// Service để giao tiếp với AI Travel Assistant qua Firebase Functions
class AiAssistantService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AiContextService _contextService = AiContextService();

  String? _currentSessionId;
  Map<String, dynamic>? _cachedContext; // Cache context trong session

  /// Lấy session ID hiện tại
  String? get currentSessionId => _currentSessionId;

  /// Gửi tin nhắn đến AI Assistant
  ///
  /// [message] - Nội dung tin nhắn từ người dùng
  /// [sessionId] - ID của session (optional, tự động tạo mới nếu không có)
  /// [includeContext] - Có gửi context cá nhân hóa không (default: true)
  ///
  /// Returns: Response từ AI với sessionId và message
  Future<Map<String, dynamic>> sendMessage(
    String message, {
    String? sessionId,
    bool includeContext = true,
  }) async {
    try {
      // Kiểm tra authentication
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }

      // Sử dụng sessionId hiện tại hoặc sessionId được truyền vào
      final useSessionId = sessionId ?? _currentSessionId;

      print('📤 Sending message to AI Assistant: "$message"');
      if (useSessionId != null) {
        print('📂 Session ID: $useSessionId');
      }

      // Lấy context nếu cần
      String? contextPrompt;
      if (includeContext) {
        // Sử dụng cached context hoặc fetch mới
        if (_cachedContext == null || useSessionId == null) {
          print('🔄 Fetching fresh context...');
          _cachedContext = await _contextService.getAiContext();
        } else {
          print('✅ Using cached context');
        }

        contextPrompt = _contextService.buildContextPrompt(_cachedContext!);
        print('📋 Context included: ${contextPrompt.length} characters');
      }

      // Gọi Cloud Function
      final callable = _functions.httpsCallable('chatWithAssistant');
      final result = await callable.call<Map<String, dynamic>>({
        'message': message,
        if (useSessionId != null) 'sessionId': useSessionId,
        if (contextPrompt != null) 'userContext': contextPrompt,
      });

      final data = result.data;

      if (data['success'] == true) {
        // Lưu session ID để dùng cho các request sau
        _currentSessionId = data['sessionId'] as String?;

        print('✅ AI Response received');
        print('📂 Session ID: $_currentSessionId');

        return {
          'success': true,
          'sessionId': _currentSessionId,
          'message': data['message'] as String,
          'weatherData': data['weatherData'],
        };
      } else {
        throw Exception('Failed to get response from AI');
      }
    } on FirebaseFunctionsException catch (e) {
      print('❌ Firebase Functions Error: ${e.code} - ${e.message}');
      throw Exception('AI Assistant Error: ${e.message}');
    } catch (e) {
      print('❌ Error sending message: $e');
      throw Exception('Failed to send message: $e');
    }
  }

  /// Reset session hiện tại (xóa lịch sử chat)
  Future<void> resetSession() async {
    try {
      if (_currentSessionId == null) {
        print('⚠️ No active session to reset');
        return;
      }

      print('🗑️ Resetting session: $_currentSessionId');

      final callable = _functions.httpsCallable('resetChatSession');
      final result = await callable.call<Map<String, dynamic>>({
        'sessionId': _currentSessionId,
      });

      if (result.data['success'] == true) {
        print('✅ Session reset successfully');
        _currentSessionId = null;
      } else {
        throw Exception('Failed to reset session');
      }
    } on FirebaseFunctionsException catch (e) {
      print('❌ Firebase Functions Error: ${e.code} - ${e.message}');
      throw Exception('Reset Session Error: ${e.message}');
    } catch (e) {
      print('❌ Error resetting session: $e');
      throw Exception('Failed to reset session: $e');
    }
  }

  /// Tạo session mới (không xóa session cũ trên server)
  void createNewSession() {
    print('🆕 Creating new session');
    _currentSessionId = null;
    _cachedContext = null; // Clear cached context khi tạo session mới
  }

  /// Refresh context (gọi khi user thay đổi vị trí hoặc preferences)
  Future<void> refreshContext() async {
    print('🔄 Refreshing AI context...');
    _cachedContext = await _contextService.getAiContext(forceRefresh: true);
    print('✅ Context refreshed');
  }

  /// Clear context cache
  Future<void> clearContextCache() async {
    await _contextService.clearCache();
    _cachedContext = null;
    print('🗑️ Context cache cleared');
  }

  /// Kiểm tra xem có session đang hoạt động không
  bool hasActiveSession() {
    return _currentSessionId != null;
  }

  /// Lấy danh sách chat sessions của user
  Future<List<Map<String, dynamic>>> getChatSessions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }

      print('📋 Fetching chat sessions...');

      final callable = _functions.httpsCallable('getChatSessions');
      final result = await callable.call<Map<String, dynamic>>({});

      if (result.data['success'] == true) {
        final sessions =
            (result.data['sessions'] as List)
                .map((s) => Map<String, dynamic>.from(s))
                .toList();

        print('✅ Found ${sessions.length} sessions');
        return sessions;
      } else {
        throw Exception('Failed to get sessions');
      }
    } on FirebaseFunctionsException catch (e) {
      print('❌ Firebase Functions Error: ${e.code} - ${e.message}');
      throw Exception('Get Sessions Error: ${e.message}');
    } catch (e) {
      print('❌ Error getting sessions: $e');
      throw Exception('Failed to get sessions: $e');
    }
  }

  /// Lấy chi tiết một session
  Future<Map<String, dynamic>> getSessionDetail(String sessionId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }

      print('📖 Fetching session detail: $sessionId');

      final callable = _functions.httpsCallable('getSessionDetail');
      final result = await callable.call<Map<String, dynamic>>({
        'sessionId': sessionId,
      });

      if (result.data['success'] == true) {
        print('✅ Session detail retrieved');
        // Fix type cast issue by explicitly converting to Map<String, dynamic>
        final sessionData = result.data['session'];
        return Map<String, dynamic>.from(sessionData as Map);
      } else {
        throw Exception('Failed to get session detail');
      }
    } on FirebaseFunctionsException catch (e) {
      print('❌ Firebase Functions Error: ${e.code} - ${e.message}');
      throw Exception('Get Session Detail Error: ${e.message}');
    } catch (e) {
      print('❌ Error getting session detail: $e');
      throw Exception('Failed to get session detail: $e');
    }
  }

  /// Set session ID để tiếp tục chat trong session cũ
  void setSessionId(String sessionId) {
    _currentSessionId = sessionId;
    print('📂 Session ID set to: $sessionId');
  }
}
