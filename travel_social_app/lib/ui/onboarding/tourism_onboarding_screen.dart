import 'dart:async';
import 'package:flutter/material.dart';
import 'package:travel_social_app/widgets/custom_button.dart';
import '../../models/tourism_type.dart';
import '../../services/tourism_type_service.dart';
import '../../services/user_preferences_service.dart';
import '../../utils/constants.dart';

class TourismOnboardingScreen extends StatefulWidget {
  const TourismOnboardingScreen({super.key});

  @override
  State<TourismOnboardingScreen> createState() =>
      _TourismOnboardingScreenState();
}

class _TourismOnboardingScreenState extends State<TourismOnboardingScreen> {
  final TourismTypeService _tourismService = TourismTypeService();
  final UserPreferencesService _preferencesService = UserPreferencesService();
  final PageController _pageController = PageController(
    viewportFraction: 0.85,
    initialPage: 10000, // Start at middle for bidirectional scroll
  );

  List<TourismType> _tourismTypes = [];
  final Set<String> _selectedTypeIds = {};
  int _currentPage = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  Timer? _autoPlayTimer;
  bool _isUserInteracting = false;

  // Định nghĩa màu và emoji cho từng loại hình
  final Map<String, Map<String, dynamic>> _typeStyles = {
    // Ẩm thực
    'food': {
      'emoji': '🍜',
      'color': const Color(0xFFE57373),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE57373), Color(0xFFC62828)],
      ),
    },
    // Mua sắm
    'shopping': {
      'emoji': '🛍️',
      'color': const Color(0xFFBA68C8),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFBA68C8), Color(0xFF7B1FA2)],
      ),
    },
    // Cặp đôi - Trăng mật
    'honeymoon': {
      'emoji': '💑',
      'color': const Color(0xFFFF80AB),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF80AB), Color(0xFFF06292)],
      ),
    },
    // Nông nghiệp
    'agriculture': {
      'emoji': '🌾',
      'color': const Color(0xFFDCE775),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFDCE775), Color(0xFFC0CA33)],
      ),
    },
    // Sông nước
    'river': {
      'emoji': '🛶',
      'color': const Color(0xFF4DD0E1),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4DD0E1), Color(0xFF0097A7)],
      ),
    },
    // Khám phá - mạo hiểm
    'adventure': {
      'emoji': '🧗',
      'color': const Color(0xFFFF9800),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF9800), Color(0xFFE65100)],
      ),
    },
    // Nghỉ dưỡng
    'resort': {
      'emoji': '🏖️',
      'color': const Color(0xFF4FC3F7),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
      ),
    },
    // Nghệ thuật - sáng tạo
    'art': {
      'emoji': '🎨',
      'color': const Color(0xFFAB47BC),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFAB47BC), Color(0xFF6A1B9A)],
      ),
    },
    // Lễ hội - sự kiện
    'festival': {
      'emoji': '🎭',
      'color': const Color(0xFFFFA726),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFA726), Color(0xFFF57C00)],
      ),
    },
    // Thể thao
    'sport': {
      'emoji': '⚽',
      'color': const Color(0xFF66BB6A),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF66BB6A), Color(0xFF388E3C)],
      ),
    },
    // Thành phố
    'city': {
      'emoji': '🏙️',
      'color': const Color(0xFF78909C),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF78909C), Color(0xFF455A64)],
      ),
    },
    // Văn hóa
    'culture': {
      'emoji': '🏛️',
      'color': const Color(0xFFFFB74D),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFB74D), Color(0xFFF57C00)],
      ),
    },
    // Gia đình
    'family': {
      'emoji': '👨‍👩‍👧‍👦',
      'color': const Color(0xFF81C784),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF81C784), Color(0xFF388E3C)],
      ),
    },
    // Sinh thái
    'ecology': {
      'emoji': '🌳',
      'color': const Color(0xFF66BB6A),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
      ),
    },
    // Tâm linh
    'spiritual': {
      'emoji': '🕉️',
      'color': const Color(0xFFFFD54F),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFD54F), Color(0xFFFFA000)],
      ),
    },
    // Giải trí
    'entertainment': {
      'emoji': '🎡',
      'color': const Color(0xFFFF8A65),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF8A65), Color(0xFFD84315)],
      ),
    },
    // Lịch sử
    'history': {
      'emoji': '🏰',
      'color': const Color(0xFF8D6E63),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF8D6E63), Color(0xFF5D4037)],
      ),
    },
    // Bụi - Phượt
    'backpacking': {
      'emoji': '🎒',
      'color': const Color(0xFF7E57C2),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF7E57C2), Color(0xFF512DA8)],
      ),
    },
    // Biển - Đảo
    'beach': {
      'emoji': '🏝️',
      'color': const Color(0xFF29B6F6),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF29B6F6), Color(0xFF0277BD)],
      ),
    },
    // Giáo dục
    'education': {
      'emoji': '📚',
      'color': const Color(0xFF5C6BC0),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF5C6BC0), Color(0xFF283593)],
      ),
    },
    'default': {
      'emoji': '🗺️',
      'color': AppColors.primaryGreen,
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primaryGreen, Color(0xFF2D6A4F)],
      ),
    },
  };

  @override
  void initState() {
    super.initState();
    _loadTourismTypes();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isUserInteracting && mounted && _tourismTypes.isNotEmpty) {
        final nextPage = _pageController.page!.toInt() + 1;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _onUserInteractionStart() {
    setState(() {
      _isUserInteracting = true;
    });
  }

  void _onUserInteractionEnd() {
    // Resume auto-play after 2 seconds of no interaction
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isUserInteracting = false;
        });
      }
    });
  }

  Future<void> _loadTourismTypes() async {
    try {
      final types = await _tourismService.getTourismTypes();
      if (mounted) {
        setState(() {
          _tourismTypes = types;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading tourism types: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _getStyleForType(String typeName) {
    final key = typeName.toLowerCase();

    if (key.contains('ẩm thực') || key.contains('food')) {
      return _typeStyles['food']!;
    } else if (key.contains('mua sắm') || key.contains('shopping')) {
      return _typeStyles['shopping']!;
    } else if (key.contains('cặp đôi') ||
        key.contains('trăng mật') ||
        key.contains('honeymoon')) {
      return _typeStyles['honeymoon']!;
    } else if (key.contains('nông nghiệp') || key.contains('agriculture')) {
      return _typeStyles['agriculture']!;
    } else if (key.contains('sông') ||
        key.contains('nước') ||
        key.contains('river')) {
      return _typeStyles['river']!;
    } else if (key.contains('khám phá') ||
        key.contains('mạo hiểm') ||
        key.contains('adventure')) {
      return _typeStyles['adventure']!;
    } else if (key.contains('nghỉ dưỡng') || key.contains('resort')) {
      return _typeStyles['resort']!;
    } else if (key.contains('nghệ thuật') ||
        key.contains('sáng tạo') ||
        key.contains('art')) {
      return _typeStyles['art']!;
    } else if (key.contains('lễ hội') ||
        key.contains('sự kiện') ||
        key.contains('festival')) {
      return _typeStyles['festival']!;
    } else if (key.contains('thể thao') || key.contains('sport')) {
      return _typeStyles['sport']!;
    } else if (key.contains('thành phố') || key.contains('city')) {
      return _typeStyles['city']!;
    } else if (key.contains('văn hóa') || key.contains('culture')) {
      return _typeStyles['culture']!;
    } else if (key.contains('gia đình') || key.contains('family')) {
      return _typeStyles['family']!;
    } else if (key.contains('sinh thái') || key.contains('ecology')) {
      return _typeStyles['ecology']!;
    } else if (key.contains('tâm linh') || key.contains('spiritual')) {
      return _typeStyles['spiritual']!;
    } else if (key.contains('giải trí') || key.contains('entertainment')) {
      return _typeStyles['entertainment']!;
    } else if (key.contains('lịch sử') || key.contains('history')) {
      return _typeStyles['history']!;
    } else if (key.contains('bụi') ||
        key.contains('phượt') ||
        key.contains('backpack')) {
      return _typeStyles['backpacking']!;
    } else if (key.contains('biển') ||
        key.contains('đảo') ||
        key.contains('beach')) {
      return _typeStyles['beach']!;
    } else if (key.contains('giáo dục') || key.contains('education')) {
      return _typeStyles['education']!;
    }
    return _typeStyles['default']!;
  }

  Future<void> _savePreferences() async {
    // Prevent double tap
    if (_isSaving) return;

    if (_selectedTypeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng chọn ít nhất một loại hình du lịch'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: AppSizes.padding(context, SizeCategory.xlarge),
            left: AppSizes.padding(context, SizeCategory.medium),
            right: AppSizes.padding(context, SizeCategory.medium),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Lưu preferences
      await _preferencesService.updateFavoriteTypes(_selectedTypeIds.toList());

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error saving preferences: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Có lỗi xảy ra. Vui lòng thử lại.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: AppSizes.padding(context, SizeCategory.xlarge),
              left: AppSizes.padding(context, SizeCategory.medium),
              right: AppSizes.padding(context, SizeCategory.medium),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryGreen,
              AppTheme.getBackgroundColor(context),
            ],
          ),
        ),
        child: SafeArea(
          child:
              _isLoading
                  ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                      strokeWidth: 3,
                    ),
                  )
                  : Column(
                    children: [
                      // Header
                      Padding(
                        padding: EdgeInsets.all(
                          AppSizes.padding(context, SizeCategory.large),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Hôm nay, bạn muốn đi đâu?',
                              style: TextStyle(
                                fontSize: AppSizes.font(
                                  context,
                                  SizeCategory.xxlarge,
                                ),
                                fontWeight: FontWeight.bold,
                                color: AppTheme.getTextPrimaryColor(context),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(
                              height: AppSizes.padding(
                                context,
                                SizeCategory.small,
                              ),
                            ),
                            Text(
                              'Mỗi ngày là một hành trình đáng nhớ',
                              style: TextStyle(
                                fontSize: AppSizes.font(
                                  context,
                                  SizeCategory.medium,
                                ),
                                color: AppTheme.getTextSecondaryColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Carousel
                      Expanded(
                        child:
                            _tourismTypes.isEmpty
                                ? Center(
                                  child: Text(
                                    'Không có loại hình du lịch',
                                    style: TextStyle(
                                      color: AppTheme.getTextSecondaryColor(
                                        context,
                                      ),
                                      fontSize: AppSizes.font(
                                        context,
                                        SizeCategory.medium,
                                      ),
                                    ),
                                  ),
                                )
                                : GestureDetector(
                                  onPanDown: (_) => _onUserInteractionStart(),
                                  onPanEnd: (_) => _onUserInteractionEnd(),
                                  onPanCancel: () => _onUserInteractionEnd(),
                                  child: PageView.builder(
                                    controller: _pageController,
                                    onPageChanged: (index) {
                                      setState(() {
                                        _currentPage =
                                            index % _tourismTypes.length;
                                      });
                                    },
                                    itemBuilder: (context, index) {
                                      final actualIndex =
                                          index % _tourismTypes.length;
                                      final type = _tourismTypes[actualIndex];
                                      final isSelected = _selectedTypeIds
                                          .contains(type.typeId);
                                      final isCurrent =
                                          actualIndex == _currentPage;
                                      return AnimatedScale(
                                        scale: isCurrent ? 1.0 : 0.85,
                                        duration: const Duration(
                                          milliseconds: 500,
                                        ),
                                        child: _buildTypeCard(
                                          type: type,
                                          isSelected: isSelected,
                                          isCurrent: isCurrent,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                      ),

                      // Page indicator
                      if (_tourismTypes.isNotEmpty) ...[
                        SizedBox(
                          height: AppSizes.padding(
                            context,
                            SizeCategory.medium,
                          ),
                        ),
                        SizedBox(
                          height: 8,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _tourismTypes.length > 10
                                  ? 10
                                  : _tourismTypes.length,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                width: _currentPage == index ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color:
                                      _currentPage == index
                                          ? AppColors.primaryGreen
                                          : AppColors.primaryGreen.withOpacity(
                                            0.3,
                                          ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],

                      SizedBox(
                        height: AppSizes.padding(context, SizeCategory.medium),
                      ),

                      // Selected count
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.padding(
                            context,
                            SizeCategory.medium,
                          ),
                          vertical: AppSizes.padding(
                            context,
                            SizeCategory.small,
                          ),
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.getSurfaceColor(context),
                          borderRadius: BorderRadius.circular(
                            AppSizes.radius(context, SizeCategory.large),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppColors.primaryGreen,
                              size: AppSizes.icon(context, SizeCategory.medium),
                            ),
                            SizedBox(
                              width: AppSizes.padding(
                                context,
                                SizeCategory.small,
                              ),
                            ),
                            Text(
                              'Đã chọn ${_selectedTypeIds.length} loại hình',
                              style: TextStyle(
                                color: AppTheme.getTextPrimaryColor(context),
                                fontSize: AppSizes.font(
                                  context,
                                  SizeCategory.medium,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(
                        height: AppSizes.padding(context, SizeCategory.large),
                      ),

                      // Buttons
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.padding(
                            context,
                            SizeCategory.large,
                          ),
                        ),
                        child: Column(
                          children: [
                            CustomButton(
                              text: "BẮT ĐẦU KHÁM PHÁ",
                              width: double.infinity,
                              isLoading: _isSaving,
                              onPressed: _isSaving ? null : _savePreferences,
                            ),

                            SizedBox(
                              height: AppSizes.padding(
                                context,
                                SizeCategory.small,
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  _isSaving
                                      ? null
                                      : () {
                                        if (mounted && !_isSaving) {
                                          Navigator.of(context).pop(false);
                                        }
                                      },
                              child: Text(
                                'Bỏ qua và vào Bản đồ',
                                style: TextStyle(
                                  color:
                                      _isSaving
                                          ? AppTheme.getTextSecondaryColor(
                                            context,
                                          ).withOpacity(0.5)
                                          : AppTheme.getTextSecondaryColor(
                                            context,
                                          ),
                                  fontSize: AppSizes.font(
                                    context,
                                    SizeCategory.small,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(
                        height: AppSizes.padding(context, SizeCategory.large),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  Widget _buildTypeCard({
    required TourismType type,
    required bool isSelected,
    required bool isCurrent,
  }) {
    final style = _getStyleForType(type.name);

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
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: AppSizes.padding(context, SizeCategory.small),
          vertical: AppSizes.padding(context, SizeCategory.large),
        ),
        decoration: BoxDecoration(
          gradient: style['gradient'],
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.xlarge),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  isSelected
                      ? style['color'].withOpacity(0.6)
                      : Colors.black.withOpacity(0.2),
              blurRadius: isSelected ? 20 : 10,
              offset: const Offset(0, 8),
            ),
          ],
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
        ),
        child: Stack(
          children: [
            // Content - Centered layout
            Padding(
              padding: EdgeInsets.all(
                AppSizes.padding(context, SizeCategory.medium),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Selection indicator (top right)
                  if (isSelected)
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: EdgeInsets.all(
                          AppSizes.padding(context, SizeCategory.small),
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check,
                          color: style['color'],
                          size: AppSizes.icon(context, SizeCategory.medium),
                        ),
                      ),
                    ),

                  const Spacer(),

                  // Emoji Icon - Centered
                  Container(
                    padding: EdgeInsets.all(
                      AppSizes.padding(context, SizeCategory.large),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      style['emoji'],
                      style: TextStyle(
                        fontSize:
                            AppSizes.font(context, SizeCategory.xxxlarge) * 1.5,
                      ),
                    ),
                  ),

                  SizedBox(
                    height: AppSizes.padding(context, SizeCategory.medium),
                  ),

                  // Name with shadow
                  Text(
                    type.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.large),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                          color: Colors.black.withOpacity(0.5),
                        ),
                        Shadow(
                          offset: const Offset(0, 1),
                          blurRadius: 2,
                          color: Colors.black.withOpacity(0.3),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(
                    height: AppSizes.padding(context, SizeCategory.small),
                  ),

                  // Description with shadow
                  Text(
                    type.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppSizes.font(context, SizeCategory.small),
                      color: Colors.white.withOpacity(0.95),
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.black.withOpacity(0.4),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const Spacer(),

                  // Status indicator
                  if (isCurrent)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSizes.padding(
                          context,
                          SizeCategory.medium,
                        ),
                        vertical: AppSizes.padding(context, SizeCategory.small),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(
                          AppSizes.radius(context, SizeCategory.large),
                        ),
                      ),
                      child: Text(
                        isSelected ? 'Đã chọn' : 'Nhấn để chọn',
                        style: TextStyle(
                          fontSize: AppSizes.font(context, SizeCategory.small),
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 1),
                              blurRadius: 2,
                              color: Colors.black.withOpacity(0.3),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
