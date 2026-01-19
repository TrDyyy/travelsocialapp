import 'package:flutter/material.dart';
import '../../../models/tourism_type.dart';
import '../../../services/tourism_type_service.dart';
import '../../../services/user_preferences_service.dart';
import '../../../utils/constants.dart';

/// Page đơn giản để user chọn các loại địa điểm yêu thích
class SelectFavoriteTypesPage extends StatefulWidget {
  const SelectFavoriteTypesPage({super.key});

  @override
  State<SelectFavoriteTypesPage> createState() =>
      _SelectFavoriteTypesPageState();
}

class _SelectFavoriteTypesPageState extends State<SelectFavoriteTypesPage> {
  final _tourismTypeService = TourismTypeService();
  final _preferencesService = UserPreferencesService();

  List<TourismType> _allTypes = [];
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

      // Lấy profile duy nhất của user
      final profile = await _preferencesService.getOrCreateProfile();

      setState(() {
        _allTypes = types;
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

  Future<void> _savePreferences() async {
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
          // Nút reset tất cả
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
          // Nút lưu - LUÔN enable (cho phép lưu 0 loại)
          TextButton.icon(
            onPressed: _savePreferences,
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
                  // Header với hướng dẫn
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
                          onPressed: _savePreferences,
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
        duration: Duration(milliseconds: 200),
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
            // Nội dung card
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
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

                  // Tên loại
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

            // Checkbox indicator
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

    // Ẩm thực
    if (lowerName.contains('ẩm thực') || lowerName.contains('food')) {
      return Icons.restaurant;
    }
    // Mua sắm
    else if (lowerName.contains('mua sắm') || lowerName.contains('shopping')) {
      return Icons.shopping_bag;
    }
    // Cặp đôi - Trăng mật
    else if (lowerName.contains('cặp đôi') ||
        lowerName.contains('trăng mật') ||
        lowerName.contains('honeymoon')) {
      return Icons.favorite;
    }
    // Nông nghiệp
    else if (lowerName.contains('nông nghiệp') ||
        lowerName.contains('agriculture')) {
      return Icons.agriculture;
    }
    // Sông nước
    else if (lowerName.contains('sông') ||
        lowerName.contains('nước') ||
        lowerName.contains('river')) {
      return Icons.water;
    }
    // Khám phá - mạo hiểm
    else if (lowerName.contains('khám phá') ||
        lowerName.contains('mạo hiểm') ||
        lowerName.contains('adventure')) {
      return Icons.explore;
    }
    // Nghỉ dưỡng
    else if (lowerName.contains('nghỉ dưỡng') || lowerName.contains('resort')) {
      return Icons.spa;
    }
    // Nghệ thuật - sáng tạo
    else if (lowerName.contains('nghệ thuật') ||
        lowerName.contains('sáng tạo') ||
        lowerName.contains('art')) {
      return Icons.palette;
    }
    // Lễ hội - sự kiện
    else if (lowerName.contains('lễ hội') ||
        lowerName.contains('sự kiện') ||
        lowerName.contains('festival')) {
      return Icons.festival;
    }
    // Thể thao
    else if (lowerName.contains('thể thao') || lowerName.contains('sport')) {
      return Icons.sports_soccer;
    }
    // Thành phố
    else if (lowerName.contains('thành phố') || lowerName.contains('city')) {
      return Icons.location_city;
    }
    // Văn hóa
    else if (lowerName.contains('văn hóa') || lowerName.contains('culture')) {
      return Icons.account_balance;
    }
    // Gia đình
    else if (lowerName.contains('gia đình') || lowerName.contains('family')) {
      return Icons.family_restroom;
    }
    // Sinh thái
    else if (lowerName.contains('sinh thái') || lowerName.contains('ecology')) {
      return Icons.eco;
    }
    // Tâm linh
    else if (lowerName.contains('tâm linh') ||
        lowerName.contains('spiritual')) {
      return Icons.self_improvement;
    }
    // Giải trí
    else if (lowerName.contains('giải trí') ||
        lowerName.contains('entertainment')) {
      return Icons.celebration;
    }
    // Lịch sử
    else if (lowerName.contains('lịch sử') || lowerName.contains('history')) {
      return Icons.museum;
    }
    // Bụi - Phượt
    else if (lowerName.contains('bụi') ||
        lowerName.contains('phượt') ||
        lowerName.contains('backpack')) {
      return Icons.backpack;
    }
    // Biển - Đảo
    else if (lowerName.contains('biển') ||
        lowerName.contains('đảo') ||
        lowerName.contains('beach')) {
      return Icons.beach_access;
    }
    // Giáo dục
    else if (lowerName.contains('giáo dục') ||
        lowerName.contains('education')) {
      return Icons.school;
    } else {
      return Icons.place;
    }
  }
}
