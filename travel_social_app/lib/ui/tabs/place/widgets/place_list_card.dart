import 'package:flutter/material.dart';
import '../../../../models/place.dart';
import '../../../../models/tourism_type.dart';
import '../../../../utils/constants.dart';

/// Card hiển thị thông tin địa điểm trong danh sách filter
class PlaceListCard extends StatelessWidget {
  final Place place;
  final TourismType? tourismType;
  final VoidCallback onTap;

  const PlaceListCard({
    super.key,
    required this.place,
    this.tourismType,
    required this.onTap,
  });

  Map<String, dynamic> _getStyleForType(String typeName) {
    final key = typeName.toLowerCase();
    final Map<String, Map<String, dynamic>> typeStyles = {
      'beach': {'emoji': '🏖️', 'color': const Color(0xFF4FC3F7)},
      'mountain': {'emoji': '⛰️', 'color': const Color(0xFF81C784)},
      'history': {'emoji': '🏛️', 'color': const Color(0xFFFFB74D)},
      'food': {'emoji': '🍜', 'color': const Color(0xFFE57373)},
      'shopping': {'emoji': '🛍️', 'color': const Color(0xFFBA68C8)},
      'entertainment': {'emoji': '🎡', 'color': const Color(0xFFFF8A65)},
      'nature': {'emoji': '🌳', 'color': const Color(0xFF66BB6A)},
      'default': {'emoji': '🗺️', 'color': AppColors.primaryGreen},
    };

    if (key.contains('biển') || key.contains('beach')) {
      return typeStyles['beach']!;
    } else if (key.contains('núi') || key.contains('mountain')) {
      return typeStyles['mountain']!;
    } else if (key.contains('lịch sử') || key.contains('history')) {
      return typeStyles['history']!;
    } else if (key.contains('ẩm thực') || key.contains('food')) {
      return typeStyles['food']!;
    } else if (key.contains('mua sắm') || key.contains('shopping')) {
      return typeStyles['shopping']!;
    } else if (key.contains('giải trí') || key.contains('entertainment')) {
      return typeStyles['entertainment']!;
    } else if (key.contains('thiên nhiên') || key.contains('nature')) {
      return typeStyles['nature']!;
    }
    return typeStyles['default']!;
  }

  @override
  Widget build(BuildContext context) {
    final style =
        tourismType != null
            ? _getStyleForType(tourismType?.name ?? '')
            : {'emoji': '🗺️', 'color': AppColors.primaryGreen};

    return Card(
      margin: EdgeInsets.only(
        bottom: AppSizes.padding(context, SizeCategory.small),
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
        child: Padding(
          padding: EdgeInsets.all(
            AppSizes.padding(context, SizeCategory.small),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Place Image or Tourism Type Icon
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: (style['color'] as Color).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(
                    AppSizes.radius(context, SizeCategory.medium),
                  ),
                ),
                child:
                    place.images != null && place.images!.isNotEmpty
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radius(context, SizeCategory.medium),
                          ),
                          child: Image.network(
                            place.images!.first,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  style['emoji'],
                                  style: const TextStyle(fontSize: 24),
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                          : null,
                                  strokeWidth: 2,
                                  color: AppColors.primaryGreen,
                                ),
                              );
                            },
                          ),
                        )
                        : Center(
                          child: Text(
                            style['emoji'],
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
              ),
              SizedBox(width: AppSizes.padding(context, SizeCategory.small)),

              // Place Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Place Name
                    Text(
                      place.name,
                      style: TextStyle(
                        fontSize: AppSizes.font(context, SizeCategory.small),
                        fontWeight: FontWeight.bold,
                        color: AppTheme.getTextPrimaryColor(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),

                    // Tourism Type Badge
                    if (tourismType != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (style['color'] as Color).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tourismType?.name ?? 'Khác',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: style['color'] as Color,
                          ),
                        ),
                      ),
                    SizedBox(height: 4),

                    // Address
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: AppColors.darkTextSecondary,
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            place.address ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.getTextSecondaryColor(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Rating
                    if (place.rating != null) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, size: 12, color: Colors.amber),
                          SizedBox(width: 4),
                          Text(
                            place.rating!.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.getTextPrimaryColor(context),
                            ),
                          ),
                          if (place.reviewCount != null)
                            Text(
                              ' (${place.reviewCount})',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.darkTextSecondary,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow Icon
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
