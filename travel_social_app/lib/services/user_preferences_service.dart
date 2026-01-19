import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_preferences.dart';
import '../models/preference_profile.dart';

/// Service để quản lý sở thích người dùng với hệ thống Profile
class UserPreferencesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _preferencesRef =>
      _firestore.collection('user_preferences');

  CollectionReference get _profilesRef =>
      _firestore.collection('preference_profiles');

  String? get _currentUserId => _auth.currentUser?.uid;

  // ============ PREFERENCE PROFILES (REFACTORED) ============

  /// Lấy hoặc tạo preference profile của user (duy nhất 1 profile/user)
  Future<PreferenceProfile> getOrCreateProfile({String? userId}) async {
    try {
      final targetUserId = userId ?? _currentUserId;
      if (targetUserId == null) {
        throw Exception('User not authenticated');
      }

      final doc = await _profilesRef.doc(targetUserId).get();

      if (!doc.exists) {
        // Tạo mới profile rỗng
        final newProfile = PreferenceProfile(
          userId: targetUserId,
          favoriteTypes: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _profilesRef.doc(targetUserId).set(newProfile.toFirestore());
        print('✅ Created new profile for user: $targetUserId');
        return newProfile;
      }

      return PreferenceProfile.fromFirestore(doc);
    } catch (e) {
      print('❌ Error getting/creating profile: $e');
      rethrow;
    }
  }

  /// Cập nhật danh sách favoriteTypes
  Future<void> updateFavoriteTypes(List<String> favoriteTypes) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      await _profilesRef.doc(_currentUserId).set({
        'userId': _currentUserId,
        'favoriteTypes': favoriteTypes,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Updated favorite types: ${favoriteTypes.length} types');
    } catch (e) {
      print('❌ Error updating favorite types: $e');
      rethrow;
    }
  }

  /// Watch profile changes
  Stream<PreferenceProfile?> watchProfile({String? userId}) {
    final targetUserId = userId ?? _currentUserId;
    if (targetUserId == null) {
      return Stream.value(null);
    }

    return _profilesRef.doc(targetUserId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return PreferenceProfile.fromFirestore(doc);
    });
  }

  // ============ LEGACY METHODS (Giữ lại cho backward compatibility) ============

  /// Lấy preferences của user (LEGACY - sẽ dần chuyển sang profile-based)
  Future<UserPreferences?> getUserPreferences({String? userId}) async {
    try {
      final targetUserId = userId ?? _currentUserId;
      if (targetUserId == null) return null;

      final doc = await _preferencesRef.doc(targetUserId).get();

      if (!doc.exists) {
        // Tạo preferences mới với giá trị mặc định
        final newPrefs = UserPreferences(
          userId: targetUserId,
          favoriteTypes: [],
          typeInteractionCounts: {},
        );
        await _preferencesRef.doc(targetUserId).set(newPrefs.toFirestore());
        return newPrefs;
      }

      return UserPreferences.fromFirestore(doc);
    } catch (e) {
      print('❌ Error getting user preferences: $e');
      return null;
    }
  }

  /// Thêm một favorite type
  Future<void> addFavoriteType(String typeId) async {
    try {
      if (_currentUserId == null) return;

      await _preferencesRef.doc(_currentUserId).update({
        'favoriteTypes': FieldValue.arrayUnion([typeId]),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print('✅ Added favorite type: $typeId');
    } catch (e) {
      // Nếu document chưa tồn tại, tạo mới
      await updateFavoriteTypes([typeId]);
    }
  }

  /// Xóa một favorite type
  Future<void> removeFavoriteType(String typeId) async {
    try {
      if (_currentUserId == null) return;

      await _preferencesRef.doc(_currentUserId).update({
        'favoriteTypes': FieldValue.arrayRemove([typeId]),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print('✅ Removed favorite type: $typeId');
    } catch (e) {
      print('❌ Error removing favorite type: $e');
    }
  }

  /// Tăng interaction count cho một type
  Future<void> incrementTypeInteraction(String typeId) async {
    try {
      if (_currentUserId == null) return;

      await _preferencesRef.doc(_currentUserId).set({
        'userId': _currentUserId,
        'typeInteractionCounts.$typeId': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ Error incrementing type interaction: $e');
    }
  }

  /// Lấy top favorite types dựa trên interaction counts
  Future<List<String>> getTopInteractedTypes({int limit = 5}) async {
    try {
      final prefs = await getUserPreferences();
      if (prefs == null) return [];

      // Sắp xếp theo count
      final sortedTypes =
          prefs.typeInteractionCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      return sortedTypes.take(limit).map((e) => e.key).toList();
    } catch (e) {
      print('❌ Error getting top interacted types: $e');
      return [];
    }
  }

  /// Kết hợp favorite types được chọn và activity history
  Future<List<String>> getCombinedFavoriteTypes() async {
    try {
      final prefs = await getUserPreferences();
      if (prefs == null) return [];

      // Lấy cả favorite types được chọn thủ công
      final manualFavorites = prefs.favoriteTypes;

      // Lấy top types từ interaction counts
      final interactedTypes = await getTopInteractedTypes(limit: 10);

      // Kết hợp và loại bỏ trùng lặp
      final combined = {...manualFavorites, ...interactedTypes}.toList();

      return combined;
    } catch (e) {
      print('❌ Error getting combined favorite types: $e');
      return [];
    }
  }

  /// Stream để lắng nghe thay đổi preferences
  Stream<UserPreferences?> watchUserPreferences({String? userId}) {
    final targetUserId = userId ?? _currentUserId;
    if (targetUserId == null) {
      return Stream.value(null);
    }

    return _preferencesRef.doc(targetUserId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserPreferences.fromFirestore(doc);
    });
  }
}
