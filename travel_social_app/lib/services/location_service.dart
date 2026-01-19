import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service xử lý location và geocoding
class LocationService {
  /// Kiểm tra trạng thái location service và permission
  Future<LocationStatus> checkLocationStatus() async {
    try {
      // Kiểm tra location service có được bật không (GPS)
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationStatus.serviceDisabled;
      }

      // Kiểm tra permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        return LocationStatus.permissionDenied;
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationStatus.permissionDeniedForever;
      }

      return LocationStatus.granted;
    } catch (e) {
      debugPrint('Error checking location status: $e');
      return LocationStatus.error;
    }
  }

  /// Kiểm tra và request location permission
  Future<bool> requestLocationPermission() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ Location services are disabled (GPS is OFF)');
        return false;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('❌ Location permissions are denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ Location permissions are permanently denied');
        // Có thể mở settings để user enable permission
        await openAppSettings();
        return false;
      }

      debugPrint('✅ Location permission granted');
      return true;
    } catch (e) {
      debugPrint('❌ Error requesting location permission: $e');
      return false;
    }
  }

  /// Lấy vị trí hiện tại với error message rõ ràng
  Future<LocationResult> getCurrentLocationWithStatus() async {
    try {
      // Kiểm tra trạng thái location
      final status = await checkLocationStatus();

      if (status == LocationStatus.serviceDisabled) {
        return LocationResult.error(
          'Vị trí chưa được bật. Vui lòng bật GPS trong cài đặt thiết bị.',
        );
      }

      if (status == LocationStatus.permissionDenied) {
        // Thử request permission
        final granted = await requestLocationPermission();
        if (!granted) {
          return LocationResult.error(
            'Vị trí chưa được cấp quyền. Vui lòng cho phép truy cập vị trí.',
          );
        }
      }

      if (status == LocationStatus.permissionDeniedForever) {
        return LocationResult.error(
          'Vị trí đã bị từ chối vĩnh viễn. Vui lòng bật trong cài đặt ứng dụng.',
        );
      }

      // Lấy vị trí
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      debugPrint(
        '✅ Current position: ${position.latitude}, ${position.longitude}',
      );
      return LocationResult.success(position);
    } catch (e) {
      debugPrint('❌ Error getting current location: $e');
      return LocationResult.error('Không thể lấy vị trí hiện tại. Lỗi: $e');
    }
  }

  /// Lấy vị trí hiện tại (legacy method - giữ lại cho backward compatibility)
  Future<Position?> getCurrentLocation() async {
    final result = await getCurrentLocationWithStatus();
    return result.position;
  }

  /// Chuyển đổi coordinates thành địa chỉ (Reverse Geocoding)
  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Build address string
        String address = '';

        if (place.subAdministrativeArea != null &&
            place.subAdministrativeArea!.isNotEmpty) {
          address = place.subAdministrativeArea!;
        } else if (place.locality != null && place.locality!.isNotEmpty) {
          address = place.locality!;
        } else if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          address = place.administrativeArea!;
        }

        debugPrint('Address: $address');
        debugPrint('Full placemark: ${place.toString()}');

        return address.isNotEmpty ? address : 'Vị trí không xác định';
      }

      return null;
    } catch (e) {
      debugPrint('Error getting address from coordinates: $e');
      return null;
    }
  }

  /// Lấy vị trí hiện tại và chuyển thành địa chỉ
  Future<String?> getCurrentAddress() async {
    try {
      Position? position = await getCurrentLocation();
      if (position == null) {
        return null;
      }

      String? address = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      return address;
    } catch (e) {
      debugPrint('Error getting current address: $e');
      return null;
    }
  }

  /// Tính khoảng cách giữa 2 điểm (km)
  double getDistanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng) /
        1000; // Convert to km
  }

  /// Stream theo dõi vị trí liên tục
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    );
  }
}

/// Enum cho trạng thái location
enum LocationStatus {
  granted,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled, // GPS tắt
  error,
}

/// Class để trả về kết quả location với error message
class LocationResult {
  final Position? position;
  final String? errorMessage;
  final bool isSuccess;

  LocationResult._({this.position, this.errorMessage, required this.isSuccess});

  factory LocationResult.success(Position position) {
    return LocationResult._(position: position, isSuccess: true);
  }

  factory LocationResult.error(String message) {
    return LocationResult._(errorMessage: message, isSuccess: false);
  }
}
