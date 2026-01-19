import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class NoInternetScreen extends StatelessWidget {
  final VoidCallback? onRetry;

  const NoInternetScreen({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.getGradient(context)),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(
                AppSizes.padding(context, SizeCategory.large),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon không có mạng
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.getSurfaceColor(context),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.wifi_off_rounded,
                      size: AppSizes.icon(context, SizeCategory.xxxlarge),
                      color: AppColors.error,
                    ),
                  ),

                  SizedBox(
                    height: AppSizes.padding(context, SizeCategory.xlarge),
                  ),

                  // Tiêu đề
                  Text(
                    'Không có kết nối',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.xxlarge),
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getTextPrimaryColor(context),
                    ),
                  ),

                  SizedBox(
                    height: AppSizes.padding(context, SizeCategory.medium),
                  ),

                  // Mô tả
                  Text(
                    'Vui lòng kiểm tra kết nối internet\nvà thử lại',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.medium),
                      color: AppTheme.getTextSecondaryColor(context),
                      height: 1.5,
                    ),
                  ),

                  SizedBox(
                    height: AppSizes.padding(context, SizeCategory.xlarge),
                  ),

                  // Nút thử lại
                  Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: ElevatedButton.icon(
                      onPressed: onRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.padding(
                            context,
                            SizeCategory.xlarge,
                          ),
                          vertical: AppSizes.padding(
                            context,
                            SizeCategory.large,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radius(context, SizeCategory.medium),
                          ),
                        ),
                        elevation: 4,
                      ),
                      icon: Icon(
                        Icons.refresh_rounded,
                        size: AppSizes.icon(context, SizeCategory.large),
                      ),
                      label: Text(
                        'Thử lại',
                        style: TextStyle(
                          fontSize: AppSizes.font(context, SizeCategory.large),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(
                    height: AppSizes.padding(context, SizeCategory.large),
                  ),

                  // Tips
                  Container(
                    constraints: const BoxConstraints(maxWidth: 350),
                    padding: EdgeInsets.all(
                      AppSizes.padding(context, SizeCategory.large),
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.getSurfaceColor(context).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(
                        AppSizes.radius(context, SizeCategory.medium),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              size: AppSizes.icon(context, SizeCategory.medium),
                              color: AppColors.warning,
                            ),
                            SizedBox(
                              width: AppSizes.padding(
                                context,
                                SizeCategory.small,
                              ),
                            ),
                            Text(
                              'Gợi ý:',
                              style: TextStyle(
                                fontSize: AppSizes.font(
                                  context,
                                  SizeCategory.medium,
                                ),
                                fontWeight: FontWeight.bold,
                                color: AppTheme.getTextPrimaryColor(context),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: AppSizes.padding(context, SizeCategory.small),
                        ),
                        _buildTip(
                          context,
                          '• Kiểm tra WiFi hoặc dữ liệu di động',
                        ),
                        _buildTip(context, '• Bật lại chế độ máy bay'),
                        _buildTip(context, '• Khởi động lại thiết bị'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTip(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: AppSizes.padding(context, SizeCategory.small),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: AppSizes.font(context, SizeCategory.small),
          color: AppTheme.getTextSecondaryColor(context),
        ),
      ),
    );
  }
}
