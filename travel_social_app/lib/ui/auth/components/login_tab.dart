import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travel_social_app/ui/tabs/homepage.dart';
import '../../../states/auth_provider.dart';
import '../../../utils/constants.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/custom_button.dart';
import '../forgot_password_screen.dart';
import '../../admin/admin_dashboard.dart';
import '../../../services/admin_service.dart';

/// Component cho tab đăng nhập
class LoginTab extends StatefulWidget {
  const LoginTab({super.key});

  @override
  State<LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<LoginTab> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();

      final success = await authProvider.signInWithEmail(
        _emailController.text,
        _passwordController.text,
      );

      if (success && mounted) {
        // Check if user is admin
        final adminService = AdminService();
        final user = authProvider.user;
        if (user != null) {
          final isAdmin = await adminService.isAdmin(user.uid);
          if (isAdmin) {
            // Navigate to Admin Dashboard
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminDashboard()),
            );
            return;
          }
        }

        // Navigate to Homepage for normal users
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Homepage()),
        );
      } else if (mounted) {
        _showError(authProvider.errorMessage ?? 'Đăng nhập thất bại');
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.signInWithGoogle();

    if (success && mounted) {
      // Check if user is admin
      final adminService = AdminService();
      final user = authProvider.user;
      if (user != null) {
        final isAdmin = await adminService.isAdmin(user.uid);
        if (isAdmin) {
          // Navigate to Admin Dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminDashboard()),
          );
          return;
        }
      }

      // Navigate to Homepage for normal users
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Homepage()),
      );
    } else if (mounted && authProvider.errorMessage != null) {
      _showError(authProvider.errorMessage!);
    }
  }

  Future<void> _handleFacebookSignIn() async {
    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.signInWithFacebook();

    if (success && mounted) {
      // Check if user is admin
      final adminService = AdminService();
      final user = authProvider.user;
      if (user != null) {
        final isAdmin = await adminService.isAdmin(user.uid);
        if (isAdmin) {
          // Navigate to Admin Dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminDashboard()),
          );
          return;
        }
      }

      // Navigate to Homepage for normal users
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Homepage()),
      );
    } else if (mounted && authProvider.errorMessage != null) {
      _showError(authProvider.errorMessage!);
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

            SizedBox(height: AppSizes.padding(context, SizeCategory.small)),

            // Forgot password - Aligned to right
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ForgotPasswordScreen(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.padding(context, SizeCategory.small),
                    vertical: AppSizes.padding(context, SizeCategory.small),
                  ),
                ),
                child: Text(
                  'Quên mật khẩu',
                  style: TextStyle(
                    color: AppTheme.getTextSecondaryColor(context),
                    fontSize: AppSizes.font(context, SizeCategory.small),
                  ),
                ),
              ),
            ),

            SizedBox(height: AppSizes.padding(context, SizeCategory.medium)),

            // Login button
            CustomButton(
              text: 'Đăng Nhập',
              onPressed: _handleLogin,
              isLoading: authProvider.isLoading,
              width: double.infinity,
            ),

            SizedBox(height: AppSizes.padding(context, SizeCategory.large)),

            // Divider with "Hoặc"
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: AppTheme.getBorderColor(context),
                    thickness: 1,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.padding(context, SizeCategory.medium),
                  ),
                  child: Text(
                    'Hoặc',
                    style: TextStyle(
                      color: AppTheme.getTextSecondaryColor(context),
                      fontSize: AppSizes.font(context, SizeCategory.small),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: AppTheme.getBorderColor(context),
                    thickness: 1,
                  ),
                ),
              ],
            ),

            SizedBox(height: AppSizes.padding(context, SizeCategory.large)),

            // Social login buttons
            _SocialButton(
              onPressed: _handleGoogleSignIn,
              imagePath: 'assets/icon/google_logo.png',
              text: 'Đăng nhập với Google',
            ),
            SizedBox(height: AppSizes.padding(context, SizeCategory.large)),

            _SocialButton(
              onPressed: _handleFacebookSignIn,
              imagePath: 'assets/icon/facebook_logo.png',
              text: 'Đăng nhập với Facebook',
            ),
            SizedBox(height: AppSizes.padding(context, SizeCategory.large)),
          ],
        ),
      ),
    );
  }
}

/// Widget button cho social login
class _SocialButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String imagePath;
  final String text;

  const _SocialButton({
    required this.onPressed,
    required this.imagePath,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(
        AppSizes.radius(context, SizeCategory.medium),
      ),

      child: Container(
        width: double.infinity,
        height: AppSizes.container(context, SizeCategory.small),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.getBorderColor(context)),
          color: AppTheme.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(
            AppSizes.radius(context, SizeCategory.medium),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo container with white background
            Container(
              width: AppSizes.icon(context, SizeCategory.xxlarge),
              height: AppSizes.icon(context, SizeCategory.xxlarge),
              decoration: BoxDecoration(
                color: AppTheme.getSurfaceColor(context),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: EdgeInsets.all(
                AppSizes.padding(context, SizeCategory.small),
              ),
              child: Image.asset(
                imagePath,
                width: AppSizes.icon(context, SizeCategory.large),
                height: AppSizes.icon(context, SizeCategory.large),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback if image not found
                  return Icon(
                    Icons.login,
                    size: AppSizes.icon(context, SizeCategory.large),
                    color: AppTheme.getSurfaceColor(context),
                  );
                },
              ),
            ),
            SizedBox(width: AppSizes.padding(context, SizeCategory.small)),
            // Text
            Text(
              text,
              style: TextStyle(
                fontSize: AppSizes.font(context, SizeCategory.small),
                fontWeight: FontWeight.w600,
                color: AppTheme.getTextPrimaryColor(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
