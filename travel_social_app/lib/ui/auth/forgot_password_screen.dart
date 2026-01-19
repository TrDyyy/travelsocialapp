import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../states/auth_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';

/// Màn hình quên mật khẩu
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();

      final success = await authProvider.sendPasswordResetEmail(
        _emailController.text,
      );

      if (success && mounted) {
        _showSuccess(
          'Email đặt lại mật khẩu đã được gửi!\nVui lòng kiểm tra hộp thư của bạn.',
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      } else if (mounted) {
        _showError(authProvider.errorMessage ?? 'Gửi email thất bại');
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.getGradient(context)),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: EdgeInsets.all(
                  AppSizes.padding(context, SizeCategory.medium),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back,
                        color: AppTheme.getIconPrimaryColor(context),
                      ),
                    ),
                    Text(
                      'Quên mật khẩu',
                      style: TextStyle(
                        fontSize: AppSizes.font(context, SizeCategory.large),
                        fontWeight: FontWeight.bold,
                        color: AppTheme.getTextPrimaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(
                      AppSizes.padding(context, SizeCategory.large),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppTheme.getSurfaceColor(context),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.lock_reset,
                            size: AppSizes.icon(context, SizeCategory.xxxlarge),
                            color: AppColors.primaryGreen,
                          ),
                        ),

                        SizedBox(
                          height: AppSizes.padding(context, SizeCategory.large),
                        ),

                        // Title
                        Text(
                          'Đặt lại mật khẩu',
                          style: TextStyle(
                            fontSize: AppSizes.font(
                              context,
                              SizeCategory.xxlarge,
                            ),
                            fontWeight: FontWeight.bold,
                            color: AppTheme.getTextPrimaryColor(context),
                          ),
                        ),

                        SizedBox(
                          height: AppSizes.padding(
                            context,
                            SizeCategory.medium,
                          ),
                        ),

                        // Description
                        Text(
                          'Nhập email của bạn để nhận\nliên kết đặt lại mật khẩu',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: AppSizes.font(
                              context,
                              SizeCategory.medium,
                            ),
                            color: AppTheme.getTextSecondaryColor(context),
                            height: 1.5,
                          ),
                        ),

                        SizedBox(
                          height: AppSizes.padding(
                            context,
                            SizeCategory.xlarge,
                          ),
                        ),

                        // Form
                        _buildResetForm(context),
                      ],
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

  Widget _buildResetForm(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.large)),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(
          AppSizes.radius(context, SizeCategory.large),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Email field
            CustomTextField(
              controller: _emailController,
              hintText: 'Email của bạn ...',
              prefixIcon: Icons.email_outlined,
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

            SizedBox(height: AppSizes.padding(context, SizeCategory.large)),

            // Send button
            Builder(
              builder: (context) {
                final authProvider = context.watch<AuthProvider>();
                return CustomButton(
                  text: 'Gửi email',
                  onPressed: _handleResetPassword,
                  isLoading: authProvider.isLoading,
                  width: double.infinity,
                  icon: Icons.send,
                );
              },
            ),

            SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),

            // Back to login
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Nhớ mật khẩu? ',
                  style: TextStyle(
                    color: AppTheme.getTextSecondaryColor(context),
                    fontSize: AppSizes.font(context, SizeCategory.small),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Đăng nhập',
                    style: TextStyle(
                      color: AppColors.primaryGreen,
                      fontSize: AppSizes.font(context, SizeCategory.small),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
