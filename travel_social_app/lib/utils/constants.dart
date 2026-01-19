import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ==================== COMMON COLORS (Both Light & Dark Mode) ====================
  /// Màu chủ đạo - Primary Green (#63AB83)
  static const Color primaryGreen = Color(0xFF63AB83);

  /// Màu đỏ quốc kỳ Việt Nam
  static const Color vietnamRed = Color(0xFFDA291C);

  /// Màu trong suốt
  static const Color transparent = Colors.transparent;

  /// Màu lỗi/cảnh báo
  static const Color error = Color(0xFFFF3D00);
  static const Color warning = Color(0xFFFFA726);
  static const Color success = Color(0xFF66BB6A);

  // ==================== LIGHT MODE COLORS ====================
  /// Màu nền chính - Light Mode (xanh lá nhạt)
  static const Color lightBackground = Color.fromARGB(255, 239, 239, 239);

  /// Màu nền phụ/card - Light Mode (trắng)
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Màu text chính - Light Mode (đen/xám đậm)
  static const Color lightTextPrimary = Color(0xFF212121);
  static const Color lightTextSecondary = Color(0xFF757575);

  /// Màu viền/border - Light Mode
  static const Color lightBorder = Color(0xFFE0E0E0);

  /// Màu cho input field - Light Mode
  static const Color lightInputBackground = Color(0xFFF5F5F5);
  static const Color lightInputBorder = Color(0xFFBDBDBD);

  /// Màu cho button - Light Mode
  static const Color lightButtonPrimary = Color(0xFF63AB83);
  static const Color lightButtonSecondary = Color(0xFFFFFFFF);
  static const Color lightButtonText = Color(0xFFFFFFFF);
  static const Color lightButtonTextSecondary = Color(0xFF63AB83);

  /// Màu icon - Light Mode
  static const Color lightIconPrimary = Color(0xFF212121);
  static const Color lightIconSecondary = Color(0xFF757575);

  // ==================== DARK MODE COLORS ====================
  /// Màu nền chính - Dark Mode (xám đậm)
  static const Color darkBackground = Color(0xFF121212);

  /// Màu nền phụ/card - Dark Mode (xám đậm hơn)
  static const Color darkSurface = Color(0xFF1E1E1E);

  /// Màu text chính - Dark Mode (trắng/xám nhạt)
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);

  /// Màu viền/border - Dark Mode
  static const Color darkBorder = Color(0xFF424242);

  /// Màu cho input field - Dark Mode
  static const Color darkInputBackground = Color(0xFF2C2C2C);
  static const Color darkInputBorder = Color(0xFF424242);

  /// Màu cho button - Dark Mode
  static const Color darkButtonPrimary = Color(0xFF63AB83);
  static const Color darkButtonSecondary = Color(0xFF2C2C2C);
  static const Color darkButtonText = Color(0xFFFFFFFF);
  static const Color darkButtonTextSecondary = Color(0xFF63AB83);

  /// Màu icon - Dark Mode
  static const Color darkIconPrimary = Color(0xFFFFFFFF);
  static const Color darkIconSecondary = Color(0xFFB0B0B0);

  // ==================== GRADIENT COLORS ====================
  /// Gradient cho background
  static const LinearGradient lightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF63AB83), Color(0xFF4A9B6E)],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1E1E1E), Color(0xFF121212)],
  );
}

