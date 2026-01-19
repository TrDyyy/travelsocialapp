import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'user_service.dart';

/// Service xử lý authentication với Firebase
class AuthService {
  FirebaseAuth? _authInstance;
  final UserService _userService = UserService();

  /// Lazy initialization của FirebaseAuth
  FirebaseAuth get _auth {
    _authInstance ??= FirebaseAuth.instance;
    return _authInstance!;
  }

  /// Stream để lắng nghe thay đổi auth state
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// User hiện tại
  User? get currentUser => _auth.currentUser;

  /// Đăng nhập bằng email và password
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Tạo/cập nhật thông tin user trong Firestore
      if (result.user != null) {
        await _userService.createOrUpdateUser(result.user!);
      }

      return result.user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  /// Đăng ký bằng email và password
  Future<User?> signUpWithEmailPassword(String email, String password) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Tạo thông tin user mới trong Firestore
      if (result.user != null) {
        await _userService.createOrUpdateUser(result.user!);
      }

      return result.user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  /// Đăng nhập bằng Google
  Future<User?> signInWithGoogle() async {
    try {
      // Trigger Google Sign In flow (hiển thị native picker trong app)
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      // Nếu user cancel
      if (googleUser == null) {
        return null;
      }

      // Lấy auth credentials
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Tạo credential cho Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Đăng nhập vào Firebase với Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      // Tạo/cập nhật thông tin user trong Firestore
      // Truyền thêm GoogleSignInAccount để đảm bảo có email
      if (userCredential.user != null) {
        await _userService.createOrUpdateUserWithGoogle(
          userCredential.user!,
          googleUser,
        );
      }

      return userCredential.user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Đăng nhập Google thất bại: $e');
    }
  }

  /// Đăng nhập bằng Facebook
  Future<User?> signInWithFacebook() async {
    try {
      // Trigger Facebook Sign In flow
      final LoginResult loginResult = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      // Nếu user cancel hoặc có lỗi
      if (loginResult.status != LoginStatus.success) {
        if (loginResult.status == LoginStatus.cancelled) {
          return null;
        }
        throw Exception('Đăng nhập Facebook thất bại: ${loginResult.message}');
      }

      // Lấy access token
      final AccessToken? accessToken = loginResult.accessToken;
      if (accessToken == null) {
        throw Exception('Không thể lấy access token từ Facebook');
      }

      // Lấy thông tin user từ Facebook Graph API
      final userData = await FacebookAuth.instance.getUserData(
        fields: "name,email,picture.width(200)",
      );
      debugPrint('📘 Facebook user data: $userData');

      // Tạo credential cho Firebase
      final OAuthCredential credential = FacebookAuthProvider.credential(
        accessToken.token,
      );

      // Đăng nhập vào Firebase với Facebook credential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // Tạo/cập nhật thông tin user trong Firestore
      // Đảm bảo user document được tạo hoàn toàn trước khi return
      if (userCredential.user != null) {
        // Cập nhật Firebase Auth user profile với thông tin từ Facebook
        if (userData['email'] != null && userCredential.user!.email == null) {
          // Không thể update email trực tiếp, chỉ lưu vào Firestore
          debugPrint('⚠️ Email from Facebook: ${userData['email']}');
        }

        await _userService.createOrUpdateUserWithFacebook(
          userCredential.user!,
          userData,
        );
        debugPrint('✅ Facebook user document created/updated successfully');
      }

      return userCredential.user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Đăng nhập Facebook thất bại: $e');
    }
  }

  /// Đăng xuất
  Future<void> signOut() async {
    try {
      // Đăng xuất khỏi Google (nếu đã đăng nhập bằng Google)
      await GoogleSignIn().signOut();
      // Đăng xuất khỏi Facebook (nếu đã đăng nhập bằng Facebook)
      await FacebookAuth.instance.logOut();
      // Đăng xuất khỏi Firebase
      await _auth.signOut();
    } catch (e) {
      throw Exception('Đăng xuất thất bại: $e');
    }
  }

  /// Gửi email reset password
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      debugPrint('Error sending password reset email: $e');
      rethrow;
    }
  }

  /// Cập nhật display name
  Future<void> updateDisplayName(String displayName) async {
    try {
      await _auth.currentUser?.updateDisplayName(displayName);
      await _auth.currentUser?.reload();
    } catch (e) {
      throw Exception('Cập nhật tên thất bại: $e');
    }
  }

  /// Cập nhật photo URL
  Future<void> updatePhotoURL(String photoURL) async {
    try {
      await _auth.currentUser?.updatePhotoURL(photoURL);
      await _auth.currentUser?.reload();
    } catch (e) {
      throw Exception('Cập nhật ảnh thất bại: $e');
    }
  }

  /// Kiểm tra email đã được verify chưa
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Gửi email verification
  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } catch (e) {
      throw Exception('Gửi email xác thực thất bại: $e');
    }
  }
}
