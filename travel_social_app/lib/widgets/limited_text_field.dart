import 'package:flutter/material.dart';
import 'package:travel_social_app/utils/constants.dart';

/// TextField với tính năng:
/// - Giới hạn ký tự tùy chỉnh
/// - Hint text động (edit/reply/normal)
/// - Border tùy chỉnh
/// - Multi-line support
/// Dùng cho: Comments, Reviews
class LimitedTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final int maxLength;
  final String? hintText;
  final bool enabled;
  final int? maxLines;
  final TextInputAction? textInputAction;
  final bool showCounter;

  const LimitedTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.maxLength = 100,
    this.hintText,
    this.enabled = true,
    this.maxLines,
    this.textInputAction,
    this.showCounter = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      maxLength: maxLength,
      maxLines: maxLines,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        hintText: hintText ?? 'Nhập nội dung...',
        hintStyle: TextStyle(fontSize: 14, color: Colors.grey[500]),
        counterText: showCounter ? null : '', // Ẩn counter nếu không cần
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.primaryGreen),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