/// Theme helper để lấy màu theo theme hiện tại
class AppTheme {
  /// Lấy màu nền chính theo theme
  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? AppColors.lightBackground
        : AppColors.darkBackground;
  }

  /// Lấy màu nền phụ/card theo theme
  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? AppColors.lightSurface
        : AppColors.darkSurface;
  }

  /// Lấy màu text chính theo theme
  static Color getTextPrimaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? AppColors.lightTextPrimary
        : AppColors.darkTextPrimary;
  }

  /// Lấy màu text phụ theo theme
  static Color getTextSecondaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? AppColors.lightTextSecondary
        : AppColors.darkTextSecondary;
  }

  /// Lấy màu viền theo theme
  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? AppColors.lightBorder
        : AppColors.darkBorder;
  }

  /// Lấy màu input background theo theme
  static Color getInputBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? AppColors.lightInputBackground
        : AppColors.darkInputBackground;
  }

  /// Lấy màu input border theo theme
  static Color getInputBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? AppColors.lightInputBorder
        : AppColors.darkInputBorder;
  }

  /// Lấy màu button primary theo theme
  static Color getButtonPrimaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? AppColors.lightButtonPrimary
        : AppColors.darkButtonPrimary;
  }

  /// Lấy màu button secondary theo theme
  static Color getButtonSecondaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? AppColors.lightButtonSecondary
        : AppColors.darkButtonSecondary;
  }

  /// Lấy màu button text theo theme
  static Color getButtonTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? AppColors.lightButtonText
        : AppColors.darkButtonText;
  }

  /// Lấy màu icon primary theo theme
  static Color getIconPrimaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? AppColors.lightIconPrimary
        : AppColors.darkIconPrimary;
  }

  /// Lấy màu icon secondary theo theme
  static Color getIconSecondaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? AppColors.lightIconSecondary
        : AppColors.darkIconSecondary;
  }

  /// Lấy gradient theo theme
  static LinearGradient getGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? AppColors.lightGradient
        : AppColors.darkGradient;
  }

  /// Light Theme Data
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.primaryGreen,
    scaffoldBackgroundColor: AppColors.lightBackground,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryGreen,
      secondary: AppColors.vietnamRed,
      surface: AppColors.lightSurface,
      error: AppColors.error,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.lightBackground,
      foregroundColor: AppColors.lightTextPrimary,
      elevation: 0,
      titleTextStyle: GoogleFonts.beVietnamPro(
        color: AppColors.darkTextPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardTheme(
      color: AppColors.lightSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.lightButtonPrimary,
        foregroundColor: AppColors.lightButtonText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.beVietnamPro(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightInputBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.lightInputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.lightInputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
      ),
      labelStyle: GoogleFonts.beVietnamPro(),
      hintStyle: GoogleFonts.beVietnamPro(),
    ),
    textTheme: GoogleFonts.beVietnamProTextTheme(
      const TextTheme(
        displayLarge: TextStyle(color: AppColors.lightTextPrimary),
        displayMedium: TextStyle(color: AppColors.lightTextPrimary),
        displaySmall: TextStyle(color: AppColors.lightTextPrimary),
        headlineMedium: TextStyle(color: AppColors.lightTextPrimary),
        headlineSmall: TextStyle(color: AppColors.lightTextPrimary),
        titleLarge: TextStyle(color: AppColors.lightTextPrimary),
        bodyLarge: TextStyle(color: AppColors.lightTextPrimary),
        bodyMedium: TextStyle(color: AppColors.lightTextSecondary),
      ),
    ),
  );

  /// Dark Theme Data
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.primaryGreen,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryGreen,
      secondary: AppColors.vietnamRed,
      surface: AppColors.darkSurface,
      error: AppColors.error,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
      titleTextStyle: GoogleFonts.beVietnamPro(
        color: AppColors.darkTextPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardTheme(
      color: AppColors.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.darkButtonPrimary,
        foregroundColor: AppColors.darkButtonText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.beVietnamPro(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkInputBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.darkInputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.darkInputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
      ),
      labelStyle: GoogleFonts.beVietnamPro(),
      hintStyle: GoogleFonts.beVietnamPro(),
    ),
    textTheme: GoogleFonts.beVietnamProTextTheme(
      const TextTheme(
        displayLarge: TextStyle(color: AppColors.darkTextPrimary),
        displayMedium: TextStyle(color: AppColors.darkTextPrimary),
        displaySmall: TextStyle(color: AppColors.darkTextPrimary),
        headlineMedium: TextStyle(color: AppColors.darkTextPrimary),
        headlineSmall: TextStyle(color: AppColors.darkTextPrimary),
        titleLarge: TextStyle(color: AppColors.darkTextPrimary),
        bodyLarge: TextStyle(color: AppColors.darkTextPrimary),
        bodyMedium: TextStyle(color: AppColors.darkTextSecondary),
      ),
    ),
  );
}

