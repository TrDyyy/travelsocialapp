import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import '../models/place.dart';

/// Service xử lý check-in tại địa điểm
class CheckInService {
  /// Bán kính cho phép check-in (mét)
  static const double checkInRadius = 500.0; // 500 meters

  /// Kiểm tra quyền location
  Future<bool> checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Kiểm tra location service có bật không
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('❌ Location services are disabled');
      return false;
    }

    // Kiểm tra quyền truy cập location
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('❌ Location permissions are denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('❌ Location permissions are permanently denied');
      return false;
    }

    debugPrint('✅ Location permission granted');
    return true;
  }

  /// Lấy vị trí hiện tại của user
  Future<Position?> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      debugPrint(
        '📍 Current location: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } catch (e) {
      debugPrint('❌ Error getting location: $e');
      return null;
    }
  }

  /// Tính khoảng cách giữa 2 điểm (mét)
  double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final distance = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    debugPrint('📏 Distance: ${distance.toStringAsFixed(2)} meters');
    return distance;
  }

  /// Kiểm tra có thể check-in tại địa điểm không
  Future<CheckInResult> canCheckIn(Place place) async {
    // 1. Kiểm tra permission
    final hasPermission = await checkLocationPermission();
    if (!hasPermission) {
      return CheckInResult(
        success: false,
        message: 'Vui lòng cấp quyền truy cập vị trí',
        errorType: CheckInErrorType.permissionDenied,
      );
    }

    // 2. Lấy vị trí hiện tại
    final currentPosition = await getCurrentLocation();
    if (currentPosition == null) {
      return CheckInResult(
        success: false,
        message: 'Không thể lấy vị trí hiện tại',
        errorType: CheckInErrorType.locationUnavailable,
      );
    }

    // 3. Tính khoảng cách
    final distance = calculateDistance(
      lat1: currentPosition.latitude,
      lon1: currentPosition.longitude,
      lat2: place.latitude,
      lon2: place.longitude,
    );

    // 4. Kiểm tra khoảng cách
    if (distance <= checkInRadius) {
      return CheckInResult(
        success: true,
        message: 'Check-in thành công!',
        distance: distance,
      );
    } else {
      return CheckInResult(
        success: false,
        message:
            'Bạn đang cách địa điểm ${distance.toStringAsFixed(0)}m. Vui lòng đến gần hơn (trong vòng ${checkInRadius.toStringAsFixed(0)}m)',
        distance: distance,
        errorType: CheckInErrorType.tooFar,
      );
    }
  }
}

/// Kết quả check-in
class CheckInResult {
  final bool success;
  final String message;
  final double? distance; // Khoảng cách tính bằng mét
  final CheckInErrorType? errorType;

  CheckInResult({
    required this.success,
    required this.message,
    this.distance,
    this.errorType,
  });
}

/// Loại lỗi check-in
enum CheckInErrorType {
  permissionDenied, // Không có quyền truy cập location
  locationUnavailable, // Không lấy được vị trí
  tooFar, // Quá xa địa điểm
}
