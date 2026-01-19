import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:travel_social_app/ui/auth/splash_screen.dart';
import 'package:travel_social_app/ui/error/no_internet_screen.dart';
import 'package:travel_social_app/services/notification_service.dart';
import 'package:travel_social_app/states/auth_provider.dart' as app_auth;
import 'package:travel_social_app/states/post_provider.dart';
import 'package:travel_social_app/states/call_provider.dart';
import 'package:travel_social_app/states/theme_provider.dart';
import 'package:travel_social_app/states/connectivity_provider.dart';
import 'package:travel_social_app/models/call.dart';
import 'package:travel_social_app/ui/call/incoming_call_screen.dart';
import 'utils/constants.dart';

// Handler for background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Handling background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Khởi tạo Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Khởi tạo Firestore với settings
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Initialize FCM only for non-web platforms
  if (!kIsWeb) {
    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize FCM
    final notificationService = NotificationService();
    await notificationService.initialize();

    // Save FCM token for current user if logged in
    final currentUser = auth.FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await notificationService.saveFCMToken(currentUser.uid, token);
      }
    }
  }

  // Initialize ThemeProvider
  final themeProvider = ThemeProvider();
  await themeProvider.initialize();

  // Initialize ConnectivityProvider
  final connectivityProvider = ConnectivityProvider();

  runApp(
    // Provider ở cấp cao nhất để bao quát toàn bộ app
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(create: (_) => CallProvider()),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: connectivityProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  // GlobalKey to access main app navigator from overlay
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Listen to incoming calls
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = auth.FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final callProvider = Provider.of<CallProvider>(context, listen: false);
        callProvider.listenToIncomingCalls(currentUser.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<CallProvider, ThemeProvider, ConnectivityProvider>(
      builder: (
        context,
        callProvider,
        themeProvider,
        connectivityProvider,
        child,
      ) {
        // Show loading while initializing connectivity
        if (!connectivityProvider.isInitialized) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: AppColors.lightBackground,
              body: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryGreen,
                  strokeWidth: 3,
                ),
              ),
            ),
          );
        }

        // Nếu không có mạng, hiển thị màn hình lỗi
        if (!connectivityProvider.hasConnection) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.materialThemeMode,
            home: NoInternetScreen(
              onRetry: () async {
                await connectivityProvider.checkConnection();
              },
            ),
          );
        }

        // Có mạng, hiển thị app bình thường
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              MaterialApp(
                navigatorKey: MyApp.navigatorKey,
                title: 'Mạng Xã Hội Du Lịch',
                debugShowCheckedModeBanner: false,

                // Light Theme với màu chủ đạo #63AB83
                theme: AppTheme.lightTheme,

                // Dark Theme
                darkTheme: AppTheme.darkTheme,

                // Theme mode từ ThemeProvider
                themeMode: themeProvider.materialThemeMode,

                home: const SplashScreen(),
              ),
              // Show incoming call overlay ONLY for receiver (not caller)
              if (callProvider.currentCall != null &&
                  callProvider.currentCall!.callStatus == CallStatus.ringing &&
                  callProvider.currentCall!.callerId !=
                      auth.FirebaseAuth.instance.currentUser?.uid)
                Positioned.fill(
                  child: IncomingCallScreen(call: callProvider.currentCall!),
                ),
            ],
          ),
        );
      },
    );
  }
}
