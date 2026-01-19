import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:travel_social_app/utils/constants.dart';
import 'package:travel_social_app/utils/toast_helper.dart';
import '../users/users_management_page.dart';
import '../places/places_management_page.dart';

/// Navigate to Users Management Page
void navigateToUsersManagement(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const UsersManagementPage()),
  );
}

/// Navigate to Places Management Page
void navigateToPlacesManagement(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const PlacesManagementPage()),
  );
}

/// Show notification dialog (wrapper for compatibility)
void showAddNotificationDialog(BuildContext context) {
  // Capture ScaffoldMessenger from outer context BEFORE opening dialog
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  _showAddNotificationDialogInternal(context, scaffoldMessenger, () {});
}

Future<void> _showAddNotificationDialogInternal(
  BuildContext context,
  ScaffoldMessengerState scaffoldMessenger,
  VoidCallback onLoadNotifications,
) async {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  final imageUrlController = TextEditingController();
  final userSearchController = TextEditingController();
  String selectedType = 'system';
  String sendMode = 'all'; // 'all' hoặc 'specific'
  List<Map<String, dynamic>> allUsers = [];
  List<Map<String, dynamic>> filteredUsers = [];
  Set<String> selectedUserIds = {};
  bool isLoadingUsers = false;

  // Load danh sách users
  Future<void> loadUsers() async {
    isLoadingUsers = true;
    try {
      final usersSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .orderBy('name')
              .get();

      allUsers =
          usersSnapshot.docs.map((doc) {
            return {
              'id': doc.id,
              'name': doc.data()['name'] ?? doc.data()['email'] ?? 'Không rõ',
              'email': doc.data()['email'] ?? '',
              'avatarUrl': doc.data()['avatarUrl'] ?? '',
            };
          }).toList();
      filteredUsers = List.from(allUsers);
    } catch (e) {
      print('Error loading users: $e');
    }
    isLoadingUsers = false;
  }

  showDialog(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            // Load users lần đầu
            if (allUsers.isEmpty && !isLoadingUsers) {
              loadUsers().then((_) => setDialogState(() {}));
            }

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    Icons.notifications_active,
                    color: AppColors.primaryGreen,
                  ),
                  SizedBox(width: 12),
                  Text('Gửi thông báo'),
                ],
              ),
              content: SizedBox(
                width: 700,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Chọn chế độ gửi
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primaryGreen.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Người nhận:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            RadioListTile<String>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Gửi đến tất cả người dùng'),
                              value: 'all',
                              groupValue: sendMode,
                              activeColor: AppColors.primaryGreen,
                              onChanged:
                                  (value) =>
                                      setDialogState(() => sendMode = value!),
                            ),
                            RadioListTile<String>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Chọn người nhận cụ thể (${selectedUserIds.length} người)',
                              ),
                              value: 'specific',
                              groupValue: sendMode,
                              activeColor: AppColors.primaryGreen,
                              onChanged:
                                  (value) =>
                                      setDialogState(() => sendMode = value!),
                            ),
                          ],
                        ),
                      ),

                      // Hiển thị phần chọn users nếu chế độ là 'specific'
                      if (sendMode == 'specific') ...[
                        const SizedBox(height: 16),
                        // Search box
                        TextField(
                          controller: userSearchController,
                          decoration: InputDecoration(
                            labelText: 'Tìm kiếm người dùng',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: AppColors.primaryGreen,
                            ),
                            hintText: 'Nhập tên hoặc email...',
                            suffixIcon:
                                userSearchController.text.isNotEmpty
                                    ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        userSearchController.clear();
                                        setDialogState(() {
                                          filteredUsers = List.from(allUsers);
                                        });
                                      },
                                    )
                                    : null,
                          ),
                          onChanged: (value) {
                            setDialogState(() {
                              if (value.isEmpty) {
                                filteredUsers = List.from(allUsers);
                              } else {
                                final query = value.toLowerCase();
                                filteredUsers =
                                    allUsers.where((user) {
                                      final name =
                                          user['name'].toString().toLowerCase();
                                      final email =
                                          user['email']
                                              .toString()
                                              .toLowerCase();
                                      return name.contains(query) ||
                                          email.contains(query);
                                    }).toList();
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        // Action buttons
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  selectedUserIds =
                                      filteredUsers
                                          .map((u) => u['id'].toString())
                                          .toSet();
                                });
                              },
                              icon: const Icon(Icons.select_all, size: 18),
                              label: const Text('Chọn tất cả'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  selectedUserIds.clear();
                                });
                              },
                              icon: const Icon(Icons.clear_all, size: 18),
                              label: const Text('Bỏ chọn tất cả'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Danh sách users
                        Container(
                          height: 250,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              isLoadingUsers
                                  ? const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primaryGreen,
                                    ),
                                  )
                                  : filteredUsers.isEmpty
                                  ? const Center(
                                    child: Text('Không tìm thấy người dùng'),
                                  )
                                  : ListView.builder(
                                    itemCount: filteredUsers.length,
                                    itemBuilder: (context, index) {
                                      final user = filteredUsers[index];
                                      final isSelected = selectedUserIds
                                          .contains(user['id']);

                                      return CheckboxListTile(
                                        dense: true,
                                        value: isSelected,
                                        activeColor: AppColors.primaryGreen,
                                        onChanged: (checked) {
                                          setDialogState(() {
                                            if (checked == true) {
                                              selectedUserIds.add(user['id']);
                                            } else {
                                              selectedUserIds.remove(
                                                user['id'],
                                              );
                                            }
                                          });
                                        },
                                        title: Text(
                                          user['name'],
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        subtitle: Text(
                                          user['email'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        secondary:
                                            user['avatarUrl']
                                                        ?.toString()
                                                        .isNotEmpty ==
                                                    true
                                                ? CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor: AppColors
                                                      .primaryGreen
                                                      .withOpacity(0.2),
                                                  child: ClipOval(
                                                    child: Image.network(
                                                      user['avatarUrl'],
                                                      width: 36,
                                                      height: 36,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) {
                                                        return Text(
                                                          user['name']
                                                                  .toString()
                                                                  .isNotEmpty
                                                              ? user['name']
                                                                  .toString()[0]
                                                                  .toUpperCase()
                                                              : '?',
                                                          style: const TextStyle(
                                                            color:
                                                                AppColors
                                                                    .primaryGreen,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                )
                                                : CircleAvatar(
                                                  backgroundColor: AppColors
                                                      .primaryGreen
                                                      .withOpacity(0.2),
                                                  radius: 18,
                                                  child: Text(
                                                    user['name']
                                                            .toString()
                                                            .isNotEmpty
                                                        ? user['name']
                                                            .toString()[0]
                                                            .toUpperCase()
                                                        : '?',
                                                    style: const TextStyle(
                                                      color:
                                                          AppColors
                                                              .primaryGreen,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                      );
                                    },
                                  ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Loại thông báo',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'system',
                            child: Text('Hệ thống'),
                          ),
                          DropdownMenuItem(
                            value: 'like',
                            child: Text('Lượt thích'),
                          ),
                          DropdownMenuItem(
                            value: 'comment',
                            child: Text('Bình luận'),
                          ),
                          DropdownMenuItem(
                            value: 'friend_request',
                            child: Text('Kết bạn'),
                          ),
                          DropdownMenuItem(
                            value: 'review',
                            child: Text('Đánh giá'),
                          ),
                          DropdownMenuItem(
                            value: 'post',
                            child: Text('Bài viết'),
                          ),
                        ],
                        onChanged:
                            (value) =>
                                setDialogState(() => selectedType = value!),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Tiêu đề *',
                          border: OutlineInputBorder(),
                          hintText: 'Nhập tiêu đề thông báo...',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: contentController,
                        decoration: const InputDecoration(
                          labelText: 'Nội dung *',
                          border: OutlineInputBorder(),
                          hintText: 'Nhập nội dung thông báo...',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: imageUrlController,
                        decoration: const InputDecoration(
                          labelText: 'URL hình ảnh (tùy chọn)',
                          border: OutlineInputBorder(),
                          hintText: 'https://...',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Validate inputs first
                    if (titleController.text.trim().isEmpty ||
                        contentController.text.trim().isEmpty) {
                      if (!context.mounted) return;
                      ToastHelper.showWarning(
                        context,
                        'Vui lòng điền tiêu đề và nội dung',
                      );
                      return;
                    }

                    if (sendMode == 'specific' && selectedUserIds.isEmpty) {
                      if (!context.mounted) return;
                      ToastHelper.showWarning(
                        context,
                        'Vui lòng chọn ít nhất 1 người nhận',
                      );
                      return;
                    }

                    // Capture navigator before async operations
                    if (!context.mounted) return;
                    final navigator = Navigator.of(context);

                    // Show modal loading dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder:
                          (_) => Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(
                                  color: AppColors.primaryGreen,
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    sendMode == 'all'
                                        ? 'Đang gửi thông báo đến tất cả người dùng...'
                                        : 'Đang gửi thông báo đến ${selectedUserIds.length} người dùng...',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    );

                    try {
                      print('🚀 [NOTIF] Bắt đầu gửi thông báo...');
                      print('📊 [NOTIF] Send mode: $sendMode');
                      print('📋 [NOTIF] Type: $selectedType');
                      print('📝 [NOTIF] Title: ${titleController.text.trim()}');

                      var batch = FirebaseFirestore.instance.batch();
                      int count = 0;
                      int batchCount = 0;

                      // Lấy danh sách user IDs cần gửi
                      List<String> targetUserIds;
                      if (sendMode == 'all') {
                        print('👥 [NOTIF] Lấy tất cả users...');
                        final usersSnapshot =
                            await FirebaseFirestore.instance
                                .collection('users')
                                .get();
                        targetUserIds =
                            usersSnapshot.docs.map((doc) => doc.id).toList();
                        print(
                          '✅ [NOTIF] Tìm thấy ${targetUserIds.length} users',
                        );
                      } else {
                        targetUserIds = selectedUserIds.toList();
                        print(
                          '👤 [NOTIF] Gửi đến ${targetUserIds.length} users đã chọn',
                        );
                      }

                      print('📤 [NOTIF] Bắt đầu tạo notifications...');

                      // Tạo notifications cho từng user
                      for (var userId in targetUserIds) {
                        final notificationData = {
                          'userId': userId,
                          'type': selectedType,
                          'title': titleController.text.trim(),
                          'body': contentController.text.trim(),
                          'imageUrl':
                              imageUrlController.text.trim().isNotEmpty
                                  ? imageUrlController.text.trim()
                                  : null,
                          'isRead': false,
                          'createdAt': FieldValue.serverTimestamp(),
                        };

                        final docRef =
                            FirebaseFirestore.instance
                                .collection('notifications')
                                .doc();
                        batch.set(docRef, notificationData);
                        count++;
                        batchCount++;

                        // Commit batch mỗi 500 documents và tạo batch mới
                        if (batchCount >= 500) {
                          print(
                            '💾 [NOTIF] Commit batch tại count=$count, batchCount=$batchCount',
                          );
                          await batch.commit();
                          print('✅ [NOTIF] Batch committed thành công');
                          batch = FirebaseFirestore.instance.batch();
                          batchCount = 0;
                          print('🔄 [NOTIF] Tạo batch mới');
                        }
                      }

                      // Commit batch cuối cùng nếu còn
                      if (batchCount > 0) {
                        print(
                          '💾 [NOTIF] Commit batch cuối cùng, batchCount=$batchCount',
                        );
                        await batch.commit();
                        print('✅ [NOTIF] Batch cuối committed thành công');
                      }

                      print('🎉 [NOTIF] Hoàn thành! Đã gửi $count thông báo');

                      // Close loading dialog
                      if (!context.mounted) return;
                      navigator.pop(); // close loading dialog

                      // Close the send notification dialog
                      navigator.pop(); // close main dialog

                      ToastHelper.showSuccess(
                        context,
                        '✅ Đã gửi thông báo đến $count người dùng!',
                      );
                      onLoadNotifications();
                    } catch (e, stackTrace) {
                      print('❌ [NOTIF] LỖI: ${e.toString()}');
                      print('📋 [NOTIF] Stack trace: $stackTrace');

                      // Close loading dialog on error
                      if (!context.mounted) return;
                      navigator.pop(); // close loading dialog

                      ToastHelper.showError(context, '❌ Lỗi: ${e.toString()}');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                  ),
                  child: const Text('Gửi'),
                ),
              ],
            );
          },
        ),
  );
}
