import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import '../../../../services/place_service.dart';
import '../../../../services/activity_tracking_service.dart';
import '../../../../utils/constants.dart';

/// Widget thanh tìm kiếm địa điểm với autocomplete
class PlaceSearchBar extends StatefulWidget {
  final Function(Map<String, dynamic>) onPlaceSelected;

  const PlaceSearchBar({super.key, required this.onPlaceSelected});

  @override
  State<PlaceSearchBar> createState() => _PlaceSearchBarState();
}

class _PlaceSearchBarState extends State<PlaceSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  final PlaceService _placeService = PlaceService();
  final ActivityTrackingService _activityService = ActivityTrackingService();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _predictions = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Tìm kiếm với debounce
  void _onSearchChanged(String query) {
    debugPrint('🔍 Search query: "$query"'); // Debug log

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() {
          _predictions = [];
          _isSearching = false;
        });
        return;
      }

      debugPrint('📡 Calling Google Places API...'); // Debug log

      setState(() {
        _isSearching = true;
      });

      final predictions = await _placeService.searchPlacesAutocomplete(query);

      debugPrint('📦 Received ${predictions.length} predictions'); // Debug log

      if (mounted) {
        setState(() {
          _predictions = predictions;
          _isSearching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Trên web (admin): Hiển thị tooltip thay vì search
    if (kIsWeb) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
          border: Border.all(color: Colors.blue.shade200),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Click vào bản đồ để chọn vị trí hoặc nhập tọa độ bên dưới',
                style: TextStyle(
                  color: Colors.blue.shade900,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Trên mobile (user): Hiển thị search bar đầy đủ
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search input
        Container(
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(
              AppSizes.radius(context, SizeCategory.medium),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            onChanged: _onSearchChanged,
            onSubmitted: (value) {
              // Khi nhấn Enter, chọn prediction đầu tiên
              if (_predictions.isNotEmpty) {
                final firstPrediction = _predictions[0];
                final mainText =
                    firstPrediction['structured_formatting']?['main_text'] ??
                    firstPrediction['description'];
                _searchController.text = mainText;
                _focusNode.unfocus();
                setState(() {
                  _predictions = [];
                });
                widget.onPlaceSelected(firstPrediction);
              }
            },
            decoration: InputDecoration(
              hintText: 'Tìm địa điểm...',
              hintStyle: TextStyle(
                color: AppTheme.getTextSecondaryColor(context),
                fontSize: AppSizes.font(context, SizeCategory.medium),
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.primaryGreen,
              ),
              suffixIcon:
                  _searchController.text.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _predictions = [];
                          });
                        },
                      )
                      : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSizes.padding(context, SizeCategory.medium),
                vertical: AppSizes.padding(context, SizeCategory.medium),
              ),
            ),
          ),
        ),

        // Predictions dropdown
        if (_predictions.isNotEmpty || _isSearching)
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: AppTheme.getSurfaceColor(context),
                borderRadius: BorderRadius.circular(
                  AppSizes.radius(context, SizeCategory.medium),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child:
                  _isSearching
                      ? Padding(
                        padding: EdgeInsets.all(
                          AppSizes.padding(context, SizeCategory.medium),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      )
                      : ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.symmetric(
                          vertical: AppSizes.padding(
                            context,
                            SizeCategory.small,
                          ),
                        ),
                        itemCount: _predictions.length,
                        separatorBuilder:
                            (context, index) => Divider(
                              height: 1,
                              color: AppTheme.getBorderColor(context),
                            ),
                        itemBuilder: (context, index) {
                          final prediction = _predictions[index];
                          final isFromDatabase =
                              prediction['isFromDatabase'] == true;
                          final description = prediction['description'] ?? '';
                          final mainText =
                              prediction['structured_formatting']?['main_text'] ??
                              description;
                          final secondaryText =
                              prediction['structured_formatting']?['secondary_text'] ??
                              '';

                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    isFromDatabase
                                        ? AppColors.primaryGreen.withOpacity(
                                          0.1,
                                        )
                                        : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isFromDatabase
                                    ? Icons.bookmark
                                    : Icons.location_on,
                                color:
                                    isFromDatabase
                                        ? AppColors.primaryGreen
                                        : Colors.grey,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              mainText,
                              style: TextStyle(
                                fontSize: AppSizes.font(
                                  context,
                                  SizeCategory.medium,
                                ),
                                fontWeight: FontWeight.w600,
                                color: AppTheme.getTextPrimaryColor(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle:
                                secondaryText.isNotEmpty
                                    ? Row(
                                      children: [
                                        if (isFromDatabase) ...[
                                          Icon(
                                            Icons.verified,
                                            size: 12,
                                            color: AppColors.primaryGreen,
                                          ),
                                          SizedBox(width: 4),
                                        ],
                                        Expanded(
                                          child: Text(
                                            secondaryText,
                                            style: TextStyle(
                                              fontSize: AppSizes.font(
                                                context,
                                                SizeCategory.small,
                                              ),
                                              color:
                                                  AppTheme.getTextSecondaryColor(
                                                    context,
                                                  ),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    )
                                    : null,
                            trailing:
                                isFromDatabase
                                    ? Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryGreen,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Đã lưu',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                    : null,
                            onTap: () {
                              _searchController.text = mainText;
                              _focusNode.unfocus();
                              setState(() {
                                _predictions = [];
                              });

                              // Track search activity
                              _activityService.trackSearchPlace(
                                searchQuery: _searchController.text,
                                placeId: prediction['place_id'],
                              );

                              widget.onPlaceSelected(prediction);
                            },
                          );
                        },
                      ),
            ),
          ),
      ],
    );
  }
}
