import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../services/admin_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/toast_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Trang quản lý Chats
class ChatsManagementPage extends StatefulWidget {
  const ChatsManagementPage({super.key});

  @override
  State<ChatsManagementPage> createState() => _ChatsManagementPageState();
}

class _ChatsManagementPageState extends State<ChatsManagementPage> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() => _isLoading = true);
    try {
      final chats = await _adminService.getCollectionData('chats', limit: 200);
      setState(() {
        _chats = chats;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastHelper.showError(context, 'Lỗi tải dữ liệu: $e');
      }
    }
  }

  List<Map<String, dynamic>> get _filteredChats {
    if (_searchQuery.isEmpty) return _chats;
    return _chats.where((chat) {
      final groupName = (chat['groupName'] ?? '').toString().toLowerCase();
      final chatType = (chat['chatType'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return groupName.contains(query) || chatType.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getSurfaceColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        title: const Text('Quản lý Cuộc trò chuyện'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadChats),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm kiếm theo tên nhóm hoặc loại...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.primaryGreen,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                      ),
                    )
                    : _buildChatsTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quản lý Cuộc trò chuyện',
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.xlarge),
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimaryColor(context),
              ),
            ),
            SizedBox(height: AppSizes.padding(context, SizeCategory.small)),
            Text(
              'Tổng số: ${_filteredChats.length} cuộc trò chuyện',
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.medium),
                color: AppTheme.getTextSecondaryColor(context),
              ),
            ),
          ],
        ),
        IconButton(
          icon: Icon(
            Icons.refresh,
            color: AppTheme.getIconPrimaryColor(context),
          ),
          onPressed: _loadChats,
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Tìm kiếm theo tên nhóm hoặc loại...',
        prefixIcon: Icon(Icons.search, color: AppColors.primaryGreen),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        filled: true,
        fillColor: AppTheme.getSurfaceColor(context),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  Widget _buildChatsTable() {
    if (_filteredChats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Không có cuộc trò chuyện nào',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: DataTable2(
            columnSpacing: 12,
            horizontalMargin: 12,
            minWidth: 1400,
            headingRowColor: MaterialStateProperty.all(
              AppColors.primaryGreen.withOpacity(0.35),
            ),
            headingTextStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.black,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
            dataTextStyle: const TextStyle(fontSize: 15, color: Colors.black87),
            columns: const [
              DataColumn2(
                label: Text('Ảnh đại diện'),
                size: ColumnSize.S,
                fixedWidth: 100,
              ),
              DataColumn2(label: Text('Tên nhóm'), size: ColumnSize.L),
              DataColumn2(
                label: Text('Loại'),
                size: ColumnSize.S,
                fixedWidth: 120,
              ),
              DataColumn2(
                label: Text('Công khai'),
                size: ColumnSize.S,
                fixedWidth: 100,
              ),
              DataColumn2(
                label: Text('Thành viên'),
                size: ColumnSize.S,
                fixedWidth: 100,
              ),
              DataColumn2(label: Text('Tin nhắn cuối'), size: ColumnSize.L),
              DataColumn2(
                label: Text('Ngày tạo'),
                size: ColumnSize.M,
                fixedWidth: 120,
              ),
              DataColumn2(
                label: Text('Hành động'),
                size: ColumnSize.M,
                fixedWidth: 140,
              ),
            ],
            rows:
                _filteredChats.asMap().entries.map((entry) {
                  final index = entry.key;
                  final chat = entry.value;
                  final createdAt = chat['createdAt'];
                  final dateStr =
                      createdAt != null && createdAt is Timestamp
                          ? '${createdAt.toDate().day.toString().padLeft(2, '0')}/${createdAt.toDate().month.toString().padLeft(2, '0')}/${createdAt.toDate().year}'
                          : '-';
                  final groupAvatar = chat['groupAvatar'] ?? '';
                  // Fix: members có thể là Map hoặc List
                  final membersData = chat['members'];
                  final members =
                      membersData is List
                          ? membersData
                          : (membersData is Map
                              ? membersData.keys.toList()
                              : []);
                  final isPublic = chat['isPublic'] ?? false;
                  final lastMessage = chat['lastMessage'] ?? '';
                  final chatType = chat['chatType'] ?? 'Cá nhân';

                  return DataRow(
                    color: MaterialStateProperty.resolveWith<Color?>((
                      Set<MaterialState> states,
                    ) {
                      if (index.isEven) {
                        return Colors.grey.shade50;
                      }
                      return null;
                    }),
                    cells: [
                      // Ảnh đại diện
                      DataCell(
                        groupAvatar is String && groupAvatar.startsWith('http')
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                groupAvatar,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                loadingBuilder: (
                                  context,
                                  child,
                                  loadingProgress,
                                ) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.grey.shade200,
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          value:
                                              loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                  : null,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder:
                                    (context, error, stackTrace) => Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey.shade300,
                                      child: const Icon(
                                        Icons.broken_image,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                    ),
                              ),
                            )
                            : Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                chatType == 'Cộng đồng'
                                    ? Icons.groups
                                    : Icons.chat,
                                size: 24,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                      ),
                      // Tên nhóm
                      DataCell(
                        Text(
                          chat['groupName'] ?? 'Không có tên',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Loại
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                chatType == 'Cộng đồng'
                                    ? AppColors.primaryGreen.withOpacity(0.2)
                                    : Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            chatType,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  chatType == 'Cộng đồng'
                                      ? AppColors.primaryGreen
                                      : Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Công khai
                      DataCell(
                        Icon(
                          isPublic ? Icons.public : Icons.lock,
                          size: 20,
                          color:
                              isPublic ? AppColors.primaryGreen : Colors.grey,
                        ),
                      ),
                      // Thành viên
                      DataCell(
                        Row(
                          children: [
                            const Icon(
                              Icons.people,
                              size: 16,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(width: 4),
                            Text('${members.length}'),
                          ],
                        ),
                      ),
                      // Tin nhắn cuối
                      DataCell(
                        Text(
                          lastMessage.isNotEmpty
                              ? lastMessage
                              : 'Chưa có tin nhắn',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                lastMessage.isEmpty
                                    ? Colors.grey
                                    : Colors.black87,
                            fontStyle:
                                lastMessage.isEmpty
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                          ),
                        ),
                      ),
                      // Ngày tạo
                      DataCell(Text(dateStr)),
                      // Hành động
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.people, size: 18),
                              color: Colors.blue,
                              tooltip: 'Xem thành viên',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _showMembersDialog(chat),
                            ),
                            IconButton(
                              icon: const Icon(Icons.visibility, size: 18),
                              color: AppColors.primaryGreen,
                              tooltip: 'Xem chi tiết',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _showDetailDialog(chat),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              color: AppColors.error,
                              tooltip: 'Xóa',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _confirmDelete(chat),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
          ),
        ),
      ),
    );
  }

  void _showDetailDialog(Map<String, dynamic> chat) {
    final createdAt =
        chat['createdAt'] != null && chat['createdAt'] is Timestamp
            ? (chat['createdAt'] as Timestamp).toDate().toString()
            : '-';
    final lastMessageTime =
        chat['lastMessageTime'] != null && chat['lastMessageTime'] is Timestamp
            ? (chat['lastMessageTime'] as Timestamp).toDate().toString()
            : '-';
    final groupAvatar = chat['groupAvatar'] ?? '';
    final groupBackground = chat['groupBackground'] ?? '';
    // Fix: members và backgroundImages có thể là Map hoặc List
    final membersData = chat['members'];
    final members =
        membersData is List
            ? membersData
            : (membersData is Map ? membersData.keys.toList() : []);
    final backgroundImagesData = chat['backgroundImages'];
    final backgroundImages =
        backgroundImagesData is List ? backgroundImagesData : [];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.chat, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                const Expanded(child: Text('Chi tiết cuộc trò chuyện')),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ảnh đại diện và background
                    if (groupAvatar is String && groupAvatar.startsWith('http'))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                groupAvatar,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) => Container(
                                      width: 100,
                                      height: 100,
                                      color: Colors.grey.shade300,
                                      child: const Icon(
                                        Icons.broken_image,
                                        size: 32,
                                      ),
                                    ),
                              ),
                            ),
                            if (groupBackground is String &&
                                groupBackground.startsWith('http')) ...[
                              const SizedBox(width: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  groupBackground,
                                  width: 200,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) => Container(
                                        width: 200,
                                        height: 100,
                                        color: Colors.grey.shade300,
                                        child: const Icon(
                                          Icons.broken_image,
                                          size: 32,
                                        ),
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    _buildDetailRow('ID', chat['id']),
                    const Divider(),
                    _buildDetailRow('Tên nhóm', chat['groupName']),
                    _buildDetailRow('Loại', chat['chatType']),
                    _buildDetailRow(
                      'Công khai',
                      chat['isPublic'] == true ? 'Có' : 'Không',
                    ),
                    _buildDetailRow('Quản trị viên', chat['groupAdmin']),
                    const Divider(),
                    _buildDetailRow('Số thành viên', '${members.length}'),
                    if (members.isNotEmpty) ...[
                      const Text(
                        'Danh sách thành viên:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...members.take(10).map((memberId) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $memberId'),
                        );
                      }).toList(),
                      if (members.length > 10)
                        Text('... và ${members.length - 10} thành viên khác'),
                      const Divider(),
                    ],
                    _buildDetailRow('Tin nhắn cuối', chat['lastMessage']),
                    _buildDetailRow(
                      'Người gửi cuối',
                      chat['lastMessageSenderId'],
                    ),
                    _buildDetailRow('Thời gian tin nhắn cuối', lastMessageTime),
                    _buildDetailRow(
                      'Số ảnh trong tin nhắn cuối',
                      '${chat['lastMessageImageCount'] ?? 0}',
                    ),
                    const Divider(),
                    if (backgroundImages.isNotEmpty) ...[
                      const Text(
                        'Ảnh nền:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            backgroundImages.take(5).map((url) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  url.toString(),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) => Container(
                                        width: 80,
                                        height: 80,
                                        color: Colors.grey.shade300,
                                        child: const Icon(
                                          Icons.broken_image,
                                          size: 20,
                                        ),
                                      ),
                                ),
                              );
                            }).toList(),
                      ),
                      const Divider(),
                    ],
                    _buildDetailRow('Ngày tạo', createdAt),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(value?.toString() ?? 'N/A'),
        ],
      ),
    );
  }

  void _showMembersDialog(Map<String, dynamic> chat) {
    // Fix: members có thể là Map hoặc List
    final membersData = chat['members'];
    final memberIds =
        membersData is List
            ? List<String>.from(membersData)
            : (membersData is Map
                ? membersData.keys.map((k) => k.toString()).toList()
                : <String>[]);
    final groupAdmin = chat['groupAdmin']?.toString() ?? '';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.people, color: AppColors.primaryGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Thành viên - ${chat['groupName'] ?? 'Chat'}'),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 400,
              child:
                  memberIds.isEmpty
                      ? const Center(child: Text('Chưa có thành viên nào'))
                      : FutureBuilder<List<Map<String, dynamic>>>(
                        future: _loadMembersData(memberIds),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primaryGreen,
                              ),
                            );
                          }

                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(
                              child: Text('Không tải được dữ liệu thành viên'),
                            );
                          }

                          final members = snapshot.data!;
                          return ListView.builder(
                            itemCount: members.length,
                            itemBuilder: (context, index) {
                              final member = members[index];
                              final isAdmin = member['id'] == groupAdmin;

                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppColors.primaryGreen
                                      .withOpacity(0.2),
                                  child:
                                      member['avatarUrl'] != null &&
                                              member['avatarUrl']
                                                  .toString()
                                                  .startsWith('http')
                                          ? ClipOval(
                                            child: Image.network(
                                              member['avatarUrl'],
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              errorBuilder: (
                                                context,
                                                error,
                                                stackTrace,
                                              ) {
                                                return Text(
                                                  (member['name'] ?? '?')[0]
                                                      .toUpperCase(),
                                                  style: const TextStyle(
                                                    color:
                                                        AppColors.primaryGreen,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                );
                                              },
                                            ),
                                          )
                                          : Text(
                                            (member['name'] ?? '?')[0]
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              color: AppColors.primaryGreen,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                ),
                                title: Text(member['name'] ?? 'Không rõ'),
                                subtitle: Text(member['email'] ?? ''),
                                trailing:
                                    isAdmin
                                        ? Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryGreen
                                                .withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Text(
                                            'Admin',
                                            style: TextStyle(
                                              color: AppColors.primaryGreen,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        )
                                        : null,
                              );
                            },
                          );
                        },
                      ),
            ),
          ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadMembersData(
    List<String> memberIds,
  ) async {
    final members = <Map<String, dynamic>>[];

    for (var memberId in memberIds) {
      try {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(memberId)
                .get();

        if (userDoc.exists) {
          final data = userDoc.data()!;
          members.add({
            'id': memberId,
            'name': data['name'] ?? data['email'] ?? 'Không rõ',
            'email': data['email'] ?? '',
            'avatarUrl': data['avatarUrl'] ?? '',
          });
        }
      } catch (e) {
        print('Error loading member $memberId: $e');
      }
    }

    return members;
  }

  void _confirmDelete(Map<String, dynamic> chat) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bạn có chắc muốn xóa cuộc trò chuyện "${chat['groupName'] ?? 'Không có tên'}"?',
                ),
                const SizedBox(height: 12),
                const Text(
                  '⚠️ Hành động này không thể hoàn tác!',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tất cả tin nhắn trong chat cũng sẽ bị xóa.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  navigator.pop();

                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Đang xóa...'),
                        ],
                      ),
                      duration: Duration(seconds: 30),
                    ),
                  );

                  try {
                    await _adminService.deleteDocument('chats', chat['id']);
                    scaffoldMessenger.hideCurrentSnackBar();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('✅ Đã xóa cuộc trò chuyện!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadChats();
                  } catch (e) {
                    scaffoldMessenger.hideCurrentSnackBar();
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('❌ Lỗi: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Xóa'),
              ),
            ],
          ),
    );
  }
}
