import 'package:flutter/material.dart';
import '../../../../models/place.dart';
import '../../../../models/tourism_type.dart';
import '../../../../utils/constants.dart';
import 'place_list_card.dart';

/// Sidebar hiển thị danh sách địa điểm đã filter
class FilteredPlacesSidebar extends StatelessWidget {
  final List<Place> filteredPlaces;
  final List<TourismType> allTypes;
  final Function(String placeId) onPlaceSelected;
  final VoidCallback onClose;
  final VoidCallback onClearFilter;
  final bool isLoading;

  const FilteredPlacesSidebar({
    super.key,
    required this.filteredPlaces,
    required this.allTypes,
    required this.onPlaceSelected,
    required this.onClose,
    required this.onClearFilter,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth * 0.85; // 85% màn hình

    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(
                AppSizes.padding(context, SizeCategory.medium),
              ),
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
              child: Row(
                children: [
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  SizedBox(
                    width: AppSizes.padding(context, SizeCategory.small),
                  ),
                  Expanded(
                    child: Text(
                      'Kết quả lọc (${filteredPlaces.length})',
                      style: TextStyle(
                        fontSize: AppSizes.font(context, SizeCategory.medium),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onClearFilter,
                    icon: const Icon(
                      Icons.filter_alt_off,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Xóa',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // List of filtered places
            Expanded(
              child:
                  isLoading
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: AppColors.primaryGreen,
                              strokeWidth: 3,
                            ),
                            SizedBox(
                              height: AppSizes.padding(
                                context,
                                SizeCategory.medium,
                              ),
                            ),
                            Text(
                              'Đang tải địa điểm...',
                              style: TextStyle(
                                fontSize: AppSizes.font(
                                  context,
                                  SizeCategory.small,
                                ),
                                color: AppTheme.getTextSecondaryColor(context),
                              ),
                            ),
                          ],
                        ),
                      )
                      : filteredPlaces.isEmpty
                      ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(
                            AppSizes.padding(context, SizeCategory.large),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.explore_off,
                                size: 64,
                                color: AppTheme.getTextSecondaryColor(
                                  context,
                                ).withOpacity(0.5),
                              ),
                              SizedBox(
                                height: AppSizes.padding(
                                  context,
                                  SizeCategory.medium,
                                ),
                              ),
                              Text(
                                'Không tìm thấy địa điểm',
                                style: TextStyle(
                                  fontSize: AppSizes.font(
                                    context,
                                    SizeCategory.medium,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.getTextPrimaryColor(context),
                                ),
                              ),
                              SizedBox(
                                height: AppSizes.padding(
                                  context,
                                  SizeCategory.small,
                                ),
                              ),
                              Text(
                                'Thử chọn loại hình khác',
                                style: TextStyle(
                                  fontSize: AppSizes.font(
                                    context,
                                    SizeCategory.small,
                                  ),
                                  color: AppTheme.getTextSecondaryColor(
                                    context,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      : ListView.builder(
                        padding: EdgeInsets.all(
                          AppSizes.padding(context, SizeCategory.medium),
                        ),
                        itemCount: filteredPlaces.length,
                        itemBuilder: (context, index) {
                          final place = filteredPlaces[index];
                          final tourismType = allTypes.firstWhere(
                            (t) => t.typeId == place.typeId,
                            orElse:
                                () => TourismType(
                                  typeId: 'default',
                                  name: 'Địa điểm',
                                  description: '',
                                ),
                          );

                          return PlaceListCard(
                            place: place,
                            tourismType: tourismType,
                            onTap: () => onPlaceSelected(place.placeId ?? ''),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