class AppStrings {
  static const String appName = 'Viva Home Valuation';
  static const String loginTitle = 'LOG IN';
  static const String emailHint = 'Email';
  static const String passwordHint = 'Password';
  static const String loginButton = 'Log In';
  static const String joinButton = 'Join';
  static const String forgotPassword = 'Forgot password?';
  static const String connectSurveyor = 'Please connect your surveyor';
  static const String privacyPolicy = 'Privacy Policy';
  static const String termsConditions = 'Terms & Conditions';
  static const String agreeToTerms =
      'By signing in, you agree to our Privacy Policy and Terms of Use.';
  static const String loggedInAs = 'Logged In:';
  static const String dashboard = 'DASHBOARD';
  static const String details = 'DETAILS';
  static const String survey = 'SURVEY';
  static const String surveyorsRequests = "SURVEYOR'S REQUESTS";
  static const String propertiesDetail = 'PROPERTY\nDETAILS';
  static const String backButton = 'Back';
  static const generalDetails = 'GENERAL';
  static const externalDetails = 'EXTERNAL';
  static const additionalDetails = 'ADDITIONAL';
  static const servicesDetails = 'SERVICES';
  static const internalDetails = 'INTERNAL';
}

/// Constants cho hệ thống báo cáo vi phạm
class ViolationConstants {
  // ==================== LOẠI VI PHẠM ====================
  /// Loại vi phạm: Nội dung khiêu dâm
  static const String typePornographic = 'pornographic';

  /// Loại vi phạm: Thông tin sai sự thật
  static const String typeMisinformation = 'misinformation';

  /// Loại vi phạm: Công kích cá nhân
  static const String typeHarassment = 'harassment';

  /// Loại vi phạm: Spam hoặc quảng cáo
  static const String typeSpam = 'spam';

  /// Loại vi phạm: Nội dung bạo lực
  static const String typeViolence = 'violence';

  /// Loại vi phạm: Ngôn từ thù ghét
  static const String typeHateSpeech = 'hate_speech';

  /// Loại vi phạm: Vi phạm bản quyền
  static const String typeCopyright = 'copyright';

  /// Loại vi phạm: Khác (cho phép người dùng mô tả)
  static const String typeOther = 'other';

  // ==================== TRẠNG THÁI REQUEST ====================
  /// Trạng thái: Đang chờ xử lý
  static const String statusPending = 'pending';

  /// Trạng thái: Đã được duyệt
  static const String statusApproved = 'approved';

  /// Trạng thái: Bị từ chối
  static const String statusRejected = 'rejected';

  // ==================== LABELS CHO UI ====================
  static const Map<String, String> violationTypeLabels = {
    typePornographic: '🔞 Nội dung khiêu dâm',
    typeMisinformation: '❌ Thông tin sai sự thật',
    typeHarassment: '😡 Công kích cá nhân',
    typeSpam: '📢 Spam/Quảng cáo',
    typeViolence: '⚔️ Nội dung bạo lực',
    typeHateSpeech: '💢 Ngôn từ thù ghét',
    typeCopyright: '©️ Vi phạm bản quyền',
    typeOther: '📝 Khác',
  };

  static const Map<String, String> statusLabels = {
    statusPending: '⏳ Đang chờ xử lý',
    statusApproved: '✅ Đã duyệt',
    statusRejected: '❌ Từ chối',
  };

  // ==================== MÔ TẢ CHO ADMIN ====================
  static const Map<String, String> violationTypeDescriptions = {
    typePornographic:
        'Nội dung có tính chất khiêu dâm, không phù hợp với cộng đồng',
    typeMisinformation:
        'Thông tin không chính xác, gây hiểu lầm hoặc sai sự thật',
    typeHarassment: 'Công kích, xúc phạm hoặc quấy rối người khác',
    typeSpam: 'Nội dung spam, quảng cáo không mong muốn',
    typeViolence: 'Nội dung bạo lực, gây sợ hãi hoặc khủng bố',
    typeHateSpeech: 'Ngôn từ kích động thù ghét, phân biệt đối xử',
    typeCopyright: 'Sử dụng nội dung vi phạm bản quyền của người khác',
    typeOther: 'Vi phạm khác (xem chi tiết trong mô tả)',
  };

  // ==================== MÀU SẮC CHO TRẠNG THÁI ====================
  static const Map<String, Color> statusColors = {
    statusPending: Color(0xFFFFA726), // Màu cam - đang chờ
    statusApproved: Color(0xFF66BB6A), // Màu xanh lá - đã duyệt
    statusRejected: Color(0xFFFF3D00), // Màu đỏ - từ chối
  };

