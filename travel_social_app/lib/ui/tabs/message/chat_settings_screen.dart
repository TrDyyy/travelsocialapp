import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../../models/chat.dart';
import '../../../models/user_model.dart';
import '../../../services/chat_service.dart';
import '../../../utils/constants.dart';
import '../../../widgets/custom_button.dart';

class ChatSettingsScreen extends StatefulWidget {
  final Chat chat;

  const ChatSettingsScreen({super.key, required this.chat});

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  final ChatService _chatService = ChatService();
  final ImagePicker _picker = ImagePicker();

  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get isAdmin => widget.chat.groupAdmin == currentUserId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        title: Text(
          'Cài đặt chat',
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
        child: Column(
          children: [
            _buildChatInfo(),
            _buildNotificationSettings(),
            if (widget.chat.chatType != ChatType.private) ...[
              _buildMembersList(),
              if (isAdmin) _buildAdminActions(),
            ],
            _buildBackgroundSection(),
            if (widget.chat.chatType == ChatType.group && isAdmin)
              _buildDangerZone(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.chat.id)
              .snapshots(),
      initialData: null,
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final mutedBy =
            snapshot.hasData && data != null
                ? (data['mutedBy'] as List?)
                : widget.chat.mutedBy;
        final isMuted = mutedBy?.contains(currentUserId) ?? false;

        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: AppSizes.padding(context, SizeCategory.medium),
            vertical: AppSizes.padding(context, SizeCategory.small),
          ),
          padding: EdgeInsets.all(
            AppSizes.padding(context, SizeCategory.medium),
          ),
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(
              AppSizes.radius(context, SizeCategory.medium),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isMuted
                      ? Icons.notifications_off
                      : Icons.notifications_active,
                  key: ValueKey(isMuted),
                  color: isMuted ? Colors.grey : AppColors.primaryGreen,
                  size: AppSizes.icon(context, SizeCategory.medium),
                ),
              ),
              SizedBox(width: AppSizes.padding(context, SizeCategory.medium)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thông báo',
                      style: TextStyle(
                        fontSize: AppSizes.font(context, SizeCategory.medium),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getTextPrimaryColor(context),
                      ),
                    ),
                    SizedBox(
                      height:
                          AppSizes.padding(context, SizeCategory.small) * 0.5,
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        isMuted
                            ? 'Đã tắt thông báo'
                            : 'Nhận thông báo tin nhắn mới',
                        key: ValueKey(isMuted),
                        style: TextStyle(
                          fontSize: AppSizes.font(context, SizeCategory.small),
                          color: AppTheme.getTextSecondaryColor(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: !isMuted,
                activeColor: AppColors.primaryGreen,
                onChanged: (value) async {
                  try {
                    if (value) {
                      await _chatService.unmuteChat(
                        widget.chat.id,
                        currentUserId,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Đã bật thông báo'),
                            backgroundColor: AppColors.primaryGreen,
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    } else {
                      await _chatService.muteChat(
                        widget.chat.id,
                        currentUserId,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('🔕 Đã tắt thông báo'),
                            backgroundColor: Colors.grey[700],
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    debugPrint('❌ Error muting chat: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '❌ Không thể ${value ? "bật" : "tắt"} thông báo',
                          ),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatInfo() {
    return Container(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.large)),
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
          CircleAvatar(
            radius: AppSizes.icon(context, SizeCategory.xxxlarge),
            backgroundColor: AppColors.primaryGreen,
            backgroundImage:
                widget.chat.groupAvatar != null
                    ? NetworkImage(widget.chat.groupAvatar!)
                    : null,
            child:
                widget.chat.groupAvatar == null
                    ? Icon(
                      widget.chat.chatType == ChatType.community
                          ? Icons.public
                          : Icons.group,
                      size: AppSizes.icon(context, SizeCategory.xxlarge),
                      color: Colors.white,
                    )
                    : null,
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
          Text(
            widget.chat.groupName ?? 'Chat',
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.xlarge),
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimaryColor(context),
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.small)),
          Text(
            '${widget.chat.members.length} thành viên',
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.medium),
              color: AppTheme.getTextSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    return Container(
      margin: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thành viên',
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.large),
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimaryColor(context),
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
          ...widget.chat.members.map((memberId) => _buildMemberItem(memberId)),
        ],
      ),
    );
  }

  Widget _buildMemberItem(String memberId) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(memberId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final user = UserModel.fromFirestore(snapshot.data!);
        final isChatAdmin = widget.chat.groupAdmin == memberId;

        return Container(
          margin: EdgeInsets.only(
            bottom: AppSizes.padding(context, SizeCategory.small),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: AppSizes.icon(context, SizeCategory.large),
                backgroundColor: AppColors.primaryGreen,
                backgroundImage:
                    (user.avatarUrl?.isNotEmpty ?? false)
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                child:
                    !(user.avatarUrl?.isNotEmpty ?? false)
                        ? Text(
                          user.name[0].toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: AppSizes.font(
                              context,
                              SizeCategory.medium,
                            ),
                          ),
                        )
                        : null,
              ),
              SizedBox(width: AppSizes.padding(context, SizeCategory.medium)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: AppSizes.font(context, SizeCategory.medium),
                        color: AppTheme.getTextPrimaryColor(context),
                      ),
                    ),
                    if (isChatAdmin)
                      Text(
                        'Quản trị viên',
                        style: TextStyle(
                          fontSize: AppSizes.font(context, SizeCategory.small),
                          color: AppColors.primaryGreen,
                        ),
                      ),
                  ],
                ),
              ),
              if (isAdmin && memberId != currentUserId)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: AppTheme.getIconSecondaryColor(context),
                  ),
                  onSelected: (value) {
                    if (value == 'remove') {
                      _removeMember(memberId, user.name);
                    } else if (value == 'transfer') {
                      _transferAdmin(memberId, user.name);
                    }
                  },
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: 'transfer',
                          child: Row(
                            children: [
                              Icon(
                                Icons.admin_panel_settings,
                                color: AppColors.primaryGreen,
                              ),
                              SizedBox(
                                width: AppSizes.padding(
                                  context,
                                  SizeCategory.small,
                                ),
                              ),
                              const Text('Chuyển quyền admin'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.remove_circle,
                                color: Colors.red,
                              ),
                              SizedBox(
                                width: AppSizes.padding(
                                  context,
                                  SizeCategory.small,
                                ),
                              ),
                              const Text('Xóa khỏi nhóm'),
                            ],
                          ),
                        ),
                      ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdminActions() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSizes.padding(context, SizeCategory.medium),
      ),
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hành động quản trị',
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.large),
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimaryColor(context),
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
          _buildActionButton(
            icon: Icons.person_add,
            title: 'Thêm thành viên',
            onTap: _addMember,
          ),
          _buildActionButton(
            icon: Icons.edit,
            title:
                widget.chat.chatType == ChatType.community
                    ? 'Đổi tên cộng đồng'
                    : 'Đổi tên nhóm',
            onTap: _changeGroupName,
          ),
          _buildActionButton(
            icon: Icons.photo,
            title:
                widget.chat.chatType == ChatType.community
                    ? 'Đổi ảnh cộng đồng'
                    : 'Đổi ảnh nhóm',
            onTap: _changeGroupAvatar,
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundSection() {
    return Container(
      margin: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hình nền chat',
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.large),
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimaryColor(context),
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
          _buildActionButton(
            icon: Icons.wallpaper,
            title:
                widget.chat.chatType == ChatType.private
                    ? 'Đổi hình nền riêng'
                    : isAdmin
                    ? 'Đổi hình nền nhóm'
                    : 'Xem hình nền',
            onTap:
                widget.chat.chatType == ChatType.private || isAdmin
                    ? _changeBackground
                    : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return Container(
      margin: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vùng nguy hiểm',
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.large),
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
          CustomButton(
            text: 'Giải tán nhóm',
            onPressed: _disbandGroup,
            backgroundColor: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        AppSizes.radius(context, SizeCategory.medium),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: AppSizes.padding(context, SizeCategory.small),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color:
                  onTap != null
                      ? AppColors.primaryGreen
                      : AppTheme.getIconSecondaryColor(context),
              size: AppSizes.icon(context, SizeCategory.medium),
            ),
            SizedBox(width: AppSizes.padding(context, SizeCategory.medium)),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: AppSizes.font(context, SizeCategory.medium),
                  color: AppTheme.getTextPrimaryColor(context),
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: AppSizes.icon(context, SizeCategory.small),
              color: AppTheme.getIconSecondaryColor(context),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ACTIONS ====================

  Future<void> _addMember() async {
    // TODO: Implement add member screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chức năng thêm thành viên đang phát triển'),
      ),
    );
  }

  Future<void> _changeGroupName() async {
    final controller = TextEditingController(text: widget.chat.groupName);

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Đổi tên nhóm'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Nhập tên nhóm mới'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () async {
                  final newName = controller.text.trim();
                  if (newName.isNotEmpty) {
                    try {
                      await _chatService.updateGroupName(
                        widget.chat.id,
                        newName,
                        currentUserId,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã đổi tên nhóm')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                      }
                    }
                  }
                },
                child: const Text('Lưu'),
              ),
            ],
          ),
    );
  }

  Future<void> _changeGroupAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return;

      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      final storageRef = FirebaseStorage.instance.ref().child(
        'group_avatars/${widget.chat.id}.jpg',
      );
      await storageRef.putFile(File(image.path));
      final avatarUrl = await storageRef.getDownloadURL();

      await _chatService.updateGroupAvatar(
        widget.chat.id,
        avatarUrl,
        currentUserId,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã đổi ảnh nhóm')));
        setState(() {}); // Refresh UI
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _changeBackground() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;

      // Show preview dialog
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => _BackgroundPreviewDialog(
              imagePath: image.path,
              chatType: widget.chat.chatType,
            ),
      );

      if (confirmed != true) return;

      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      final storageRef = FirebaseStorage.instance.ref().child(
        'chat_backgrounds/${widget.chat.id}_${currentUserId}.jpg',
      );
      await storageRef.putFile(File(image.path));
      final backgroundUrl = await storageRef.getDownloadURL();

      if (widget.chat.chatType == ChatType.private) {
        await _chatService.updatePrivateBackground(
          widget.chat.id,
          currentUserId,
          backgroundUrl,
        );
      } else if (widget.chat.chatType == ChatType.group) {
        await _chatService.updateGroupBackground(
          widget.chat.id,
          backgroundUrl,
          currentUserId,
        );
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã đổi hình nền')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _removeMember(String memberId, String memberName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xóa thành viên'),
            content: Text('Bạn có chắc muốn xóa $memberName khỏi nhóm?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Xóa', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await _chatService.removeMemberFromGroup(widget.chat.id, memberId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã xóa $memberName khỏi nhóm')),
          );
          setState(() {}); // Refresh UI
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
      }
    }
  }

  Future<void> _transferAdmin(String memberId, String memberName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Chuyển quyền admin'),
            content: Text(
              'Bạn có chắc muốn chuyển quyền admin cho $memberName? Bạn sẽ không còn là admin nữa.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Chuyển'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await _chatService.transferAdmin(
          widget.chat.id,
          currentUserId,
          memberId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã chuyển quyền admin cho $memberName')),
          );
          Navigator.pop(context); // Close settings screen
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
      }
    }
  }

  Future<void> _disbandGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Giải tán nhóm'),
            content: const Text(
              'Bạn có chắc muốn giải tán nhóm này? Hành động này không thể hoàn tác!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Giải tán',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await _chatService.disbandGroup(widget.chat.id, currentUserId);
        if (mounted) {
          Navigator.pop(context); // Close settings
          Navigator.pop(context); // Close chat screen
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Đã giải tán nhóm')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
      }
    }
  }
}

