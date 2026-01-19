import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../../services/admin_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/toast_helper.dart';

class CommunitiesManagementPage extends StatefulWidget {
  const CommunitiesManagementPage({super.key});

  @override
  State<CommunitiesManagementPage> createState() =>
      _CommunitiesManagementPageState();
}

class _CommunitiesManagementPageState extends State<CommunitiesManagementPage> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _communities = [];
  Map<String, String> _adminNames = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCommunities();
  }

  Future<void> _loadCommunities() async {
    setState(() => _isLoading = true);
    try {
      final communities = await _adminService.getCollectionData(
        'communities',
        limit: 200,
      );

      // Load admin names
      final adminIds =
          communities
              .map((c) => c['adminId']?.toString())
              .where((id) => id != null && id.isNotEmpty)
              .toSet();

      final adminNames = <String, String>{};
      for (var adminId in adminIds) {
        try {
          final userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(adminId)
                  .get();
          if (userDoc.exists) {
            final userData = userDoc.data();
            adminNames[adminId!] =
                userData?['name'] ?? userData?['email'] ?? 'Admin';
          }
        } catch (e) {
          print('Error loading admin $adminId: $e');
        }
      }

      setState(() {
        _communities = communities;
        _adminNames = adminNames;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastHelper.showError(context, 'Lỗi tải dữ liệu: $e');
      }
    }
  }

  List<Map<String, dynamic>> get _filteredCommunities {
    if (_searchQuery.isEmpty) return _communities;
    return _communities.where((community) {
      final name = (community['name'] ?? '').toString().toLowerCase();
      final description =
          (community['description'] ?? '').toString().toLowerCase();
      final adminId = community['adminId']?.toString() ?? '';
      final adminName = (_adminNames[adminId] ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          description.contains(query) ||
          adminName.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getSurfaceColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        title: const Text('Quản lý Cộng đồng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCommunities,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEditDialog,
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add),
        label: const Text('Tạo cộng đồng'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm kiếm theo tên, mô tả, admin...',
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
                    : _filteredCommunities.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.groups,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Không có cộng đồng nào',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : _buildDataTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(
        AppSizes.radius(context, SizeCategory.medium),
      ),
      color: AppTheme.getSurfaceColor(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
        child: DataTable2(
          columnSpacing: 12,
          horizontalMargin: 12,
          minWidth: 1400,
          headingRowColor: MaterialStateProperty.all(
            AppColors.primaryGreen.withOpacity(0.15),
          ),
          headingTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.getTextPrimaryColor(context),
            fontSize: AppSizes.font(context, SizeCategory.medium),
          ),
          dataTextStyle: TextStyle(
            fontSize: AppSizes.font(context, SizeCategory.medium),
            color: AppTheme.getTextPrimaryColor(context),
          ),
          columns: const [
            DataColumn2(label: Text('Ảnh'), size: ColumnSize.S, fixedWidth: 60),
            DataColumn2(label: Text('Tên cộng đồng'), size: ColumnSize.L),
            DataColumn2(label: Text('Admin'), size: ColumnSize.M),
            DataColumn2(
              label: Text('Thành viên'),
              size: ColumnSize.S,
              fixedWidth: 100,
            ),
            DataColumn2(
              label: Text('Bài viết'),
              size: ColumnSize.S,
              fixedWidth: 80,
            ),
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
              _filteredCommunities.asMap().entries.map((entry) {
                final index = entry.key;
                final community = entry.value;
                final createdAt = community['createdAt'];
                final dateStr =
                    createdAt is Timestamp
                        ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
                        : '-';
                final avatarUrl = community['avatarUrl']?.toString() ?? '';
                final adminId = community['adminId']?.toString() ?? '';
                final adminName = _adminNames[adminId] ?? 'Không rõ';

                return DataRow(
                  color: MaterialStateProperty.all(
                    index.isEven
                        ? AppTheme.getInputBackgroundColor(context)
                        : null,
                  ),
                  cells: [
                    DataCell(_buildAvatar(avatarUrl)),
                    DataCell(
                      Text(
                        community['name'] ?? '-',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DataCell(
                      Text(
                        adminName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          const Icon(
                            Icons.people,
                            size: 16,
                            color: AppColors.primaryGreen,
                          ),
                          const SizedBox(width: 4),
                          Text('${community['memberCount'] ?? 0}'),
                        ],
                      ),
                    ),
                    DataCell(Text('${community['postCount'] ?? 0}')),
                    DataCell(Text(dateStr)),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.people, size: 18),
                            color: Colors.blue,
                            tooltip: 'Xem thành viên',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed: () => _showMembersDialog(community),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            color: Colors.orange,
                            tooltip: 'Sửa',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed:
                                () => _showAddEditDialog(community: community),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            color: AppColors.error,
                            tooltip: 'Xóa',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed: () => _confirmDelete(community),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildAvatar(String avatarUrl) {
    if (avatarUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          avatarUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _defaultAvatar(),
        ),
      );
    }
    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.groups, size: 24, color: AppColors.primaryGreen),
    );
  }

  void _showAddEditDialog({Map<String, dynamic>? community}) {
    final isEdit = community != null;
    final nameController = TextEditingController(
      text: community?['name'] ?? '',
    );
    final descriptionController = TextEditingController(
      text: community?['description'] ?? '',
    );
    String? avatarUrl = community?['avatarUrl'];
    String? coverImageUrl = community?['coverImageUrl'];
    Uint8List? avatarImageBytes;
    Uint8List? coverImageBytes;
    String? selectedAdminId = community?['adminId'];
    List<String> allUserIds = [];
    Map<String, String> allUserNames = {};
    bool isLoadingUsers = false;

    Future<void> loadUsers() async {
      isLoadingUsers = true;
      try {
        final usersSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .orderBy('name')
                .get();

        allUserIds = usersSnapshot.docs.map((doc) => doc.id).toList();
        allUserNames = {
          for (var doc in usersSnapshot.docs)
            doc.id: doc.data()['name'] ?? doc.data()['email'] ?? 'Không rõ',
        };
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
              if (allUserIds.isEmpty && !isLoadingUsers) {
                loadUsers().then((_) => setDialogState(() {}));
              }

              return AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.groups, color: AppColors.primaryGreen),
                    const SizedBox(width: 12),
                    Text(isEdit ? 'Sửa cộng đồng' : 'Tạo cộng đồng mới'),
                  ],
                ),
                content: SizedBox(
                  width: 600,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        const Text(
                          'Ảnh đại diện *',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final ImagePicker picker = ImagePicker();
                            final XFile? image = await picker.pickImage(
                              source: ImageSource.gallery,
                            );
                            if (image != null) {
                              final bytes = await image.readAsBytes();
                              setDialogState(() {
                                avatarImageBytes = bytes;
                              });
                            }
                          },
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child:
                                avatarImageBytes != null
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.memory(
                                        avatarImageBytes!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                    : avatarUrl != null &&
                                        avatarUrl.startsWith('http')
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        avatarUrl,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                    : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate,
                                          size: 40,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Chọn ảnh',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Cover Image
                        const Text(
                          'Ảnh bìa (tùy chọn)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final ImagePicker picker = ImagePicker();
                            final XFile? image = await picker.pickImage(
                              source: ImageSource.gallery,
                            );
                            if (image != null) {
                              final bytes = await image.readAsBytes();
                              setDialogState(() {
                                coverImageBytes = bytes;
                              });
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            height: 120,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child:
                                coverImageBytes != null
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.memory(
                                        coverImageBytes!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                    : coverImageUrl != null &&
                                        coverImageUrl.startsWith('http')
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        coverImageUrl,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                    : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate,
                                          size: 40,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Chọn ảnh bìa',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Tên cộng đồng
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Tên cộng đồng *',
                            border: OutlineInputBorder(),
                            hintText: 'Nhập tên cộng đồng...',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Mô tả
                        TextField(
                          controller: descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Mô tả *',
                            border: OutlineInputBorder(),
                            hintText: 'Nhập mô tả cộng đồng...',
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),

                        // Admin
                        DropdownButtonFormField<String>(
                          value: selectedAdminId,
                          decoration: const InputDecoration(
                            labelText: 'Admin *',
                            border: OutlineInputBorder(),
                          ),
                          items:
                              allUserIds.map((userId) {
                                return DropdownMenuItem(
                                  value: userId,
                                  child: Text(
                                    allUserNames[userId] ?? userId,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                          onChanged:
                              (value) =>
                                  setDialogState(() => selectedAdminId = value),
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
                      if (nameController.text.trim().isEmpty ||
                          descriptionController.text.trim().isEmpty ||
                          selectedAdminId == null) {
                        ToastHelper.showWarning(
                          context,
                          'Vui lòng điền đầy đủ thông tin bắt buộc',
                        );
                        return;
                      }

                      if (!isEdit &&
                          avatarImageBytes == null &&
                          (avatarUrl == null ||
                              !avatarUrl.startsWith('http'))) {
                        ToastHelper.showWarning(
                          context,
                          'Vui lòng chọn ảnh đại diện',
                        );
                        return;
                      }

                      final navigator = Navigator.of(context);
                      navigator.pop();

                      if (!mounted) return;

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
                                      isEdit
                                          ? 'Đang cập nhật...'
                                          : 'Đang tạo cộng đồng...',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      );

                      try {
                        // Debug: Check auth status
                        final currentUser = FirebaseAuth.instance.currentUser;
                        print('🔍 Current user: ${currentUser?.uid}');
                        print('🔍 User email: ${currentUser?.email}');

                        if (currentUser == null) {
                          throw Exception('User not authenticated');
                        }

                        String? finalAvatarUrl = avatarUrl;
                        String? finalCoverUrl = coverImageUrl;

                        // Upload avatar nếu có
                        if (avatarImageBytes != null) {
                          print('📤 Uploading avatar...');
                          final storageRef = FirebaseStorage.instance.ref().child(
                            'communities/${DateTime.now().millisecondsSinceEpoch}_avatar.jpg',
                          );

                          final metadata = SettableMetadata(
                            contentType: 'image/jpeg',
                            customMetadata: {'uploadedBy': currentUser.uid},
                          );

                          await storageRef.putData(avatarImageBytes!, metadata);
                          finalAvatarUrl = await storageRef.getDownloadURL();
                          print('✅ Avatar uploaded: $finalAvatarUrl');
                        }

                        // Upload cover nếu có
                        if (coverImageBytes != null) {
                          print('📤 Uploading cover...');
                          final storageRef = FirebaseStorage.instance.ref().child(
                            'communities/${DateTime.now().millisecondsSinceEpoch}_cover.jpg',
                          );

                          final metadata = SettableMetadata(
                            contentType: 'image/jpeg',
                            customMetadata: {'uploadedBy': currentUser.uid},
                          );

                          await storageRef.putData(coverImageBytes!, metadata);
                          finalCoverUrl = await storageRef.getDownloadURL();
                          print('✅ Cover uploaded: $finalCoverUrl');
                        }

                        final data = {
                          'name': nameController.text.trim(),
                          'description': descriptionController.text.trim(),
                          'adminId': selectedAdminId!,
                          'avatarUrl': finalAvatarUrl,
                          'coverImageUrl': finalCoverUrl,
                          'memberIds':
                              isEdit
                                  ? community['memberIds'] ?? [selectedAdminId]
                                  : [selectedAdminId],
                          'memberCount':
                              isEdit ? community['memberCount'] ?? 1 : 1,
                          'postCount': isEdit ? community['postCount'] ?? 0 : 0,
                          'rules': isEdit ? community['rules'] ?? [] : [],
                          'tourismTypes':
                              isEdit ? community['tourismTypes'] ?? [] : [],
                          'updatedAt': FieldValue.serverTimestamp(),
                        };

                        if (isEdit) {
                          await FirebaseFirestore.instance
                              .collection('communities')
                              .doc(community['id'])
                              .update(data);
                        } else {
                          data['createdAt'] = FieldValue.serverTimestamp();
                          await FirebaseFirestore.instance
                              .collection('communities')
                              .add(data);
                        }

                        if (!mounted) return;
                        navigator.pop(); // close loading dialog

                        ToastHelper.showSuccess(
                          context,
                          isEdit
                              ? '✅ Đã cập nhật cộng đồng!'
                              : '✅ Đã tạo cộng đồng mới!',
                        );
                        _loadCommunities();
                      } catch (e) {
                        if (!mounted) return;
                        navigator.pop(); // close loading dialog

                        ToastHelper.showError(
                          context,
                          '❌ Lỗi: ${e.toString()}',
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                    ),
                    child: Text(isEdit ? 'Cập nhật' : 'Tạo mới'),
                  ),
                ],
              );
            },
          ),
    );
  }

  void _showMembersDialog(Map<String, dynamic> community) {
    final memberIds = List<String>.from(community['memberIds'] ?? []);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.people, color: AppColors.primaryGreen),
                const SizedBox(width: 12),
                Expanded(child: Text('Thành viên - ${community['name']}')),
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
                              final isAdmin =
                                  member['id'] == community['adminId'];

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
                                                // Fallback khi load ảnh lỗi (429, etc.)
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

  void _confirmDelete(Map<String, dynamic> community) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bạn có chắc muốn xóa cộng đồng "${community['name']}"?'),
                const SizedBox(height: 12),
                const Text(
                  '⚠️ Hành động này không thể hoàn tác!',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
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
                    await _adminService.deleteDocument(
                      'communities',
                      community['id'],
                    );
                    scaffoldMessenger.hideCurrentSnackBar();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('✅ Đã xóa cộng đồng!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadCommunities();
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
