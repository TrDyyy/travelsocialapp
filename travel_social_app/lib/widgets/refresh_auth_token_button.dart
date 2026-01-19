import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Button để force refresh Firebase Auth token
class RefreshAuthTokenButton extends StatefulWidget {
  const RefreshAuthTokenButton({super.key});

  @override
  State<RefreshAuthTokenButton> createState() => _RefreshAuthTokenButtonState();
}

class _RefreshAuthTokenButtonState extends State<RefreshAuthTokenButton> {
  bool _isLoading = false;

  Future<void> _refreshToken() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showMessage('❌ Chưa đăng nhập');
        return;
      }

      // Force reload user để get token mới
      await user.reload();

      // Get fresh token
      final token = await user.getIdToken(true); // true = force refresh

      debugPrint('✅ Token refreshed: ${token?.substring(0, 20)}...');
      _showMessage('✅ Đã refresh token thành công!');
    } catch (e) {
      debugPrint('❌ Error refreshing token: $e');
      _showMessage('❌ Lỗi: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: _isLoading ? null : _refreshToken,
      icon:
          _isLoading
              ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
              : const Icon(Icons.refresh),
      label: const Text('Refresh Token'),
      backgroundColor: Colors.orange,
    );
  }
}