  // ==================== ĐIỂM BỊ TRỪ KHI VI PHẠM ====================
  /// Điểm bị trừ cho từng loại vi phạm
  static const Map<String, int> violationPenaltyPoints = {
    typePornographic: -50,
    typeMisinformation: -30,
    typeHarassment: -40,
    typeSpam: -20,
    typeViolence: -50,
    typeHateSpeech: -45,
    typeCopyright: -35,
    typeOther: -25,
  };

  // ==================== HELPER METHODS ====================
  /// Lấy label hiển thị của loại vi phạm
  static String getViolationTypeLabel(String type) {
    return violationTypeLabels[type] ?? type;
  }

  /// Lấy label hiển thị của trạng thái
  static String getStatusLabel(String status) {
    return statusLabels[status] ?? status;
  }

  /// Lấy mô tả của loại vi phạm
  static String getViolationTypeDescription(String type) {
    return violationTypeDescriptions[type] ?? '';
  }

  /// Lấy màu của trạng thái
  static Color getStatusColor(String status) {
    return statusColors[status] ?? AppColors.lightTextSecondary;
  }

  /// Lấy điểm bị trừ của loại vi phạm
  static int getPenaltyPoints(String type) {
    return violationPenaltyPoints[type] ?? -25;
  }

  /// Danh sách tất cả các loại vi phạm
  static List<String> get allViolationTypes => [
    typePornographic,
    typeMisinformation,
    typeHarassment,
    typeSpam,
    typeViolence,
    typeHateSpeech,
    typeCopyright,
    typeOther,
  ];
}

/// Size categories for responsive design system
enum SizeCategory { small, medium, large, xlarge, xxlarge, xxxlarge }

/// Size type for different responsive properties
enum SizeType { padding, radius, font, icon, container }

/// A comprehensive responsive sizing system for Flutter applications.
///
/// This class provides responsive sizing for padding, radius, and fonts
/// based on screen dimensions and device characteristics. It supports
/// custom breakpoints and accessibility features.
///
/// Example usage:
/// ```dart
/// // Responsive sizing (recommended)
/// Container(
///   padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
///   child: Text(
///     'Hello',
///     style: TextStyle(fontSize: AppSizes.font(context, SizeCategory.large)),
///   ),
/// )
///
/// // Static fallback
/// Container(
///   padding: EdgeInsets.all(AppSizes.paddingStatic(SizeCategory.medium)),
/// )
///
/// // Device type checking
/// if (AppSizes.isMobile(context)) {
///   // Mobile-specific logic
/// }
/// ```
class AppSizes {
  /// Base sizes configuration for different types
  static const Map<SizeType, double> _baseValues = {
    SizeType.padding: 8.0,
    SizeType.radius: 4.0,
    SizeType.font: 14.0,
    SizeType.icon: 16.0,
    SizeType.container: 48.0,
  };

  /// Size multipliers configuration for each category
  static const Map<SizeCategory, Map<SizeType, double>> _sizeMultipliers = {
    SizeCategory.small: {
      SizeType.padding: 1.0, // 8.0
      SizeType.radius: 2.0, // 8.0
      SizeType.font: 0.85, // ~12.0
      SizeType.icon: 1.0, // 16.0
      SizeType.container: 1.5, // 72.0
    },
    SizeCategory.medium: {
      SizeType.padding: 2.0, // 16.0
      SizeType.radius: 3.0, // 12.0
      SizeType.font: 1.0, // 14.0
      SizeType.icon: 1.5, // 24.0
      SizeType.container: 2.5, // 120.0
    },
    SizeCategory.large: {
      SizeType.padding: 3.0, // 24.0
      SizeType.radius: 4.0, // 16.0
      SizeType.font: 1.15, // ~16.0
      SizeType.icon: 2.0, // 32.0
      SizeType.container: 3.0, // 144.0
    },
    SizeCategory.xlarge: {
      SizeType.padding: 4.0, // 32.0
      SizeType.radius: 5.0, // 20.0
      SizeType.font: 1.3, // ~18.0
      SizeType.icon: 2.5, // 40.0
      SizeType.container: 3.5, // 168.0
    },
    SizeCategory.xxlarge: {
      SizeType.padding: 5.0, // 40.0
      SizeType.radius: 6.0, // 24.0
      SizeType.font: 1.7, // ~24.0
      SizeType.icon: 3.0, // 48.0
      SizeType.container: 4.0, // 192.0
    },
    SizeCategory.xxxlarge: {
      SizeType.padding: 6.0, // 48.0
      SizeType.radius: 7.0, // 28.0
      SizeType.font: 2.1, // ~30.0
      SizeType.icon: 4.0, // 64.0
      SizeType.container: 3.65, // ~175.0
    },
  };

