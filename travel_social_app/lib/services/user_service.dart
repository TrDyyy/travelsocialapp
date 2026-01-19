import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../models/user_badge.dart';

/// Service quản lý thông tin người dùng
class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference get _usersRef => _firestore.collection('users');

  /// Tạo hoặc cập nhật thông tin user khi đăng nhập
  Future<void> createOrUpdateUser(User firebaseUser) async {
    try {
      debugPrint('🔵 Creating/updating user: ${firebaseUser.uid}');
      final docRef = _usersRef.doc(firebaseUser.uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        // Tạo user mới với đầy đủ thông tin từ provider
        final firstBadge = UserBadge.getBadgeByPoints(
          0,
        ); // Người mới với 0 điểm
        final newUser = UserModel(
          userId: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'Người dùng',
          email: firebaseUser.email ?? '',
          avatarUrl: firebaseUser.photoURL,
          bio: 'Yêu thích du lịch',
          level: 1,
          currentBadge: firstBadge,
        );
        await docRef.set(newUser.toFirestore());
        debugPrint('✅ Created new user document');
        debugPrint('   - Name: ${newUser.name}');
        debugPrint('   - Email: ${newUser.email}');
        debugPrint('   - Avatar: ${newUser.avatarUrl}');
        debugPrint('   - Badge: ${firstBadge.name} (${firstBadge.icon})');
      } else {
        // Cập nhật thông tin cơ bản từ provider (Google, Facebook, etc.)
        // Chỉ cập nhật nếu có giá trị mới từ provider
        final Map<String, dynamic> updates = {};

        if (firebaseUser.displayName != null) {
          updates['name'] = firebaseUser.displayName;
        }

        if (firebaseUser.photoURL != null) {
          updates['avatarUrl'] = firebaseUser.photoURL;
        }

        if (firebaseUser.email != null) {
          updates['email'] = firebaseUser.email;
        }

        if (updates.isNotEmpty) {
          await docRef.update(updates);
          debugPrint('✅ Updated user document');
          debugPrint('   - Updated fields: ${updates.keys.join(", ")}');
        } else {
          debugPrint('ℹ️ No updates needed for existing user');
        }
      }
    } catch (e) {
      debugPrint('❌ Error creating/updating user: $e');
      rethrow;
    }
  }

  /// Tạo hoặc cập nhật thông tin user khi đăng nhập bằng Google
  /// Sử dụng GoogleSignInAccount để đảm bảo lấy được email chính xác
  Future<void> createOrUpdateUserWithGoogle(
    User firebaseUser,
    GoogleSignInAccount googleUser,
  ) async {
    try {
      final docRef = _usersRef.doc(firebaseUser.uid);
      final doc = await docRef.get();

      // Ưu tiên lấy email từ GoogleSignInAccount vì luôn có giá trị
      final String email = googleUser.email; // Google account luôn có email
      final String name =
          firebaseUser.displayName ?? googleUser.displayName ?? 'Người dùng';
      final String? avatarUrl = firebaseUser.photoURL ?? googleUser.photoUrl;

      if (!doc.exists) {
        // Tạo user mới với đầy đủ thông tin từ Google
        final firstBadge = UserBadge.getBadgeByPoints(
          0,
        ); // Người mới với 0 điểm
        final newUser = UserModel(
          userId: firebaseUser.uid,
          name: name,
          email: email,
          avatarUrl: avatarUrl,
          bio: 'Yêu thích du lịch',
          level: 1,
          currentBadge: firstBadge,
        );
        await docRef.set(newUser.toFirestore());
        debugPrint('✅ Created new user from Google');
        debugPrint('   - Name: $name');
        debugPrint('   - Email: $email');
        debugPrint('   - Avatar: $avatarUrl');
        debugPrint('   - Badge: ${firstBadge.name} (${firstBadge.icon})');
      } else {
        // Cập nhật thông tin từ Google
        final Map<String, dynamic> updates = {};

        if (name.isNotEmpty) {
          updates['name'] = name;
        }

        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          updates['avatarUrl'] = avatarUrl;
        }

        if (email.isNotEmpty) {
          updates['email'] = email;
        }

        if (updates.isNotEmpty) {
          await docRef.update(updates);
          debugPrint('✅ Updated user from Google');
          debugPrint('   - Updated fields: ${updates.keys.join(", ")}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error creating/updating user from Google: $e');
      rethrow;
    }
  }

  /// Tạo hoặc cập nhật thông tin user khi đăng nhập bằng Facebook
  /// Sử dụng Facebook userData từ Graph API
  Future<void> createOrUpdateUserWithFacebook(
    User firebaseUser,
    Map<String, dynamic> facebookData,
  ) async {
    try {
      debugPrint(
        '🔵 Creating/updating user from Facebook: ${firebaseUser.uid}',
      );
      final docRef = _usersRef.doc(firebaseUser.uid);
      final doc = await docRef.get();

      // Lấy thông tin từ Facebook Graph API
      final String name =
          facebookData['name'] ?? firebaseUser.displayName ?? 'Người dùng';
      final String email = facebookData['email'] ?? firebaseUser.email ?? '';
      final String? avatarUrl =
          facebookData['picture']?['data']?['url'] ?? firebaseUser.photoURL;

      if (!doc.exists) {
        // Tạo user mới với đầy đủ thông tin từ Facebook
        final firstBadge = UserBadge.getBadgeByPoints(
          0,
        ); // Người mới với 0 điểm
        final newUser = UserModel(
          userId: firebaseUser.uid,
          name: name,
          email: email,
          avatarUrl: avatarUrl,
          bio: 'Yêu thích du lịch',
          level: 1,
          currentBadge: firstBadge,
        );
        await docRef.set(newUser.toFirestore());
        debugPrint('✅ Created new user from Facebook');
        debugPrint('   - Name: $name');
        debugPrint('   - Email: $email');
        debugPrint('   - Avatar: $avatarUrl');
        debugPrint('   - Badge: ${firstBadge.name} (${firstBadge.icon})');
      } else {
        // Cập nhật thông tin từ Facebook
        final Map<String, dynamic> updates = {};

        if (name.isNotEmpty) {
          updates['name'] = name;
        }

        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          updates['avatarUrl'] = avatarUrl;
        }

        if (email.isNotEmpty) {
          updates['email'] = email;
        }

        if (updates.isNotEmpty) {
          await docRef.update(updates);
          debugPrint('✅ Updated user from Facebook');
          debugPrint('   - Updated fields: ${updates.keys.join(", ")}');
        } else {
          debugPrint('ℹ️ No updates needed for existing Facebook user');
        }
      }
    } catch (e) {
      debugPrint('❌ Error creating/updating user from Facebook: $e');
      rethrow;
    }
  }

  /// Lấy thông tin user theo ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      debugPrint('🔍 Getting user by ID: $userId');
      final doc = await _usersRef.doc(userId).get();
      debugPrint('📄 Document exists: ${doc.exists}');

      if (doc.exists) {
        debugPrint('📦 Document data: ${doc.data()}');
        final user = UserModel.fromFirestore(doc);
        debugPrint('✅ Parsed UserModel: ${user.name}');
        return user;
      }

      debugPrint('❌ Document does not exist');
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ Error getting user: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Cập nhật thông tin user
  Future<bool> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      await _usersRef.doc(userId).update(data);
      debugPrint('✅ Updated user successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating user: $e');
      return false;
    }
  }

  /// Upload ảnh đại diện
  Future<String?> uploadAvatar(String userId, File imageFile) async {
    try {
      final ref = _storage.ref().child('avatars/$userId.jpg');
      final uploadTask = await ref.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Cập nhật vào Firestore
      await updateUser(userId, {'avatarUrl': downloadUrl});

      debugPrint('✅ Avatar uploaded: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading avatar: $e');
      return null;
    }
  }

  /// Cập nhật điểm và rank
  /// DEPRECATED: Sử dụng PointsTrackingService.awardPoints() thay thế
  /// Phương thức này chỉ update currentBadge dựa trên điểm mới
  Future<void> updatePointsAndRank(String userId, int points) async {
    try {
      // Get appropriate badge based on points
      final newBadge = UserBadge.getBadgeByPoints(points);

      await _usersRef.doc(userId).update({
        'currentBadge': newBadge.toFirestore(),
        'level': newBadge.level,
        'totalPoints': points, // For backward compatibility
        'points': points, // Deprecated field, kept for compatibility
      });

      debugPrint(
        '✅ Updated user $userId: ${newBadge.name} with $points points',
      );
    } catch (e) {
      debugPrint('Error updating points and rank: $e');
    }
  }

  /// Lắng nghe thay đổi thông tin user
  Stream<UserModel?> watchUser(String userId) {
    return _usersRef.doc(userId).snapshots().map((doc) {
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Fix data cũ: Chuyển points từ String sang int
  Future<void> fixUserPointsDataType(String userId) async {
    try {
      final doc = await _usersRef.doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['points'] is String) {
          final pointsValue = int.tryParse(data['points'] as String) ?? 0;
          await _usersRef.doc(userId).update({'points': pointsValue});
          debugPrint('✅ Fixed points data type for user $userId: $pointsValue');
        }
      }
    } catch (e) {
      debugPrint('❌ Error fixing points data type: $e');
    }
  }
}
