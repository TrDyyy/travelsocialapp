import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/admin_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/toast_helper.dart';

class PostsManagementPage extends StatefulWidget {
  const PostsManagementPage({super.key});

  @override
  State<PostsManagementPage> createState() => _PostsManagementPageState();
}

class _PostsManagementPageState extends State<PostsManagementPage> {
  final AdminService _adminService = AdminService();
  final ImagePicker _imagePicker = ImagePicker();
  List<Map<String, dynamic>> _posts = [];
  Map<String, String> _userNames = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      final posts = await _adminService.getCollectionData('posts', limit: 200);

      // Load user names
      final userIds =
          posts
              .map((p) => p['userId']?.toString())
              .where((id) => id != null && id.isNotEmpty)
              .toSet();

      final userNames = <String, String>{};
      for (var userId in userIds) {
        try {
          final userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .get();
          if (userDoc.exists) {
            final userData = userDoc.data();
            userNames[userId!] =
                userData?['name'] ??
                userData?['displayName'] ??
                userData?['email'] ??
                'Người dùng';
          }
        } catch (e) {
          print('Error loading user $userId: $e');
        }
      }

      setState(() {
        _posts = posts;
        _userNames = userNames;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastHelper.showError(context, 'Lỗi tải dữ liệu: $e');
      }
    }
  }

  List<Map<String, dynamic>> get _filteredPosts {
    if (_searchQuery.isEmpty) return _posts;
    return _posts.where((post) {
      final content = (post['content'] ?? '').toString().toLowerCase();
      final userId = post['userId']?.toString() ?? '';
      final userName = (_userNames[userId] ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return content.contains(query) || userName.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getSurfaceColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        title: const Text('Quản lý bài viết'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPosts),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm kiếm theo người đăng, nội dung...',
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
                    : _filteredPosts.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.article_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Không có bài viết nào',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add),
        label: const Text('Tạo bài viết'),
      ),
    );
  }

  Widget _buildDataTable() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: DataTable2(
            columnSpacing: 12,
            horizontalMargin: 12,
            minWidth: 1200,
            headingRowColor: WidgetStateProperty.all(
              AppColors.primaryGreen.withOpacity(0.2),
            ),
            headingTextStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontSize: 15,
            ),
            columns: const [
              DataColumn2(label: Text('Người đăng'), size: ColumnSize.M),
              DataColumn2(
                label: Text('Loại bài'),
                size: ColumnSize.S,
                fixedWidth: 110,
              ),
              DataColumn2(label: Text('Nội dung'), size: ColumnSize.L),
              DataColumn2(
                label: Text('Hình ảnh'),
                size: ColumnSize.S,
                fixedWidth: 70,
              ),
              DataColumn2(
                label: Text('Lượt thích'),
                size: ColumnSize.S,
                fixedWidth: 100,
              ),
              DataColumn2(
                label: Text('Bình luận'),
                size: ColumnSize.S,
                fixedWidth: 100,
              ),
              DataColumn2(
                label: Text('Ngày tạo'),
                size: ColumnSize.S,
                fixedWidth: 110,
              ),
              DataColumn2(
                label: Text('Hành động'),
                size: ColumnSize.S,
                fixedWidth: 150,
              ),
            ],
            rows:
                _filteredPosts.asMap().entries.map((entry) {
                  final index = entry.key;
                  final post = entry.value;
                  final userId = post['userId']?.toString() ?? '';
                  final userName = _userNames[userId] ?? 'Không rõ';
                  final postType = post['postType'] ?? 'normal';
                  final images = post['images'] as List<dynamic>? ?? [];
                  final likeCount = post['likeCount'] ?? 0;
                  final commentCount = post['commentCount'] ?? 0;
                  final createdAt = post['createdAt'];

                  String dateStr = '-';
                  if (createdAt is Timestamp) {
                    final date = createdAt.toDate();
                    dateStr =
                        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                  }

                  return DataRow(
                    color: MaterialStateProperty.resolveWith<Color?>(
                      (states) => index.isEven ? Colors.grey.shade50 : null,
                    ),
                    cells: [
                      DataCell(
                        Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                postType == 'reviewShare'
                                    ? Colors.purple.withOpacity(0.1)
                                    : AppColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            postType == 'reviewShare' ? 'Đánh giá' : 'Thường',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color:
                                  postType == 'reviewShare'
                                      ? Colors.purple
                                      : AppColors.primaryGreen,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          post['content'] ?? '-',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DataCell(
                        images.isNotEmpty
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                images[0].toString(),
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) => Container(
                                      width: 40,
                                      height: 40,
                                      color: Colors.grey.shade300,
                                      child: const Icon(
                                        Icons.broken_image,
                                        size: 20,
                                      ),
                                    ),
                              ),
                            )
                            : const Text('-'),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.favorite,
                              size: 14,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              likeCount.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.comment,
                              size: 14,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              commentCount.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text(dateStr)),
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
                              onPressed: () => _showDetailDialog(post),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              color: Colors.blue,
                              tooltip: 'Sửa',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _showEditDialog(post),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              color: Colors.red,
                              tooltip: 'Xóa',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _confirmDelete(post),
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

  void _showAddDialog() {
    final contentController = TextEditingController();
    String selectedType = 'normal';
    List<XFile> selectedImages = [];

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.add_circle, color: AppColors.primaryGreen),
                      SizedBox(width: 12),
                      Text('Tạo bài viết mới'),
                    ],
                  ),
                  content: SizedBox(
                    width: 600,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String>(
                            value: selectedType,
                            decoration: const InputDecoration(
                              labelText: 'Loại bài',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'normal',
                                child: Text('Bài viết thường'),
                              ),
                              DropdownMenuItem(
                                value: 'reviewShare',
                                child: Text('Chia sẻ đánh giá'),
                              ),
                            ],
                            onChanged:
                                (value) =>
                                    setDialogState(() => selectedType = value!),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: contentController,
                            decoration: const InputDecoration(
                              labelText: 'Nội dung *',
                              border: OutlineInputBorder(),
                              hintText: 'Nhập nội dung bài viết...',
                            ),
                            maxLines: 5,
                          ),
                          const SizedBox(height: 16),
                          if (selectedImages.isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  selectedImages.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final file = entry.value;
                                    return FutureBuilder<Uint8List>(
                                      future: file.readAsBytes(),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData)
                                          return const SizedBox(
                                            width: 80,
                                            height: 80,
                                            child: Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          );
                                        return Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.memory(
                                                snapshot.data!,
                                                width: 80,
                                                height: 80,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: GestureDetector(
                                                onTap:
                                                    () => setDialogState(
                                                      () => selectedImages
                                                          .removeAt(index),
                                                    ),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  }).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                          OutlinedButton.icon(
                            onPressed: () async {
                              final images =
                                  await _imagePicker.pickMultiImage();
                              if (images.isNotEmpty)
                                setDialogState(
                                  () => selectedImages.addAll(images),
                                );
                            },
                            icon: const Icon(Icons.add_photo_alternate),
                            label: const Text('Thêm ảnh'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
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
                        if (contentController.text.trim().isEmpty) {
                          if (!mounted) return;
                          ToastHelper.showWarning(
                            context,
                            'Vui lòng nhập nội dung',
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
                              (context) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                        );

                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) throw Exception('Chưa đăng nhập');

                          final imageUrls = <String>[];
                          for (int i = 0; i < selectedImages.length; i++) {
                            final file = selectedImages[i];
                            final fileName =
                                'posts/${user.uid}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
                            final ref = FirebaseStorage.instance.ref().child(
                              fileName,
                            );
                            final bytes = await file.readAsBytes();
                            await ref.putData(Uint8List.fromList(bytes));
                            final url = await ref.getDownloadURL();
                            imageUrls.add(url);
                          }

                          final data = {
                            'userId': user.uid,
                            'content': contentController.text.trim(),
                            'postType': selectedType,
                            'images': imageUrls,
                            'likeCount': 0,
                            'commentCount': 0,
                            'taggedPlaceIds': [],
                            'taggedUserIds': [],
                            'createdAt': FieldValue.serverTimestamp(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          };

                          await _adminService.addDocument('posts', data);
                          if (!mounted) return;
                          navigator.pop();
                          ToastHelper.showSuccess(
                            context,
                            'Đã tạo bài viết thành công',
                          );
                          _loadPosts();
                        } catch (e) {
                          if (!mounted) return;
                          navigator.pop();
                          ToastHelper.showError(
                            context,
                            'Lỗi: ${e.toString()}',
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                      ),
                      child: const Text('Tạo'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showEditDialog(Map<String, dynamic> post) {
    final contentController = TextEditingController(text: post['content']);
    String selectedType = post['postType'] ?? 'normal';
    List<String> existingImages =
        (post['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        [];
    List<XFile> newImages = [];

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue),
                      SizedBox(width: 12),
                      Text('Sửa bài viết'),
                    ],
                  ),
                  content: SizedBox(
                    width: 600,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String>(
                            value: selectedType,
                            decoration: const InputDecoration(
                              labelText: 'Loại bài',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'normal',
                                child: Text('Bài viết thường'),
                              ),
                              DropdownMenuItem(
                                value: 'reviewShare',
                                child: Text('Chia sẻ đánh giá'),
                              ),
                            ],
                            onChanged:
                                (value) =>
                                    setDialogState(() => selectedType = value!),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: contentController,
                            decoration: const InputDecoration(
                              labelText: 'Nội dung *',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 5,
                          ),
                          const SizedBox(height: 16),
                          if (existingImages.isNotEmpty) ...[
                            const Text(
                              'Ảnh hiện tại',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  existingImages.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final imageUrl = entry.value;
                                    return Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            imageUrl,
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: GestureDetector(
                                            onTap:
                                                () => setDialogState(
                                                  () => existingImages.removeAt(
                                                    index,
                                                  ),
                                                ),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (newImages.isNotEmpty) ...[
                            const Text(
                              'Ảnh mới',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  newImages.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final file = entry.value;
                                    return FutureBuilder<Uint8List>(
                                      future: file.readAsBytes(),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData)
                                          return const SizedBox(
                                            width: 80,
                                            height: 80,
                                            child: Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          );
                                        return Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.memory(
                                                snapshot.data!,
                                                width: 80,
                                                height: 80,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: GestureDetector(
                                                onTap:
                                                    () => setDialogState(
                                                      () => newImages.removeAt(
                                                        index,
                                                      ),
                                                    ),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  }).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                          OutlinedButton.icon(
                            onPressed: () async {
                              final images =
                                  await _imagePicker.pickMultiImage();
                              if (images.isNotEmpty)
                                setDialogState(() => newImages.addAll(images));
                            },
                            icon: const Icon(Icons.add_photo_alternate),
                            label: const Text('Thêm ảnh'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
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
                        if (contentController.text.trim().isEmpty) {
                          if (!mounted) return;
                          ToastHelper.showWarning(
                            context,
                            'Vui lòng nhập nội dung',
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
                              (context) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                        );

                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) throw Exception('Chưa đăng nhập');

                          final newImageUrls = <String>[];
                          for (int i = 0; i < newImages.length; i++) {
                            final file = newImages[i];
                            final fileName =
                                'posts/${user.uid}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
                            final ref = FirebaseStorage.instance.ref().child(
                              fileName,
                            );
                            final bytes = await file.readAsBytes();
                            await ref.putData(Uint8List.fromList(bytes));
                            final url = await ref.getDownloadURL();
                            newImageUrls.add(url);
                          }

                          final allImages = [
                            ...existingImages,
                            ...newImageUrls,
                          ];
                          final data = {
                            'content': contentController.text.trim(),
                            'postType': selectedType,
                            'images': allImages,
                            'updatedAt': FieldValue.serverTimestamp(),
                          };

                          await _adminService.updateDocument(
                            'posts',
                            post['id'],
                            data,
                          );
                          if (!mounted) return;
                          navigator.pop();
                          ToastHelper.showSuccess(
                            context,
                            'Đã cập nhật thành công',
                          );
                          _loadPosts();
                        } catch (e) {
                          if (!mounted) return;
                          navigator.pop();
                          ToastHelper.showError(
                            context,
                            'Lỗi: ${e.toString()}',
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      child: const Text('Cập nhật'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showDetailDialog(Map<String, dynamic> post) {
    final userId = post['userId']?.toString() ?? '';
    final userName = _userNames[userId] ?? 'Không rõ';
    final images = post['images'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.article, color: AppColors.primaryGreen),
                const SizedBox(width: 12),
                const Expanded(child: Text('Chi tiết bài viết')),
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
                  children: [
                    _buildDetailRow('Người đăng', userName),
                    _buildDetailRow(
                      'Loại bài',
                      post['postType'] == 'reviewShare'
                          ? 'Chia sẻ đánh giá'
                          : 'Bài viết thường',
                    ),
                    _buildDetailRow(
                      'Nội dung',
                      post['content'] ?? 'Không có nội dung',
                    ),
                    _buildDetailRow('Lượt thích', '${post['likeCount'] ?? 0}'),
                    _buildDetailRow(
                      'Bình luận',
                      '${post['commentCount'] ?? 0}',
                    ),
                    if (images.isNotEmpty) ...[
                      const Text(
                        'Hình ảnh',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            images.map((img) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  img.toString(),
                                  width: 150,
                                  height: 150,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) => Container(
                                        width: 150,
                                        height: 150,
                                        color: Colors.grey.shade300,
                                        child: const Icon(Icons.broken_image),
                                      ),
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildDetailRow(
                      'Ngày tạo',
                      post['createdAt'] is Timestamp
                          ? (post['createdAt'] as Timestamp)
                              .toDate()
                              .toString()
                              .split('.')[0]
                          : 'N/A',
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bạn có chắc muốn xóa bài viết này?'),
                SizedBox(height: 12),
                Text(
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
                  final navigator = Navigator.of(context);
                  navigator.pop();

                  if (!mounted) return;

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (context) =>
                            const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    await _adminService.deleteDocument('posts', post['id']);
                    if (!mounted) return;
                    navigator.pop();
                    ToastHelper.showSuccess(
                      context,
                      'Đã xóa bài viết thành công',
                    );
                    _loadPosts();
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
