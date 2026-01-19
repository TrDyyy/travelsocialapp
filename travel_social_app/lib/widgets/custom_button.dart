import 'package:flutter/material.dart';
import '../utils/constants.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return SizedBox(
        width: width,
        height: height,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            padding:
                padding ??
                EdgeInsets.symmetric(
                  vertical: AppSizes.padding(context, SizeCategory.large),
                  horizontal: AppSizes.padding(context, SizeCategory.xlarge),
                ),
            side: BorderSide(
              color: backgroundColor ?? AppColors.primaryGreen,
              width: 2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                AppSizes.radius(context, SizeCategory.medium),
              ),
            ),
          ),
          child: _buildChild(context),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primaryGreen,
          foregroundColor: textColor ?? Colors.white,
          padding:
              padding ??
              EdgeInsets.symmetric(
                vertical: AppSizes.padding(context, SizeCategory.large),
                horizontal: AppSizes.padding(context, SizeCategory.xlarge),
              ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppSizes.radius(context, SizeCategory.medium),
            ),
          ),
          elevation: 4,
        ),
        child: _buildChild(context),
      ),
    );
  }

  Widget _buildChild(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        height: AppSizes.icon(context, SizeCategory.medium),
        width: AppSizes.icon(context, SizeCategory.medium),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            isOutlined
                ? (backgroundColor ?? AppColors.primaryGreen)
                : (textColor ?? Colors.white),
          ),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: AppSizes.icon(context, SizeCategory.medium)),
          SizedBox(width: AppSizes.padding(context, SizeCategory.small)),
          Text(
            text,
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.medium),
              fontWeight: FontWeight.w600,
              color:
                  isOutlined
                      ? (textColor ?? AppColors.primaryGreen)
                      : (textColor ?? Colors.white),
            ),
          ),
        ],
      );
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: AppSizes.font(context, SizeCategory.medium),
        fontWeight: FontWeight.w600,
        color:
            isOutlined
                ? (textColor ?? AppColors.primaryGreen)
                : (textColor ?? Colors.white),
      ),
    );
  }
}

/// Icon button cho social login
class SocialButton extends StatelessWidget {
  final String iconPath;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Widget? icon;

  const SocialButton({
    super.key,
    this.iconPath = '',
    this.onPressed,
    this.backgroundColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(24),
          border:
              backgroundColor == null
                  ? Border.all(color: AppTheme.getBorderColor(context))
                  : null,
        ),
        child:
            icon ?? Center(child: Image.asset(iconPath, width: 24, height: 24)),
      ),
    );
  }
}
