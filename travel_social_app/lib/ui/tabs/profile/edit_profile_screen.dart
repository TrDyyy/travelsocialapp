import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:travel_social_app/models/user_badge.dart';
import '../../../models/user_model.dart';
import '../../../services/user_service.dart';
import '../../../utils/constants.dart';

/// Màn hình chỉnh sửa thông tin cá nhân
class EditProfileScreen extends StatefulWidget {
  final UserModel user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;

  DateTime? _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _bioController = TextEditingController(text: widget.user.bio ?? '');
    _phoneController = TextEditingController(
      text: widget.user.phoneNumber ?? '',
    );
    _selectedDate = widget.user.dateBirth;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final success = await _userService.updateUser(user.uid, {
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'phoneNumber':
            _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
        'dateBirth': _selectedDate,
      });

      if (success && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cập nhật thông tin thành công!'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Chỉnh sửa thông tin',
          style: TextStyle(
            fontSize: AppSizes.font(context, SizeCategory.large),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            AppSizes.padding(context, SizeCategory.large),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Email (Read-only)
              _buildInfoField(
                label: 'Email',
                value: widget.user.email,
                icon: Icons.email,
                enabled: false,
                subtitle: 'Email không thể thay đổi',
              ),
              SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),

              // Name
              _buildTextField(
                controller: _nameController,
                label: 'Tên hiển thị',
                icon: Icons.person,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên';
                  }
                  return null;
                },
              ),
              SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),

              // Bio
              _buildTextField(
                controller: _bioController,
                label: 'Tiểu sử',
                icon: Icons.description,
                maxLines: 3,
                hintText: 'Giới thiệu về bạn...',
              ),
              SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),

              // Phone
              _buildTextField(
                controller: _phoneController,
                label: 'Số điện thoại',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                hintText: '0901234567',
              ),
              SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),

              // Date of Birth
              _buildDateField(),
              SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),

              // Rank (Read-only)
              _buildInfoField(
                label: 'Cấp bậc',
                value:
                    widget.user.currentBadge?.name ??
                    UserBadge.getBadgeByPoints(widget.user.totalPoints).name,
                icon: Icons.military_tech,
                enabled: false,
              ),
              SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),

              // Points (Read-only)
              _buildInfoField(
                label: 'Điểm tích lũy',
                value: '${widget.user.totalPoints} điểm',
                icon: Icons.stars,
                enabled: false,
              ),
              SizedBox(height: AppSizes.padding(context, SizeCategory.xlarge)),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: AppSizes.container(context, SizeCategory.medium),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSizes.radius(context, SizeCategory.medium),
                      ),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : Text(
                            'Lưu thay đổi',
                            style: TextStyle(
                              fontSize: AppSizes.font(
                                context,
                                SizeCategory.medium,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: AppTheme.getTextPrimaryColor(context)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.getTextSecondaryColor(context)),
        hintText: hintText,
        hintStyle: TextStyle(color: AppTheme.getTextSecondaryColor(context)),
        prefixIcon: Icon(icon, color: AppTheme.getIconSecondaryColor(context)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
          borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
          borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        filled: true,
        fillColor: AppTheme.getInputBackgroundColor(context),
      ),
      validator: validator,
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _selectDate,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Ngày sinh',
          labelStyle: TextStyle(color: AppTheme.getTextSecondaryColor(context)),
          prefixIcon: Icon(
            Icons.calendar_today,
            color: AppTheme.getIconSecondaryColor(context),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              AppSizes.radius(context, SizeCategory.medium),
            ),
            borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              AppSizes.radius(context, SizeCategory.medium),
            ),
            borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
          ),
          filled: true,
          fillColor: AppTheme.getInputBackgroundColor(context),
        ),
        child: Text(
          _selectedDate != null
              ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
              : 'Chọn ngày sinh',
          style: TextStyle(
            color:
                _selectedDate != null
                    ? AppTheme.getTextPrimaryColor(context)
                    : AppTheme.getTextSecondaryColor(context),
            fontSize: AppSizes.font(context, SizeCategory.medium),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoField({
    required String label,
    required String value,
    required IconData icon,
    required bool enabled,
    String? subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: value,
          enabled: enabled,
          style: TextStyle(
            color:
                enabled
                    ? AppTheme.getTextPrimaryColor(context)
                    : AppTheme.getTextSecondaryColor(context),
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: AppTheme.getTextSecondaryColor(context),
            ),
            prefixIcon: Icon(
              icon,
              color: AppTheme.getIconSecondaryColor(context),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppSizes.radius(context, SizeCategory.medium),
              ),
              borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppSizes.radius(context, SizeCategory.medium),
              ),
              borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppSizes.radius(context, SizeCategory.medium),
              ),
              borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
            ),
            filled: true,
            fillColor:
                isDark
                    ? AppColors.darkInputBackground.withOpacity(0.5)
                    : AppColors.lightInputBackground.withOpacity(0.5),
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: EdgeInsets.only(
              left: AppSizes.padding(context, SizeCategory.small),
              top: AppSizes.padding(context, SizeCategory.small) / 2,
            ),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.small),
                color: AppTheme.getTextSecondaryColor(context),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}
