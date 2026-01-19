import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'location_service.dart';
import 'recommendation_service.dart';
import 'place_service.dart';
import 'user_preferences_service.dart';
import 'activity_tracking_service.dart';
import '../models/place.dart';
import '../models/user_activity.dart';

/// Service quản lý context cho AI Assistant
/// Cache dữ liệu cá nhân hóa locally để giảm API calls và tăng tốc phản hồi
class AiContextService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocationService _locationService = LocationService();
  final RecommendationService _recommendationService = RecommendationService();
  final PlaceService _placeService = PlaceService();
  final UserPreferencesService _preferencesService = UserPreferencesService();
  final ActivityTrackingService _activityService = ActivityTrackingService();

  // Cache keys
  static const String _keyUserContext = 'ai_user_context';
  static const String _keyLastUpdate = 'ai_context_last_update';

  // Cache duration
  static const Duration _cacheDuration = Duration(hours: 6);

  /// Lấy full context cho AI (từ cache hoặc fetch mới)
  Future<Map<String, dynamic>> getAiContext({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    // Kiểm tra cache
    if (!forceRefresh && await _isCacheValid(prefs)) {
      print('✅ Using cached AI context');
      return await _loadCachedContext(prefs);
    }

    print('🔄 Refreshing AI context...');

    // Fetch context mới
    final context = await _fetchFreshContext();

    // Lưu vào cache
    await _saveCachedContext(prefs, context);

    return context;
  }

  /// Fetch context mới từ services
  Future<Map<String, dynamic>> _fetchFreshContext() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return {};
    }

    final context = <String, dynamic>{};

    // 1. User preferences context
    try {
      final profile = await _preferencesService.getOrCreateProfile();
      context['userPreferences'] = {
        'favoriteTypes': profile.favoriteTypes,
        'hasSetPreferences': profile.favoriteTypes.isNotEmpty,
      };
      print('✅ Loaded user preferences: ${profile.favoriteTypes.length} types');
    } catch (e) {
      print('⚠️ Error loading preferences: $e');
      context['userPreferences'] = {
        'favoriteTypes': [],
        'hasSetPreferences': false,
      };
    }

    // 2. Location context
    try {
      final locationResult =
          await _locationService.getCurrentLocationWithStatus();
      if (locationResult.isSuccess && locationResult.position != null) {
        final position = locationResult.position!;
        final address = await _locationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );

        context['location'] = {
          'hasLocation': true,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'address': address ?? 'Không xác định',
          'timestamp': DateTime.now().toIso8601String(),
        };
        print('✅ Loaded location: $address');
      } else {
        context['location'] = {
          'hasLocation': false,
          'errorMessage': locationResult.errorMessage,
        };
        print('⚠️ Location not available: ${locationResult.errorMessage}');
      }
    } catch (e) {
      print('⚠️ Error loading location: $e');
      context['location'] = {
        'hasLocation': false,
        'errorMessage': e.toString(),
      };
    }

    // 3. User behavior analysis
    try {
      // Lấy thống kê từ preferences analysis
      final preferences = await _activityService.analyzeUserPreferences();

      // Lấy các activities gần đây để đếm số lượng theo loại
      final recentActivities = await _activityService.getUserActivities(
        limit: 100,
      );

      // Đếm số lượng activities theo loại
      final viewCount =
          recentActivities
              .where((a) => a.activityType == ActivityType.viewPlace)
              .length;
      final reviewCount =
          recentActivities
              .where((a) => a.activityType == ActivityType.reviewPlace)
              .length;
      final checkInCount =
          recentActivities
              .where((a) => a.activityType == ActivityType.postWithPlace)
              .length;

      context['userBehavior'] = {
        'totalViews': viewCount,
        'totalReviews': reviewCount,
        'totalCheckIns': checkInCount,
        'totalActivities': preferences['totalActivities'] ?? 0,
        'uniquePlaces': preferences['uniquePlaces'] ?? 0,
        'favoriteTypes': preferences['favoriteTypes'] ?? [],
      };
      print(
        '✅ Loaded behavior stats: $viewCount views, $reviewCount reviews, ${preferences['uniquePlaces']} unique places',
      );
    } catch (e) {
      print('⚠️ Error loading behavior: $e');
      context['userBehavior'] = {
        'totalViews': 0,
        'totalReviews': 0,
        'totalCheckIns': 0,
        'totalActivities': 0,
        'uniquePlaces': 0,
        'favoriteTypes': [],
      };
    }

    // 4. Popular places trong hệ thống (top 10)
    try {
      final allPlaces = await _placeService.getAllPlaces();
      // Sắp xếp theo rating và lấy top 10
      final sortedPlaces = List<Place>.from(allPlaces)..sort((a, b) {
        final ratingA = a.rating ?? 0.0;
        final ratingB = b.rating ?? 0.0;
        return ratingB.compareTo(ratingA); // Giảm dần
      });
      final places = sortedPlaces.take(10).toList();

      context['popularPlaces'] =
          places
              .map(
                (place) => {
                  'name': place.name,
                  'typeId': place.typeId,
                  'rating': place.rating ?? 0.0,
                  'reviewCount': place.reviewCount ?? 0,
                  'address': place.address ?? '',
                },
              )
              .toList();
      print('✅ Loaded ${places.length} popular places');
    } catch (e) {
      print('⚠️ Error loading popular places: $e');
      context['popularPlaces'] = [];
    }

    // 5. Recommended places (dựa trên smart recommendation)
    try {
      final recommendations = await _recommendationService
          .getSmartRecommendations(limit: 5);
      context['recommendedPlaces'] =
          recommendations
              .map(
                (place) => {
                  'name': place.name,
                  'typeId': place.typeId,
                  'rating': place.rating ?? 0.0,
                  'address': place.address ?? '',
                },
              )
              .toList();
      print('✅ Loaded ${recommendations.length} recommendations');
    } catch (e) {
      print('⚠️ Error loading recommendations: $e');
      context['recommendedPlaces'] = [];
    }

    context['lastUpdated'] = DateTime.now().toIso8601String();

    return context;
  }

  /// Kiểm tra cache còn hợp lệ không
  Future<bool> _isCacheValid(SharedPreferences prefs) async {
    final lastUpdateStr = prefs.getString(_keyLastUpdate);
    if (lastUpdateStr == null) return false;

    try {
      final lastUpdate = DateTime.parse(lastUpdateStr);
      final now = DateTime.now();
      return now.difference(lastUpdate) < _cacheDuration;
    } catch (e) {
      return false;
    }
  }

  /// Load context từ cache
  Future<Map<String, dynamic>> _loadCachedContext(
    SharedPreferences prefs,
  ) async {
    try {
      final contextStr = prefs.getString(_keyUserContext);
      if (contextStr == null) return {};

      return Map<String, dynamic>.from(json.decode(contextStr));
    } catch (e) {
      print('❌ Error loading cached context: $e');
      return {};
    }
  }

  /// Save context vào cache
  Future<void> _saveCachedContext(
    SharedPreferences prefs,
    Map<String, dynamic> context,
  ) async {
    try {
      await prefs.setString(_keyUserContext, json.encode(context));
      await prefs.setString(_keyLastUpdate, DateTime.now().toIso8601String());
      print('💾 Context saved to cache');
    } catch (e) {
      print('❌ Error saving context: $e');
    }
  }

  /// Clear cache
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserContext);
    await prefs.remove(_keyLastUpdate);
    print('🗑️ AI context cache cleared');
  }

  /// Tạo context string cho AI prompt
  String buildContextPrompt(Map<String, dynamic> context) {
    final buffer = StringBuffer();

    buffer.writeln('\n📱 THÔNG TIN NGƯỜI DÙNG:');

    // User preferences
    final prefs = context['userPreferences'] as Map<String, dynamic>?;
    if (prefs != null && prefs['hasSetPreferences'] == true) {
      final favoriteTypes = prefs['favoriteTypes'] as List<dynamic>;
      if (favoriteTypes.isNotEmpty) {
        buffer.writeln('- Sở thích du lịch: ${favoriteTypes.join(", ")}');
      }
    } else {
      buffer.writeln('- Chưa thiết lập sở thích du lịch');
    }

    // Location
    final location = context['location'] as Map<String, dynamic>?;
    if (location != null && location['hasLocation'] == true) {
      buffer.writeln('- Vị trí hiện tại: ${location['address']}');
      buffer.writeln(
        '- Tọa độ: ${location['latitude']}, ${location['longitude']}',
      );
    } else {
      buffer.writeln('- Vị trí: Không xác định');
    }

    // User behavior
    final behavior = context['userBehavior'] as Map<String, dynamic>?;
    if (behavior != null) {
      buffer.writeln('\n📊 HOẠT ĐỘNG GẦN ĐÂY:');
      buffer.writeln('- Đã xem: ${behavior['totalViews']} địa điểm');
      buffer.writeln('- Đã đánh giá: ${behavior['totalReviews']} lần');
      buffer.writeln('- Đã check-in: ${behavior['totalCheckIns']} lần');

      final recentPlaces = behavior['recentPlaceNames'] as List<dynamic>?;
      if (recentPlaces != null && recentPlaces.isNotEmpty) {
        buffer.writeln(
          '- Địa điểm gần đây: ${recentPlaces.take(3).join(", ")}',
        );
      }
    }

    // Recommended places
    final recommended = context['recommendedPlaces'] as List<dynamic>?;
    if (recommended != null && recommended.isNotEmpty) {
      buffer.writeln('\n✨ ĐỊA ĐIỂM GỢI Ý CHO NGƯỜI DÙNG:');
      for (var i = 0; i < recommended.length && i < 5; i++) {
        final place = recommended[i] as Map<String, dynamic>;
        buffer.writeln(
          '${i + 1}. ${place['name']} - ${place['typeId']} (${place['rating']}⭐)',
        );
      }
    }

    // Popular places
    final popular = context['popularPlaces'] as List<dynamic>?;
    if (popular != null && popular.isNotEmpty) {
      buffer.writeln('\n🔥 ĐỊA ĐIỂM PHỔ BIẾN TRONG HỆ THỐNG:');
      for (var i = 0; i < popular.length && i < 5; i++) {
        final place = popular[i] as Map<String, dynamic>;
        buffer.writeln(
          '${i + 1}. ${place['name']} - ${place['typeId']} (${place['rating']}⭐, ${place['reviewCount']} đánh giá)',
        );
      }
    }

    buffer.writeln('\n💡 GỢI Ý SỬ DỤNG CONTEXT:');
    buffer.writeln('- Ưu tiên gợi ý các địa điểm trong danh sách trên');
    buffer.writeln('- Cân nhắc vị trí và sở thích người dùng');
    buffer.writeln('- Đề xuất địa điểm phù hợp với lịch sử hoạt động');

    return buffer.toString();
  }

  /// Làm mới context location (khi user di chuyển)
  Future<void> refreshLocationContext() async {
    final prefs = await SharedPreferences.getInstance();
    final context = await _loadCachedContext(prefs);

    try {
      final locationResult =
          await _locationService.getCurrentLocationWithStatus();
      if (locationResult.isSuccess && locationResult.position != null) {
        final position = locationResult.position!;
        final address = await _locationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );

        context['location'] = {
          'hasLocation': true,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'address': address ?? 'Không xác định',
          'timestamp': DateTime.now().toIso8601String(),
        };

        await _saveCachedContext(prefs, context);
        print('✅ Location context refreshed');
      }
    } catch (e) {
      print('❌ Error refreshing location: $e');
    }
  }

  /// Làm mới context behavior (sau khi user thực hiện action)
  Future<void> refreshBehaviorContext() async {
    final prefs = await SharedPreferences.getInstance();
    final context = await _loadCachedContext(prefs);

    try {
      // Lấy thống kê từ preferences analysis
      final preferences = await _activityService.analyzeUserPreferences();

      // Lấy các activities gần đây để đếm số lượng theo loại
      final recentActivities = await _activityService.getUserActivities(
        limit: 100,
      );

      // Đếm số lượng activities theo loại
      final viewCount =
          recentActivities
              .where((a) => a.activityType == ActivityType.viewPlace)
              .length;
      final reviewCount =
          recentActivities
              .where((a) => a.activityType == ActivityType.reviewPlace)
              .length;
      final checkInCount =
          recentActivities
              .where((a) => a.activityType == ActivityType.postWithPlace)
              .length;

      context['userBehavior'] = {
        'totalViews': viewCount,
        'totalReviews': reviewCount,
        'totalCheckIns': checkInCount,
        'totalActivities': preferences['totalActivities'] ?? 0,
        'uniquePlaces': preferences['uniquePlaces'] ?? 0,
        'favoriteTypes': preferences['favoriteTypes'] ?? [],
      };

      await _saveCachedContext(prefs, context);
      print('✅ Behavior context refreshed');
    } catch (e) {
      print('❌ Error refreshing behavior: $e');
    }
  }
}
