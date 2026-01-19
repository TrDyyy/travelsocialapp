import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/place.dart';
import '../models/tourism_type.dart';

/// Service quản lý địa điểm du lịch
class PlaceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';

  // Collection references
  CollectionReference get _placesRef => _firestore.collection('places');
  CollectionReference get _tourismTypesRef =>
      _firestore.collection('tourismTypes');

  /// Tìm kiếm địa điểm qua Google Places Autocomplete
  /// Ưu tiên kết quả từ database trước, sau đó mới từ Google
  Future<List<Map<String, dynamic>>> searchPlacesAutocomplete(
    String query,
  ) async {
    if (query.isEmpty) return [];

    debugPrint('🔍 Searching for: "$query"');

    // 1. Tìm trong database trước (Firestore)
    final localResults = await _searchPlacesInFirestore(query);
    debugPrint('📦 Found ${localResults.length} results from Firestore');

    // 2. Nếu đã có kết quả từ database và đủ nhiều (>= 3), ưu tiên hiển thị
    if (localResults.length >= 3) {
      debugPrint('✅ Using Firestore results only');
      return localResults;
    }

    // 3. Nếu chưa đủ, tìm thêm từ Google
    debugPrint('🌐 Fetching more from Google Places API...');

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$_apiKey&language=vi&components=country:vn',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final googlePredictions = List<Map<String, dynamic>>.from(
            data['predictions'],
          );
          debugPrint(
            '🌐 Found ${googlePredictions.length} predictions from Google',
          );

          // Gộp kết quả: Database trước, Google sau
          // Loại bỏ trùng lặp dựa trên place_id hoặc tên
          final combinedResults = <Map<String, dynamic>>[...localResults];

          for (final googleResult in googlePredictions) {
            // Kiểm tra trùng lặp
            final isDuplicate = combinedResults.any((local) {
              return local['place_id'] == googleResult['place_id'] ||
                  local['description']?.toLowerCase() ==
                      googleResult['description']?.toLowerCase();
            });

            if (!isDuplicate) {
              combinedResults.add(googleResult);
            }
          }

          debugPrint('✅ Total combined results: ${combinedResults.length}');
          return combinedResults;
        } else {
          debugPrint(
            '❌ Google API Error: ${data['status']} - ${data['error_message'] ?? 'No message'}',
          );
          // Trả về kết quả từ database nếu Google API lỗi
          return localResults;
        }
      }
      return localResults;
    } catch (e) {
      debugPrint('❌ Error searching places: $e');
      // Trả về kết quả từ database nếu có lỗi
      return localResults;
    }
  }

  /// Tìm kiếm địa điểm trong Firestore
  Future<List<Map<String, dynamic>>> _searchPlacesInFirestore(
    String query,
  ) async {
    try {
      final queryLower = query.toLowerCase();

      // Query tất cả places (giới hạn 50 để tránh quá tải)
      final querySnapshot = await _placesRef.limit(50).get();

      final results = <Map<String, dynamic>>[];

      for (var doc in querySnapshot.docs) {
        final place = Place.fromFirestore(doc);
        final nameLower = place.name.toLowerCase();
        final addressLower = place.address?.toLowerCase() ?? '';

        // Tìm kiếm theo tên hoặc địa chỉ
        if (nameLower.contains(queryLower) ||
            addressLower.contains(queryLower)) {
          results.add({
            'place_id': place.googlePlaceId ?? doc.id, // Ưu tiên googlePlaceId
            'description':
                '${place.name}${place.address != null ? ', ${place.address}' : ''}',
            'structured_formatting': {
              'main_text': place.name,
              'secondary_text': place.address ?? '',
            },
            'isFromDatabase': true, // Flag để phân biệt
            'firestoreId': doc.id, // Lưu Firestore ID
            'geometry': {
              'location': {'lat': place.latitude, 'lng': place.longitude},
            },
          });
        }
      }

      return results;
    } catch (e) {
      debugPrint('❌ Error searching in Firestore: $e');
      return [];
    }
  }

  /// Lấy chi tiết địa điểm từ Google Places
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_apiKey&language=vi&fields=name,geometry,formatted_address,photos,types',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return data['result'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting place details: $e');
      return null;
    }
  }

  /// Lấy khoảng cách và thời gian di chuyển thực tế từ Google Distance Matrix API
  Future<Map<String, dynamic>?> getRealDistance(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/distancematrix/json?'
      'origins=$originLat,$originLng&'
      'destinations=$destLat,$destLng&'
      'key=$_apiKey&'
      'language=vi&'
      'mode=driving&'
      'avoid=highways', // Tránh đường cao tốc
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final rows = data['rows'] as List;
          if (rows.isNotEmpty) {
            final elements = rows[0]['elements'] as List;
            if (elements.isNotEmpty) {
              final element = elements[0];
              if (element['status'] == 'OK') {
                return {
                  'distance': element['distance']['value'], // meters
                  'duration': element['duration']['value'], // seconds
                  'distanceText': element['distance']['text'],
                  'durationText': element['duration']['text'],
                };
              }
            }
          }
        } else {
          debugPrint('Distance Matrix API Error: ${data['status']}');
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting real distance: $e');
      return null;
    }
  }

  /// Lấy chỉ đường từ Google Directions API
  Future<Map<String, dynamic>?> getDirections(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?'
      'origin=$originLat,$originLng&'
      'destination=$destLat,$destLng&'
      'key=$_apiKey&'
      'language=vi&'
      'mode=driving&'
      'avoid=highways', // Tránh đường cao tốc
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return data;
        } else {
          debugPrint('Directions API Error: ${data['status']}');
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting directions: $e');
      return null;
    }
  }

  /// Tìm địa điểm trong Firestore theo Google Place ID (ưu tiên) hoặc tọa độ
  Future<Place?> findPlaceByCoordinates(
    double latitude,
    double longitude, {
    String? googlePlaceId,
  }) async {
    try {
      // 1. Ưu tiên tìm theo Google Place ID nếu có
      if (googlePlaceId != null && googlePlaceId.isNotEmpty) {
        debugPrint('🔍 Searching by Google Place ID: $googlePlaceId');

        final querySnapshot =
            await _placesRef
                .where('googlePlaceId', isEqualTo: googlePlaceId)
                .limit(1)
                .get();

        if (querySnapshot.docs.isNotEmpty) {
          debugPrint('✅ Found place by Google Place ID');
          return Place.fromFirestore(querySnapshot.docs.first);
        }
        debugPrint('⚠️ No place found with Google Place ID');
      }

      // 2. Nếu không tìm thấy theo place_id, tìm theo tọa độ
      debugPrint('🔍 Searching by coordinates: ($latitude, $longitude)');

      // Tạo bounding box với độ chính xác ~0.0001 độ (~11m)
      // Giảm delta để chính xác hơn
      final double delta = 0.0001;

      // Query tất cả places
      final querySnapshot = await _placesRef.get();

      for (var doc in querySnapshot.docs) {
        final place = Place.fromFirestore(doc);

        // Tính khoảng cách giữa 2 điểm
        final latDiff = (place.latitude - latitude).abs();
        final lonDiff = (place.longitude - longitude).abs();

        // Nếu cả 2 đều < delta thì coi như trùng vị trí
        if (latDiff < delta && lonDiff < delta) {
          debugPrint('✅ Found place by coordinates');
          return place;
        }
      }

      debugPrint('⚠️ No place found at coordinates');
      return null;
    } catch (e) {
      debugPrint('❌ Error finding place: $e');
      return null;
    }
  }

  /// Thêm địa điểm mới vào Firestore
  Future<String?> addPlace(Place place) async {
    try {
      final docRef = await _placesRef.add(place.toFirestore());
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding place: $e');
      return null;
    }
  }

  /// Lấy danh sách địa điểm từ Firestore
  Future<List<Place>> getPlaces({int limit = 20}) async {
    try {
      final querySnapshot = await _placesRef.limit(limit).get();
      return querySnapshot.docs.map((doc) => Place.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting places: $e');
      return [];
    }
  }

  /// Lấy địa điểm theo ID
  Future<Place?> getPlaceById(String placeId) async {
    try {
      final doc = await _placesRef.doc(placeId).get();
      if (doc.exists) {
        return Place.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting place by id: $e');
      return null;
    }
  }

  /// Stream lắng nghe thay đổi địa điểm theo ID (realtime)
  Stream<Place?> getPlaceStream(String placeId) {
    return _placesRef.doc(placeId).snapshots().map((doc) {
      if (doc.exists) {
        return Place.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Lấy loại hình du lịch theo ID
  Future<TourismType?> getTourismTypeById(String typeId) async {
    try {
      final doc = await _tourismTypesRef.doc(typeId).get();
      if (doc.exists) {
        return TourismType.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting tourism type: $e');
      return null;
    }
  }

  /// Lấy tất cả loại hình du lịch
  Future<List<TourismType>> getAllTourismTypes() async {
    try {
      final querySnapshot = await _tourismTypesRef.get();
      return querySnapshot.docs
          .map((doc) => TourismType.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting tourism types: $e');
      return [];
    }
  }

  /// Alias cho getAllTourismTypes để dễ sử dụng
  Future<List<TourismType>> getTourismTypes() => getAllTourismTypes();

  /// Stream để lắng nghe thay đổi địa điểm
  Stream<List<Place>> placesStream({int limit = 20}) {
    return _placesRef
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Place.fromFirestore(doc)).toList(),
        );
  }

  /// Cập nhật đánh giá địa điểm
  Future<void> updatePlaceRating(
    String placeId,
    double rating,
    int reviewCount,
  ) async {
    try {
      await _placesRef.doc(placeId).update({
        'rating': rating,
        'reviewCount': reviewCount,
      });
    } catch (e) {
      debugPrint('Error updating place rating: $e');
    }
  }

  /// Decode polyline từ Google Directions API
  /// Reference: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
  List<Map<String, double>> decodePolyline(String encoded) {
    List<Map<String, double>> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add({'lat': lat / 1E5, 'lng': lng / 1E5});
    }

    return points;
  }

  /// Lấy tất cả địa điểm
  Future<List<Place>> getAllPlaces() async {
    try {
      final snapshot = await _placesRef.get();
      return snapshot.docs.map((doc) => Place.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error getting all places: $e');
      return [];
    }
  }

  /// Lấy địa điểm theo loại hình du lịch
  Future<List<Place>> getPlacesByType(String typeId) async {
    try {
      final snapshot =
          await _placesRef
              .where('typeId', isEqualTo: typeId)
              .orderBy('rating', descending: true)
              .get();
      return snapshot.docs.map((doc) => Place.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error getting places by type: $e');
      return [];
    }
  }
}
