import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/location_service.dart';
import '../../../services/place_service.dart';
import '../../../services/admin_service.dart';
import '../../../models/tourism_type.dart';
import '../../../utils/constants.dart';
import '../../tabs/place/widgets/search_bar_widget.dart';
import '../../../utils/toast_helper.dart';

/// Màn hình thêm địa điểm mới cho Admin với Map
class AddPlaceScreen extends StatefulWidget {
  const AddPlaceScreen({super.key});

  @override
  State<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends State<AddPlaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final LocationService _locationService = LocationService();
  final PlaceService _placeService = PlaceService();
  final AdminService _adminService = AdminService();
  final ImagePicker _imagePicker = ImagePicker();

  // Map controllers
  GoogleMapController? _mapController;
  Position? _currentPosition;
  LatLng _initialPosition = const LatLng(10.762622, 106.660172);
  LatLng? _selectedLocation;
  final Set<Marker> _markers = {};

  // Form data
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  String? _selectedTypeId;
  List<TourismType> _tourismTypes = [];
  final List<XFile> _selectedImages =
      []; // Dùng XFile để hỗ trợ cả web và mobile

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      // Load tourism types
      final types = await _placeService.getAllTourismTypes();

      // Get current location
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

      setState(() {
        _tourismTypes = types;
        if (types.isNotEmpty) {
          _selectedTypeId = types.first.typeId;
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Xử lý khi chọn địa điểm từ search
  Future<void> _onPlaceSelected(Map<String, dynamic> prediction) async {
    final placeId = prediction['place_id'];
    final placeDetails = await _placeService.getPlaceDetails(placeId);

    if (placeDetails != null && mounted) {
      final geometry = placeDetails['geometry'];
      final location = geometry['location'];
      final lat = location['lat'];
      final lng = location['lng'];
      final name = placeDetails['name'] ?? prediction['description'];
      final address = placeDetails['formatted_address'] ?? '';

      setState(() {
        _selectedLocation = LatLng(lat, lng);
        _nameController.text = name;
        _addressController.text = address;

        // Update marker
        _markers.clear();
        _markers.add(
          Marker(
            markerId: const MarkerId('selected_place'),
            position: _selectedLocation!,
            draggable: true,
            onDragEnd: (newPosition) {
              setState(() {
                _selectedLocation = newPosition;
              });
            },
          ),
        );
      });

      // Move camera
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation!, 15),
      );
    }
  }

  /// Xử lý khi tap trên map
  void _onMapTap(LatLng position) {
    setState(() {
      _selectedLocation = position;

      // Cập nhật TextFields
      _latController.text = position.latitude.toStringAsFixed(6);
      _lngController.text = position.longitude.toStringAsFixed(6);

      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_place'),
          position: position,
          draggable: true,
          onDragEnd: (newPosition) {
            setState(() {
              _selectedLocation = newPosition;
              _latController.text = newPosition.latitude.toStringAsFixed(6);
              _lngController.text = newPosition.longitude.toStringAsFixed(6);
            });
          },
        ),
      );
    });
  }

  /// Chọn ảnh từ thư viện
  Future<void> _pickImages() async {
    try {
      final pickedFiles = await _imagePicker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
      );

      if (pickedFiles.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(pickedFiles);
        });
      }
    } catch (e) {
      _showError('Không thể chọn ảnh: $e');
    }
  }

  /// Chụp ảnh từ camera
  Future<void> _takePhoto() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImages.add(pickedFile);
        });
      }
    } catch (e) {
      _showError('Không thể chụp ảnh: $e');
    }
  }

  /// Upload ảnh lên Firebase Storage
  Future<List<String>> _uploadImages() async {
    final List<String> imageUrls = [];
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return imageUrls;

    for (int i = 0; i < _selectedImages.length; i++) {
      try {
        final file = _selectedImages[i];
        final fileName =
            'places/${user.uid}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final ref = FirebaseStorage.instance.ref().child(fileName);

        final bytes = await file.readAsBytes();
        await ref.putData(Uint8List.fromList(bytes));
        final url = await ref.getDownloadURL();
        imageUrls.add(url);

        print('✅ Uploaded image $i: $url');
      } catch (e) {
        print('❌ Error uploading image $i: $e');
      }
    }

    return imageUrls;
  }

  /// Submit form
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLocation == null) {
      _showError('Vui lòng chọn vị trí trên bản đồ');
      return;
    }

    if (_selectedImages.isEmpty) {
      _showError('Vui lòng thêm ít nhất 1 ảnh');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Chưa đăng nhập');
      }

      // Upload images
      final imageUrls = await _uploadImages();

      if (imageUrls.isEmpty) {
        throw Exception('Không thể upload ảnh');
      }

      // Create place data
      final placeData = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'description': _descriptionController.text.trim(),
        'typeId': _selectedTypeId!,
        'location': GeoPoint(
          _selectedLocation!.latitude,
          _selectedLocation!.longitude,
        ),
        'images': imageUrls,
        'createAt': FieldValue.serverTimestamp(),
        'updateAt': FieldValue.serverTimestamp(),
        'userId': currentUser.uid,
        'status': 'active',
        'rating': 0.0,
        'reviewCount': 0,
        'viewCount': 0,
      };

      // Add to places collection
      final docId = await _adminService.addDocument('places', placeData);

      if (docId != null && mounted) {
        if (mounted)
          ToastHelper.showSuccess(context, 'Đã thêm địa điểm thành công');
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Lỗi khi thêm địa điểm: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ToastHelper.showError(context, message);
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm địa điểm mới'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Map section - hiển thị cả trên web và mobile
          SizedBox(
            height: 250,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _initialPosition,
                    zoom: 14,
                  ),
                  mapType: MapType.normal,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  markers: _markers,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  onTap: _onMapTap,
                ),

                // Search bar
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: PlaceSearchBar(onPlaceSelected: _onPlaceSelected),
                ),

                // My location button
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    mini: true,
                    heroTag: 'addPlaceMyLocationFAB', // Unique hero tag
                    backgroundColor: Colors.white,
                    onPressed: () {
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
              ],
            ),
          ),

          // Form section
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Hiển thị tọa độ đã chọn (từ map hoặc nhập thủ công)
                  if (_selectedLocation != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppColors.primaryGreen,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Vị trí: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Form nhập tọa độ thủ công (cho web hoặc nếu không chọn được từ map)
                  if (kIsWeb || _selectedLocation == null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Nhập tọa độ thủ công',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latController,
                            decoration: const InputDecoration(
                              labelText: 'Vĩ độ (Latitude) *',
                              border: OutlineInputBorder(),
                              hintText: '10.762622',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              final lat = double.tryParse(value);
                              if (lat != null && _selectedLocation != null) {
                                setState(() {
                                  _selectedLocation = LatLng(
                                    lat,
                                    _selectedLocation!.longitude,
                                  );
                                });
                              } else if (lat != null) {
                                setState(() {
                                  _selectedLocation = LatLng(lat, 106.660172);
                                });
                              }
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Vui lòng nhập vĩ độ';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Vĩ độ không hợp lệ';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lngController,
                            decoration: const InputDecoration(
                              labelText: 'Kinh độ (Longitude) *',
                              border: OutlineInputBorder(),
                              hintText: '106.660172',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              final lng = double.tryParse(value);
                              if (lng != null && _selectedLocation != null) {
                                setState(() {
                                  _selectedLocation = LatLng(
                                    _selectedLocation!.latitude,
                                    lng,
                                  );
                                });
                              } else if (lng != null) {
                                setState(() {
                                  _selectedLocation = LatLng(10.762622, lng);
                                });
                              }
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Vui lòng nhập kinh độ';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Kinh độ không hợp lệ';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Name field
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên địa điểm *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập tên địa điểm';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Address field
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập địa chỉ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Tourism type dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedTypeId,
                    decoration: const InputDecoration(
                      labelText: 'Loại hình du lịch *',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        _tourismTypes.map((type) {
                          return DropdownMenuItem(
                            value: type.typeId,
                            child: Text(type.name),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTypeId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Vui lòng chọn loại hình';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Description field
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả *',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập mô tả';
                      }
                      if (value.trim().length < 20) {
                        return 'Mô tả phải có ít nhất 20 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Images section
                  const Text(
                    'Hình ảnh *',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Thư viện'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _takePhoto,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Chụp ảnh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Display selected images
                  if (_selectedImages.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: FutureBuilder<Uint8List>(
                                future: _selectedImages[index]
                                    .readAsBytes()
                                    .then((bytes) => Uint8List.fromList(bytes)),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Image.memory(
                                      snapshot.data!,
                                      fit: BoxFit.cover,
                                    );
                                  }
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(28, 28),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _selectedImages.removeAt(index);
                                  });
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                  if (_selectedImages.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: const Center(
                        child: Text(
                          'Chưa có ảnh nào\nNhấn nút ở trên để thêm ảnh',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Submit button
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child:
                        _isSubmitting
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text(
                              'Thêm địa điểm',
                              style: TextStyle(fontSize: 16),
                            ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
