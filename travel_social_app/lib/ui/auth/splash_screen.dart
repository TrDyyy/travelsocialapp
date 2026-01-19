import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travel_social_app/ui/auth/auth_first.dart';
import 'package:travel_social_app/ui/tabs/homepage.dart';
import '../../utils/constants.dart';
import '../../utils/navigation_helper.dart';
import '../../states/auth_provider.dart';
import '../../services/admin_service.dart';
import '../../services/location_service.dart';
import '../admin/admin_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    try {
      // Request location permission ngay từ đầu
      final locationService = LocationService();
      await locationService.requestLocationPermission();

      // Đợi AuthProvider khởi tạo
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Đợi cho đến khi AuthProvider initialized
      while (!authProvider.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Giả lập loading thêm ít thời gian để hiển thị splash
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // Check nếu user đã đăng nhập
      if (authProvider.isAuthenticated) {
        debugPrint('User đã đăng nhập: ${authProvider.user?.email}');

        // Check if user is admin
        final user = authProvider.user;
        if (user != null) {
          final adminService = AdminService();
          final isAdmin = await adminService.isAdmin(user.uid);

          if (isAdmin) {
            debugPrint('User là admin, chuyển đến Admin Dashboard');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminDashboard()),
            );
            return;
          }
        }

        // Normal user -> Homepage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Homepage(key: homepageKey)),
        );
      } else {
        debugPrint('User chưa đăng nhập, chuyển đến Auth Screen');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthFirst()),
        );
      }
    } catch (e) {
      debugPrint('Lỗi khi navigate: $e');
      if (mounted) {
        // Fallback: vẫn navigate đến auth screen nếu có lỗi
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthFirst()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Sử dụng gradient từ AppTheme
        decoration: BoxDecoration(gradient: AppTheme.getGradient(context)),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  height: AppSizes.padding(context, SizeCategory.xxxlarge),
                ), // Khoảng cách từ trên xuống
                Center(
                  child: Container(
                    width:
                        AppSizes.container(context, SizeCategory.xxxlarge) *
                        1.3,
                    height:
                        AppSizes.container(context, SizeCategory.xxxlarge) * 2,
                    decoration: BoxDecoration(
                      color: AppTheme.getSurfaceColor(context),
                      borderRadius: BorderRadius.circular(
                        AppSizes.radius(context, SizeCategory.large),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppSizes.radius(context, SizeCategory.medium),
                      ),
                      child: Image.asset(
                        'assets/icon/vietnam_icon_map.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Nếu không có ảnh, hiển thị icon thay thế
                          return Icon(
                            Icons.map,
                            size: 100,
                            color: AppColors.primaryGreen,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: AppSizes.padding(context, SizeCategory.medium),
                ),

                // Logo cờ Việt Nam và tiêu đề
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.padding(context, SizeCategory.large),
                    vertical: AppSizes.padding(context, SizeCategory.medium),
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.getBackgroundColor(context),
                    borderRadius: BorderRadius.circular(
                      AppSizes.radius(context, SizeCategory.medium),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon cờ Việt Nam
                      Container(
                        width: AppSizes.icon(context, SizeCategory.xlarge),
                        height:
                            AppSizes.icon(context, SizeCategory.xlarge) * 2 / 3,
                        decoration: BoxDecoration(
                          color: AppColors.vietnamRed,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.star,
                            color: Colors.yellow,
                            size: 12,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: AppSizes.padding(context, SizeCategory.medium),
                      ),
                      // Tiêu đề ứng dụng
                      Text(
                        'CHẠM LÀ CHẠY',
                        style: TextStyle(
                          color: AppTheme.getTextPrimaryColor(context),
                          fontSize: AppSizes.font(context, SizeCategory.large),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  height: AppSizes.padding(context, SizeCategory.medium),
                ),

                // Tiêu đề phụ
                Center(
                  child: Text(
                    'Khám phá vùng đất nghìn năm văn hiến',
                    style: TextStyle(
                      color: AppTheme.getTextPrimaryColor(context),
                      fontSize: AppSizes.font(context, SizeCategory.medium),
                    ),
                  ),
                ),

                SizedBox(
                  height: AppSizes.padding(context, SizeCategory.xlarge),
                ),

                // Vòng tròn tải
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.getTextPrimaryColor(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
