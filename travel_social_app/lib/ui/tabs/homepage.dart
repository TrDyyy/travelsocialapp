import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:line_icons/line_icons.dart';
import 'package:travel_social_app/ui/tabs/chatbot/chat_assistant_screen.dart';
import 'package:travel_social_app/ui/tabs/social/social_home_screen.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/constants.dart';
import '../../services/location_service.dart';
import 'place/index.dart';
import 'profile/index.dart';
import 'message/chat_list_screen.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => HomepageState();
}

class HomepageState extends State<Homepage> {
  int _selectedIndex = 0;
  final LocationService _locationService = LocationService();
  String _currentLocation = 'Đang tải vị trí...';
  bool _isLoadingLocation = true;

  // GlobalKey cho PlaceScreen để access state
  final GlobalKey<PlaceScreenState> _placeScreenKey =
      GlobalKey<PlaceScreenState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      PlaceScreen(key: _placeScreenKey),
      //// Màn hình bản đồ với key
      const SocialHomeScreen(),
      const ChatListScreen(),
      const ChatAssistantScreen(),
    ];
    _loadCurrentLocation();
  }

  /// Public method để switch tab từ bên ngoài
  void switchToTab(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  /// Public method để switch đến Map tab và focus vào place
  void switchToMapTab(String? placeId) {
    if (mounted) {
      setState(() {
        _selectedIndex = 0;
      });

      // Nếu có placeId, call PlaceScreen để focus vào place đó
      if (placeId != null) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _placeScreenKey.currentState?.focusOnPlace(placeId);
        });
      }
    }
  }

  /// Public method để switch đến Map tab với tên địa điểm để search
  void switchToMapTabWithSearch(String placeName) {
    if (mounted) {
      setState(() {
        _selectedIndex = 0;
      });

      // Note: PlaceScreen sẽ tự động focus vào search bar
      // User sẽ thấy placeName trong context và có thể search
    }
  }

  /// Load vị trí hiện tại
  Future<void> _loadCurrentLocation() async {
    try {
      // Yêu cầu quyền truy cập vị trí
      final hasPermission = await _locationService.requestLocationPermission();

      if (!hasPermission) {
        setState(() {
          _currentLocation = 'Không có quyền truy cập vị trí';
          _isLoadingLocation = false;
        });
        return;
      }

      // Lấy địa chỉ hiện tại
      final address = await _locationService.getCurrentAddress();

      if (mounted) {
        setState(() {
          _currentLocation = address ?? 'Không thể lấy vị trí';
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentLocation = 'Không thể lấy vị trí';
          _isLoadingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getSurfaceColor(context),
      // Ẩn AppBar khi ở tab PlaceScreen (index 0)
      appBar:
          _selectedIndex == 0
              ? null
              : CustomAppBar(
                locationText: _currentLocation,
                onLocationTap: () {
                  _showLocationPicker(context);
                },
                // onNotificationTap removed - CustomAppBar auto-navigates to NotificationsScreen
                onAvatarTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
              ),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: AppTheme.getSurfaceColor(context),
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.padding(context, SizeCategory.small),
            vertical: AppSizes.padding(context, SizeCategory.small),
          ),
          child: SizedBox(
            width: double.infinity,
            child: GNav(
              selectedIndex: _selectedIndex,
              onTabChange: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              rippleColor: AppTheme.getBorderColor(context),
              hoverColor: AppTheme.getInputBackgroundColor(context),
              haptic: true,
              tabBorderRadius: AppSizes.radius(context, SizeCategory.medium),
              curve: Curves.fastOutSlowIn,
              duration: const Duration(milliseconds: 400),
              gap: AppSizes.padding(context, SizeCategory.small),
              color: AppTheme.getIconSecondaryColor(context),
              activeColor: Colors.white,
              iconSize: AppSizes.icon(context, SizeCategory.medium),
              tabBackgroundColor: AppColors.primaryGreen,
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.padding(context, SizeCategory.medium),
                vertical: AppSizes.padding(context, SizeCategory.small),
              ),
              tabs: const [
                GButton(icon: LineIcons.home, text: 'Trang chủ'),
                GButton(icon: LineIcons.connectDevelop, text: 'Mạng xã hội'),
                GButton(icon: Icons.message_outlined, text: 'Trò chuyện'),
                GButton(icon: LineIcons.robot, text: 'Dora'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Hiển thị location picker với reload option
  void _showLocationPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radius(context, SizeCategory.large)),
        ),
      ),
      builder:
          (context) => Container(
            padding: EdgeInsets.all(
              AppSizes.padding(context, SizeCategory.large),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Vị trí của bạn',
                  style: TextStyle(
                    fontSize: AppSizes.font(context, SizeCategory.large),
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextPrimaryColor(context),
                  ),
                ),
                SizedBox(
                  height: AppSizes.padding(context, SizeCategory.medium),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.my_location,
                    color: AppColors.primaryGreen,
                  ),
                  title: Text(_currentLocation),
                  subtitle: const Text('Vị trí hiện tại'),
                  trailing:
                      _isLoadingLocation
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () {
                              Navigator.pop(context);
                              _loadCurrentLocation();
                            },
                          ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.settings,
                    color: AppColors.primaryGreen,
                  ),
                  title: const Text('Cài đặt quyền vị trí'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _locationService.requestLocationPermission();
                  },
                ),
              ],
            ),
          ),
    );
  }
}
