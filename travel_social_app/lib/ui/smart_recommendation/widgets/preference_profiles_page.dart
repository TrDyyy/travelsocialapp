import 'package:flutter/material.dart';
import '../../../models/tourism_type.dart';
import '../../../models/preference_profile.dart';
import '../../../services/tourism_type_service.dart';
import '../../../services/user_preferences_service.dart';
import '../../../utils/constants.dart';

/// Page để xem và chỉnh sửa Profile sở thích (1 profile duy nhất/user)
class PreferenceProfilesPage extends StatefulWidget {
  const PreferenceProfilesPage({super.key});

  @override
  State<PreferenceProfilesPage> createState() => _PreferenceProfilesPageState();
}

class _PreferenceProfilesPageState extends State<PreferenceProfilesPage> {
  final _tourismTypeService = TourismTypeService();
  final _preferencesService = UserPreferencesService();

  List<TourismType> _allTypes = [];
  PreferenceProfile? _profile;
  Set<String> _selectedTypeIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Lấy tất cả tourism types
      final types = await _tourismTypeService.getTourismTypes();

      // Lấy hoặc tạo profile duy nhất của user
      final profile = await _preferencesService.getOrCreateProfile();

      setState(() {
        _allTypes = types;
        _profile = profile;
        _selectedTypeIds = Set<String>.from(profile.favoriteTypes);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu: $e')));
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_profile == null) return;

    try {
      // Cập nhật favorite types của profile duy nhất
      await _preferencesService.updateFavoriteTypes(_selectedTypeIds.toList());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedTypeIds.isEmpty
                  ? '✅ Đã reset! Hệ thống sẽ học từ hành vi của bạn'
                  : '✅ Đã lưu ${_selectedTypeIds.length} loại sở thích!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi lưu: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Sở thích của bạn'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          // Nút reset
          if (_selectedTypeIds.isNotEmpty)
            IconButton(
              onPressed: () {
                setState(() {
                  _selectedTypeIds.clear();
                });
              },
              icon: const Icon(Icons.clear_all),
              tooltip: 'Bỏ chọn tất cả',
            ),
          // Nút lưu - LUÔN enable
          TextButton.icon(
            onPressed: _saveProfile,
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('Lưu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Header info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.favorite,
                              color: AppColors.primaryGreen,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Chọn loại địa điểm yêu thích',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.getTextPrimaryColor(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedTypeIds.isEmpty
                              ? 'Chọn các loại địa điểm bạn quan tâm, hoặc bỏ trống để hệ thống tự học từ hành vi của bạn.'
                              : 'Đã chọn ${_selectedTypeIds.length} loại. Bỏ trống nếu muốn hệ thống tự học từ hành vi.',
                          style: TextStyle(
                            color: AppTheme.getTextSecondaryColor(context),
                          ),
                        ),
                        if (_profile != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Cập nhật lần cuối: ${_formatDate(_profile!.updatedAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.getTextSecondaryColor(context),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Grid các tourism types
                  Expanded(
                    child:
                        _allTypes.isEmpty
                            ? Center(
                              child: Text(
                                'Không có dữ liệu',
                                style: TextStyle(
                                  color: AppTheme.getTextSecondaryColor(
                                    context,
                                  ),
                                ),
                              ),
                            )
                            : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 1.2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                              itemCount: _allTypes.length,
                              itemBuilder: (context, index) {
                                final type = _allTypes[index];
                                final isSelected = _selectedTypeIds.contains(
                                  type.typeId,
                                );
                                return _buildTypeCard(type, isSelected);
                              },
                            ),
                  ),

                  // Bottom info - LUÔN hiển thị
                  Container(
                    padding: const EdgeInsets.all(16),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedTypeIds.isEmpty
                                    ? '🤖 Chế độ AI tự động'
                                    : 'Đã chọn: ${_selectedTypeIds.length} loại',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.getTextPrimaryColor(context),
                                ),
                              ),
                              if (_selectedTypeIds.isEmpty)
                                Text(
                                  'Hệ thống sẽ học từ hành vi của bạn',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.getTextSecondaryColor(
                                      context,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _saveProfile,
                          icon: const Icon(Icons.check),
                          label: const Text('Lưu'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildTypeCard(TourismType type, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedTypeIds.remove(type.typeId);
          } else {
            _selectedTypeIds.add(type.typeId);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primaryGreen.withOpacity(0.1)
                  : AppTheme.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected
                    ? AppColors.primaryGreen
                    : AppTheme.getBorderColor(context),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? AppColors.primaryGreen.withOpacity(0.2)
                              : AppTheme.getBorderColor(
                                context,
                              ).withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIconForType(type.name),
                      size: 32,
                      color:
                          isSelected
                              ? AppColors.primaryGreen
                              : AppTheme.getTextSecondaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    type.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color:
                          isSelected
                              ? AppColors.primaryGreen
                              : AppTheme.getTextPrimaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 16, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String typeName) {
    final lowerName = typeName.toLowerCase();
    if (lowerName.contains('biển') || lowerName.contains('bãi')) {
      return Icons.beach_access;
    } else if (lowerName.contains('núi') || lowerName.contains('đồi')) {
      return Icons.terrain;
    } else if (lowerName.contains('chùa') ||
        lowerName.contains('đền') ||
        lowerName.contains('miếu')) {
      return Icons.temple_buddhist;
    } else if (lowerName.contains('bảo tàng') || lowerName.contains('museum')) {
      return Icons.museum;
    } else if (lowerName.contains('công viên') || lowerName.contains('park')) {
      return Icons.park;
    } else if (lowerName.contains('ẩm thực') ||
        lowerName.contains('nhà hàng') ||
        lowerName.contains('food')) {
      return Icons.restaurant;
    } else if (lowerName.contains('khách sạn') ||
        lowerName.contains('resort') ||
        lowerName.contains('hotel')) {
      return Icons.hotel;
    } else if (lowerName.contains('mua sắm') ||
        lowerName.contains('shop') ||
        lowerName.contains('chợ')) {
      return Icons.shopping_bag;
    } else if (lowerName.contains('giải trí') ||
        lowerName.contains('entertainment')) {
      return Icons.celebration;
    } else if (lowerName.contains('văn hóa') || lowerName.contains('culture')) {
      return Icons.account_balance;
    } else if (lowerName.contains('thiên nhiên') ||
        lowerName.contains('nature')) {
      return Icons.nature;
    } else {
      return Icons.place;
    }
  }
}
