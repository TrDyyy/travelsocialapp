import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/place_service.dart';
import '../../../services/admin_service.dart';
import '../../../models/tourism_type.dart';
import '../../../utils/constants.dart';
import '../../../utils/toast_helper.dart';

/// Màn hình sửa địa điểm cho Admin
class EditPlaceScreen extends StatefulWidget {
  final Map<String, dynamic> place;

  const EditPlaceScreen({super.key, required this.place});

  @override
  State<EditPlaceScreen> createState() => _EditPlaceScreenState();
}

class _EditPlaceScreenState extends State<EditPlaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final PlaceService _placeService = PlaceService();
  final AdminService _adminService = AdminService();
  final ImagePicker _imagePicker = ImagePicker();

  // Map controllers
  GoogleMapController? _mapController;
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
  final List<XFile> _selectedImages = [];
  List<String> _existingImageUrls = [];

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

      // Populate form with existing data
      _nameController.text = widget.place['name'] ?? '';
      _addressController.text = widget.place['address'] ?? '';
      _descriptionController.text = widget.place['description'] ?? '';
      _selectedTypeId = widget.place['typeId'];

      // Get location from GeoPoint
      final location = widget.place['location'];
      if (location is GeoPoint) {
        _selectedLocation = LatLng(location.latitude, location.longitude);
        _initialPosition = _selectedLocation!;
        _latController.text = location.latitude.toStringAsFixed(6);
        _lngController.text = location.longitude.toStringAsFixed(6);

        // Add marker
        _markers.add(
          Marker(
            markerId: const MarkerId('selected_place'),
            position: _selectedLocation!,
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
      }

      // Get existing images
      final images = widget.place['images'] as List<dynamic>? ?? [];
      _existingImageUrls = images.map((img) => img.toString()).toList();

      setState(() {
        _tourismTypes = types;
        if (_selectedTypeId == null && types.isNotEmpty) {
          _selectedTypeId = types.first.typeId;
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Xử lý khi tap trên map
  void _onMapTap(LatLng position) {
    setState(() {
      _selectedLocation = position;

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

  /// Xóa ảnh existing
  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  /// Xóa ảnh mới chọn
  void _removeNewImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  /// Upload ảnh mới lên Firebase Storage
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLocation == null) {
      _showError('Vui lòng chọn vị trí trên bản đồ');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      // Upload new images
      final newImageUrls = await _uploadImages();

      // Combine existing and new images
      final allImages = [..._existingImageUrls, ...newImageUrls];

      if (allImages.isEmpty) {
        throw Exception('Vui lòng thêm ít nhất 1 ảnh');
      }

      // Update place data
      final placeData = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'description': _descriptionController.text.trim(),
        'typeId': _selectedTypeId,
        'location': GeoPoint(
          _selectedLocation!.latitude,
          _selectedLocation!.longitude,
        ),
        'images': allImages,
        'updateAt': FieldValue.serverTimestamp(),
      };

      // Update in Firestore
      await _adminService.updateDocument(
        'places',
        widget.place['id'],
        placeData,
      );

      if (mounted)
        ToastHelper.showSuccess(context, 'Đã cập nhật địa điểm thành công');
      navigator.pop(true); // Return true to refresh list
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Lỗi: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) ToastHelper.showError(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getSurfaceColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        title: const Text('Sửa địa điểm'),
        actions: [
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Map section
                      const Text(
                        'Vị trí trên bản đồ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 300,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _initialPosition,
                              zoom: 15,
                            ),
                            onMapCreated:
                                (controller) => _mapController = controller,
                            onTap: _onMapTap,
                            markers: _markers,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: true,
                            mapToolbarEnabled: false,
                          ),
                        ),
                      ),
                      if (_selectedLocation != null) ...[
                        const SizedBox(height: 8),
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
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Vị trí: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Manual coordinates input
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
                                  if (lat != null &&
                                      _selectedLocation != null) {
                                    setState(() {
                                      _selectedLocation = LatLng(
                                        lat,
                                        _selectedLocation!.longitude,
                                      );
                                    });
                                  } else if (lat != null) {
                                    setState(() {
                                      _selectedLocation = LatLng(
                                        lat,
                                        106.660172,
                                      );
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
                                  if (lng != null &&
                                      _selectedLocation != null) {
                                    setState(() {
                                      _selectedLocation = LatLng(
                                        _selectedLocation!.latitude,
                                        lng,
                                      );
                                    });
                                  } else if (lng != null) {
                                    setState(() {
                                      _selectedLocation = LatLng(
                                        10.762622,
                                        lng,
                                      );
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
                          if (value == null || value.isEmpty) {
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
                          if (value == null || value.isEmpty) {
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
                          labelText: 'Loại hình *',
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
                          setState(() => _selectedTypeId = value);
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
                        decoration: const InputDecoration(
                          labelText: 'Mô tả *',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập mô tả';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Existing images section
                      if (_existingImageUrls.isNotEmpty) ...[
                        const Text(
                          'Ảnh hiện tại',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              _existingImageUrls.asMap().entries.map((entry) {
                                final index = entry.key;
                                final imageUrl = entry.value;
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        imageUrl,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap:
                                            () => _removeExistingImage(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // New images section
                      if (_selectedImages.isNotEmpty) ...[
                        const Text(
                          'Ảnh mới thêm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              _selectedImages.asMap().entries.map((entry) {
                                final index = entry.key;
                                final file = entry.value;
                                return FutureBuilder<Uint8List>(
                                  future: file.readAsBytes(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const SizedBox(
                                        width: 100,
                                        height: 100,
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }
                                    return Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.memory(
                                            snapshot.data!,
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: GestureDetector(
                                            onTap: () => _removeNewImage(index),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Add images button
                      OutlinedButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Thêm ảnh'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          side: const BorderSide(color: AppColors.primaryGreen),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
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
                                    'Cập nhật địa điểm',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}
