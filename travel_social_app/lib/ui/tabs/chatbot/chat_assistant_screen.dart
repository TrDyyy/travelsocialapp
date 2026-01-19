import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:travel_social_app/services/ai_assistant_service.dart';
import 'package:travel_social_app/ui/tabs/chatbot/chat_history_screen.dart';
import 'package:travel_social_app/utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Message model cho chat
class ChatMessage {
  final String role; // 'user' hoặc 'model'
  final String content;
  final DateTime timestamp;
  final bool isLoading;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.isLoading = false,
  });

  bool get isUser => role == 'user';
}

/// Màn hình chat với AI Travel Assistant
class ChatAssistantScreen extends StatefulWidget {
  const ChatAssistantScreen({super.key});

  @override
  State<ChatAssistantScreen> createState() => _ChatAssistantScreenState();
}

class _ChatAssistantScreenState extends State<ChatAssistantScreen> {
  final AiAssistantService _aiService = AiAssistantService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Thêm message chào mừng
  void _addWelcomeMessage() {
    setState(() {
      _messages.add(
        ChatMessage(
          role: 'model',
          content:
              'Xin chào! Tôi là trợ lý du lịch của bạn. '
              'Tôi có thể giúp bạn:\n\n'
              '🌍 Tư vấn địa điểm du lịch\n'
              '🌤️ Cung cấp thông tin thời tiết\n'
              '🏨 Gợi ý khách sạn, nhà hàng\n'
              '📅 Lập lịch trình du lịch\n\n'
              'Hãy hỏi tôi bất cứ điều gì!',
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  /// Gửi tin nhắn
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Xóa error message cũ
    setState(() {
      _errorMessage = null;
    });

    // Thêm message của user vào danh sách
    final userMessage = ChatMessage(
      role: 'user',
      content: message,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    // Xóa input
    _messageController.clear();

    // Scroll xuống cuối
    _scrollToBottom();

    try {
      // Gọi API
      final response = await _aiService.sendMessage(message);

      // Thêm response của AI
      setState(() {
        _messages.add(
          ChatMessage(
            role: 'model',
            content: response['message'] as String,
            timestamp: DateTime.now(),
          ),
        );
        _isLoading = false;
      });

      // Scroll xuống cuối
      _scrollToBottom();
    } catch (e) {
      // Check error type and show user-friendly message
      String errorMsg;

      if (e.toString().contains('quota') || e.toString().contains('429')) {
        errorMsg = '⚠️ Hệ thống đang quá tải.\nVui lòng thử lại sau ít phút.';
      } else if (e.toString().contains('503') ||
          e.toString().contains('overloaded') ||
          e.toString().contains('Service Unavailable')) {
        errorMsg = '⚠️ Hệ thống AI đang bận.\nVui lòng thử lại sau giây lát.';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorMsg = '⚠️ Lỗi kết nối mạng.\nKiểm tra internet và thử lại.';
      } else if (e.toString().contains('timeout')) {
        errorMsg = '⏱️ Yêu cầu quá lâu.\nVui lòng thử lại.';
      } else if (e.toString().contains('All models failed')) {
        errorMsg = '❌ Hiện tại đang có lỗi hệ thống.\nVui lòng thử lại sau.';
      } else {
        // Generic error for unknown issues
        errorMsg = '❌ Có lỗi xảy ra.\nVui lòng thử lại sau.';
      }

      setState(() {
        _isLoading = false;
        _errorMessage = errorMsg;
      });

      // Xóa error message sau 8s
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted) {
          setState(() {
            _errorMessage = null;
          });
        }
      });
    }
  }

  /// Scroll xuống cuối danh sách
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Reset chat session
  Future<void> _resetSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xóa lịch sử chat?'),
            content: const Text(
              'Bạn có chắc chắn muốn xóa toàn bộ lịch sử chat? '
              'Hành động này không thể hoàn tác.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Xóa'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      await _aiService.resetSession();
      setState(() {
        _messages.clear();
      });
      _addWelcomeMessage();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa lịch sử chat'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xóa chat: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Tạo chat mới (session mới)
  Future<void> _createNewChat() async {
    if (_messages.length <= 1) {
      // Chỉ có welcome message, không cần tạo mới
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn đang ở chat mới rồi'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Tạo chat mới?'),
            content: const Text(
              'Bạn có muốn bắt đầu một cuộc hội thoại mới?\n'
              'Chat hiện tại sẽ được lưu vào lịch sử.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Tạo mới'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      // Reset session trên server
      await _aiService.resetSession();

      // Xóa messages và thêm welcome message mới
      setState(() {
        _messages.clear();
        _errorMessage = null;
      });
      _addWelcomeMessage();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Đã tạo chat mới'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tạo chat mới: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dora - Trợ lý du lịch',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.getSurfaceColor(context),
        foregroundColor: AppTheme.getTextPrimaryColor(context),
        elevation: 0,
        actions: [
          // New Chat button
          IconButton(
            icon: const Icon(Icons.add_comment),
            onPressed: _createNewChat,
            tooltip: 'Tạo cuộc hội thoại mới',
          ),

          // History button
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChatHistoryScreen(),
                ),
              );
            },
            tooltip: 'Xem lịch sử chat',
          ),

          // Session info
          if (_aiService.hasActiveSession())
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Chip(
                label: Text(
                  'Session Active',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.getSurfaceColor(context),
                  ),
                ),
                backgroundColor: AppTheme.getTextSecondaryColor(context),
                avatar: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),

          // Reset button
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _resetSession,
            tooltip: 'Xóa lịch sử chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primaryGreen.withOpacity(0.05),
                    AppTheme.getSurfaceColor(context),
                  ],
                ),
              ),
              child:
                  _messages.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length && _isLoading) {
                            return _buildLoadingBubble();
                          }
                          return _buildMessageBubble(_messages[index]);
                        },
                      ),
            ),
          ),

          // Error message
          if (_errorMessage != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade100,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Input area
          Container(
            decoration: BoxDecoration(
              color: AppTheme.getSurfaceColor(context),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.getInputBackgroundColor(context),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SafeArea(
              child: Row(
                children: [
                  // Input field
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Hỏi về du lịch, thời tiết...',
                        hintStyle: TextStyle(
                          color: AppTheme.getTextSecondaryColor(context),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: AppTheme.getInputBackgroundColor(context),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: AppTheme.getBorderColor(context),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        filled: true,
                        fillColor: AppTheme.getInputBackgroundColor(context),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      enabled: !_isLoading,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send button
                  Material(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: _isLoading ? null : _sendMessage,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.send,
                          color: _isLoading ? Colors.grey : Colors.white,
                        ),
                      ),
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

  /// Build message bubble
  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // AI Avatar
            CircleAvatar(
              radius: AppSizes.radius(context, SizeCategory.large),
              child: ClipOval(
                child: Image.asset(
                  'assets/icon/avatar_ai.jpg',
                  width: AppSizes.icon(context, SizeCategory.large),
                  height: AppSizes.icon(context, SizeCategory.large),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(width: AppSizes.padding(context, SizeCategory.small)),
          ],

          // Message content
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: () {
                    // Copy message to clipboard
                    Clipboard.setData(ClipboardData(text: message.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Đã copy tin nhắn',
                          style: TextStyle(
                            color: AppTheme.getTextPrimaryColor(context),
                          ),
                        ),
                        duration: Duration(seconds: 1),
                        backgroundColor: AppTheme.getSurfaceColor(context),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isUser
                              ? AppColors.primaryGreen
                              : AppTheme.getSurfaceColor(context),
                      borderRadius: BorderRadius.circular(16).copyWith(
                        topLeft:
                            isUser ? const Radius.circular(16) : Radius.zero,
                        topRight:
                            isUser ? Radius.zero : const Radius.circular(16),
                      ),
                    ),
                    child:
                        isUser
                            ? Text(
                              message.content,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            )
                            : MarkdownBody(
                              data: message.content,
                              styleSheet: MarkdownStyleSheet(
                                p: TextStyle(
                                  color: AppTheme.getTextPrimaryColor(context),
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                                strong: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.getTextSecondaryColor(
                                    context,
                                  ),
                                ),
                                em: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: AppTheme.getTextSecondaryColor(
                                    context,
                                  ),
                                ),
                                h1: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.getTextSecondaryColor(
                                    context,
                                  ),
                                ),
                                h2: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.getTextSecondaryColor(
                                    context,
                                  ),
                                ),
                                h3: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.getTextSecondaryColor(
                                    context,
                                  ),
                                ),
                                listBullet: TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontSize: 15,
                                ),
                                code: TextStyle(
                                  backgroundColor:
                                      AppTheme.getInputBackgroundColor(context),
                                  color: Colors.red.shade700,
                                  fontFamily: 'monospace',
                                ),
                                codeblockDecoration: BoxDecoration(
                                  color: AppTheme.getInputBackgroundColor(
                                    context,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              selectable: true,
                            ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm').format(message.timestamp),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          if (isUser) ...[
            const SizedBox(width: 8),
            // User Avatar
            CircleAvatar(
              backgroundColor: AppColors.primaryGreen.withOpacity(0.2),
              radius: 18,
              child: const Icon(
                Icons.person,
                color: AppColors.primaryGreen,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build loading bubble
  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: AppSizes.radius(context, SizeCategory.large),
            child: ClipOval(
              child: Image.asset(
                'assets/icon/avatar_ai.jpg',
                width: AppSizes.icon(context, SizeCategory.large),
                height: AppSizes.icon(context, SizeCategory.large),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.getInputBackgroundColor(context),
              borderRadius: BorderRadius.circular(
                16,
              ).copyWith(topLeft: Radius.zero),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Đang trả lời...'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
