import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/location_service.dart';
import '../../../services/place_service.dart';
import '../../../services/user_preferences_service.dart';
import '../../../services/tourism_type_service.dart';
import '../../../models/place.dart';
import '../../../models/tourism_type.dart';
import '../../../utils/constants.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/place_detail_sheet.dart';
import 'widgets/filter_dialog.dart';
import 'widgets/filtered_places_sidebar.dart';
import 'register_place_screen.dart';
import '../../smart_recommendation/smart_recommendations_screen.dart';
import '../../onboarding/tourism_onboarding_screen.dart';

/// Màn hình tìm kiếm và hiển thị địa điểm trên bản đồ
class PlaceScreen extends StatefulWidget {
  const PlaceScreen({super.key});

  @override
  State<PlaceScreen> createState() => PlaceScreenState();
}

class PlaceScreenState extends State<PlaceScreen>
    with AutomaticKeepAliveClientMixin {
  final LocationService _locationService = LocationService();
  final PlaceService _placeService = PlaceService();
  final UserPreferencesService _preferencesService = UserPreferencesService();
  final TourismTypeService _tourismTypeService = TourismTypeService();

  GoogleMapController? _mapController;
  Position? _currentPosition;
  LatLng _initialPosition = const LatLng(10.762622, 106.660172); // HCM mặc định
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {}; // Thêm polylines cho chỉ đường
  bool _isLoading = true;
  bool _isInitialized = false; // Thêm flag để track initialization

  // Bottom sheet state
  Map<String, dynamic>? _selectedPlaceDetails;
  Place? _selectedExistingPlace;
  bool _showBottomSheet = false;

  // Onboarding state
  bool _isCheckingOnboarding = true;

  // Filter state
  List<TourismType> _allTypes = [];
  Set<String> _selectedTypeIds = {};
  List<Place> _filteredPlaces = [];
  bool _showSidebar = false;
  bool _isLoadingPlaces = false;

  @override
  bool get wantKeepAlive => true; // Giữ state khi chuyển tab

  @override
  void initState() {
    super.initState();
    // Defer onboarding check until after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnboardingStatus();
    });
  }

  /// Kiểm tra xem user đã hoàn thành onboarding chưa
  Future<void> _checkOnboardingStatus() async {
    // Luôn hiển thị onboarding screen trước
    if (mounted) {
      setState(() {
        _isCheckingOnboarding = false;
      });
      _showOnboarding();
    }
  }

  /// Hiển thị màn hình onboarding
  Future<void> _showOnboarding() async {
    print('🎯 Showing onboarding...');
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const TourismOnboardingScreen(),
        fullscreenDialog: true,
      ),
    );

    print('✅ Onboarding completed, result: $result');

    if (!mounted) return;

    // Init map nếu chưa init (chỉ lần đầu)
    if (!_isInitialized) {
      print('📍 Initializing map...');
      await _initializeMap();
    }

    // Nếu user bỏ qua (result == false), reset bộ lọc
    if (result == false) {
      print('⏭️ User skipped onboarding, clearing filter...');
      if (mounted) {
        setState(() {
          _selectedTypeIds.clear();
          _filteredPlaces.clear();
          _showSidebar = false;
        });
      }
      return;
    }

    // Tự động load favorite types làm filter (luôn load lại khi user hoàn thành onboarding)
    try {
      print('🔍 Loading favorite types...');
      final profile = await _preferencesService.getOrCreateProfile();
      print('📋 Profile favoriteTypes: ${profile.favoriteTypes}');

      if (profile.favoriteTypes.isNotEmpty && mounted) {
        setState(() {
          _selectedTypeIds = Set.from(profile.favoriteTypes);
        });
        print('✨ Selected type IDs: $_selectedTypeIds');

        // Load filtered places ngay
        print('🏖️ Loading filtered places...');
        await _loadFilteredPlaces();
        print('✅ Filtered places loaded: ${_filteredPlaces.length} places');
      } else {
        print('⚠️ No favorite types found');
        // Nếu không có favorite types, clear filter
        if (mounted) {
          setState(() {
            _selectedTypeIds.clear();
            _filteredPlaces.clear();
            _showSidebar = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading favorite types: $e');
    }
  }

  /// Khởi tạo bản đồ với vị trí hiện tại
  Future<void> _initializeMap() async {
    if (_isInitialized) return; // Đã init rồi thì return

    _isInitialized = true; // Đánh dấu đã init

    print('🔄 Loading fresh data...');

    try {
      // Load tourism types
      await _loadTourismTypes();

      // Yêu cầu quyền và lấy vị trí
      final hasPermission = await _locationService.requestLocationPermission();
      if (hasPermission) {
        final position = await _locationService.getCurrentLocation();
        if (position != null) {
          setState(() {
            _currentPosition = position;
            _initialPosition = LatLng(position.latitude, position.longitude);
          });
        }
      }
    } catch (e) {
      print('Error initializing map: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Load danh sách tourism types từ Firestore
  Future<void> _loadTourismTypes() async {
    try {
      final types = await _tourismTypeService.getTourismTypes();
      if (mounted) {
        setState(() {
          _allTypes = types;
        });
      }
    } catch (e) {
      print('Error loading tourism types: $e');
    }
  }

  /// Mở FilterDialog và xử lý kết quả
  Future<void> _openFilterDialog() async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder:
          (context) => FilterDialog(
            allTypes: _allTypes,
            selectedTypeIds: Set.from(
              _selectedTypeIds,
            ), // Pass copy, not reference
          ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedTypeIds = result;
      });
      // Load filtered places
      await _loadFilteredPlaces();
    }
  }

  /// Load places theo filter
  Future<void> _loadFilteredPlaces() async {
    print('🎯 _loadFilteredPlaces called with typeIds: $_selectedTypeIds');

    if (_selectedTypeIds.isEmpty) {
      print('⚠️ No type IDs selected, clearing filter');
      setState(() {
        _filteredPlaces = [];
        _showSidebar = false;
      });
      return;
    }

    print('🔄 Setting loading state and showing sidebar');
    setState(() {
      _isLoadingPlaces = true;
      _showSidebar = true;
    });

    try {
      // DEBUG: Check total places in database
      final allPlacesInDb = await _placeService.getAllPlaces();
      print('📊 Total places in database: ${allPlacesInDb.length}');
      if (allPlacesInDb.isNotEmpty) {
        print(
          '📊 Sample place typeIds: ${allPlacesInDb.take(5).map((p) => '${p.name}: ${p.typeId}').join(', ')}',
        );
      }

      // Load places cho từng type và gộp lại (loại bỏ trùng)
      final allPlaces = <Place>[];
      final seenPlaceIds = <String>{};

      print('📦 Loading places for ${_selectedTypeIds.length} types...');
      for (final typeId in _selectedTypeIds) {
        print('  → Loading places for typeId: $typeId');
        final places = await _placeService.getPlacesByType(typeId);
        print('    Found ${places.length} places');

        for (final place in places) {
          if (!seenPlaceIds.contains(place.placeId)) {
            allPlaces.add(place);
            seenPlaceIds.add(place.placeId!);
          }
        }
      }

      print('✅ Total unique places: ${allPlaces.length}');

      if (mounted) {
        setState(() {
          _filteredPlaces = allPlaces;
          _isLoadingPlaces = false;
        });
        print(
          '✅ State updated: _filteredPlaces=${_filteredPlaces.length}, _showSidebar=$_showSidebar',
        );
      }
    } catch (e) {
      print('❌ Error loading filtered places: $e');
      if (mounted) {
        setState(() {
          _isLoadingPlaces = false;
        });
      }
    }
  }

  /// Clear filter
  void _clearFilter() {
    setState(() {
      _selectedTypeIds.clear();
      _filteredPlaces.clear();
      _showSidebar = false;
    });
  }

  /// Public method để focus vào place từ bên ngoài
  Future<void> focusOnPlace(String placeId) async {
    try {
      // Load place từ database
      final place = await _placeService.getPlaceById(placeId);

      if (place != null && mounted) {
        // Di chuyển camera đến vị trí place
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(place.latitude, place.longitude),
            16,
          ),
        );

        // Thêm marker
        setState(() {
          _markers.clear();
          _markers.add(
            Marker(
              markerId: MarkerId(placeId),
              position: LatLng(place.latitude, place.longitude),
              infoWindow: InfoWindow(title: place.name),
            ),
          );
        });

        // Tạo placeDetails object giống như khi search
        final placeDetails = {
          'place_id': place.placeId,
          'name': place.name,
          'formatted_address': place.address ?? '',
          'geometry': {
            'location': {'lat': place.latitude, 'lng': place.longitude},
          },
          'rating': place.rating,
          'user_ratings_total': place.reviewCount,
        };

        // Hiển thị bottom sheet với đầy đủ thông tin như khi search
        setState(() {
          _selectedPlaceDetails = placeDetails;
          _selectedExistingPlace = place; // Place đã tồn tại trong DB
          _showBottomSheet = true;
        });
      } else {
        debugPrint('⚠️ Place not found: $placeId');
      }
    } catch (e) {
      debugPrint('❌ Error focusing on place: $e');
    }
  }

  /// Xử lý khi chọn địa điểm từ search
  Future<void> _onPlaceSelected(Map<String, dynamic> prediction) async {
    final placeId = prediction['place_id'];
    final isFromDatabase = prediction['isFromDatabase'] == true;

    Map<String, dynamic>? placeDetails;

    if (isFromDatabase) {
      // Nếu từ database, dùng thông tin có sẵn
      debugPrint('📦 Using place from database');
      placeDetails = {
        'place_id': placeId,
        'name':
            prediction['structured_formatting']?['main_text'] ??
            prediction['description'],
        'formatted_address':
            prediction['structured_formatting']?['secondary_text'] ?? '',
        'geometry': prediction['geometry'],
      };
    } else {
      // Nếu từ Google, lấy chi tiết từ Google Places API
      debugPrint('🌐 Fetching details from Google Places API');
      placeDetails = await _placeService.getPlaceDetails(placeId);
    }

    if (placeDetails != null && mounted) {
      final geometry = placeDetails['geometry'];
      final location = geometry['location'];
      final lat = location['lat'];
      final lng = location['lng'];
      final name = placeDetails['name'] ?? prediction['description'];

      // Di chuyển camera đến vị trí
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15),
      );

      // Thêm marker
      setState(() {
        _markers.clear();
        _markers.add(
          Marker(
            markerId: MarkerId(placeId),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(title: name),
          ),
        );
      });

      // Kiểm tra địa điểm đã tồn tại trong Firestore chưa
      // Truyền thêm googlePlaceId để tìm chính xác hơn
      Place? existingPlace;
      try {
        existingPlace = await _placeService.findPlaceByCoordinates(
          lat,
          lng,
          googlePlaceId: placeId,
        );
      } catch (e) {
        print('Error checking existing place: $e');
      }

      // Cập nhật state để hiển thị bottom sheet
      setState(() {
        _selectedPlaceDetails = placeDetails;
        _selectedExistingPlace = existingPlace;
        _showBottomSheet = true;
      });
    }
  }

  /// Hiển thị chỉ đường đến địa điểm
  Future<void> _showDirections(LatLng destination) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể lấy vị trí hiện tại'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final origin = LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    // Gọi Google Directions API để lấy đường thực
    try {
      final directions = await _placeService.getDirections(
        origin.latitude,
        origin.longitude,
        destination.latitude,
        destination.longitude,
      );

      if (directions != null && mounted) {
        final routes = directions['routes'] as List;
        if (routes.isNotEmpty) {
          final route = routes[0];
          final polylinePoints = route['overview_polyline']['points'];

          // Decode polyline sử dụng service
          final decodedPointsMap = _placeService.decodePolyline(polylinePoints);
          final decodedPoints =
              decodedPointsMap
                  .map((point) => LatLng(point['lat']!, point['lng']!))
                  .toList();

          setState(() {
            // Tạo polyline từ các điểm thực tế
            _polylines.clear();
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('direction'),
                color: AppColors.primaryGreen,
                width: 5,
                points: decodedPoints,
              ),
            );

            // Thêm marker cho vị trí hiện tại
            _markers.add(
              Marker(
                markerId: const MarkerId('current_location'),
                position: origin,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue,
                ),
                infoWindow: const InfoWindow(title: 'Vị trí của bạn'),
              ),
            );
          });

          // Zoom để hiển thị cả 2 điểm
          _mapController?.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(
                  origin.latitude < destination.latitude
                      ? origin.latitude
                      : destination.latitude,
                  origin.longitude < destination.longitude
                      ? origin.longitude
                      : destination.longitude,
                ),
                northeast: LatLng(
                  origin.latitude > destination.latitude
                      ? origin.latitude
                      : destination.latitude,
                  origin.longitude > destination.longitude
                      ? origin.longitude
                      : destination.longitude,
                ),
              ),
              100,
            ),
          );

          // Lấy thông tin khoảng cách và thời gian
          final leg = route['legs'][0];
          final distance = leg['distance']['text'];
          final duration = leg['duration']['text'];

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Khoảng cách: $distance • Thời gian: $duration'),
              backgroundColor: AppColors.primaryGreen,
              action: SnackBarAction(
                label: 'Xóa',
                textColor: Colors.white,
                onPressed: () {
                  setState(() {
                    _polylines.clear();
                    _markers.removeWhere(
                      (m) => m.markerId.value == 'current_location',
                    );
                  });
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error getting directions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể lấy chỉ đường'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Hiển thị màn hình đăng ký địa điểm mới
  Future<void> _showRegisterPlaceDialog(
    Map<String, dynamic> placeDetails,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => RegisterPlaceScreen(
              googlePlaceDetails: placeDetails,
              existingPlace: _selectedExistingPlace,
            ),
      ),
    );

    // Nếu đăng ký thành công, có thể refresh data
    if (result == true && mounted) {
      // TODO: Refresh places list nếu cần
      print('✅ Place registered successfully');
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Đang check onboarding
    if (_isCheckingOnboarding) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryGreen,
            strokeWidth: 3,
          ),
        ),
      );
    }

    // Nếu chưa init hoặc đang loading, show loading
    final shouldShowMap = _isInitialized || !_isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body:
          shouldShowMap
              ? Stack(
                children: [
                  // Google Map
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _initialPosition,
                      zoom: 14,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    markers: _markers,
                    polylines: _polylines,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                  ),

                  // Search bar overlay
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 16,
                    left: 16,
                    right: 16,
                    child: PlaceSearchBar(onPlaceSelected: _onPlaceSelected),
                  ),

                  // Back to Onboarding button (góc trái trên)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 80,
                    left: 16,
                    child: FloatingActionButton(
                      mini: true,
                      heroTag: 'onboardingBackFAB',
                      backgroundColor: Colors.white,
                      onPressed: () async {
                        // Mở lại onboarding để user chỉnh sở thích
                        await _showOnboarding();
                      },
                      child: Icon(
                        Icons.settings,
                        color: AppColors.primaryGreen,
                      ),
                      tooltip: 'Chỉnh sở thích',
                    ),
                  ),

                  // Recommendations button (top)
                  Positioned(
                    bottom: 160,
                    right: 16,
                    child: FloatingActionButton(
                      mini: true,
                      heroTag: 'recommendationsFAB',
                      backgroundColor: AppColors.primaryGreen,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => const SmartRecommendationsScreen(),
                          ),
                        );
                      },
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Filter button
                  Positioned(
                    bottom: 220,
                    right: 16,
                    child: FloatingActionButton(
                      mini: true,
                      heroTag: 'filterFAB',
                      backgroundColor:
                          _selectedTypeIds.isNotEmpty
                              ? AppColors.primaryGreen
                              : Colors.white,
                      onPressed: _openFilterDialog,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.filter_list,
                            color:
                                _selectedTypeIds.isNotEmpty
                                    ? Colors.white
                                    : AppColors.primaryGreen,
                          ),
                          if (_selectedTypeIds.isNotEmpty)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Center(
                                  child: Text(
                                    '${_selectedTypeIds.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // My location button
                  Positioned(
                    bottom: 100,
                    right: 16,
                    child: FloatingActionButton(
                      mini: true,
                      heroTag: 'myLocationFAB', // Unique hero tag
                      backgroundColor: Colors.white,
                      onPressed: () async {
                        if (_currentPosition != null) {
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(
                              LatLng(
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                              ),
                              15,
                            ),
                          );
                        }
                      },
                      child: const Icon(
                        Icons.my_location,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),

                  if (!_showBottomSheet && _selectedPlaceDetails != null)
                    Positioned(
                      bottom: 20,
                      left: 16,
                      child: FloatingActionButton.extended(
                        heroTag: 'placeDetailsFAB', // Unique hero tag
                        backgroundColor: AppColors.primaryGreen,
                        onPressed: () {
                          setState(() {
                            _showBottomSheet = true;
                          });
                        },
                        icon: const Icon(
                          Icons.info_outline,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Xem thông tin',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  if (_showBottomSheet && _selectedPlaceDetails != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: PlaceDetailSheet(
                        googlePlaceDetails: _selectedPlaceDetails!,
                        existingPlace: _selectedExistingPlace,
                        onClose: () {
                          setState(() {
                            _showBottomSheet = false;
                          });
                        },
                        onRegisterPlace: () {
                          _showRegisterPlaceDialog(_selectedPlaceDetails!);
                        },
                        onGetDirections: () {
                          if (_selectedPlaceDetails != null) {
                            final geometry = _selectedPlaceDetails!['geometry'];
                            final location = geometry['location'];
                            final lat = location['lat'];
                            final lng = location['lng'];
                            _showDirections(LatLng(lat, lng));
                          }
                        },
                      ),
                    ),

                  // Filtered places sidebar
                  if (_showSidebar)
                    FilteredPlacesSidebar(
                      filteredPlaces: _filteredPlaces,
                      allTypes: _allTypes,
                      isLoading: _isLoadingPlaces,
                      onClose: () {
                        setState(() {
                          _showSidebar = false;
                        });
                      },
                      onClearFilter: _clearFilter,
                      onPlaceSelected: (placeId) async {
                        setState(() {
                          _showSidebar = false;
                        });
                        // Focus vào place trên map
                        await focusOnPlace(placeId);
                      },
                    ),
                ],
              )
              : const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              ),
    );
  }
}
