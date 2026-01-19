import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../../services/chat_service.dart';
import '../../../utils/constants.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import 'chat_screen.dart';

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _communityNameController =
      TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _communityAvatarFile;
  String? _communityAvatarUrl;
  bool _isLoading = false;

  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _communityNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        title: Text(
          'Tạo cộng đồng',
          style: TextStyle(
            color: Colors.white,
            fontSize: AppSizes.font(context, SizeCategory.large),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: AppSizes.icon(context, SizeCategory.medium),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(
            AppSizes.padding(context, SizeCategory.medium),
          ),
          child: Column(
            children: [
              _buildAvatarSection(),
              SizedBox(height: AppSizes.padding(context, SizeCategory.large)),
              _buildFormSection(),
              SizedBox(height: AppSizes.padding(context, SizeCategory.large)),
              _buildInfoCard(),
              SizedBox(height: AppSizes.padding(context, SizeCategory.large)),
              CustomButton(
                text: 'Tạo cộng đồng',
                onPressed:
                    _communityNameController.text.trim().isEmpty
                        ? null
                        : _createCommunity,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: GestureDetector(
        onTap: _pickCommunityAvatar,
        child: Stack(
          children: [
            Container(
              padding: EdgeInsets.all(
                AppSizes.padding(context, SizeCategory.small),
              ),
              decoration: BoxDecoration(
                color: AppTheme.getSurfaceColor(context),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: AppSizes.icon(context, SizeCategory.xxxlarge),
                backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                backgroundImage:
                    _communityAvatarFile != null
                        ? FileImage(_communityAvatarFile!)
                        : null,
                child:
                    _communityAvatarFile == null
                        ? Icon(
                          Icons.public,
                          size: AppSizes.icon(context, SizeCategory.xxxlarge),
                          color: AppColors.primaryGreen,
                        )
                        : null,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.all(
                  AppSizes.padding(context, SizeCategory.small),
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: AppSizes.icon(context, SizeCategory.medium),
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Column(
      children: [
        CustomTextField(
          controller: _communityNameController,
          hintText: 'Tên cộng đồng',
          prefixIcon: Icons.people,
        ),
        SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
        CustomTextField(
          controller: _descriptionController,
          hintText: 'Mô tả cộng đồng (tùy chọn)',
          prefixIcon: Icons.description,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
        border: Border.all(
          color: AppColors.primaryGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: AppColors.primaryGreen,
            size: AppSizes.icon(context, SizeCategory.large),
          ),
          SizedBox(width: AppSizes.padding(context, SizeCategory.medium)),
          Expanded(
            child: Text(
              'Cộng đồng là nơi mọi người có thể tham gia và trò chuyện công khai. Bất kỳ ai cũng có thể tìm thấy và tham gia cộng đồng của bạn.',
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.small),
                color: AppTheme.getTextPrimaryColor(context),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCommunityAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _communityAvatarFile = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi chọn ảnh: $e')));
      }
    }
  }

  Future<void> _createCommunity() async {
    if (_isLoading) return;

    final communityName = _communityNameController.text.trim();
    if (communityName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên cộng đồng')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload avatar if selected
      if (_communityAvatarFile != null) {
        final storageRef = FirebaseStorage.instance.ref().child(
          'community_avatars/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await storageRef.putFile(_communityAvatarFile!);
        _communityAvatarUrl = await storageRef.getDownloadURL();
      }

      // Create community with creator as first member
      final chat = await _chatService.createCommunityChat(
        creatorId: currentUserId,
        communityName: communityName,
        communityAvatar: _communityAvatarUrl,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ChatScreen(
                  chat: chat,
                  displayName: communityName,
                  displayAvatar: _communityAvatarUrl,
                ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tạo cộng đồng: $e')));
      }
    }
  }
}
