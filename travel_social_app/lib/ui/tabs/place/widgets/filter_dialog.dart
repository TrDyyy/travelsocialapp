import 'package:flutter/material.dart';
import '../../../../models/tourism_type.dart';
import '../../../../utils/constants.dart';

/// Dialog chọn loại hình du lịch để filter
class FilterDialog extends StatefulWidget {
  final List<TourismType> allTypes;
  final Set<String> selectedTypeIds;

  const FilterDialog({
    super.key,
    required this.allTypes,
    required this.selectedTypeIds,
  });

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  late Set<String> _tempSelectedIds;

  @override
  void initState() {
    super.initState();
    _tempSelectedIds = Set.from(widget.selectedTypeIds);
  }

  Map<String, dynamic> _getStyleForType(String typeName) {
    final key = typeName.toLowerCase();
    final Map<String, Map<String, dynamic>> typeStyles = {
      // Ẩm thực
      'food': {'icon': Icons.restaurant, 'color': const Color(0xFFE57373)},
      // Mua sắm
      'shopping': {
        'icon': Icons.shopping_bag,
        'color': const Color(0xFFBA68C8),
      },
      // Cặp đôi - Trăng mật
      'honeymoon': {'icon': Icons.favorite, 'color': const Color(0xFFFF80AB)},
      // Nông nghiệp
      'agriculture': {
        'icon': Icons.agriculture,
        'color': const Color(0xFFDCE775),
      },
      // Sông nước
      'river': {'icon': Icons.water, 'color': const Color(0xFF4DD0E1)},
      // Khám phá - mạo hiểm
      'adventure': {'icon': Icons.explore, 'color': const Color(0xFFFF9800)},
      // Nghỉ dưỡng
      'resort': {'icon': Icons.spa, 'color': const Color(0xFF4FC3F7)},
      // Nghệ thuật - sáng tạo
      'art': {'icon': Icons.palette, 'color': const Color(0xFFAB47BC)},
      // Lễ hội - sự kiện
      'festival': {'icon': Icons.festival, 'color': const Color(0xFFFFA726)},
      // Thể thao
      'sport': {'icon': Icons.sports_soccer, 'color': const Color(0xFF66BB6A)},
      // Thành phố
      'city': {'icon': Icons.location_city, 'color': const Color(0xFF78909C)},
      // Văn hóa
      'culture': {
        'icon': Icons.account_balance,
        'color': const Color(0xFFFFB74D),
      },
      // Gia đình
      'family': {
        'icon': Icons.family_restroom,
        'color': const Color(0xFF81C784),
      },
      // Sinh thái
      'ecology': {'icon': Icons.eco, 'color': const Color(0xFF66BB6A)},
      // Tâm linh
      'spiritual': {
        'icon': Icons.self_improvement,
        'color': const Color(0xFFFFD54F),
      },
      // Giải trí
      'entertainment': {
        'icon': Icons.celebration,
        'color': const Color(0xFFFF8A65),
      },
      // Lịch sử
      'history': {'icon': Icons.museum, 'color': const Color(0xFF8D6E63)},
      // Bụi - Phượt
      'backpacking': {'icon': Icons.backpack, 'color': const Color(0xFF7E57C2)},
      // Biển - Đảo
      'beach': {'icon': Icons.beach_access, 'color': const Color(0xFF29B6F6)},
      // Giáo dục
      'education': {'icon': Icons.school, 'color': const Color(0xFF5C6BC0)},
      'default': {'icon': Icons.place, 'color': AppColors.primaryGreen},
    };

    if (key.contains('ẩm thực') || key.contains('food')) {
      return typeStyles['food']!;
    } else if (key.contains('mua sắm') || key.contains('shopping')) {
      return typeStyles['shopping']!;
    } else if (key.contains('cặp đôi') ||
        key.contains('trăng mật') ||
        key.contains('honeymoon')) {
      return typeStyles['honeymoon']!;
    } else if (key.contains('nông nghiệp') || key.contains('agriculture')) {
      return typeStyles['agriculture']!;
    } else if (key.contains('sông') ||
        key.contains('nước') ||
        key.contains('river')) {
      return typeStyles['river']!;
    } else if (key.contains('khám phá') ||
        key.contains('mạo hiểm') ||
        key.contains('adventure')) {
      return typeStyles['adventure']!;
    } else if (key.contains('nghỉ dưỡng') || key.contains('resort')) {
      return typeStyles['resort']!;
    } else if (key.contains('nghệ thuật') ||
        key.contains('sáng tạo') ||
        key.contains('art')) {
      return typeStyles['art']!;
    } else if (key.contains('lễ hội') ||
        key.contains('sự kiện') ||
        key.contains('festival')) {
      return typeStyles['festival']!;
    } else if (key.contains('thể thao') || key.contains('sport')) {
      return typeStyles['sport']!;
    } else if (key.contains('thành phố') || key.contains('city')) {
      return typeStyles['city']!;
    } else if (key.contains('văn hóa') || key.contains('culture')) {
      return typeStyles['culture']!;
    } else if (key.contains('gia đình') || key.contains('family')) {
      return typeStyles['family']!;
    } else if (key.contains('sinh thái') || key.contains('ecology')) {
      return typeStyles['ecology']!;
    } else if (key.contains('tâm linh') || key.contains('spiritual')) {
      return typeStyles['spiritual']!;
    } else if (key.contains('giải trí') || key.contains('entertainment')) {
      return typeStyles['entertainment']!;
    } else if (key.contains('lịch sử') || key.contains('history')) {
      return typeStyles['history']!;
    } else if (key.contains('bụi') ||
        key.contains('phượt') ||
        key.contains('backpack')) {
      return typeStyles['backpacking']!;
    } else if (key.contains('biển') ||
        key.contains('đảo') ||
        key.contains('beach')) {
      return typeStyles['beach']!;
    } else if (key.contains('giáo dục') || key.contains('education')) {
      return typeStyles['education']!;
    }
    return typeStyles['default']!;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.large),
        ),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.filter_list,
                  color: AppColors.primaryGreen,
                  size: AppSizes.icon(context, SizeCategory.large),
                ),
                SizedBox(width: AppSizes.padding(context, SizeCategory.small)),
                Expanded(
                  child: Text(
                    'Chọn loại hình du lịch',
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.large),
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getTextPrimaryColor(context),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: AppTheme.getTextSecondaryColor(context),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            Divider(color: AppTheme.getBorderColor(context)),
            SizedBox(height: AppSizes.padding(context, SizeCategory.small)),

            // Quick actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _tempSelectedIds = Set.from(
                          widget.allTypes.map((t) => t.typeId),
                        );
                      });
                    },
                    icon: const Icon(Icons.select_all, size: 18),
                    label: const Text('Chọn tất cả'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: BorderSide(color: AppColors.primaryGreen),
                      padding: EdgeInsets.symmetric(
                        vertical: AppSizes.padding(context, SizeCategory.small),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppSizes.padding(context, SizeCategory.small)),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _tempSelectedIds.clear();
                      });
                    },
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Bỏ tất cả'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.getTextSecondaryColor(context),
                      side: BorderSide(color: AppTheme.getBorderColor(context)),
                      padding: EdgeInsets.symmetric(
                        vertical: AppSizes.padding(context, SizeCategory.small),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSizes.padding(context, SizeCategory.small)),

            // Grid of tourism types
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: widget.allTypes.length,
                itemBuilder: (context, index) {
                  final type = widget.allTypes[index];
                  final style = _getStyleForType(type.name);
                  final isSelected = _tempSelectedIds.contains(type.typeId);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _tempSelectedIds.remove(type.typeId);
                        } else {
                          _tempSelectedIds.add(type.typeId);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(
                      AppSizes.radius(context, SizeCategory.medium),
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? (style['color'] as Color).withOpacity(0.15)
                                : AppTheme.getSurfaceColor(context),
                        borderRadius: BorderRadius.circular(
                          AppSizes.radius(context, SizeCategory.medium),
                        ),
                        border: Border.all(
                          color:
                              isSelected
                                  ? style['color'] as Color
                                  : AppTheme.getBorderColor(context),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon instead of emoji
                          Container(
                            padding: EdgeInsets.all(
                              AppSizes.padding(context, SizeCategory.small),
                            ),
                            decoration: BoxDecoration(
                              color: (style['color'] as Color).withOpacity(
                                0.15,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              style['icon'] as IconData,
                              size: 32,
                              color: style['color'] as Color,
                            ),
                          ),
                          SizedBox(
                            height: AppSizes.padding(
                              context,
                              SizeCategory.small,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              type.name,
                              style: TextStyle(
                                fontSize: AppSizes.font(
                                  context,
                                  SizeCategory.small,
                                ),
                                fontWeight:
                                    isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                color:
                                    isSelected
                                        ? style['color'] as Color
                                        : AppTheme.getTextPrimaryColor(context),
                                shadows:
                                    isSelected
                                        ? [
                                          Shadow(
                                            offset: const Offset(0, 1),
                                            blurRadius: 3,
                                            color: (style['color'] as Color)
                                                .withOpacity(0.5),
                                          ),
                                          Shadow(
                                            offset: const Offset(0, 0.5),
                                            blurRadius: 1,
                                            color: Colors.black.withOpacity(
                                              0.3,
                                            ),
                                          ),
                                        ]
                                        : null,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: style['color'] as Color,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.getTextSecondaryColor(context),
                      side: BorderSide(color: AppTheme.getBorderColor(context)),
                      padding: EdgeInsets.symmetric(
                        vertical: AppSizes.padding(
                          context,
                          SizeCategory.medium,
                        ),
                      ),
                    ),
                    child: Text(
                      'Hủy',
                      style: TextStyle(
                        fontSize: AppSizes.font(context, SizeCategory.small),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppSizes.padding(context, SizeCategory.small)),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, _tempSelectedIds);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: AppSizes.padding(
                          context,
                          SizeCategory.medium,
                        ),
                      ),
                    ),
                    child: Text(
                      _tempSelectedIds.isEmpty
                          ? 'Xóa bộ lọc'
                          : 'Áp dụng (${_tempSelectedIds.length})',
                      style: TextStyle(
                        fontSize: AppSizes.font(context, SizeCategory.small),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