  /// Device-specific scaling multipliers
  static const Map<String, Map<SizeType, double>> _deviceMultipliers = {
    'mobile': {
      SizeType.padding: 1.0,
      SizeType.radius: 1.0,
      SizeType.font: 1.0,
      SizeType.icon: 1.0,
      SizeType.container: 1.0,
    },
    'tablet': {
      SizeType.padding: 1.5,
      SizeType.radius: 1.5,
      SizeType.font: 1.15,
      SizeType.icon: 1.2,
      SizeType.container: 1.2,
    },
    'desktop': {
      SizeType.padding: 2.0,
      SizeType.radius: 2.0,
      SizeType.font: 1.25,
      SizeType.icon: 1.3,
      SizeType.container: 1.3,
    },
  };

  /// Default screen size breakpoints in logical pixels
  ///
  /// These can be overridden using custom breakpoint methods.
  /// Based on Material Design guidelines and common device sizes.
  static const double _defaultMobileBreakpoint = 600;
  static const double _defaultTabletBreakpoint = 1024;

  // ==================== SCREEN INFO METHODS ====================

  /// Returns the full screen size including status bar and navigation
  static Size screenSize(BuildContext context) => MediaQuery.of(context).size;

  /// Returns the screen width in logical pixels
  static double screenWidth(BuildContext context) => screenSize(context).width;

  /// Returns the screen height in logical pixels
  static double screenHeight(BuildContext context) =>
      screenSize(context).height;

