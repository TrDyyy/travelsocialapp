import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../states/auth_provider.dart';
import '../../../utils/constants.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/custom_button.dart';

/// Component cho tab đăng ký
class RegisterTab extends StatefulWidget {
  const RegisterTab({super.key});

  @override
  State<RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<RegisterTab> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();

      final success = await authProvider.signUpWithEmail(
        _emailController.text,
        _passwordController.text,
      );

      if (success && mounted) {
        _showSuccess('Đăng ký thành công! Vui lòng đăng nhập');
        // Clear form
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
      } else if (mounted) {
        _showError(authProvider.errorMessage ?? 'Đăng ký thất bại');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Email field
            CustomTextField(
              controller: _emailController,
              hintText: 'Email hoặc số điện thoại ...',
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập email';
                }
                if (!value.contains('@')) {
                  return 'Email không hợp lệ';
                }
                return null;
              },
            ),

            SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),

            // Password field
            CustomTextField(
              controller: _passwordController,
              hintText: 'Mật khẩu ...',
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập mật khẩu';
                }
                if (value.length < 6) {
                  return 'Mật khẩu phải có ít nhất 6 ký tự';
                }
                return null;
              },
            ),

            SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),

            // Confirm Password field
            CustomTextField(
              controller: _confirmPasswordController,
              hintText: 'Xác nhận mật khẩu ...',
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng xác nhận mật khẩu';
                }
                if (value != _passwordController.text) {
                  return 'Mật khẩu không khớp';
                }
                return null;
              },
            ),

            SizedBox(height: AppSizes.padding(context, SizeCategory.large)),

            // Register button
            CustomButton(
              text: 'Đăng Ký',
              onPressed: _handleRegister,
              isLoading: authProvider.isLoading,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}
