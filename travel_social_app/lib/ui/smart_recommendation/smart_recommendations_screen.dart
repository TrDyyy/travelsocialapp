import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/place.dart';
import '../../models/tourism_type.dart';
import '../../services/recommendation_service.dart';
import '../../services/tourism_type_service.dart';
import '../../services/location_service.dart';
import '../../services/place_service.dart';
import '../../services/activity_tracking_service.dart';
import '../../utils/constants.dart';
import '../../utils/navigation_helper.dart';
import 'widgets/select_favorite_types_page.dart';
import '../tabs/place/widgets/place_detail_sheet.dart';

/// Màn hình gợi ý địa điểm thông minh
class SmartRecommendationsScreen extends StatefulWidget {
  const SmartRecommendationsScreen({super.key});

  @override
  State<SmartRecommendationsScreen> createState() =>
      _SmartRecommendationsScreenState();
}

class _SmartRecommendationsScreenState extends State<SmartRecommendationsScreen>
    with SingleTickerProviderStateMixin {
  final RecommendationService _recommendationService = RecommendationService();
  final TourismTypeService _tourismTypeService = TourismTypeService();
  final LocationService _locationService = LocationService();
  final PlaceService _placeService = PlaceService();
  final ActivityTrackingService _activityService = ActivityTrackingService();

  late TabController _tabController;
  Position? _currentPosition;
  String? _locationErrorMessage; // Thông báo lỗi về vị trí

  List<Place> _smartRecommendations = [];
  List<Place> _nearbyRecommendations = [];
  List<Place> _preferenceRecommendations = [];

  Map<String, TourismType> _tourismTypes = {};

  bool _isLoadingSmart = true;
  bool _isLoadingNearby = true;
  bool _isLoadingPreference = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Load current position với error message rõ ràng
    try {
      final result = await _locationService.getCurrentLocationWithStatus();
      if (mounted) {
        setState(() {
          _currentPosition = result.position;
          _locationErrorMessage = result.errorMessage;
        });
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
      if (mounted) {
        setState(() {
          _locationErrorMessage = 'Không thể lấy vị trí hiện tại';
        });
      }
    }

    // Load tourism types
    final types = await _tourismTypeService.getTourismTypes();
    setState(() {
      _tourismTypes = {for (var t in types) t.typeId: t};
    });

    // Load recommendations in parallel
    _loadSmartRecommendations();
    _loadNearbyRecommendations();
    _loadPreferenceRecommendations();
  }

  Future<void> _loadSmartRecommendations() async {
    setState(() => _isLoadingSmart = true);
    try {
      final recommendations = await _recommendationService
          .getSmartRecommendations(limit: 15);
      if (mounted) {
        setState(() {
          _smartRecommendations = recommendations;
          _isLoadingSmart = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSmart = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải gợi ý: $e')));
      }
    }
  }

  Future<void> _loadNearbyRecommendations() async {
    setState(() => _isLoadingNearby = true);
    try {
      final recommendations = await _recommendationService
          .getNearbyRecommendations(radiusKm: 50, limit: 15);
      if (mounted) {
        setState(() {
          _nearbyRecommendations = recommendations;
          _isLoadingNearby = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingNearby = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải địa điểm gần, vui lòng kiểm tra vị trí: $e'),
          ),
        );
      }
    }
  }

  Future<void> _loadPreferenceRecommendations() async {
    setState(() => _isLoadingPreference = true);
    try {
      final recommendations = await _recommendationService
          .getPreferenceBasedRecommendations(limit: 15);
      if (mounted) {
        setState(() {
          _preferenceRecommendations = recommendations;
          _isLoadingPreference = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPreference = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải gợi ý theo sở thích: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text(
          'Gợi ý dành cho bạn',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.auto_awesome), text: 'Thông minh'),
            Tab(icon: Icon(Icons.near_me), text: 'Gần bạn'),
            Tab(icon: Icon(Icons.favorite), text: 'Sở thích'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Smart Recommendations (KHÔNG có profile switcher)
          _buildRecommendationsList(
            _smartRecommendations,
            _isLoadingSmart,
            'Gợi ý thông minh dựa trên vị trí, hành vi và sở thích của bạn',
            Icons.auto_awesome,
            showDistance: false,
          ),

          // Tab 2: Nearby Recommendations (KHÔNG có profile switcher)
          _buildNearbyTab(),

          // Tab 3: Preference Recommendations (CÓ profile switcher)
          _buildPreferenceTab(),
        ],
      ),
    );
  }

  /// Tab Nearby với kiểm tra location error
  Widget _buildNearbyTab() {
    // Nếu có lỗi về vị trí, hiển thị thông báo
    if (_locationErrorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 24),
              Text(
                _locationErrorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Để sử dụng tính năng này, bạn cần:\n• Bật GPS trên thiết bị\n• Cấp quyền truy cập vị trí cho ứng dụng',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.getTextSecondaryColor(context),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  // Thử request lại permission
                  setState(() {
                    _locationErrorMessage = null;
                    _isLoadingNearby = true;
                  });
                  await _loadData();
                  if (_locationErrorMessage == null) {
                    _loadNearbyRecommendations();
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Nếu không có lỗi, hiển thị danh sách bình thường
    return _buildRecommendationsList(
      _nearbyRecommendations,
      _isLoadingNearby,
      'Các địa điểm du lịch gần vị trí hiện tại của bạn',
      Icons.near_me,
      showDistance: true,
    );
  }

  /// Tab Preference với nút chọn sở thích
  Widget _buildPreferenceTab() {
    return Column(
      children: [
        // Nút chọn sở thích
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            border: Border(
              bottom: BorderSide(
                color: AppTheme.getBorderColor(context),
                width: 1,
              ),
            ),
          ),
          child: ElevatedButton.icon(
            onPressed: () async {
              // Mở page chọn favorite types
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => const SelectFavoriteTypesPage(),
                ),
              );

              // Nếu có thay đổi, reload recommendations
              if (result == true && mounted) {
                _loadPreferenceRecommendations();
                _loadSmartRecommendations();
              }
            },
            icon: const Icon(Icons.favorite),
            label: const Text('Chọn sở thích của bạn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        // Danh sách recommendations
        Expanded(
          child: _buildRecommendationsList(
            _preferenceRecommendations,
            _isLoadingPreference,
            'Gợi ý dựa trên loại hình du lịch bạn yêu thích',
            Icons.favorite,
            showDistance: false,
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationsList(
    List<Place> places,
    bool isLoading,
    String description,
    IconData icon, {
    bool showDistance = false,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (places.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Chưa có gợi ý',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Hãy khám phá và đánh giá các địa điểm để nhận được gợi ý tốt hơn!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.getTextSecondaryColor(context),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: Column(
        children: [
          // Header description
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.getBorderColor(context),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primaryGreen, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    description,
                    style: TextStyle(
                      color: AppTheme.getTextSecondaryColor(context),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List of places
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: places.length,
              itemBuilder: (context, index) {
                final place = places[index];
                // Determine recommendation type based on which list we're showing
                String recommendationType = 'smart';
                if (showDistance) {
                  recommendationType = 'nearby';
                } else if (places == _preferenceRecommendations) {
                  recommendationType = 'preference';
                }
                return _buildPlaceCard(
                  place,
                  index + 1,
                  showDistance: showDistance,
                  recommendationType: recommendationType,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceCard(
    Place place,
    int rank, {
    bool showDistance = false,
    required String recommendationType,
  }) {
    final tourismType = _tourismTypes[place.typeId];
    final rating = place.rating ?? 0.0;
    final reviewCount = place.reviewCount ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Track recommendation click
          _activityService.trackClickRecommendation(
            place: place,
            recommendationType: recommendationType,
          );
          _showPlaceDetail(place);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with rank badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child:
                      place.images != null && place.images!.isNotEmpty
                          ? Image.network(
                            place.images!.first,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) =>
                                    _buildPlaceholder(),
                          )
                          : _buildPlaceholder(),
                ),
                // Rank badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '#$rank',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    place.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Tourism type
                  if (tourismType != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tourismType.name,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),

                  // Rating
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        return Icon(
                          index < rating.floor()
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
                      const SizedBox(width: 4),
                      Text(
                        '${rating.toStringAsFixed(1)} ($reviewCount)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.getTextSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Address
                  if (place.address != null)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: AppTheme.getTextSecondaryColor(context),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            place.address!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.getTextSecondaryColor(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                  // Distance chip with real driving distance
                  if (showDistance && _currentPosition != null) ...[
                    const SizedBox(height: 8),
                    FutureBuilder<Map<String, dynamic>?>(
                      future: _placeService.getRealDistance(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                        place.latitude,
                        place.longitude,
                      ),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          // Show loading or placeholder
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primaryGreen.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primaryGreen,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Đang tính...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final distanceData = snapshot.data;
                        if (distanceData == null) {
                          return const SizedBox.shrink();
                        }

                        final distanceText =
                            distanceData['distanceText'] as String;
                        final durationText =
                            distanceData['durationText'] as String;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primaryGreen.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.directions_car,
                                size: 14,
                                color: AppColors.primaryGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$distanceText • $durationText',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  // Action buttons
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showPlaceDetail(place),
                          icon: const Icon(Icons.info_outline, size: 16),
                          label: const Text('Chi tiết'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryGreen,
                            side: const BorderSide(
                              color: AppColors.primaryGreen,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 180,
      width: double.infinity,
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
      ),
    );
  }

  void _showPlaceDetail(Place place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return PlaceDetailSheet(
          googlePlaceDetails: {
            'name': place.name,
            'formatted_address': place.address,
            'geometry': {
              'location': {'lat': place.latitude, 'lng': place.longitude},
            },
          },
          existingPlace: place,
          onRegisterPlace: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Địa điểm đã có trong hệ thống')),
            );
          },
          onGetDirections: () {
            Navigator.pop(context);
            _navigateToMapForDirections(place);
          },
          onClose: () => Navigator.pop(context),
        );
      },
    );
  }

  void _navigateToMapForDirections(Place place) {
    if (place.placeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể chỉ đường đến địa điểm này'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Track get directions activity
    _activityService.trackGetDirections(place);

    // Navigate to Map tab with place ID for directions
    NavigationHelper.navigateToMapWithPlace(
      context,
      place.placeId!,
      place.name,
    );
  }
}