  /// Returns the shortest side (width or height) - useful for responsive design
  ///
  /// This is more reliable than width alone for determining device categories,
  /// especially for foldable devices or tablets in different orientations.
  static double shortestSide(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide;

  /// Returns the current device orientation
  static Orientation orientation(BuildContext context) =>
      MediaQuery.of(context).orientation;

  /// Returns the user's accessibility text scaler
  ///
  /// This automatically adjusts font sizes based on system accessibility settings.
  /// Uses the modern textScaler API instead of deprecated textScaleFactor.
  static TextScaler textScaler(BuildContext context) =>
      MediaQuery.of(context).textScaler;

  // ==================== BREAKPOINT METHODS ====================

  /// Determines device category based on shortest side with custom breakpoints
  ///
  /// [mobileBreakpoint] - Max shortest side for mobile devices (default: 600)
  /// [tabletBreakpoint] - Max shortest side for tablet devices (default: 1024)
  ///
  /// Returns:
  /// - 'mobile' for devices <= mobileBreakpoint
  /// - 'tablet' for devices > mobileBreakpoint && <= tabletBreakpoint
  /// - 'desktop' for devices > tabletBreakpoint
  static String getDeviceType(
    BuildContext context, {
    double mobileBreakpoint = _defaultMobileBreakpoint,
    double tabletBreakpoint = _defaultTabletBreakpoint,
  }) {
    final shortest = shortestSide(context);
    if (shortest <= mobileBreakpoint) return 'mobile';
    if (shortest <= tabletBreakpoint) return 'tablet';
    return 'desktop';
  }

  /// Checks if device is mobile category
  static bool isMobile(
    BuildContext context, {
    double mobileBreakpoint = _defaultMobileBreakpoint,
  }) => getDeviceType(context, mobileBreakpoint: mobileBreakpoint) == 'mobile';

  /// Checks if device is tablet category
  static bool isTablet(
    BuildContext context, {
    double mobileBreakpoint = _defaultMobileBreakpoint,
    double tabletBreakpoint = _defaultTabletBreakpoint,
  }) =>
      getDeviceType(
        context,
        mobileBreakpoint: mobileBreakpoint,
        tabletBreakpoint: tabletBreakpoint,
      ) ==
      'tablet';

  /// Checks if device is desktop/large screen category
  static bool isLargeScreen(
    BuildContext context, {
    double tabletBreakpoint = _defaultTabletBreakpoint,
  }) => getDeviceType(context, tabletBreakpoint: tabletBreakpoint) == 'desktop';

  // ==================== CORE GENERIC FUNCTIONS ====================

  /// Generic responsive scaling function for any size type
  ///
  /// [context] - BuildContext for responsive calculations
  /// [sizeType] - Type of size (padding, radius, font)
  /// [category] - Size category (small, medium, large, etc.)
  /// [mobileBreakpoint] - Custom mobile breakpoint (default: 600)
  /// [tabletBreakpoint] - Custom tablet breakpoint (default: 1024)
  /// [adjustForLandscape] - Apply landscape adjustment (default: true)
  /// [landscapeMultiplier] - Landscape size adjustment (default: 0.9)
  static double _genericScale(
    BuildContext context,
    SizeType sizeType,
    SizeCategory category, {
    double mobileBreakpoint = _defaultMobileBreakpoint,
    double tabletBreakpoint = _defaultTabletBreakpoint,
    bool adjustForLandscape = true,
    double landscapeMultiplier = 0.9,
  }) {
    // Get base value and category multiplier
    final baseValue = _baseValues[sizeType]!;
    final categoryMultiplier = _sizeMultipliers[category]![sizeType]!;

    // Get device type and device multiplier
    final deviceType = getDeviceType(
      context,
      mobileBreakpoint: mobileBreakpoint,
      tabletBreakpoint: tabletBreakpoint,
    );
    final deviceMultiplier = _deviceMultipliers[deviceType]![sizeType]!;

    // Calculate final size
    double finalSize = baseValue * categoryMultiplier * deviceMultiplier;

    // Apply landscape adjustment if enabled
    if (adjustForLandscape && orientation(context) == Orientation.landscape) {
      finalSize *= landscapeMultiplier;
    }

    // Apply accessibility scaling for fonts
    if (sizeType == SizeType.font) {
      finalSize = textScaler(context).scale(finalSize);
    }

    return finalSize;
  }

  // ==================== PUBLIC GENERIC METHODS ====================

  /// Returns responsive padding based on size category
  static double padding(
    BuildContext context,
    SizeCategory category, {
    double mobileBreakpoint = _defaultMobileBreakpoint,
    double tabletBreakpoint = _defaultTabletBreakpoint,
  }) => _genericScale(
    context,
    SizeType.padding,
    category,
    mobileBreakpoint: mobileBreakpoint,
    tabletBreakpoint: tabletBreakpoint,
  );

  /// Returns responsive border radius based on size category
  static double radius(
    BuildContext context,
    SizeCategory category, {
    double mobileBreakpoint = _defaultMobileBreakpoint,
    double tabletBreakpoint = _defaultTabletBreakpoint,
  }) => _genericScale(
    context,
    SizeType.radius,
    category,
    mobileBreakpoint: mobileBreakpoint,
    tabletBreakpoint: tabletBreakpoint,
  );

  /// Returns responsive font size based on size category with accessibility support
  static double font(
    BuildContext context,
    SizeCategory category, {
    double mobileBreakpoint = _defaultMobileBreakpoint,
    double tabletBreakpoint = _defaultTabletBreakpoint,
  }) => _genericScale(
    context,
    SizeType.font,
    category,
    mobileBreakpoint: mobileBreakpoint,
    tabletBreakpoint: tabletBreakpoint,
  );

  /// Returns responsive icon size based on size category
  static double icon(
    BuildContext context,
    SizeCategory category, {
    double mobileBreakpoint = _defaultMobileBreakpoint,
    double tabletBreakpoint = _defaultTabletBreakpoint,
  }) => _genericScale(
    context,
    SizeType.icon,
    category,
    mobileBreakpoint: mobileBreakpoint,
    tabletBreakpoint: tabletBreakpoint,
  );

  /// Returns responsive container height based on size category
  static double container(
    BuildContext context,
    SizeCategory category, {
    double mobileBreakpoint = _defaultMobileBreakpoint,
    double tabletBreakpoint = _defaultTabletBreakpoint,
  }) => _genericScale(
    context,
    SizeType.container,
    category,
    mobileBreakpoint: mobileBreakpoint,
    tabletBreakpoint: tabletBreakpoint,
  );
}
