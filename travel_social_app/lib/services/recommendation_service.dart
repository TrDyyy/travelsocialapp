import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/place.dart';
import 'location_service.dart';
import 'place_service.dart';
import 'activity_tracking_service.dart';
import 'user_preferences_service.dart';

/// Service để gợi ý địa điểm thông minh dựa trên:
/// 1. Vị trí hiện tại
/// 2. Hành vi người dùng (lịch sử activities từ ActivityTrackingService)
/// 3. Sở thích (tourism types yêu thích từ UserPreferencesService)
class RecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocationService _locationService = LocationService();
  final PlaceService _placeService = PlaceService();
  final ActivityTrackingService _activityService = ActivityTrackingService();
  final UserPreferencesService _preferencesService = UserPreferencesService();

  /// Lấy gợi ý địa điểm thông minh
  Future<List<Place>> getSmartRecommendations({int limit = 10}) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      print('🤖 Generating smart recommendations...');

      // 1. Lấy vị trí hiện tại
      Position? currentPosition;
      try {
        currentPosition = await _locationService.getCurrentLocation();
        if (currentPosition != null) {
          print(
            '📍 Current location: ${currentPosition.latitude}, ${currentPosition.longitude}',
          );
        }
      } catch (e) {
        print('⚠️ Could not get current location: $e');
      }

      // 2. Phân tích hành vi người dùng
      final userBehavior = await _analyzeUserBehavior(userId);
      print('📊 User behavior analyzed:');
      print('   - Favorite types: ${userBehavior['favoriteTypes']}');
      print('   - Visit count: ${userBehavior['visitCount']}');

      // 3. Lấy danh sách địa điểm
      final allPlaces = await _placeService.getAllPlaces();

      // 4. Tính điểm cho mỗi địa điểm
      final scoredPlaces = <Map<String, dynamic>>[];

      for (final place in allPlaces) {
        double score = 0.0;

        // A. Điểm dựa trên khoảng cách (max 25 điểm)
        if (currentPosition != null) {
          final distance =
              Geolocator.distanceBetween(
                currentPosition.latitude,
                currentPosition.longitude,
                place.latitude,
                place.longitude,
              ) /
              1000; // Convert to km

          // Càng gần càng cao điểm
          if (distance < 5) {
            score += 25;
          } else if (distance < 10) {
            score += 20;
          } else if (distance < 20) {
            score += 15;
          } else if (distance < 50) {
            score += 10;
          } else {
            score += 5;
          }
        } else {
          score += 12.5; // Không có vị trí - cho điểm trung bình
        }

        // B. Điểm dựa trên sở thích (max 35 điểm)
        final favoriteTypes = userBehavior['favoriteTypes'] as List<String>;
        if (favoriteTypes.isNotEmpty) {
          if (favoriteTypes.contains(place.typeId)) {
            // Tính vị trí trong danh sách favorite
            final index = favoriteTypes.indexOf(place.typeId);
            if (index < 3) {
              // Top 3 favorites
              score += 35 - (index * 3); // 35, 32, 29
            } else if (index < 5) {
              // Top 5 favorites
              score += 25;
            } else {
              // Còn lại
              score += 20;
            }
          } else {
            // Không trong favorites
            score += 8;
          }
        } else {
          // Chưa có preference
          score += 15;
        }

        // C. Điểm dựa trên rating (max 25 điểm)
        if (place.rating != null) {
          score += (place.rating! / 5.0) * 25;
        } else {
          score += 12.5; // Chưa có rating
        }

        // D. Điểm dựa trên số lượng review (max 15 điểm)
        if (place.reviewCount != null) {
          if (place.reviewCount! >= 50) {
            score += 15;
          } else if (place.reviewCount! >= 20) {
            score += 12;
          } else if (place.reviewCount! >= 10) {
            score += 9;
          } else if (place.reviewCount! >= 5) {
            score += 6;
          } else {
            score += 3;
          }
        }

        scoredPlaces.add({'place': place, 'score': score});
      }

      // 5. Sắp xếp theo điểm giảm dần
      scoredPlaces.sort(
        (a, b) => (b['score'] as double).compareTo(a['score'] as double),
      );

      // 6. Lấy top N địa điểm
      final recommendations =
          scoredPlaces
              .take(limit)
              .map((item) => item['place'] as Place)
              .toList();

      print('✅ Generated ${recommendations.length} recommendations');
      return recommendations;
    } catch (e) {
      print('❌ Error getting smart recommendations: $e');
      rethrow;
    }
  }

  /// Phân tích hành vi người dùng với ưu tiên CAO cho favorite types từ profile
  Future<Map<String, dynamic>> _analyzeUserBehavior(String userId) async {
    try {
      // 1. Lấy favorite types từ PROFILE DUY NHẤT (ưu tiên CAO NHẤT)
      final profile = await _preferencesService.getOrCreateProfile(
        userId: userId,
      );
      final profileFavorites = profile.favoriteTypes;

      // 2. Lấy favorite types từ ActivityTrackingService (behavioral)
      final activityPrefs = await _activityService.analyzeUserPreferences();
      final behavioralFavorites =
          (activityPrefs['favoriteTypes'] as List<dynamic>?)?.cast<String>() ??
          <String>[];
      final typeScores =
          (activityPrefs['typeScores'] as Map<dynamic, dynamic>?)?.map(
            (key, value) => MapEntry(key.toString(), value as double),
          ) ??
          <String, double>{};
      final totalActivities = activityPrefs['totalActivities'] as int? ?? 0;

      // 3. Kết hợp với TRỌNG SỐ CỰC CAO cho profile favorites
      final combinedFavorites = <String>{};
      final combinedScores = <String, double>{};

      // ƯUTIÊN TUYỆT ĐỐI: Profile favorites có điểm cực cao (100.0)
      for (final typeId in profileFavorites) {
        combinedFavorites.add(typeId);
        combinedScores[typeId] = 100.0; // Điểm tối đa
      }

      // Behavioral favorites có điểm thấp hơn (dựa trên activity scores)
      for (final typeId in behavioralFavorites) {
        if (!profileFavorites.contains(typeId)) {
          // Chỉ thêm nếu chưa có trong profile
          combinedFavorites.add(typeId);
          final score = typeScores[typeId] ?? 0.0;
          combinedScores[typeId] = score * 0.5; // Giảm trọng số xuống 50%
        }
      }

      // Sắp xếp theo điểm giảm dần
      final sortedTypes =
          combinedScores.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
      final topFavorites = sortedTypes.map((e) => e.key).toList();

      print('📊 User preferences (Profile-based with high priority):');
      print('   - Profile favorites: $profileFavorites');
      print('   - Behavioral favorites: $behavioralFavorites');
      print('   - Combined top types: $topFavorites');
      print('   - Total activities: $totalActivities');

      return {
        'favoriteTypes': topFavorites,
        'visitCount': totalActivities,
        'typeDistribution': Map.fromEntries(sortedTypes),
        'profileFavoritesCount': profileFavorites.length,
        'behavioralCount': behavioralFavorites.length,
      };
    } catch (e) {
      print('❌ Error analyzing user behavior: $e');
      return {
        'favoriteTypes': <String>[],
        'visitCount': 0,
        'typeDistribution': <String, double>{},
        'profileFavoritesCount': 0,
        'behavioralCount': 0,
      };
    }
  }

  /// Lấy gợi ý địa điểm gần vị trí hiện tại
  Future<List<Place>> getNearbyRecommendations({
    int radiusKm = 50,
    int limit = 10,
  }) async {
    try {
      print('📍 Getting nearby recommendations (radius: ${radiusKm}km)...');

      // 1. Lấy vị trí hiện tại
      final currentPosition = await _locationService.getCurrentLocation();
      if (currentPosition == null) {
        throw Exception('Could not get current location');
      }
      print(
        '📍 Current location: ${currentPosition.latitude}, ${currentPosition.longitude}',
      );

      // 2. Lấy tất cả địa điểm
      final allPlaces = await _placeService.getAllPlaces();

      // 3. Lọc và sắp xếp theo khoảng cách
      final nearbyPlaces = <Map<String, dynamic>>[];

      for (final place in allPlaces) {
        final distance =
            Geolocator.distanceBetween(
              currentPosition.latitude,
              currentPosition.longitude,
              place.latitude,
              place.longitude,
            ) /
            1000; // Convert to km

        if (distance <= radiusKm) {
          nearbyPlaces.add({'place': place, 'distance': distance});
        }
      }

      // 4. Sắp xếp theo khoảng cách
      nearbyPlaces.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );

      // 5. Lấy top N
      final recommendations =
          nearbyPlaces
              .take(limit)
              .map((item) => item['place'] as Place)
              .toList();

      print('✅ Found ${recommendations.length} nearby places');
      return recommendations;
    } catch (e) {
      print('❌ Error getting nearby recommendations: $e');
      rethrow;
    }
  }

  /// Lấy gợi ý địa điểm theo sở thích - FOCUS 90% vào favoriteTypes
  Future<List<Place>> getPreferenceBasedRecommendations({
    int limit = 10,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      print(
        '🎯 Getting preference-based recommendations (90% favoriteTypes focus)...',
      );

      // 1. Phân tích sở thích
      final userBehavior = await _analyzeUserBehavior(userId);
      final favoriteTypes = userBehavior['favoriteTypes'] as List<String>;

      if (favoriteTypes.isEmpty) {
        print('⚠️ No preference data, returning popular places');
        return await _getPopularPlaces(limit);
      }

      print('📊 Favorite types: $favoriteTypes');

      // 2. Lấy TẤT CẢ địa điểm
      final allPlaces = await _placeService.getAllPlaces();

      // 3. Tính điểm cho mỗi địa điểm với tỷ trọng 90% favoriteTypes
      final scoredPlaces = <Map<String, dynamic>>[];

      for (final place in allPlaces) {
        double score = 0.0;

        // A. Điểm dựa trên FAVORITE TYPES - 90% (max 90 điểm)
        if (favoriteTypes.contains(place.typeId)) {
          // Trong favorite types
          final index = favoriteTypes.indexOf(place.typeId);
          if (index < 3) {
            // Top 3 favorites - điểm CỰC cao
            score += 90 - (index * 3); // 90, 87, 84
          } else if (index < 5) {
            // Top 5 favorites
            score += 80;
          } else if (index < 10) {
            // Top 10 favorites
            score += 70;
          } else {
            // Còn lại trong favorites
            score += 60;
          }
        } else {
          // KHÔNG trong favorites - điểm CỰC thấp
          score += 3;
        }

        // B. Điểm dựa trên rating - 7% (max 7 điểm)
        if (place.rating != null) {
          score += (place.rating! / 5.0) * 7;
        } else {
          score += 3.5;
        }

        // C. Điểm dựa trên review count - 3% (max 3 điểm)
        if (place.reviewCount != null) {
          if (place.reviewCount! >= 50) {
            score += 3;
          } else if (place.reviewCount! >= 20) {
            score += 2.4;
          } else if (place.reviewCount! >= 10) {
            score += 1.8;
          } else if (place.reviewCount! >= 5) {
            score += 1.2;
          } else {
            score += 0.6;
          }
        }

        scoredPlaces.add({'place': place, 'score': score});
      }

      // 4. Sắp xếp theo điểm giảm dần
      scoredPlaces.sort(
        (a, b) => (b['score'] as double).compareTo(a['score'] as double),
      );

      // 5. Lấy top N
      final result =
          scoredPlaces
              .take(limit)
              .map((item) => item['place'] as Place)
              .toList();

      print('✅ Found ${result.length} preference-based places');
      return result;
    } catch (e) {
      print('❌ Error getting preference-based recommendations: $e');
      rethrow;
    }
  }

  /// Lấy địa điểm phổ biến (fallback khi chưa có dữ liệu người dùng)
  Future<List<Place>> _getPopularPlaces(int limit) async {
    try {
      final placesSnapshot =
          await _firestore
              .collection('places')
              .orderBy('reviewCount', descending: true)
              .limit(limit)
              .get();

      return placesSnapshot.docs
          .map((doc) => Place.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ Error getting popular places: $e');
      return [];
    }
  }
}
