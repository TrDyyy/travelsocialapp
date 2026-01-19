import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration for call feature using Agora RTC
///
/// To get started:
/// 1. Go to https://console.agora.io/
/// 2. Create a new project or use existing one
/// 3. Get your App ID from the project dashboard
/// 4. Add it to .env file as AGORA_APP_ID
///
/// For production:
/// - Enable App Certificate in Agora Console
/// - Implement token generation server
/// - Never hardcode tokens in the app

class CallConfig {
  /// Your Agora App ID loaded from .env file
  /// Get it from: https://console.agora.io/
  static String get agoraAppId => dotenv.env['AGORA_APP_ID'] ?? '';

  /// Channel name prefix for calls
  static const String channelPrefix = 'call_';

  /// Default video encoding configuration
  static const int videoWidth = 640;
  static const int videoHeight = 480;
  static const int videoFrameRate = 15;
  static const int videoBitrate = 800;

  /// Audio configuration
  static const bool enableEchoCancellation = true;
  static const bool enableNoiseSuppression = true;

  /// Validate if Agora is properly configured
  static bool get isConfigured =>
      agoraAppId.isNotEmpty && agoraAppId.length > 10;
}
