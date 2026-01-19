import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../models/chat.dart';
import '../../../models/message.dart';
import '../../../models/call.dart';
import '../../../models/reaction.dart';
import '../../../models/user_model.dart';
import '../../../services/chat_service.dart';
import '../../../services/call_service.dart';
import '../../../services/media_service.dart';
import '../../../services/reaction_service.dart';
import '../../../services/user_service.dart';
import '../../../states/auth_provider.dart' as app_auth;
import '../../../states/call_provider.dart';
import '../../../utils/constants.dart';
import '../../../widgets/limited_text_field.dart';
import '../../../widgets/editable_image_grid.dart';
import '../../../widgets/image_picker_buttons.dart';
import '../../../widgets/media_viewer.dart';
import '../../../widgets/reaction_button.dart';
import '../../call/calling_screen.dart';
import '../../profile/profile_screen.dart';
import 'chat_settings_screen.dart';

class ChatScreen extends StatefulWidget {
  final Chat chat;
  final String displayName;
  final String? displayAvatar;

  const ChatScreen({
    super.key,
    required this.chat,
    required this.displayName,
    this.displayAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final CallService _callService = CallService();
  final MediaService _mediaService = MediaService();
  final UserService _userService = UserService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _hasTextNotifier = ValueNotifier(false);

  Message? _editingMessage; // Message đang được edit

  // Image management
  List<File> _selectedImages = []; // Ảnh mới chọn
  List<String> _existingImageUrls = []; // Ảnh cũ của message đang edit

  // User cache for avatars (để tránh fetch lại nhiều lần)
  final Map<String, UserModel?> _userCache = {};

  bool get _isEditing => _editingMessage != null;

  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _chatService.markAllMessagesAsRead(widget.chat.id, currentUserId);

    // Listen to text changes for send button state
    _messageController.addListener(() {
      _hasTextNotifier.value = _messageController.text.trim().isNotEmpty;
    });

    // Listen to keyboard state changes
    WidgetsBinding.instance.addObserver(this);

    // Auto-scroll to bottom when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Scroll to bottom when keyboard opens/closes
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    if (bottomInset > 0) {
      // Keyboard is opening - scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottom();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    _isLoadingNotifier.dispose();
    _hasTextNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Chat?>(
      stream: _chatService.getChatStream(widget.chat.id),
      initialData: widget.chat,
      builder: (context, chatSnapshot) {
        final currentChat = chatSnapshot.data ?? widget.chat;

        return Scaffold(
          body: Container(
            decoration: _getBackgroundDecoration(currentChat),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(currentChat),
                  Expanded(child: _buildMessageList()),
                  _buildInputArea(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  BoxDecoration _getBackgroundDecoration(Chat chat) {
    String? backgroundUrl;

    switch (chat.chatType) {
      case ChatType.private:
        // Private: Lấy ảnh nền chung (từ bất kỳ user nào đã set)
        if (chat.backgroundImages != null &&
            chat.backgroundImages!.isNotEmpty) {
          backgroundUrl = chat.backgroundImages!.values.first;
        }
        break;
      case ChatType.group:
        // Group: Chỉ admin đổi, dùng groupBackground chung
        backgroundUrl = chat.groupBackground;
        break;
      case ChatType.community:
        backgroundUrl = null;
        break;
    }

    if (backgroundUrl != null) {
      return BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(backgroundUrl),
          fit: BoxFit.cover,
        ),
      );
    }

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppTheme.getBackgroundColor(context).withOpacity(0.3),
          AppTheme.getBackgroundColor(context).withOpacity(0.5),
          AppTheme.getBackgroundColor(context).withOpacity(0.7),
        ],
      ),
    );
  }

  Widget _buildHeader(Chat currentChat) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.padding(context, SizeCategory.medium),
        vertical: AppSizes.padding(context, SizeCategory.medium),
      ),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context).withOpacity(0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              size: AppSizes.icon(context, SizeCategory.medium),
              color: AppTheme.getIconPrimaryColor(context),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          CircleAvatar(
            radius: AppSizes.icon(context, SizeCategory.large),
            backgroundColor: AppColors.primaryGreen,
            backgroundImage:
                widget.displayAvatar != null
                    ? NetworkImage(widget.displayAvatar!)
                    : null,
            child:
                widget.displayAvatar == null
                    ? Text(
                      widget.displayName[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: AppSizes.font(context, SizeCategory.medium),
                      ),
                    )
                    : null,
          ),
          SizedBox(width: AppSizes.padding(context, SizeCategory.medium)),
          Expanded(
            child: Text(
              widget.displayName,
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.large),
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimaryColor(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Call buttons (only if can make call)
          if (_callService.canMakeCall(currentChat))
            ..._buildCallButtons(currentChat),

          IconButton(
            icon: Icon(
              Icons.more_vert,
              size: AppSizes.icon(context, SizeCategory.medium),
              color: AppTheme.getIconPrimaryColor(context),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatSettingsScreen(chat: widget.chat),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCallButtons(Chat chat) {
    // Null-safety checks
    if (!mounted) return [];

    final authProvider = Provider.of<app_auth.AuthProvider>(
      context,
      listen: false,
    );
    final currentUser = authProvider.user;
    if (currentUser == null) return [];

    // Kiểm tra chat data có đầy đủ không
    if (chat.members.isEmpty) return [];

    // Lấy danh sách receiver IDs (loại bỏ current user)
    final receiverIds =
        chat.members.where((id) => id != currentUser.uid).toList();

    if (receiverIds.isEmpty) return [];

    return [
      // Voice call button
      IconButton(
        icon: const Icon(Icons.phone),
        onPressed: () async {
          try {
            if (!mounted) return;

            final callProvider = Provider.of<CallProvider>(
              context,
              listen: false,
            );
            await callProvider.initiateCall(
              chatId: chat.id,
              callerId: currentUser.uid,
              receiverIds: receiverIds,
              callType: CallType.voice,
            );

            // Navigate to calling screen (caller waits for answer)
            if (mounted && callProvider.currentCall != null) {
              final call =
                  callProvider
                      .currentCall!; // Store reference before navigation
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CallingScreen(call: call),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Không thể thực hiện cuộc gọi: ${e.toString()}',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
      // Video call button
      IconButton(
        icon: const Icon(Icons.videocam),
        onPressed: () async {
          try {
            if (!mounted) return;

            final callProvider = Provider.of<CallProvider>(
              context,
              listen: false,
            );
            await callProvider.initiateCall(
              chatId: chat.id,
              callerId: currentUser.uid,
              receiverIds: receiverIds,
              callType: CallType.video,
            );

            // Navigate to calling screen (caller waits for answer)
            if (mounted && callProvider.currentCall != null) {
              final call =
                  callProvider
                      .currentCall!; // Store reference before navigation
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CallingScreen(call: call),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Không thể thực hiện cuộc gọi: ${e.toString()}',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    ];
  }

  Widget _buildMessageList() {
    return StreamBuilder<List<Message>>(
      stream: _chatService.getChatMessages(widget.chat.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: AppSizes.icon(context, SizeCategory.xxxlarge),
                  color: AppTheme.getIconSecondaryColor(context),
                ),
                SizedBox(
                  height: AppSizes.padding(context, SizeCategory.medium),
                ),
                Text(
                  'Chưa có tin nhắn\nHãy bắt đầu trò chuyện!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.getTextPrimaryColor(context),
                    fontSize: AppSizes.font(context, SizeCategory.medium),
                  ),
                ),
              ],
            ),
          );
        }

        final messages = snapshot.data!.reversed.toList();

        // Auto-scroll to bottom when new messages arrive
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });

        return ListView.builder(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(), // Better scroll behavior
          padding: EdgeInsets.all(
            AppSizes.padding(context, SizeCategory.medium),
          ),
          reverse: false,
          itemCount: messages.length,
          addAutomaticKeepAlives: true, // Keep alive for better performance
          addRepaintBoundaries: true, // Isolate repaints
          cacheExtent: 500, // Cache more items for smoother scrolling
          itemBuilder: (context, index) {
            final message = messages[index];
            final isMe = message.senderId == currentUserId;
            final showDate = _shouldShowDate(messages, index);

            return Column(
              key: ValueKey(message.id), // Add key for better performance
              children: [
                if (showDate) _buildDateDivider(message.sentAt),
                _buildMessageBubble(message, isMe),
              ],
            );
          },
        );
      },
    );
  }

  bool _shouldShowDate(List<Message> messages, int index) {
    if (index == 0) return true;

    final currentDate = messages[index].sentAt;
    final previousDate = messages[index - 1].sentAt;

    return currentDate.day != previousDate.day ||
        currentDate.month != previousDate.month ||
        currentDate.year != previousDate.year;
  }

  Widget _buildDateDivider(DateTime date) {
    final now = DateTime.now();
    String dateText;

    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      dateText = 'Hôm nay';
    } else if (date.day == now.day - 1 &&
        date.month == now.month &&
        date.year == now.year) {
      dateText = 'Hôm qua';
    } else {
      dateText = DateFormat('dd/MM/yyyy').format(date);
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: AppSizes.padding(context, SizeCategory.medium),
      ),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: AppTheme.getIconSecondaryColor(context)),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSizes.padding(context, SizeCategory.medium),
            ),
            child: Text(
              dateText,
              style: TextStyle(
                color: AppTheme.getTextPrimaryColor(context),
                fontSize: AppSizes.font(context, SizeCategory.small),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: AppTheme.getIconSecondaryColor(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    return RepaintBoundary(
      child: _MessageBubbleWidget(
        message: message,
        isMe: isMe,
        currentUserId: currentUserId,
        userCache: _userCache,
        userService: _userService,
        onLongPress: isMe ? () => _showMessageOptions(message) : null,
      ),
    );
  }

  Widget _buildInputArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Editing banner
        if (_isEditing)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: AppSizes.padding(context, SizeCategory.medium),
              vertical: AppSizes.padding(context, SizeCategory.small),
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.primaryGreen.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.edit,
                  size: AppSizes.icon(context, SizeCategory.small),
                  color: AppColors.primaryGreen,
                ),
                SizedBox(width: AppSizes.padding(context, SizeCategory.small)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đang chỉnh sửa',
                        style: TextStyle(
                          fontSize: AppSizes.font(context, SizeCategory.small),
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      Text(
                        _editingMessage!.message,
                        style: TextStyle(
                          fontSize:
                              AppSizes.font(context, SizeCategory.small) * 0.9,
                          color: AppTheme.getTextSecondaryColor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _cancelEditing,
                  color: AppTheme.getTextSecondaryColor(context),
                ),
              ],
            ),
          ),

        // Image preview with EditableImageGrid
        if (_selectedImages.isNotEmpty || _existingImageUrls.isNotEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: AppSizes.padding(context, SizeCategory.medium),
              vertical: AppSizes.padding(context, SizeCategory.small),
            ),
            decoration: BoxDecoration(
              color: AppTheme.getSurfaceColor(context),
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: EditableImageGrid(
              existingImageUrls: _existingImageUrls,
              newImages: _selectedImages,
              onRemoveExisting: _removeExistingImage,
              onRemoveNew: _removeSelectedImage,
              displayMode: 'horizontal',
              height: 80,
            ),
          ),

        // Input row
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.padding(context, SizeCategory.small),
            vertical: AppSizes.padding(context, SizeCategory.small),
          ),
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
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.emoji_emotions_outlined,
                  color: AppColors.primaryGreen,
                  size: AppSizes.icon(context, SizeCategory.medium),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Emoji picker đang phát triển'),
                    ),
                  );
                },
              ),
              Expanded(
                child: LimitedTextField(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  maxLength: 500,
                  hintText: _isEditing ? 'Sửa tin nhắn...' : 'Tin nhắn...',
                  maxLines: 3,
                  showCounter: false,
                ),
              ),
              // Replace single image icon with ImagePickerButtons for camera + gallery
              ValueListenableBuilder<bool>(
                valueListenable: _isLoadingNotifier,
                builder: (context, isLoading, _) {
                  return ImagePickerButtons(
                    onCamera: _takePhoto,
                    onGallery: _pickImages,
                    enabled: !isLoading,
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _hasTextNotifier,
                builder: (context, hasText, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: _isLoadingNotifier,
                    builder: (context, isLoading, _) {
                      final hasContent =
                          hasText ||
                          _selectedImages.isNotEmpty ||
                          _existingImageUrls.isNotEmpty;

                      return IconButton(
                        icon:
                            isLoading
                                ? SizedBox(
                                  width:
                                      AppSizes.icon(
                                        context,
                                        SizeCategory.medium,
                                      ) -
                                      8,
                                  height:
                                      AppSizes.icon(
                                        context,
                                        SizeCategory.medium,
                                      ) -
                                      8,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primaryGreen,
                                    ),
                                  ),
                                )
                                : Icon(
                                  _isEditing ? Icons.check : Icons.send,
                                  color:
                                      hasContent
                                          ? AppColors.primaryGreen
                                          : AppTheme.getIconSecondaryColor(
                                            context,
                                          ),
                                  size: AppSizes.icon(
                                    context,
                                    SizeCategory.medium,
                                  ),
                                ),
                        onPressed: isLoading ? null : _sendMessage,
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Pick images from gallery
  Future<void> _pickImages() async {
    final images = await _mediaService.pickImages();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  /// Take photo with camera
  Future<void> _takePhoto() async {
    final image = await _mediaService.takePhoto();
    if (image != null) {
      setState(() {
        _selectedImages.add(image);
      });
    }
  }

  /// Remove selected image
  void _removeSelectedImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  /// Remove existing image (when editing)
  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  /// Upload images to Storage
  Future<List<String>> _uploadImages(List<File> images) async {
    if (images.isEmpty) return [];

    return await _mediaService.uploadMedia(
      images,
      'chat_images/${widget.chat.id}_${currentUserId}_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedImages.isEmpty && _existingImageUrls.isEmpty) {
      return;
    }

    _isLoadingNotifier.value = true;

    try {
      if (_isEditing) {
        // Edit message
        // Note: Currently only text editing is supported
        // Image editing can be added by enhancing the editMessage method

        final success = await _chatService.editMessage(
          _editingMessage!.id,
          currentUserId,
          text,
        );

        if (success) {
          _messageController.clear();
          if (mounted) {
            setState(() {
              _editingMessage = null;
              _selectedImages.clear();
              _existingImageUrls.clear();
            });
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Đã chỉnh sửa tin nhắn')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('❌ Không thể chỉnh sửa tin nhắn')),
            );
          }
        }
      } else {
        // Send new message - don't wait for response
        List<String>? imageUrls;

        if (_selectedImages.isNotEmpty) {
          final urls = await _uploadImages(_selectedImages);
          imageUrls = urls.isNotEmpty ? urls : null;
        }

        // Clear input immediately for better UX
        final messageText = text;
        _messageController.clear();
        if (mounted) {
          setState(() => _selectedImages.clear());
        }

        // Send message asynchronously
        _chatService
            .sendMessage(
              chatId: widget.chat.id,
              senderId: currentUserId,
              messageText: messageText,
              imageUrls: imageUrls,
            )
            .then((_) {
              // Scroll after message is sent
              _scrollToBottom();
            });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      _isLoadingNotifier.value = false;
    }
  }

  void _showMessageOptions(Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radius(context, SizeCategory.large)),
        ),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.all(
              AppSizes.padding(context, SizeCategory.medium),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.edit,
                    color: AppColors.primaryGreen,
                  ),
                  title: const Text('Chỉnh sửa'),
                  onTap: () {
                    Navigator.pop(context);
                    _startEditingMessage(message);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.replay, color: Colors.red),
                  title: const Text(
                    'Thu hồi',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmRecallMessage(message);
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _startEditingMessage(Message message) {
    setState(() {
      _editingMessage = message;
      _messageController.text = message.message;
      // Load all images from imageUrls for editing
      _existingImageUrls =
          (message.imageUrls != null && message.imageUrls!.isNotEmpty)
              ? List<String>.from(message.imageUrls!)
              : [];
      _selectedImages.clear(); // Clear any new images
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingMessage = null;
      _messageController.clear();
      _existingImageUrls.clear();
      _selectedImages.clear();
    });
  }

  Future<void> _confirmRecallMessage(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Thu hồi tin nhắn?'),
            content: const Text(
              'Tin nhắn sẽ bị thu hồi với tất cả mọi người. Bạn có chắc chắn?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Thu hồi',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final success = await _chatService.recallMessage(
        message.id,
        currentUserId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? '✅ Đã thu hồi tin nhắn' : '❌ Không thể thu hồi',
            ),
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      // Use jumpTo instead of animateTo for instant scroll
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }
}

// Separate widget for message bubble to optimize rebuilds
class _MessageBubbleWidget extends StatefulWidget {
  final Message message;
  final bool isMe;
  final String currentUserId;
  final Map<String, UserModel?> userCache;
  final UserService userService;
  final VoidCallback? onLongPress;

  const _MessageBubbleWidget({
    required this.message,
    required this.isMe,
    required this.currentUserId,
    required this.userCache,
    required this.userService,
    this.onLongPress,
  });

  @override
  State<_MessageBubbleWidget> createState() => _MessageBubbleWidgetState();
}

class _MessageBubbleWidgetState extends State<_MessageBubbleWidget> {
  UserModel? _senderUser;
  bool _isLoadingUser = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isMe) {
      _fetchSenderInfo();
    }
  }

  Future<void> _fetchSenderInfo() async {
    // Check cache first
    if (widget.userCache.containsKey(widget.message.senderId)) {
      setState(() {
        _senderUser = widget.userCache[widget.message.senderId];
      });
      return;
    }

    // Fetch from Firestore
    setState(() => _isLoadingUser = true);
    try {
      final user = await widget.userService.getUserById(
        widget.message.senderId,
      );
      if (mounted) {
        setState(() {
          _senderUser = user;
          widget.userCache[widget.message.senderId] = user;
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUser = false);
      }
    }
  }

  void _navigateToProfile() {
    if (_senderUser != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(userId: _senderUser!.userId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build Stack children dynamically
    final stackChildren = <Widget>[
      GestureDetector(
        onLongPress: widget.onLongPress,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          margin: EdgeInsets.symmetric(
            vertical: AppSizes.padding(context, SizeCategory.small) * 0.5,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.padding(context, SizeCategory.medium),
            vertical: AppSizes.padding(context, SizeCategory.small),
          ),
          decoration: BoxDecoration(
            color:
                widget.isMe
                    ? AppColors.primaryGreen
                    : AppTheme.getSurfaceColor(context).withOpacity(0.9),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(
                AppSizes.radius(context, SizeCategory.large),
              ),
              topRight: Radius.circular(
                AppSizes.radius(context, SizeCategory.large),
              ),
              bottomLeft:
                  widget.isMe
                      ? Radius.circular(
                        AppSizes.radius(context, SizeCategory.large),
                      )
                      : Radius.circular(
                        AppSizes.radius(context, SizeCategory.small),
                      ),
              bottomRight:
                  widget.isMe
                      ? Radius.circular(
                        AppSizes.radius(context, SizeCategory.small),
                      )
                      : Radius.circular(
                        AppSizes.radius(context, SizeCategory.large),
                      ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Check if message is recalled
              if (widget.message.isRecalled)
                Row(
                  children: [
                    Icon(
                      Icons.block,
                      size: AppSizes.icon(context, SizeCategory.small),
                      color:
                          widget.isMe
                              ? Colors.white70
                              : AppTheme.getTextSecondaryColor(context),
                    ),
                    SizedBox(
                      width:
                          AppSizes.padding(context, SizeCategory.small) * 0.5,
                    ),
                    Expanded(
                      child: Text(
                        'Tin nhắn đã bị thu hồi',
                        style: TextStyle(
                          color:
                              widget.isMe
                                  ? Colors.white70
                                  : AppTheme.getTextSecondaryColor(context),
                          fontSize: AppSizes.font(context, SizeCategory.medium),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                // Show normal message content if not recalled
                if (widget.message.imageUrls != null &&
                    widget.message.imageUrls!.isNotEmpty) ...[
                  // Hiển thị nhiều ảnh trong grid nếu > 1 ảnh
                  if (widget.message.imageUrls!.length == 1)
                    // Hiển thị 1 ảnh như cũ
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => MediaViewer(
                                  mediaUrls: widget.message.imageUrls!,
                                  initialIndex: 0,
                                ),
                          ),
                        );
                      },
                      child: _buildSingleImage(widget.message.imageUrls![0]),
                    )
                  else
                    // Hiển thị nhiều ảnh trong grid
                    _buildImageGrid(widget.message.imageUrls!),
                  SizedBox(
                    height: AppSizes.padding(context, SizeCategory.small),
                  ),
                ],
                if (widget.message.message.isNotEmpty)
                  Text(
                    widget.message.message,
                    style: TextStyle(
                      color:
                          widget.isMe
                              ? Colors.white
                              : AppTheme.getTextPrimaryColor(context),
                      fontSize: AppSizes.font(context, SizeCategory.medium),
                    ),
                  ),
              ], // Close else block for non-recalled messages
              SizedBox(
                height: AppSizes.padding(context, SizeCategory.small) * 0.5,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('HH:mm').format(widget.message.sentAt),
                    style: TextStyle(
                      color:
                          widget.isMe
                              ? Colors.white70
                              : AppTheme.getTextSecondaryColor(context),
                      fontSize:
                          AppSizes.font(context, SizeCategory.small) * 0.9,
                    ),
                  ),
                  if (widget.message.isEdited) ...[
                    const SizedBox(width: 4),
                    Text(
                      '• Đã chỉnh sửa',
                      style: TextStyle(
                        color:
                            widget.isMe
                                ? Colors.white60
                                : AppTheme.getTextSecondaryColor(context),
                        fontSize:
                            AppSizes.font(context, SizeCategory.small) * 0.8,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    ];

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: 4,
          left: widget.isMe ? 0 : 0, // No padding, avatar will be positioned
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar for other users
            if (!widget.isMe) ...[
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 2),
                child: GestureDetector(
                  onTap: _navigateToProfile,
                  child: CircleAvatar(
                    radius: 20, // Increased from 16 to 20
                    backgroundColor: AppColors.primaryGreen.withOpacity(0.2),
                    backgroundImage:
                        _senderUser?.avatarUrl != null
                            ? CachedNetworkImageProvider(
                              _senderUser!.avatarUrl!,
                            )
                            : null,
                    child:
                        _senderUser?.avatarUrl == null
                            ? (_isLoadingUser
                                ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primaryGreen,
                                    ),
                                  ),
                                )
                                : Text(
                                  _senderUser?.name[0].toUpperCase() ?? '?',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryGreen,
                                  ),
                                ))
                            : null,
                  ),
                ),
              ),
            ],
            // Message bubble and reaction
            Column(
              crossAxisAlignment:
                  widget.isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
              children: [
                Stack(clipBehavior: Clip.none, children: stackChildren),
                // Reaction button below the bubble
                if (!widget.message.isRecalled)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: StreamBuilder<ReactionStats>(
                      stream: ReactionService().getReactionStatsStream(
                        targetId: widget.message.id,
                        targetType: ReactionTargetType.message,
                        currentUserId: widget.currentUserId,
                      ),
                      initialData: ReactionStats.empty(),
                      builder: (context, snapshot) {
                        final stats = snapshot.data ?? ReactionStats.empty();
                        // Always show ReactionButton (even when no reactions yet)
                        return ReactionButton(
                          targetId: widget.message.id,
                          targetType: ReactionTargetType.message,
                          targetOwnerId: widget.message.senderId,
                          initialStats: stats,
                          showCount: true,
                          iconSize: 16,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Build single image
  Widget _buildSingleImage(String imageUrl) {
    return Builder(
      builder:
          (context) => ClipRRect(
            borderRadius: BorderRadius.circular(
              AppSizes.radius(context, SizeCategory.medium),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: 200,
                maxWidth: MediaQuery.of(context).size.width * 0.6,
              ),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheHeight: 400,
                    placeholder:
                        (context, url) => Container(
                          height: 150,
                          color: Colors.grey.withOpacity(0.3),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    errorWidget:
                        (context, url, error) => Container(
                          height: 150,
                          color: Colors.grey.withOpacity(0.3),
                          child: const Icon(
                            Icons.broken_image,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.zoom_in,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // Build image grid (2x2 or more)
  Widget _buildImageGrid(List<String> imageUrls) {
    final int count = imageUrls.length;
    final int displayCount = count > 4 ? 4 : count;

    return Builder(
      builder:
          (context) => ClipRRect(
            borderRadius: BorderRadius.circular(
              AppSizes.radius(context, SizeCategory.medium),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.6,
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                itemCount: displayCount,
                itemBuilder: (context, index) {
                  final isLast = index == 3 && count > 4;
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => MediaViewer(
                                mediaUrls: imageUrls,
                                initialIndex: index,
                              ),
                        ),
                      );
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: imageUrls[index],
                          fit: BoxFit.cover,
                          memCacheHeight: 200,
                          placeholder:
                              (context, url) => Container(
                                color: Colors.grey.withOpacity(0.3),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => Container(
                                color: Colors.grey.withOpacity(0.3),
                                child: const Icon(
                                  Icons.broken_image,
                                  size: 30,
                                  color: Colors.grey,
                                ),
                              ),
                        ),
                        if (isLast)
                          Container(
                            color: Colors.black54,
                            child: Center(
                              child: Text(
                                '+${count - 4}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
    );
  }
}
