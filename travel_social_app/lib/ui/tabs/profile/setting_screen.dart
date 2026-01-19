import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../states/theme_provider.dart';
import '../../../utils/constants.dart';

/// Màn hình cài đặt ứng dụng
class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  @override
  void initState() {
    super.initState();
  }

  /// Save theme preference vào SharedPreferences
  Future<void> _saveThemePreference(AppThemeMode mode) async {
    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      await themeProvider.setThemeMode(mode);

      // Notify user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã thay đổi giao diện thành công',
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.medium),
              ),
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving theme preference: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lỗi khi lưu cài đặt: $e',
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.medium),
              ),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Cài đặt',
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.large),
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
                size: AppSizes.icon(context, SizeCategory.medium),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body:
              !themeProvider.isInitialized
                  ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                      strokeWidth: 3,
                    ),
                  )
                  : ListView(
                    padding: EdgeInsets.all(
                      AppSizes.padding(context, SizeCategory.medium),
                    ),
                    children: [
                      // Appearance Section
                      _buildSectionHeader(context, 'Giao diện'),
                      SizedBox(
                        height: AppSizes.padding(context, SizeCategory.small),
                      ),
                      _buildThemeCard(context, themeProvider),

                      SizedBox(
                        height: AppSizes.padding(context, SizeCategory.large),
                      ),

                      // About Section
                      _buildSectionHeader(context, 'Thông tin'),
                      SizedBox(
                        height: AppSizes.padding(context, SizeCategory.small),
                      ),
                      _buildInfoCard(context),
                    ],
                  ),
        );
      },
    );
  }

  /// Build section header
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.padding(context, SizeCategory.small),
      ),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: AppSizes.font(context, SizeCategory.small),
          fontWeight: FontWeight.w600,
          color: AppTheme.getTextSecondaryColor(context),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// Build theme selection card
  Widget _buildThemeCard(BuildContext context, ThemeProvider themeProvider) {
    final currentThemeMode = themeProvider.themeMode;

    return Card(
      color: AppTheme.getSurfaceColor(context),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.palette,
                  color: AppColors.primaryGreen,
                  size: AppSizes.icon(context, SizeCategory.medium),
                ),
                SizedBox(width: AppSizes.padding(context, SizeCategory.small)),
                Text(
                  'Chủ đề giao diện',
                  style: TextStyle(
                    fontSize: AppSizes.font(context, SizeCategory.medium),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.getTextPrimaryColor(context),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),

            // Theme options
            ...AppThemeMode.values.map((mode) {
              final isSelected = currentThemeMode == mode;
              return InkWell(
                onTap: () => _saveThemePreference(mode),
                borderRadius: BorderRadius.circular(
                  AppSizes.radius(context, SizeCategory.small),
                ),
                child: Container(
                  margin: EdgeInsets.only(
                    bottom: AppSizes.padding(context, SizeCategory.small),
                  ),
                  padding: EdgeInsets.all(
                    AppSizes.padding(context, SizeCategory.medium),
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? AppColors.primaryGreen.withOpacity(0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      AppSizes.radius(context, SizeCategory.small),
                    ),
                    border: Border.all(
                      color:
                          isSelected
                              ? AppColors.primaryGreen
                              : AppTheme.getBorderColor(context),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        ThemeProvider.getThemeModeIcon(mode),
                        color:
                            isSelected
                                ? AppColors.primaryGreen
                                : AppTheme.getIconSecondaryColor(context),
                        size: AppSizes.icon(context, SizeCategory.medium),
                      ),
                      SizedBox(
                        width: AppSizes.padding(context, SizeCategory.medium),
                      ),
                      Expanded(
                        child: Text(
                          ThemeProvider.getThemeModeDisplayName(mode),
                          style: TextStyle(
                            fontSize: AppSizes.font(
                              context,
                              SizeCategory.medium,
                            ),
                            fontWeight:
                                isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                            color:
                                isSelected
                                    ? AppColors.primaryGreen
                                    : AppTheme.getTextPrimaryColor(context),
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: AppColors.primaryGreen,
                          size: AppSizes.icon(context, SizeCategory.medium),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  /// Build info card
  Widget _buildInfoCard(BuildContext context) {
    return Card(
      color: AppTheme.getSurfaceColor(context),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
        child: Column(
          children: [
            _buildInfoRow(
              context,
              icon: Icons.info_outline,
              title: 'Phiên bản',
              value: '1.0.0',
            ),
            Divider(
              height: AppSizes.padding(context, SizeCategory.medium) * 2,
              color: AppTheme.getBorderColor(context),
            ),
            _buildInfoRow(
              context,
              icon: Icons.code,
              title: 'Build',
              value: '100',
            ),
          ],
        ),
      ),
    );
  }

  /// Build info row
  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.primaryGreen,
          size: AppSizes.icon(context, SizeCategory.medium),
        ),
        SizedBox(width: AppSizes.padding(context, SizeCategory.medium)),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.medium),
              color: AppTheme.getTextPrimaryColor(context),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: AppSizes.font(context, SizeCategory.medium),
            color: AppTheme.getTextSecondaryColor(context),
          ),
        ),
      ],
    );
  }
}
