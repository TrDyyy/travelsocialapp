import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:travel_social_app/services/auth_service.dart';
import 'package:travel_social_app/ui/auth/splash_screen.dart';
import 'package:travel_social_app/ui/tabs/profile/friend_list_screen.dart';
import 'package:travel_social_app/ui/tabs/profile/save_post_list_screen.dart';
import 'package:travel_social_app/ui/tabs/profile/setting_screen.dart';
import 'package:travel_social_app/ui/violation/violation_history_screen.dart';
import '../../../models/user_model.dart';
import '../../../services/user_service.dart';
import '../../../utils/constants.dart';
import 'edit_profile_screen.dart';
import 'badge_screen.dart';

/// Trang cá nhân của user
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  final _imagePicker = ImagePicker();
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    // Fallback: Nếu sau 10 giây vẫn loading thì force stop
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        print('⏱️ Timeout loading user data, forcing stop');
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('🔄 Loading user data for: ${user.uid}');

        // Fix data cũ nếu cần (chuyển points từ String sang int)
        await _userService.fixUserPointsDataType(user.uid);

        final userData = await _userService.getUserById(user.uid);
        print('✅ User data loaded: ${userData?.name}');
        if (mounted) {
          setState(() {
            _currentUser = userData;
            _isLoading = false;
          });
        }
      } else {
        print('❌ No Firebase user found');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _changeAvatar() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 500,
      );

      if (pickedFile != null) {
        setState(() => _isLoading = true);

        final user = FirebaseAuth.instance.currentUser;
        final newUrl = await _userService.uploadAvatar(
          user!.uid,
          File(pickedFile.path),
        );

        if (newUrl != null) {
          await _loadUserData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Đã cập nhật ảnh đại diện!'),
                backgroundColor: AppColors.primaryGreen,
              ),
            );
          }
        }

        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
      '🔄 ProfileScreen build() called - isLoading: $_isLoading, hasUser: ${_currentUser != null}',
    );

    if (_isLoading || _currentUser == null) {
      return Scaffold(
        backgroundColor: AppTheme.getBackgroundColor(context),
        appBar: AppBar(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Trang cá nhân',
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.large),
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Trang cá nhân',
          style: TextStyle(
            fontSize: AppSizes.font(context, SizeCategory.large),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
        child: Column(
          children: [
            // Avatar Card
            _buildAvatarCard(),
            SizedBox(height: AppSizes.padding(context, SizeCategory.large)),

            // Action Buttons Grid
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSizes.padding(context, SizeCategory.medium),
      ),
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.large)),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar với nút edit
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage:
                    _currentUser!.avatarUrl != null &&
                            _currentUser!.avatarUrl!.isNotEmpty
                        ? NetworkImage(_currentUser!.avatarUrl!)
                        : null,
                backgroundColor: AppColors.primaryGreen,
                child:
                    _currentUser!.avatarUrl == null ||
                            _currentUser!.avatarUrl!.isEmpty
                        ? Icon(
                          Icons.person,
                          size: AppSizes.icon(context, SizeCategory.xlarge),
                          color: Colors.white,
                        )
                        : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _changeAvatar,
                  child: Container(
                    padding: EdgeInsets.all(
                      AppSizes.padding(context, SizeCategory.small),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.getSurfaceColor(context),
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: AppSizes.icon(context, SizeCategory.small),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),

          // Name
          Text(
            _currentUser!.name,
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.xlarge),
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.padding(context, SizeCategory.medium),
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: AppSizes.padding(context, SizeCategory.medium),
        crossAxisSpacing: AppSizes.padding(context, SizeCategory.medium),
        childAspectRatio: 1.0,
        children: [
          _buildActionButton(
            icon: Icons.badge,
            label: 'Huy hiệu\nhành trình',
            color: const Color(0xFF4A90E2),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BadgeScreen()),
              );
            },
          ),
          _buildActionButton(
            icon: Icons.info_outline,
            label: 'Thông tin\ncá nhân',
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(user: _currentUser!),
                ),
              );
              if (result == true) {
                _loadUserData();
              }
            },
          ),
          _buildActionButton(
            icon: Icons.bookmark_border,
            label: 'Kho lưu trữ',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavePostListScreen(),
                ),
              );
            },
          ),

          _buildActionButton(
            icon: Icons.group,
            label: 'Bạn bè',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FriendListScreen(),
                ),
              );
            },
          ),
          _buildActionButton(
            icon: Icons.settings,
            label: 'Cài đặt',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingScreen()),
              );
            },
          ),
          _buildActionButton(
            icon: Icons.help_outline,
            label: 'Vi phạm và khiếu nại',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ViolationHistoryScreen(),
                ),
              );
            },
          ),
          _buildActionButton(
            icon: Icons.logout,
            label: 'Đăng xuất',
            color: Colors.red,
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => SplashScreen()),
                (route) => false,
              );
              AuthService().signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = color ?? AppTheme.getTextSecondaryColor(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        AppSizes.radius(context, SizeCategory.small),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.small),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(
            AppSizes.padding(context, SizeCategory.medium),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: AppSizes.icon(context, SizeCategory.large),
                color: defaultColor,
              ),
              SizedBox(height: AppSizes.padding(context, SizeCategory.small)),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppSizes.font(context, SizeCategory.small),
                  color: defaultColor,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
