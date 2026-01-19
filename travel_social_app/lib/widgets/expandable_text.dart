import 'package:flutter/material.dart';
import 'package:travel_social_app/utils/constants.dart';

/// Widget hiển thị text có thể expand/collapse
/// Hiển thị tối đa số từ cho trước, có nút "Xem thêm" và "Thu gọn"
class ExpandableText extends StatefulWidget {
  final String text;
  final int maxWords;
  final TextStyle? style;
  final TextAlign textAlign;

  const ExpandableText({
    super.key,
    required this.text,
    this.maxWords = 50,
    this.style,
    this.textAlign = TextAlign.start,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final words = widget.text.split(RegExp(r'\s+'));
    final needsExpansion = words.length > widget.maxWords;

    String displayText;
    if (!needsExpansion || _isExpanded) {
      displayText = widget.text;
    } else {
      displayText = '${words.take(widget.maxWords).join(' ')}...';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayText,
          style:
              widget.style ??
              TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.medium),
                color: AppTheme.getTextPrimaryColor(context),
              ),
          textAlign: widget.textAlign,
        ),
        if (needsExpansion) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Text(
              _isExpanded ? 'Thu gọn' : 'Xem thêm',
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.small),
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
