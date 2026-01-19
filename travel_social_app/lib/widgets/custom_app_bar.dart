import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../utils/constants.dart';
import '../states/auth_provider.dart';
import '../services/notification_service.dart';
import '../ui/notifications/notifications_screen.dart';

/// Custom AppBar với logo, location, notification và avatar
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? locationText;
  final VoidCallback? onLocationTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onAvatarTap;

  const CustomAppBar({
    super.key,
    this.locationText,
    this.onLocationTap,
    this.onNotificationTap,
    this.onAvatarTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56); // Reduced from 60 to 56 for better mobile UX

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.padding(context, SizeCategory.small),
            vertical: AppSizes.padding(context, SizeCategory.small) * 0.5,
          ),
          child: Row(
            children: [
              // Logo và Text "Cham Là Chay"
              _buildLogo(context),

              // Flexible spacer để đẩy các items sang phải
              const Spacer(),

              // Location Button (flexible để tránh overflow)
              Flexible(child: _buildLocationButton(context)),

              SizedBox(width: AppSizes.padding(context, SizeCategory.small)),

              // Notification Bell với unread count
              _buildNotificationButton(context),

              SizedBox(width: AppSizes.padding(context, SizeCategory.small)),

              // User Avatar
              _buildUserAvatar(context, user),
            ],
          ),
        ),
      ),
    );
  }

  /// Build logo với cờ và text (responsive)
  Widget _buildLogo(BuildContext context) {
    final isSmallMobile = AppSizes.screenWidth(context) < 360;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon cờ với ngôi sao vàng
        Container(
          width: isSmallMobile ? 28 : 32,
          height: isSmallMobile ? 20 : 22,
          decoration: BoxDecoration(
            color: AppColors.vietnamRed,
            borderRadius: BorderRadius.circular(
              AppSizes.radius(context, SizeCategory.small),
            ),
          ),
          child: Center(
            child: Icon(
              Icons.star,
              color: const Color(0xFFFDD835),
              size: isSmallMobile ? 12 : 14,
            ),
          ),
        ),
        SizedBox(width: AppSizes.padding(context, SizeCategory.small)),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Chạm',
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.small),
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1,
              ),
            ),
            Text(
              'Là Chạy',
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.small),
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build location button với text (responsive)
  Widget _buildLocationButton(BuildContext context) {
    final screenWidth = AppSizes.screenWidth(context);
    final isMobile = AppSizes.isMobile(context);

    // Calculate max width for location text
    // Logo (~80) + Spacer + Location + Notification (40) + Avatar (40) + Paddings (~60)
    // Total fixed = ~220, so location should not exceed screenWidth - 220
    final maxLocationWidth = screenWidth - 220;

    return InkWell(
      onTap: onLocationTap,
      borderRadius: BorderRadius.circular(
        AppSizes.radius(context, SizeCategory.medium),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxLocationWidth.clamp(80, 200), // Min 80, Max 200
        ),
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.padding(context, SizeCategory.small),
          vertical: AppSizes.padding(context, SizeCategory.small) * 0.5,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on,
              color: Colors.white,
              size: AppSizes.icon(context, SizeCategory.small),
            ),
            SizedBox(
              width: AppSizes.padding(context, SizeCategory.small) * 0.5,
            ),
            Flexible(
              child: Text(
                locationText ?? (isMobile ? 'TP.HCM' : 'Thành phố Hồ Chí Minh'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AppSizes.font(context, SizeCategory.small),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build notification button với số lượng badge (responsive)
  Widget _buildNotificationButton(BuildContext context) {
    final isSmallMobile = AppSizes.screenWidth(context) < 360;
    final buttonSize = isSmallMobile ? 36.0 : 40.0;
    final currentUserId = auth.FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return _buildNotificationIcon(context, 0);
    }

    return StreamBuilder<int>(
      stream: NotificationService().unreadCountStream(currentUserId),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        return InkWell(
          onTap: () {
            if (onNotificationTap != null) {
              onNotificationTap!();
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.large),
          ),
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: AppSizes.icon(context, SizeCategory.medium),
                  ),
                ),
                // Badge đỏ hiển thị số lượng
                if (unreadCount > 0)
                  Positioned(
                    right: isSmallMobile ? 4 : 6,
                    top: isSmallMobile ? 4 : 6,
                    child: Container(
                      padding: EdgeInsets.all(isSmallMobile ? 3 : 4),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: isSmallMobile ? 16 : 18,
                        minHeight: isSmallMobile ? 16 : 18,
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallMobile ? 8 : 9,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Helper to build notification icon without stream
  Widget _buildNotificationIcon(BuildContext context, int notificationCount) {
    final isSmallMobile = AppSizes.screenWidth(context) < 360;
    final buttonSize = isSmallMobile ? 36.0 : 40.0;

    return InkWell(
      onTap: onNotificationTap,
      borderRadius: BorderRadius.circular(
        AppSizes.radius(context, SizeCategory.large),
      ),
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: AppSizes.icon(context, SizeCategory.medium),
              ),
            ),
            // Badge đỏ hiển thị số lượng
            if (notificationCount > 0)
              Positioned(
                right: isSmallMobile ? 4 : 6,
                top: isSmallMobile ? 4 : 6,
                child: Container(
                  padding: EdgeInsets.all(isSmallMobile ? 3 : 4),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(
                    minWidth: isSmallMobile ? 16 : 18,
                    minHeight: isSmallMobile ? 16 : 18,
                  ),
                  child: Center(
                    child: Text(
                      notificationCount > 9 ? '9+' : '$notificationCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallMobile ? 8 : 9,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build user avatar với border và shadow (responsive)
  Widget _buildUserAvatar(BuildContext context, dynamic user) {
    final isSmallMobile = AppSizes.screenWidth(context) < 360;
    final avatarSize = isSmallMobile ? 36.0 : 40.0;

    return InkWell(
      onTap: onAvatarTap,
      borderRadius: BorderRadius.circular(
        AppSizes.radius(context, SizeCategory.large),
      ),
      child: Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child:
              user?.photoURL != null
                  ? Image.network(
                    user!.photoURL!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildDefaultAvatar(context);
                    },
                  )
                  : _buildDefaultAvatar(context),
        ),
      ),
    );
  }

  /// Build default avatar
  Widget _buildDefaultAvatar(BuildContext context) {
    return Container(
      color: AppColors.primaryGreen.withOpacity(0.2),
      child: Icon(
        Icons.person,
        color: AppColors.primaryGreen,
        size: AppSizes.icon(context, SizeCategory.medium),
      ),
    );
  }
}
