import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service để kiểm tra và theo dõi trạng thái kết nối internet
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Stream<bool> get connectionStream => _connectionController.stream;
  bool _isConnected = true;

  ConnectivityService() {
    _initConnectivity();
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  /// Kiểm tra kết nối ban đầu
  Future<void> _initConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
    }
  }

  /// Cập nhật trạng thái kết nối
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    if (results.isEmpty) {
      _isConnected = false;
      _connectionController.add(false);
      return;
    }

    // Kiểm tra nếu có ít nhất một kết nối không phải none
    final hasConnection = results.any(
      (result) => result != ConnectivityResult.none,
    );

    if (_isConnected != hasConnection) {
      _isConnected = hasConnection;
      _connectionController.add(hasConnection);
    }
  }

  /// Kiểm tra trạng thái kết nối hiện tại
  Future<bool> checkConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  /// Lấy trạng thái kết nối hiện tại (không async)
  bool get isConnected => _isConnected;

  /// Dispose stream controller
  void dispose() {
    _connectionController.close();
  }
}
