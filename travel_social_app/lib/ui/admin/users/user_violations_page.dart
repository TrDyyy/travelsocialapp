import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../utils/constants.dart';

/// Page hiển thị danh sách user vi phạm (bị cấm hoặc có cảnh báo)
class UserViolationsPage extends StatefulWidget {
  final String filterType; // 'banned' hoặc 'warning'

  const UserViolationsPage({super.key, this.filterType = 'all'});

  @override
  State<UserViolationsPage> createState() => _UserViolationsPageState();
}

class _UserViolationsPageState extends State<UserViolationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'all'; // 'all', 'banned', 'warning'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.filterType;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _getUsersStream() {
    Query query = _firestore.collection('users');

    // Apply filter - lấy tất cả users, filter sau bằng code
    return query.limit(500).snapshots();
  }

  bool _shouldShowUser(Map<String, dynamic> userData) {
    final isBanned = userData['isBanned'] ?? false;
    final warningCount = userData['warningCount'] ?? 0;

    if (_selectedFilter == 'banned') {
      return isBanned;
    } else if (_selectedFilter == 'warning') {
      return warningCount > 0 && !isBanned;
    } else {
      // 'all' - users with violations (banned OR has warnings)
      return isBanned || warningCount > 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.getSurfaceColor(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'User vi phạm',
          style: TextStyle(
            fontSize: AppSizes.font(context, SizeCategory.xlarge),
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.withOpacity(0.2)),
        ),
      ),
      body: Column(
        children: [
          _buildFilterAndSearch(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Lỗi: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data?.docs ?? [];

                // Filter by violation status first, then by search query
                final filteredUsers =
                    users.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      // Check violation filter
                      if (!_shouldShowUser(data)) return false;

                      // Check search query
                      if (_searchQuery.isEmpty) return true;
                      final displayName =
                          (data['displayName'] ?? '').toString().toLowerCase();
                      final email =
                          (data['email'] ?? '').toString().toLowerCase();
                      final query = _searchQuery.toLowerCase();
                      return displayName.contains(query) ||
                          email.contains(query);
                    }).toList();

                // Sort by warningCount descending
                filteredUsers.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aWarning = aData['warningCount'] ?? 0;
                  final bWarning = bData['warningCount'] ?? 0;
                  return bWarning.compareTo(aWarning);
                });

                if (filteredUsers.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: EdgeInsets.all(
                    AppSizes.padding(context, SizeCategory.medium),
                  ),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final userDoc = filteredUsers[index];
                    final userData = userDoc.data() as Map<String, dynamic>;
                    return _buildUserCard(userDoc.id, userData);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndSearch() {
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
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Tất cả', 'all'),
                SizedBox(width: AppSizes.padding(context, SizeCategory.small)),
                _buildFilterChip('Bị cấm', 'banned'),
                SizedBox(width: AppSizes.padding(context, SizeCategory.small)),
                _buildFilterChip('Có cảnh báo', 'warning'),
              ],
            ),
          ),
          SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên hoặc email...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon:
                  _searchQuery.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppSizes.radius(context, SizeCategory.medium),
                ),
              ),
              filled: true,
              fillColor: AppTheme.getBackgroundColor(context),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      backgroundColor: AppTheme.getSurfaceColor(context),
      selectedColor: AppColors.primaryGreen.withOpacity(0.2),
      checkmarkColor: AppColors.primaryGreen,
      labelStyle: TextStyle(
        color:
            isSelected
                ? AppColors.primaryGreen
                : AppTheme.getTextSecondaryColor(context),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildUserCard(String userId, Map<String, dynamic> userData) {
    final name = userData['name'] ?? 'Không có tên';
    final email = userData['email'] ?? '';
    final avatarUrl = userData['avatarUrl'] as String?;
    final isBanned = userData['isBanned'] ?? false;
    final warningCount = userData['warningCount'] ?? 0;
    final totalPoints = userData['totalPoints'] ?? 0;

    return Card(
      margin: EdgeInsets.only(
        bottom: AppSizes.padding(context, SizeCategory.medium),
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.medium),
        ),
        side: BorderSide(
          color:
              isBanned
                  ? Colors.red.withOpacity(0.3)
                  : Colors.orange.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(
          AppSizes.padding(context, SizeCategory.medium),
        ),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.grey[300],
              child:
                  avatarUrl != null && avatarUrl.isNotEmpty
                      ? ClipOval(
                        child: Image.network(
                          avatarUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.person, size: 30);
                          },
                        ),
                      )
                      : const Icon(Icons.person, size: 30),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isBanned ? Colors.red : Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  isBanned ? Icons.block : Icons.warning,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        title: Text(
          name,
          style: TextStyle(
            fontSize: AppSizes.font(context, SizeCategory.large),
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (email.isNotEmpty)
              Text(
                email,
                style: TextStyle(
                  fontSize: AppSizes.font(context, SizeCategory.small),
                  color: AppTheme.getTextSecondaryColor(context),
                ),
              ),
            SizedBox(height: AppSizes.padding(context, SizeCategory.small)),
            Row(
              children: [
                _buildBadge(
                  isBanned ? 'Đã cấm' : '$warningCount cảnh báo',
                  isBanned ? Colors.red : Colors.orange,
                  isBanned ? Icons.block : Icons.warning,
                ),
                SizedBox(width: AppSizes.padding(context, SizeCategory.small)),
                _buildBadge(
                  '$totalPoints điểm phạt',
                  Colors.purple,
                  Icons.whatshot,
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 18),
          onPressed: () => _showUserViolationDetails(userId, userData),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
          SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),
          Text(
            'Không có user vi phạm',
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.large),
              color: AppTheme.getTextSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showUserViolationDetails(
    String userId,
    Map<String, dynamic> userData,
  ) async {
    final name = userData['name'] ?? 'Không có tên';
    final isBanned = userData['isBanned'] ?? false;
    final warningCount = userData['warningCount'] ?? 0;
    final totalPoints = userData['totalPoints'] ?? 0;

    // Fetch user warnings history
    final warningsSnapshot =
        await _firestore
            .collection('userWarnings')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .limit(20)
            .get();

    final warnings = warningsSnapshot.docs;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: AppTheme.getSurfaceColor(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(
                    AppSizes.padding(context, SizeCategory.large),
                  ),
                  decoration: BoxDecoration(
                    color:
                        isBanned
                            ? Colors.red.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(
                        height: AppSizes.padding(context, SizeCategory.medium),
                      ),
                      Row(
                        children: [
                          Icon(
                            isBanned ? Icons.block : Icons.warning,
                            color: isBanned ? Colors.red : Colors.orange,
                            size: 32,
                          ),
                          SizedBox(
                            width: AppSizes.padding(
                              context,
                              SizeCategory.medium,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: AppSizes.font(
                                      context,
                                      SizeCategory.xlarge,
                                    ),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  isBanned
                                      ? 'Tài khoản đã bị cấm'
                                      : 'Có cảnh báo',
                                  style: TextStyle(
                                    fontSize: AppSizes.font(
                                      context,
                                      SizeCategory.medium,
                                    ),
                                    color:
                                        isBanned ? Colors.red : Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: AppSizes.padding(context, SizeCategory.medium),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Cảnh báo', warningCount.toString()),
                          _buildStatItem('Điểm phạt', totalPoints.toString()),
                          _buildStatItem('Lịch sử', warnings.length.toString()),
                        ],
                      ),
                    ],
                  ),
                ),
                // Warnings list
                Expanded(
                  child:
                      warnings.isEmpty
                          ? Center(
                            child: Text(
                              'Chưa có lịch sử cảnh báo',
                              style: TextStyle(
                                color: AppTheme.getTextSecondaryColor(context),
                              ),
                            ),
                          )
                          : ListView.builder(
                            padding: EdgeInsets.all(
                              AppSizes.padding(context, SizeCategory.medium),
                            ),
                            itemCount: warnings.length,
                            itemBuilder: (context, index) {
                              final warning = warnings[index].data();
                              final createdAt =
                                  (warning['createdAt'] as Timestamp?)
                                      ?.toDate();
                              final violationType =
                                  warning['violationType'] ?? '';
                              final reason = warning['reason'] ?? '';
                              final adminNote = warning['adminNote'] ?? '';
                              final actionLevel = warning['actionLevel'] ?? '';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        actionLevel == 'ban'
                                            ? Colors.red.withOpacity(0.2)
                                            : Colors.orange.withOpacity(0.2),
                                    child: Icon(
                                      actionLevel == 'ban'
                                          ? Icons.block
                                          : Icons.warning,
                                      color:
                                          actionLevel == 'ban'
                                              ? Colors.red
                                              : Colors.orange,
                                    ),
                                  ),
                                  title: Text(
                                    violationType,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (reason.isNotEmpty)
                                        Text('Lý do: $reason'),
                                      if (adminNote.isNotEmpty)
                                        Text(
                                          'Ghi chú: $adminNote',
                                          style: TextStyle(
                                            fontSize: AppSizes.font(
                                              context,
                                              SizeCategory.small,
                                            ),
                                            color:
                                                AppTheme.getTextSecondaryColor(
                                                  context,
                                                ),
                                          ),
                                        ),
                                      if (createdAt != null)
                                        Text(
                                          _formatDate(createdAt),
                                          style: TextStyle(
                                            fontSize: AppSizes.font(
                                              context,
                                              SizeCategory.small,
                                            ),
                                            color:
                                                AppTheme.getTextSecondaryColor(
                                                  context,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: AppSizes.font(context, SizeCategory.xxlarge),
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: AppSizes.font(context, SizeCategory.small),
            color: AppTheme.getTextSecondaryColor(context),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes} phút trước';
      }
      return '${diff.inHours} giờ trước';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} ngày trước';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
