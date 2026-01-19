import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../../../models/user_model.dart';
import '../../../models/friend.dart';
import '../../../models/chat.dart';
import '../../../services/chat_service.dart';
import '../../../services/friend_service.dart';
import '../../../utils/constants.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import 'chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final FriendService _friendService = FriendService();
  final ChatService _chatService = ChatService();
  final TextEditingController _groupNameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _searchQuery = '';
  File? _groupAvatarFile;
  String? _groupAvatarUrl;
  final Set<String> _selectedFriendIds = {};
  bool _isLoading = false;

  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        title: Text(
          'Tạo nhóm',
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
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildGroupInfoSection(),
                  _buildSearchBar(),
                  _buildFriendList(),
                ],
              ),
            ),
          ),
          _buildCreateButton(),
        ],
      ),
    );
  }

  Widget _buildGroupInfoSection() {
    return Container(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickGroupAvatar,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: AppSizes.icon(context, SizeCategory.xxxlarge) * 0.75,
                  backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                  backgroundImage:
                      _groupAvatarFile != null
                          ? FileImage(_groupAvatarFile!)
                          : null,
                  child:
                      _groupAvatarFile == null
                          ? Icon(
                            Icons.group,
                            size: AppSizes.icon(context, SizeCategory.xxlarge),
                            color: AppColors.primaryGreen,
                          )
                          : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.all(
                      AppSizes.padding(context, SizeCategory.small) * 0.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: AppSizes.icon(context, SizeCategory.small),
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
          CustomTextField(
            controller: _groupNameController,
            hintText: 'Tên nhóm',
            prefixIcon: Icons.edit,
          ),
          if (_selectedFriendIds.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                top: AppSizes.padding(context, SizeCategory.small),
              ),
              child: Text(
                'Đã chọn ${_selectedFriendIds.length} thành viên',
                style: TextStyle(
                  fontSize: AppSizes.font(context, SizeCategory.small),
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
      child: TextField(
        style: TextStyle(
          color: AppTheme.getTextPrimaryColor(context),
          fontSize: AppSizes.font(context, SizeCategory.medium),
        ),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm bạn bè...',
          hintStyle: TextStyle(color: AppTheme.getTextSecondaryColor(context)),
          prefixIcon: Icon(
            Icons.search,
            color: AppTheme.getIconSecondaryColor(context),
            size: AppSizes.icon(context, SizeCategory.medium),
          ),
          filled: true,
          fillColor: AppTheme.getSurfaceColor(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              AppSizes.radius(context, SizeCategory.medium),
            ),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
      ),
    );
  }

  Widget _buildFriendList() {
    return StreamBuilder<List<Friendship>>(
      stream: _friendService.friendsStream(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: EdgeInsets.all(
              AppSizes.padding(context, SizeCategory.large),
            ),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Padding(
            padding: EdgeInsets.all(
              AppSizes.padding(context, SizeCategory.large),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: AppSizes.icon(context, SizeCategory.xxxlarge),
                  color: AppTheme.getIconSecondaryColor(context),
                ),
                SizedBox(
                  height: AppSizes.padding(context, SizeCategory.medium),
                ),
                Text(
                  'Chưa có bạn bè',
                  style: TextStyle(
                    fontSize: AppSizes.font(context, SizeCategory.medium),
                    color: AppTheme.getTextSecondaryColor(context),
                  ),
                ),
              ],
            ),
          );
        }

        var friendships = snapshot.data!;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.padding(context, SizeCategory.small),
          ),
          itemCount: friendships.length,
          itemBuilder: (context, index) {
            final friendship = friendships[index];
            final friendId =
                friendship.userId1 == currentUserId
                    ? friendship.userId2
                    : friendship.userId1;

            return FutureBuilder<DocumentSnapshot>(
              future:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(friendId)
                      .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final friend = UserModel.fromFirestore(userSnapshot.data!);

                if (_searchQuery.isNotEmpty) {
                  final name = friend.name.toLowerCase();
                  if (!name.contains(_searchQuery)) {
                    return const SizedBox.shrink();
                  }
                }

                return _buildFriendItem(friend);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFriendItem(UserModel friend) {
    final isSelected = _selectedFriendIds.contains(friend.userId);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSizes.padding(context, SizeCategory.small),
        vertical: AppSizes.padding(context, SizeCategory.small) * 0.5,
      ),
      decoration: BoxDecoration(
        color:
            isSelected
                ? AppColors.primaryGreen.withOpacity(0.1)
                : AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
        border:
            isSelected
                ? Border.all(color: AppColors.primaryGreen, width: 2)
                : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(
          AppSizes.padding(context, SizeCategory.small),
        ),
        leading: CircleAvatar(
          radius: AppSizes.icon(context, SizeCategory.xlarge) * 0.875,
          backgroundColor: AppColors.primaryGreen,
          backgroundImage:
              (friend.avatarUrl?.isNotEmpty ?? false)
                  ? NetworkImage(friend.avatarUrl!)
                  : null,
          child:
              !(friend.avatarUrl?.isNotEmpty ?? false)
                  ? Text(
                    friend.name[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: AppSizes.font(context, SizeCategory.medium),
                    ),
                  )
                  : null,
        ),
        title: Text(
          friend.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppSizes.font(context, SizeCategory.medium),
            color: AppTheme.getTextPrimaryColor(context),
          ),
        ),
        subtitle:
            friend.bio != null
                ? Text(
                  friend.bio!,
                  style: TextStyle(
                    fontSize: AppSizes.font(context, SizeCategory.small),
                    color: AppTheme.getTextSecondaryColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
                : null,
        trailing: Checkbox(
          value: isSelected,
          activeColor: AppColors.primaryGreen,
          onChanged: (value) {
            setState(() {
              if (value == true) {
                _selectedFriendIds.add(friend.userId);
              } else {
                _selectedFriendIds.remove(friend.userId);
              }
            });
          },
        ),
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedFriendIds.remove(friend.userId);
            } else {
              _selectedFriendIds.add(friend.userId);
            }
          });
        },
      ),
    );
  }

  Widget _buildCreateButton() {
    return Container(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: CustomButton(
        text: 'Tạo nhóm',
        onPressed:
            (_groupNameController.text.trim().isEmpty ||
                    _selectedFriendIds.isEmpty)
                ? null
                : _createGroup,
        isLoading: _isLoading,
      ),
    );
  }

  Future<void> _pickGroupAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _groupAvatarFile = File(image.path);
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

  Future<void> _createGroup() async {
    if (_isLoading) return;

    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên nhóm')));
      return;
    }

    if (_selectedFriendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất 1 thành viên')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_groupAvatarFile != null) {
        final storageRef = FirebaseStorage.instance.ref().child(
          'group_avatars/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await storageRef.putFile(_groupAvatarFile!);
        _groupAvatarUrl = await storageRef.getDownloadURL();
      }

      final memberIds = [currentUserId, ..._selectedFriendIds];
      final chatId = await _chatService.createGroupChat(
        memberIds,
        currentUserId,
      );

      // Update group name và avatar nếu có
      if (groupName.isNotEmpty) {
        await _chatService.updateGroupName(chatId, groupName, currentUserId);
      }

      if (_groupAvatarUrl != null) {
        await _chatService.updateGroupAvatar(
          chatId,
          _groupAvatarUrl!,
          currentUserId,
        );
      }

      final chatDoc =
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .get();
      final chat = Chat.fromFirestore(chatDoc);

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ChatScreen(
                  chat: chat,
                  displayName: groupName,
                  displayAvatar: _groupAvatarUrl,
                ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tạo nhóm: $e')));
      }
    }
  }
}
