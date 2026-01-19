import 'package:flutter/material.dart';
import '../../../models/tourism_type.dart';
import '../../../services/tourism_type_service.dart';
import '../../../services/user_preferences_service.dart';

/// Page để user chọn các loại địa điểm yêu thích
class FavoriteTypesPage extends StatefulWidget {
  const FavoriteTypesPage({super.key});

  @override
  State<FavoriteTypesPage> createState() => _FavoriteTypesPageState();
}

class _FavoriteTypesPageState extends State<FavoriteTypesPage> {
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

      // Lấy favorite types hiện tại
      final prefs = await _preferencesService.getUserPreferences();

      setState(() {
        _allTypes = types;
        _selectedTypeIds = Set<String>.from(prefs?.favoriteTypes ?? []);
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
      await _preferencesService.updateFavoriteTypes(_selectedTypeIds.toList());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã lưu sở thích của bạn!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi lưu: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sở thích của bạn'),
        actions: [
          TextButton.icon(
            onPressed: _selectedTypeIds.isEmpty ? null : _savePreferences,
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
                    color: Colors.blue.shade50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.favorite, color: Colors.red, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Chọn loại địa điểm yêu thích',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Chọn ít nhất ${_selectedTypeIds.isEmpty ? "1" : "${_selectedTypeIds.length}"} loại địa điểm bạn quan tâm để nhận gợi ý phù hợp hơn.',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),

                  // Grid các tourism types
                  Expanded(
                    child:
                        _allTypes.isEmpty
                            ? const Center(child: Text('Không có dữ liệu'))
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

                  // Bottom info
                  if (_selectedTypeIds.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
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
                          Text(
                            'Đã chọn: ${_selectedTypeIds.length} loại',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _savePreferences,
                            icon: const Icon(Icons.check),
                            label: const Text('Lưu sở thích'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
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
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
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
                              ? Colors.blue.shade100
                              : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIconForType(type.name),
                      size: 32,
                      color: isSelected ? Colors.blue : Colors.grey[600],
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
                      color: isSelected ? Colors.blue : Colors.black87,
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
                    color: Colors.blue,
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
