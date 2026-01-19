import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/place.dart';
import '../../../models/place_edit_request.dart';
import '../../../models/tourism_type.dart';
import '../../../services/place_edit_request_service.dart';
import '../../../services/place_service.dart';
import '../../../utils/constants.dart';

/// Màn hình đăng ký địa điểm lên hệ thống
class RegisterPlaceScreen extends StatefulWidget {
  final Map<String, dynamic> googlePlaceDetails;
  final Place? existingPlace;

  const RegisterPlaceScreen({
    super.key,
    required this.googlePlaceDetails,
    this.existingPlace,
  });

  @override
  State<RegisterPlaceScreen> createState() => _RegisterPlaceScreenState();
}

class _RegisterPlaceScreenState extends State<RegisterPlaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _placeService = PlaceService();
  final _requestService = PlaceEditRequestService();
  final _imagePicker = ImagePicker();

  List<File> _selectedImages = [];
  List<TourismType> _tourismTypes = [];
  Set<String> _selectedTypeIds =
      {}; // Đổi từ String? sang Set<String> để chọn nhiều
  bool _isLoading = false;
  bool _isLoadingTypes = true;

  @override
  void initState() {
    super.initState();
    _loadTourismTypes();
    // Pre-fill content nếu đã có
    if (widget.existingPlace != null) {
      _contentController.text = widget.existingPlace!.description;
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  /// Load danh sách loại hình du lịch
  Future<void> _loadTourismTypes() async {
    try {
      final types = await _placeService.getTourismTypes();
      setState(() {
        _tourismTypes = types;
        _isLoadingTypes = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTypes = false;
      });
      _showError('Không thể tải danh sách loại hình du lịch');
    }
  }

  /// Chọn nhiều ảnh từ thư viện
  Future<void> _pickImages() async {
    try {
      final pickedFiles = await _imagePicker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
      );

      if (pickedFiles.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(
            pickedFiles.map((xFile) => File(xFile.path)).toList(),
          );
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
          _selectedImages.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      _showError('Không thể chụp ảnh: $e');
    }
  }

  /// Xóa ảnh đã chọn
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  /// Submit form đăng ký
  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedImages.isEmpty) {
      _showError('Vui lòng thêm ít nhất 1 ảnh');
      return;
    }

    if (_selectedTypeIds.isEmpty) {
      _showError('Vui lòng chọn ít nhất 1 loại hình du lịch');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Vui lòng đăng nhập để tiếp tục');
        return;
      }

      // Lấy thông tin địa điểm từ Google Places
      final geometry = widget.googlePlaceDetails['geometry'];
      final location = geometry['location'];
      final lat = location['lat'];
      final lng = location['lng'];
      final name = widget.googlePlaceDetails['name'] ?? 'Không có tên';
      final address = widget.googlePlaceDetails['formatted_address'] ?? '';
      final googlePlaceId =
          widget.googlePlaceDetails['place_id']; // Lấy Google Place ID

      // Upload ảnh (tạm thời upload vào folder "pending")
      final imageUrls = await _requestService.uploadImages(
        _selectedImages,
        'pending_${user.uid}_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (imageUrls.isEmpty) {
        throw Exception('Không thể upload ảnh');
      }

      // Lấy tên của loại hình du lịch đầu tiên (chính)
      final primaryTypeName =
          _tourismTypes
              .firstWhere(
                (type) => type.typeId == _selectedTypeIds.first,
                orElse: () => _tourismTypes.first,
              )
              .name;

      // Tạo yêu cầu đăng ký địa điểm mới (chưa có placeId)
      final request = PlaceEditRequest(
        placeId: widget.existingPlace?.placeId, // null nếu là địa điểm mới
        googlePlaceId: googlePlaceId, // Lưu Google Place ID
        proposedBy: user.uid,
        content: _contentController.text,
        images: imageUrls,
        status: 'Đã tiếp nhận',
        placeName: name,
        location: GeoPoint(lat, lng),
        address: address,
        typeIds: _selectedTypeIds.toList(),
        typeName: primaryTypeName, // Lưu tên loại hình để hiển thị
      );

      final requestId = await _requestService.createRequest(request);

      if (requestId != null) {
        if (mounted) {
          Navigator.pop(context, true); // Return true để refresh
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '✅ Đã gửi yêu cầu đăng ký địa điểm! Vui lòng chờ admin duyệt.',
              ),
              backgroundColor: AppColors.primaryGreen,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception('Không thể tạo yêu cầu');
      }
    } catch (e) {
      _showError('Lỗi: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.googlePlaceDetails['name'] ?? 'Không có tên';
    final address =
        widget.googlePlaceDetails['formatted_address'] ?? 'Không có địa chỉ';
    final geometry = widget.googlePlaceDetails['geometry'];
    final location = geometry?['location'];
    final lat = location?['lat'] ?? 0.0;
    final lng = location?['lng'] ?? 0.0;

    return Scaffold(
      backgroundColor: AppTheme.getSurfaceColor(context),
      appBar: AppBar(
        title: const Text('Đăng ký địa điểm du lịch'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppTheme.getTextPrimaryColor(context),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            AppSizes.padding(context, SizeCategory.large),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thông tin địa điểm
              _buildInfoCard(name, address, lat, lng),
              SizedBox(height: AppSizes.padding(context, SizeCategory.large)),

              // User info
              _buildUserInfo(),
              SizedBox(height: AppSizes.padding(context, SizeCategory.large)),

              // Địa chỉ
              _buildAddressField(address),
              SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),

              // Loại hình du lịch
              _buildTourismTypeField(),
              SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),

              // Mô tả
              _buildDescriptionField(),
              SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),

              // Upload ảnh
              _buildImagePicker(),
              SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),

              // Grid hiển thị ảnh đã chọn
              if (_selectedImages.isNotEmpty) _buildImageGrid(),
              SizedBox(height: AppSizes.padding(context, SizeCategory.large)),

              // Nút đăng ký
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppTheme.getTextPrimaryColor(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSizes.radius(context, SizeCategory.medium),
                      ),
                    ),
                  ),
                  child:
                      _isLoading
                          ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: AppTheme.getTextPrimaryColor(context),
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            'Đăng',
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

  Widget _buildInfoCard(String name, String address, double lat, double lng) {
    return Card(
      color: AppTheme.getSurfaceColor(context),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: AppColors.primaryGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Thông tin sẽ được cập nhật vào hệ thống sau khi xác thực',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.getTextSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    final user = FirebaseAuth.instance.currentUser;
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundImage:
              (user?.photoURL?.isNotEmpty ?? false)
                  ? NetworkImage(user!.photoURL!)
                  : null,
          backgroundColor: AppColors.primaryGreen,
          child:
              !(user?.photoURL?.isNotEmpty ?? false)
                  ? Icon(
                    Icons.person,
                    color: AppTheme.getTextPrimaryColor(context),
                  )
                  : Image.network(user!.photoURL!, fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.displayName ?? 'Người dùng',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Thông tin sẽ được cập nhật vào hệ thống sau khi xác thực',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.getTextSecondaryColor(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddressField(String address) {
    return TextFormField(
      initialValue: address,
      enabled: false,
      decoration: InputDecoration(
        labelText: 'Địa chỉ',
        prefixIcon: const Icon(Icons.location_on),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
        ),
        filled: true,
        fillColor: AppTheme.getSurfaceColor(context),
      ),
    );
  }

  Widget _buildTourismTypeField() {
    if (_isLoadingTypes) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Loại hình du lịch *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Chọn các loại hình du lịch phù hợp với địa điểm',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.getTextSecondaryColor(context),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(
              AppSizes.radius(context, SizeCategory.medium),
            ),
            border: Border.all(color: AppTheme.getBorderColor(context)),
          ),
          child: Column(
            children:
                _tourismTypes.map((type) {
                  final isSelected = _selectedTypeIds.contains(type.typeId);
                  return CheckboxListTile(
                    title: Text(type.name),
                    value: isSelected,
                    activeColor: AppColors.primaryGreen,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedTypeIds.add(type.typeId);
                        } else {
                          _selectedTypeIds.remove(type.typeId);
                        }
                      });
                    },
                  );
                }).toList(),
          ),
        ),
        if (_selectedTypeIds.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8, left: 12),
            child: Text(
              'Vui lòng chọn ít nhất 1 loại hình du lịch',
              style: TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _contentController,
      maxLines: 5,
      decoration: InputDecoration(
        labelText: 'Mô tả về địa điểm',
        hintText: 'Nhập mô tả chi tiết về địa điểm...',
        alignLabelWithHint: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
        ),
        filled: true,
        fillColor: AppTheme.getSurfaceColor(context),
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
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thêm ảnh và video',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(
              AppSizes.radius(context, SizeCategory.medium),
            ),
            border: Border.all(
              color: AppColors.primaryGreen,
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildImagePickerButton(
                icon: Icons.photo_library,
                label: 'Thư viện',
                onTap: _pickImages,
              ),
              _buildImagePickerButton(
                icon: Icons.camera_alt,
                label: 'Camera',
                onTap: _takePhoto,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImagePickerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.getSurfaceColor(context),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryGreen),
            ),
            child: Icon(icon, color: AppColors.primaryGreen, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Đã chọn ${_selectedImages.length} ảnh',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                  child: Image.file(_selectedImages[index], fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: InkWell(
                    onTap: () => _removeImage(index),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: AppTheme.getTextPrimaryColor(context),
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