/// Dialog preview ảnh nền trước khi set
class _BackgroundPreviewDialog extends StatefulWidget {
  final String imagePath;
  final ChatType chatType;

  const _BackgroundPreviewDialog({
    required this.imagePath,
    required this.chatType,
  });

  @override
  State<_BackgroundPreviewDialog> createState() =>
      _BackgroundPreviewDialogState();
}

class _BackgroundPreviewDialogState extends State<_BackgroundPreviewDialog> {
  BoxFit _fit = BoxFit.cover;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: FileImage(File(widget.imagePath)),
            fit: _fit,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                color: Colors.black.withOpacity(0.7),
                padding: EdgeInsets.all(
                  AppSizes.padding(context, SizeCategory.medium),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: AppSizes.icon(context, SizeCategory.medium),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    Expanded(
                      child: Text(
                        'Xem trước ảnh nền',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: AppSizes.font(context, SizeCategory.large),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.check,
                        color: AppColors.primaryGreen,
                        size: AppSizes.icon(context, SizeCategory.medium),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Sample messages để xem ảnh nền có đẹp không
              Container(
                margin: EdgeInsets.all(
                  AppSizes.padding(context, SizeCategory.medium),
                ),
                padding: EdgeInsets.all(
                  AppSizes.padding(context, SizeCategory.medium),
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(
                    AppSizes.radius(context, SizeCategory.medium),
                  ),
                ),
                child: Text(
                  'Đây là tin nhắn mẫu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppSizes.font(context, SizeCategory.medium),
                  ),
                ),
              ),

              Container(
                margin: EdgeInsets.symmetric(
                  horizontal: AppSizes.padding(context, SizeCategory.medium),
                ),
                padding: EdgeInsets.all(
                  AppSizes.padding(context, SizeCategory.medium),
                ),
                decoration: BoxDecoration(
                  color: AppTheme.getSurfaceColor(context),
                  borderRadius: BorderRadius.circular(
                    AppSizes.radius(context, SizeCategory.medium),
                  ),
                ),
                child: Text(
                  'Tin nhắn từ người khác',
                  style: TextStyle(
                    color: AppTheme.getTextPrimaryColor(context),
                    fontSize: AppSizes.font(context, SizeCategory.medium),
                  ),
                ),
              ),

              const Spacer(),

              // Controls
              Container(
                color: Colors.black.withOpacity(0.7),
                padding: EdgeInsets.all(
                  AppSizes.padding(context, SizeCategory.medium),
                ),
                child: Column(
                  children: [
                    Text(
                      'Chế độ hiển thị',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppSizes.font(context, SizeCategory.medium),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(
                      height: AppSizes.padding(context, SizeCategory.small),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFitOption('Che phủ', BoxFit.cover, Icons.crop),
                        _buildFitOption(
                          'Vừa khít',
                          BoxFit.contain,
                          Icons.fit_screen,
                        ),
                        _buildFitOption(
                          'Kéo dãn',
                          BoxFit.fill,
                          Icons.fullscreen,
                        ),
                      ],
                    ),
                    SizedBox(
                      height: AppSizes.padding(context, SizeCategory.small),
                    ),
                    Text(
                      widget.chatType == ChatType.group
                          ? '⚠️ Chỉ admin được đổi ảnh nền'
                          : '✅ Ảnh nền sẽ hiển thị cho tất cả',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: AppSizes.font(context, SizeCategory.small),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFitOption(String label, BoxFit fit, IconData icon) {
    final isSelected = _fit == fit;
    return InkWell(
      onTap: () => setState(() => _fit = fit),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.padding(context, SizeCategory.medium),
          vertical: AppSizes.padding(context, SizeCategory.small),
        ),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primaryGreen
                  : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: AppSizes.icon(context, SizeCategory.medium),
            ),
            SizedBox(
              height: AppSizes.padding(context, SizeCategory.small) * 0.5,
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: AppSizes.font(context, SizeCategory.small),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
