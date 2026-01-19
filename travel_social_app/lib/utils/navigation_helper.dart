import 'package:flutter/material.dart';
import '../ui/tabs/homepage.dart';

/// Global key để access Homepage state từ bất kỳ đâu
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<HomepageState> homepageKey = GlobalKey<HomepageState>();

/// Helper class để navigate đến các tab khác nhau
class NavigationHelper {
  /// Navigate đến Map tab và focus vào place cụ thể
  static void navigateToMapWithPlace(
    BuildContext context,
    String placeId,
    String placeName,
  ) {
    // Pop tất cả routes về root
    Navigator.of(context).popUntil((route) => route.isFirst);

    // Chuyển sang tab Map (index 0) và truyền placeId
    homepageKey.currentState?.switchToMapTab(placeId);

    // Show snackbar thông báo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đang mở "$placeName" trên bản đồ...'),
        backgroundColor: const Color(0xFF63AB83),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Navigate đến Map tab với tên địa điểm để search (cho place chưa có trong hệ thống)
  static void navigateToMapWithSearch(BuildContext context, String placeName) {
    // Pop tất cả routes về root
    Navigator.of(context).popUntil((route) => route.isFirst);

    // Chuyển sang tab Map và trigger search
    homepageKey.currentState?.switchToMapTabWithSearch(placeName);

    // Show snackbar thông báo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đang tìm "$placeName" trên bản đồ...'),
        backgroundColor: const Color(0xFF63AB83),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Navigate đến Map tab (không focus place cụ thể)
  static void navigateToMapTab(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    homepageKey.currentState?.switchToMapTab(null);
  }

  /// Navigate đến Social tab
  static void navigateToSocialTab(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    homepageKey.currentState?.switchToTab(1);
  }
}
