import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../models/community.dart';
import '../../../../models/tourism_type.dart';
import '../../../../services/community_service.dart';
import '../../../../services/media_service.dart';
import '../../../../services/tourism_type_service.dart';
import '../../../../utils/constants.dart';

/// Màn hình tạo Group mới
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  final CommunityService _communityService = CommunityService();
  final MediaService _mediaService = MediaService();
  final TourismTypeService _tourismTypeService = TourismTypeService();

  File? _avatarImage;
  List<TourismType> _allTourismTypes = [];
  List<String> _selectedTourismTypeIds = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTourismTypes();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadTourismTypes() async {
    final types = await _tourismTypeService.getTourismTypes();
    setState(() {
      _allTourismTypes = types;
    });
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _avatarImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload avatar nếu có
      String? avatarUrl;
      if (_avatarImage != null) {
        avatarUrl = await _mediaService.uploadCommunityAvatar(
          _avatarImage!,
          user.uid,
        );
      }

      // Tạo community object
      final community = Community(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        adminId: user.uid,
        memberIds: [user.uid],
        avatarUrl: avatarUrl,
        tourismTypes:
            _allTourismTypes
                .where((t) => _selectedTourismTypeIds.contains(t.typeId))
                .toList(),
        createdAt: DateTime.now(),
      );

      // Lưu vào Firestore
      final groupId = await _communityService.createCommunity(community);

      if (groupId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tạo nhóm thành công!'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tạo nhóm: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        title: const Text(
          'Tạo nhóm mới',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar picker
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: AppColors.primaryGreen,
                        backgroundImage:
                            _avatarImage != null
                                ? FileImage(_avatarImage!)
                                : null,
                        child:
                            _avatarImage == null
                                ? const Icon(
                                  Icons.group,
                                  size: 50,
                                  color: Colors.white,
                                )
                                : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.camera_alt,
                            size: 20,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Group name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Tên nhóm *',
                  hintText: 'Nhập tên nhóm',
                  prefixIcon: const Icon(
                    Icons.group,
                    color: AppColors.primaryGreen,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên nhóm';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Mô tả nhóm *',
                  hintText: 'Mô tả về mục đích, nội dung của nhóm',
                  prefixIcon: const Icon(
                    Icons.description,
                    color: AppColors.primaryGreen,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập mô tả';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Tourism types
              const Text(
                'Loại hình du lịch',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Chọn các loại hình du lịch phù hợp với nhóm',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              _allTourismTypes.isEmpty
                  ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Chưa có loại hình du lịch nào. Vui lòng thêm trong Firestore collection "tourismTypes"',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        _allTourismTypes.map((type) {
                          final isSelected = _selectedTourismTypeIds.contains(
                            type.typeId,
                          );
                          return FilterChip(
                            label: Text(type.name),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedTourismTypeIds.add(type.typeId);
                                } else {
                                  _selectedTourismTypeIds.remove(type.typeId);
                                }
                              });
                            },
                            selectedColor: AppColors.primaryGreen,
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color:
                                  isSelected
                                      ? Colors.white
                                      : AppTheme.getTextPrimaryColor(context),
                            ),
                          );
                        }).toList(),
                  ),
              const SizedBox(height: 32),

              // Create button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createGroup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            'Tạo nhóm',
                            style: TextStyle(
                              color: Colors.white,
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
}
