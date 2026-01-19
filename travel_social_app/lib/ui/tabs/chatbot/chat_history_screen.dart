import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:travel_social_app/services/ai_assistant_service.dart';
import 'package:travel_social_app/ui/tabs/chatbot/chat_assistant_screen.dart';
import 'package:travel_social_app/utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Màn hình xem lịch sử các chat sessions
class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final AiAssistantService _aiService = AiAssistantService();
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessions = await _aiService.getChatSessions();
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _viewSession(String sessionId, bool isReadOnly) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Lấy session detail
      final sessionDetail = await _aiService.getSessionDetail(sessionId);

      // Close loading
      if (mounted) Navigator.pop(context);

      // Navigate to view screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => SessionDetailScreen(
                  sessionDetail: sessionDetail,
                  isReadOnly: isReadOnly,
                ),
          ),
        );
      }
    } catch (e) {
      // Close loading
      if (mounted) Navigator.pop(context);

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is Map) {
        // Handle server timestamp format
        dateTime = DateTime.fromMillisecondsSinceEpoch(
          timestamp['_seconds'] * 1000,
        );
      } else {
        return '';
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Vừa xong';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes} phút trước';
      } else if (difference.inDays < 1) {
        return '${difference.inHours} giờ trước';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} ngày trước';
      } else {
        return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lịch sử Chat',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ChatAssistantScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Chat Mới'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Lỗi tải dữ liệu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadSessions,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Chưa có lịch sử chat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bắt đầu chat để lưu lịch sử',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _sessions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final session = _sessions[index];
        return _buildSessionCard(session);
      },
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final sessionId = session['sessionId'] as String;
    final lastMessage = session['lastMessage'] as String? ?? '';
    final messageCount = session['messageCount'] as int? ?? 0;
    final createdAt = session['createdAt']; // Đổi từ updatedAt sang createdAt
    final updatedAt = session['updatedAt'];

    // Format thời gian tạo chat
    String chatTitle = 'Chat lúc ${_formatTimestamp(createdAt)}';
    if (createdAt != null) {
      try {
        DateTime dateTime;
        if (createdAt is Timestamp) {
          dateTime = createdAt.toDate();
        } else if (createdAt is Map) {
          dateTime = DateTime.fromMillisecondsSinceEpoch(
            createdAt['_seconds'] * 1000,
          );
        } else {
          dateTime = DateTime.now();
        }
        chatTitle = 'Chat ${DateFormat('dd/MM/yyyy HH:mm').format(dateTime)}';
      } catch (e) {
        chatTitle = 'Chat ${sessionId.substring(0, 8)}';
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _viewSession(sessionId, true),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                      Icons.chat,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chatTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cập nhật ${_formatTimestamp(updatedAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(
                      '$messageCount tin nhắn',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              if (lastMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Text(
                  lastMessage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Màn hình xem chi tiết session (Read-only)
class SessionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> sessionDetail;
  final bool isReadOnly;

  const SessionDetailScreen({
    super.key,
    required this.sessionDetail,
    required this.isReadOnly,
  });

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is Map) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(
          timestamp['_seconds'] * 1000,
        );
      } else {
        return '';
      }
      return DateFormat('HH:mm dd/MM/yyyy').format(dateTime);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = sessionDetail['messages'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chi tiết Session',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Row(
              children: [
                Icon(Icons.touch_app, size: 12),
                SizedBox(width: 4),
                Text('Nhấn giữ để copy', style: TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Warning banner
          if (isReadOnly)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.shade100,
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đây là session cũ (chỉ xem). Tạo session mới để tiếp tục chat.',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Messages
          Expanded(
            child:
                messages.isEmpty
                    ? const Center(child: Text('Không có tin nhắn'))
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isUser = message['role'] == 'user';
                        final content = message['content'] as String;
                        final timestamp = message['timestamp'];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            mainAxisAlignment:
                                isUser
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isUser) ...[
                                CircleAvatar(
                                  backgroundColor: AppColors.primaryGreen,
                                  radius: 18,
                                  child: const Icon(
                                    Icons.smart_toy,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Column(
                                  crossAxisAlignment:
                                      isUser
                                          ? CrossAxisAlignment.end
                                          : CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onLongPress: () {
                                        // Copy message to clipboard
                                        Clipboard.setData(
                                          ClipboardData(text: content),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Đã copy tin nhắn'),
                                            duration: Duration(seconds: 1),
                                            backgroundColor: Colors.green,
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
                                                  : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ).copyWith(
                                            topLeft:
                                                isUser
                                                    ? const Radius.circular(16)
                                                    : Radius.zero,
                                            topRight:
                                                isUser
                                                    ? Radius.zero
                                                    : const Radius.circular(16),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.grey.shade300,
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child:
                                            isUser
                                                ? Text(
                                                  content,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    height: 1.4,
                                                  ),
                                                )
                                                : MarkdownBody(
                                                  data: content,
                                                  styleSheet: MarkdownStyleSheet(
                                                    p: const TextStyle(
                                                      color: Colors.black87,
                                                      fontSize: 15,
                                                      height: 1.4,
                                                    ),
                                                    strong: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black,
                                                    ),
                                                    em: const TextStyle(
                                                      fontStyle:
                                                          FontStyle.italic,
                                                      color: Colors.black87,
                                                    ),
                                                    listBullet: const TextStyle(
                                                      color:
                                                          AppColors
                                                              .primaryGreen,
                                                      fontSize: 15,
                                                    ),
                                                    code: TextStyle(
                                                      backgroundColor:
                                                          Colors.grey.shade200,
                                                      color:
                                                          Colors.red.shade700,
                                                      fontFamily: 'monospace',
                                                    ),
                                                  ),
                                                  selectable: true,
                                                ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTimestamp(timestamp),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isUser) ...[
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  backgroundColor: AppColors.primaryGreen
                                      .withOpacity(0.2),
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
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
