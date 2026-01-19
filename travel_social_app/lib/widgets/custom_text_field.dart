import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Custom text field với design đồng nhất theo Figma
class CustomTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final VoidCallback? onSuffixIconTap;
  final bool enabled;
  final int? maxLines;
  final FocusNode? focusNode;

  const CustomTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.onSuffixIconTap,
    this.enabled = true,
    this.maxLines = 1,
    this.focusNode,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscureText,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      onChanged: widget.onChanged,
      enabled: widget.enabled,
      maxLines: widget.maxLines,
      focusNode: widget.focusNode,
      style: TextStyle(
        color: AppTheme.getTextPrimaryColor(context),
        fontSize: AppSizes.font(context, SizeCategory.medium),
      ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        labelText: widget.labelText,
        hintStyle: TextStyle(color: AppTheme.getTextSecondaryColor(context)),
        labelStyle: TextStyle(color: AppTheme.getTextSecondaryColor(context)),
        prefixIcon:
            widget.prefixIcon != null
                ? Icon(
                  widget.prefixIcon,
                  color: AppTheme.getIconSecondaryColor(context),
                  size: AppSizes.icon(context, SizeCategory.medium),
                )
                : null,
        suffixIcon:
            widget.obscureText
                ? IconButton(
                  icon: Icon(
                    _obscureText
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppTheme.getIconSecondaryColor(context),
                    size: AppSizes.icon(context, SizeCategory.medium),
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                )
                : widget.suffixIcon != null
                ? IconButton(
                  icon: Icon(
                    widget.suffixIcon,
                    color: AppTheme.getIconSecondaryColor(context),
                    size: AppSizes.icon(context, SizeCategory.medium),
                  ),
                  onPressed: widget.onSuffixIconTap,
                )
                : null,
        filled: true,
        fillColor: AppTheme.getInputBackgroundColor(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
          borderSide: BorderSide(color: AppTheme.getInputBorderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
          borderSide: BorderSide(color: AppTheme.getInputBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSizes.padding(context, SizeCategory.large),
          vertical: AppSizes.padding(context, SizeCategory.large),
        ),
      ),
    );
  }
}
