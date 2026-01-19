import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

/// Provider quản lý state authentication
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isInitialized => _isInitialized;

  AuthProvider() {
    _initializeAuth();
  }

  /// Khởi tạo và kiểm tra auth state
  Future<void> _initializeAuth() async {
    try {
      // Lấy current user từ Firebase
      _user = _authService.currentUser;

      // Lắng nghe thay đổi auth state
      _authService.authStateChanges.listen((user) {
        _user = user;
        notifyListeners();
      });

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Lỗi khởi tạo auth: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Đăng nhập bằng email và password
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      _clearError();

      final user = await _authService.signInWithEmailPassword(email, password);
      _user = user;

      // Save FCM token after successful login
      if (user != null) {
        await _saveFCMToken(user.uid);
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(_getErrorMessage(e));
      _setLoading(false);
      return false;
    }
  }

  /// Đăng ký bằng email và password
  Future<bool> signUpWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      _clearError();

      final user = await _authService.signUpWithEmailPassword(email, password);
      _user = user;

      // Save FCM token after successful signup
      if (user != null) {
        await _saveFCMToken(user.uid);
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(_getErrorMessage(e));
      _setLoading(false);
      return false;
    }
  }

  /// Đăng nhập bằng Google
  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);
      _clearError();

      final user = await _authService.signInWithGoogle();
      _user = user;

      // Save FCM token after successful Google sign in
      if (user != null) {
        await _saveFCMToken(user.uid);
      }

      _setLoading(false);
      return user != null;
    } catch (e) {
      _setError(_getErrorMessage(e));
      _setLoading(false);
      return false;
    }
  }

  /// Đăng nhập bằng Facebook
  Future<bool> signInWithFacebook() async {
    try {
      _setLoading(true);
      _clearError();

      final user = await _authService.signInWithFacebook();
      _user = user;

      // Save FCM token after successful Facebook sign in
      if (user != null) {
        await _saveFCMToken(user.uid);
      }

      _setLoading(false);
      return user != null;
    } catch (e) {
      _setError(_getErrorMessage(e));
      _setLoading(false);
      return false;
    }
  }

  /// Đăng xuất
  Future<void> signOut() async {
    try {
      _setLoading(true);
      _clearError();

      await _authService.signOut();
      _user = null;

      _setLoading(false);
    } catch (e) {
      _setError(_getErrorMessage(e));
      _setLoading(false);
    }
  }

  /// Gửi email reset password
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      _setLoading(true);
      _clearError();

      await _authService.sendPasswordResetEmail(email);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(_getErrorMessage(e));
      _setLoading(false);
      return false;
    }
  }

  // Helper methods
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Save FCM token after successful authentication
  Future<void> _saveFCMToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _notificationService.saveFCMToken(userId, token);
        debugPrint('FCM token saved for user: $userId');
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
      // Don't throw error - token saving failure shouldn't block login
    }
  }

  /// Chuyển đổi Firebase error thành message tiếng Việt
  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        // Login errors
        case 'user-not-found':
          return 'Không tìm thấy tài khoản với email này';
        case 'wrong-password':
          return 'Thông tin tài khoản không chính xác';
        case 'invalid-credential':
          return 'Thông tin tài khoản không chính xác';
        case 'invalid-email':
          return 'Email không hợp lệ';

        // Registration errors
        case 'email-already-in-use':
          return 'Email này đã được sử dụng';
        case 'weak-password':
          return 'Mật khẩu quá yếu (tối thiểu 6 ký tự)';
        case 'operation-not-allowed':
          return 'Phương thức đăng nhập này chưa được kích hoạt';

        // Account status errors
        case 'user-disabled':
          return 'Tài khoản đã bị vô hiệu hóa';
        case 'account-exists-with-different-credential':
          return 'Email này đã được sử dụng với phương thức đăng nhập khác';

        // Network and rate limit errors
        case 'too-many-requests':
          return 'Quá nhiều yêu cầu. Vui lòng thử lại sau';
        case 'network-request-failed':
          return 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối Internet';

        // Session errors
        case 'requires-recent-login':
          return 'Vui lòng đăng nhập lại để thực hiện thao tác này';
        case 'user-token-expired':
          return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại';

        // Password reset errors
        case 'expired-action-code':
          return 'Mã xác thực đã hết hạn';
        case 'invalid-action-code':
          return 'Mã xác thực không hợp lệ';

        default:
          // For any unknown errors, provide a generic Vietnamese message
          debugPrint('Firebase Auth Error Code: ${error.code}');
          debugPrint('Firebase Auth Error Message: ${error.message}');
          return 'Đăng nhập thất bại. Vui lòng kiểm tra lại thông tin đăng nhập';
      }
    }

    // Handle non-Firebase errors
    debugPrint('Non-Firebase Error: $error');
    return 'Đã xảy ra lỗi. Vui lòng thử lại sau';
  }

  void clearError() {
    _clearError();
  }
}
