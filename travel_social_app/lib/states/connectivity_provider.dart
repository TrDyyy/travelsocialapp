import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

/// Provider quản lý trạng thái kết nối mạng của app
class ConnectivityProvider extends ChangeNotifier {
  final ConnectivityService _connectivityService = ConnectivityService();

  bool _hasConnection = true;
  bool _isInitialized = false;

  bool get hasConnection => _hasConnection;
  bool get isInitialized => _isInitialized;

  ConnectivityProvider() {
    _initialize();
  }

  /// Initialize connectivity service và bắt đầu listen
  Future<void> _initialize() async {
    // Check initial connection
    _hasConnection = await _connectivityService.checkConnection();
    _isInitialized = true;
    notifyListeners();

    // Listen to connectivity changes
    _connectivityService.connectionStream.listen((hasConnection) {
      if (_hasConnection != hasConnection) {
        _hasConnection = hasConnection;
        notifyListeners();

        debugPrint(
          hasConnection ? '✅ Internet connected' : '❌ Internet disconnected',
        );
      }
    });
  }

  /// Manually check connection (for retry)
  Future<void> checkConnection() async {
    final hasConnection = await _connectivityService.checkConnection();
    if (_hasConnection != hasConnection) {
      _hasConnection = hasConnection;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivityService.dispose();
    super.dispose();
  }
}
