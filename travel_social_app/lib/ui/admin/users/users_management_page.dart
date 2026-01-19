import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/admin_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/toast_helper.dart';

/// Trang quản lý Users với tích hợp Firebase Auth
class UsersManagementPage extends StatefulWidget {
  const UsersManagementPage({super.key});

  @override
  State<UsersManagementPage> createState() => _UsersManagementPageState();
}

class _UsersManagementPageState extends State<UsersManagementPage> {
  final AdminService _adminService = AdminService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _adminService.getCollectionData('users', limit: 200);
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastHelper.showError(context, 'Lỗi tải dữ liệu: $e');
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((user) {
      final name = (user['name'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final role = (user['role'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          email.contains(query) ||
          role.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text(
          'Quản lý Users',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.person_add),
        label: const Text('Thêm User'),
      ),
      body: Padding(
        padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 16),
            Expanded(
              child:
                  _isLoading
                      ? Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryGreen,
                        ),
                      )
                      : _buildUsersTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Tìm kiếm theo tên, email hoặc role...',
        prefixIcon: Icon(Icons.search, color: AppColors.primaryGreen),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
        ),
        filled: true,
        fillColor: AppTheme.getSurfaceColor(context),
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }

  Widget _buildUsersTable() {
    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Không có user nào',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DataTable2(
          columnSpacing: 12,
          horizontalMargin: 12,
          minWidth: 1400,
          headingRowColor: MaterialStateProperty.all(
            AppColors.primaryGreen.withOpacity(0.2),
          ),
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 15,
          ),
          columns: const [
            DataColumn2(
              label: Text('Ảnh đại diện'),
              size: ColumnSize.S,
              fixedWidth: 70,
            ),
            DataColumn2(label: Text('Tên'), size: ColumnSize.L),
            DataColumn2(label: Text('Email'), size: ColumnSize.L),
            DataColumn2(
              label: Text('Vai trò'),
              size: ColumnSize.S,
              fixedWidth: 100,
            ),
            DataColumn2(
              label: Text('Hạng'),
              size: ColumnSize.S,
              fixedWidth: 100,
            ),
            DataColumn2(
              label: Text('Level'),
              size: ColumnSize.S,
              fixedWidth: 80,
            ),
            DataColumn2(
              label: Text('Điểm'),
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
              size: ColumnSize.S,
              fixedWidth: 150,
            ),
          ],
          rows:
              _filteredUsers.asMap().entries.map((entry) {
                final index = entry.key;
                final user = entry.value;

                final createdAt = user['createdAt'];
                final createdAtStr =
                    createdAt != null && createdAt is Timestamp
                        ? '${createdAt.toDate().day.toString().padLeft(2, '0')}/${createdAt.toDate().month.toString().padLeft(2, '0')}/${createdAt.toDate().year}'
                        : '-';

                // Lấy tên badge/hạng
                String rank = '-';
                if (user['currentBadge'] != null &&
                    user['currentBadge'] is Map &&
                    user['currentBadge']['name'] != null) {
                  rank = user['currentBadge']['name'];
                }

                return DataRow(
                  color: MaterialStateProperty.resolveWith<Color?>(
                    (states) => index.isEven ? Colors.grey.shade50 : null,
                  ),
                  cells: [
                    // Avatar
                    DataCell(
                      user['avatarUrl'] != null &&
                              user['avatarUrl'].toString().isNotEmpty
                          ? CircleAvatar(
                            radius: 20,
                            child: ClipOval(
                              child: Image.network(
                                user['avatarUrl'],
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 40,
                                    height: 40,
                                    color: AppColors.primaryGreen,
                                    child: Center(
                                      child: Text(
                                        (user['name'] ?? 'U')
                                            .toString()[0]
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                loadingBuilder: (
                                  context,
                                  child,
                                  loadingProgress,
                                ) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    width: 40,
                                    height: 40,
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          )
                          : CircleAvatar(
                            backgroundColor: AppColors.primaryGreen,
                            child: Text(
                              (user['name'] ?? 'U').toString()[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                    ),
                    // Tên
                    DataCell(
                      Text(
                        user['name'] ?? '-',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Email
                    DataCell(
                      Text(
                        user['email'] ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Vai trò
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              user['role'] == 'admin'
                                  ? Colors.red.shade100
                                  : Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          user['role'] == 'admin' ? 'Admin' : 'User',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color:
                                user['role'] == 'admin'
                                    ? Colors.red.shade700
                                    : Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ),
                    // Hạng
                    DataCell(Text(rank)),
                    // Level
                    DataCell(Text('${user['level'] ?? 1}')),
                    // Điểm
                    DataCell(Text('${user['totalPoints'] ?? 0}')),
                    // Ngày tạo
                    DataCell(Text(createdAtStr)),
                    // Hành động
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility, size: 18),
                            color: AppColors.primaryGreen,
                            tooltip: 'Xem',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed: () => _showUserDetailDialog(user),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            color: Colors.blue,
                            tooltip: 'Sửa',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed: () => _showEditUserDialog(user),
                          ),
                          IconButton(
                            icon: const Icon(Icons.lock_reset, size: 18),
                            color: Colors.orange,
                            tooltip: 'Reset password',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed: () => _resetPassword(user),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            color: Colors.red,
                            tooltip: 'Xóa',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed: () => _confirmDeleteUser(user),
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

  void _showAddUserDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'user';

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Thêm User Mới'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên người dùng *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password (tối thiểu 6 ký tự) *',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    StatefulBuilder(
                      builder: (context, setDialogState) {
                        return DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Vai trò',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'user',
                              child: Text('User'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Admin'),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() => selectedRole = value!);
                          },
                        );
                      },
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
                  if (nameController.text.isEmpty ||
                      emailController.text.isEmpty ||
                      passwordController.text.isEmpty) {
                    if (!mounted) return;
                    ToastHelper.showWarning(
                      context,
                      'Vui lòng nhập đầy đủ thông tin',
                    );
                    return;
                  }
                  if (passwordController.text.length < 6) {
                    if (!mounted) return;
                    ToastHelper.showWarning(
                      context,
                      'Password phải có ít nhất 6 ký tự',
                    );
                    return;
                  }
                  final navigator = Navigator.of(context);
                  Navigator.of(dialogContext).pop();

                  if (!mounted) return;

                  // Show loading dialog while creating user
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (context) =>
                            const Center(child: CircularProgressIndicator()),
                  );
                  try {
                    final userCredential = await _auth
                        .createUserWithEmailAndPassword(
                          email: emailController.text.trim(),
                          password: passwordController.text.trim(),
                        );
                    final userId = userCredential.user!.uid;
                    await _firestore.collection('users').doc(userId).set({
                      'name': nameController.text.trim(),
                      'email': emailController.text.trim(),
                      'role': selectedRole,
                      'totalPoints': 0,
                      'level': 1,
                      'currentBadge': {
                        'badgeId': 'newbie',
                        'color': '#A0D8B3',
                        'description': 'Chào mừng đến với cộng đồng',
                        'icon': '🌱',
                        'level': 1,
                        'name': 'Người mới',
                        'requiredPoints': 0,
                      },
                      'bio': '',
                      'avatarUrl': '',
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    if (!mounted) return;
                    navigator.pop(); // close loading
                    ToastHelper.showSuccess(context, 'Tạo user thành công');
                    _loadUsers();
                  } catch (e) {
                    if (!mounted) return;
                    navigator.pop();
                    ToastHelper.showError(context, 'Lỗi: ${e.toString()}');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                ),
                child: const Text('Tạo'),
              ),
            ],
          ),
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final nameController = TextEditingController(text: user['name']);
    final bioController = TextEditingController(text: user['bio']);
    final phoneController = TextEditingController(text: user['phoneNumber']);
    String selectedRole = user['role'] ?? 'user';

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Chỉnh sửa User'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên người dùng',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: bioController,
                      decoration: const InputDecoration(
                        labelText: 'Giới thiệu',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    StatefulBuilder(
                      builder: (context, setDialogState) {
                        return DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Vai trò',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'user',
                              child: Text('User'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Admin'),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() => selectedRole = value!);
                          },
                        );
                      },
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
                  final navigator = Navigator.of(context);
                  Navigator.of(dialogContext).pop();

                  if (!mounted) return;

                  // Show loading dialog while updating
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (context) =>
                            const Center(child: CircularProgressIndicator()),
                  );
                  try {
                    await _firestore.collection('users').doc(user['id']).update({
                      'name': nameController.text.trim(),
                      'bio': bioController.text.trim(),
                      'phoneNumber': phoneController.text.trim(),
                      'role': selectedRole,
                      // Nếu muốn cho phép chỉnh sửa level, totalPoints, currentBadge thì thêm vào đây
                    });
                    if (!mounted) return;
                    navigator.pop();
                    ToastHelper.showSuccess(context, 'Cập nhật thành công');
                    _loadUsers();
                  } catch (e) {
                    if (!mounted) return;
                    navigator.pop();
                    ToastHelper.showError(context, 'Lỗi: ${e.toString()}');
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text('Cập nhật'),
              ),
            ],
          ),
    );
  }

  void _showUserDetailDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                if (user['avatarUrl'] != null &&
                    user['avatarUrl'].toString().isNotEmpty)
                  CircleAvatar(
                    backgroundImage: NetworkImage(user['avatarUrl']),
                    radius: 25,
                  )
                else
                  CircleAvatar(
                    backgroundColor: AppColors.primaryGreen,
                    child: Text((user['name'] ?? 'U')[0].toUpperCase()),
                    radius: 25,
                  ),
                const SizedBox(width: 12),
                Expanded(child: Text(user['name'] ?? 'User')),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('ID', user['id']),
                    _buildDetailRow('Email', user['email']),
                    _buildDetailRow('Vai trò', user['role']),
                    _buildDetailRow('Hạng', user['rank']),
                    _buildDetailRow('Điểm', user['points']?.toString()),
                    _buildDetailRow('SĐT', user['phoneNumber']),
                    _buildDetailRow('Giới thiệu', user['bio']),
                    _buildDetailRow('Ngày sinh', user['dateBirth']?.toString()),
                    _buildDetailRow(
                      'Ngày tạo',
                      user['createdAt'] is Timestamp
                          ? (user['createdAt'] as Timestamp).toDate().toString()
                          : user['createdAt']?.toString(),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
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
          Text(value ?? 'N/A'),
        ],
      ),
    );
  }

  Future<void> _resetPassword(Map<String, dynamic> user) async {
    final email = user['email']?.toString();
    if (email == null || email.isEmpty) {
      if (!mounted) return;
      ToastHelper.showWarning(context, 'User không có email');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset Password'),
            content: Text('Gửi email reset password đến $email?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Gửi'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      if (!mounted) return;

      final navigator = Navigator.of(context);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await _auth.sendPasswordResetEmail(email: email);
        if (!mounted) return;
        navigator.pop();
        ToastHelper.showSuccess(
          context,
          'Đã gửi email reset password đến $email',
        );
      } catch (e) {
        if (!mounted) return;
        navigator.pop();
        ToastHelper.showError(context, 'Lỗi: ${e.toString()}');
      }
    }
  }

  void _confirmDeleteUser(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bạn có chắc muốn xóa user ${user['name']}?'),
                const SizedBox(height: 12),
                const Text(
                  '⚠️ Chú ý: Chỉ xóa dữ liệu Firestore. Tài khoản Auth vẫn còn!',
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
                  final navigator = Navigator.of(context);

                  navigator.pop();

                  if (!mounted) return;

                  // Show loading
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (context) =>
                            const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    await _adminService.deleteDocument('users', user['id']);
                    if (!mounted) return;
                    navigator.pop();
                    ToastHelper.showSuccess(context, 'Xóa thành công');
                    _loadUsers();
                  } catch (e) {
                    if (!mounted) return;
                    navigator.pop();
                    ToastHelper.showError(context, 'Lỗi: ${e.toString()}');
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
