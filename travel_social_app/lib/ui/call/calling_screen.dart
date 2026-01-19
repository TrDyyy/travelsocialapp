import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/call.dart';
import '../../models/user_model.dart';
import '../../states/call_provider.dart';
import '../../utils/constants.dart';
import 'call_screen.dart';

/// Màn hình "Đang gọi..." cho người gọi (caller)
class CallingScreen extends StatefulWidget {
  final Call call;

  const CallingScreen({super.key, required this.call});

  @override
  State<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends State<CallingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  UserModel? _receiver;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _loadReceiverInfo();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadReceiverInfo() async {
    try {
      // Lấy thông tin người nhận đầu tiên
      final receiverId = widget.call.receiverIds.firstOrNull;
      if (receiverId == null) return;

      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(receiverId)
              .get();
      if (doc.exists && mounted) {
        setState(() {
          _receiver = UserModel.fromFirestore(doc);
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading receiver info: $e');
    }
  }

  Future<void> _handleCancel() async {
    try {
      final callProvider = Provider.of<CallProvider>(context, listen: false);
      await callProvider.endCall(widget.call.id);

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _navigateToCallScreen(Call call) {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => CallScreen(call: call)),
    );
  }

  void _closeScreen() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallProvider>(
      builder: (context, callProvider, _) {
        final currentCall = callProvider.currentCall;

        // Xử lý các trạng thái của cuộc gọi
        if (currentCall == null || currentCall.id != widget.call.id) {
          // Call đã bị cancel/ended
          WidgetsBinding.instance.addPostFrameCallback((_) => _closeScreen());
          return const SizedBox.shrink();
        }

        // Nếu call được answer → chuyển sang CallScreen
        if (currentCall.callStatus == CallStatus.answered) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _navigateToCallScreen(currentCall),
          );
          return const SizedBox.shrink();
        }

        // Nếu call bị reject/missed → đóng màn hình
        if (currentCall.callStatus == CallStatus.rejected ||
            currentCall.callStatus == CallStatus.missed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _closeScreen();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    currentCall.callStatus == CallStatus.rejected
                        ? 'Cuộc gọi bị từ chối'
                        : 'Không có phản hồi',
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          });
          return const SizedBox.shrink();
        }

        // Hiển thị màn hình "Đang gọi..."
        return Scaffold(
          backgroundColor: AppColors.primaryGreen,
          body: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 60),

                // Receiver info
                Column(
                  children: [
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: CircleAvatar(
                        radius: 80,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        child: CircleAvatar(
                          radius: 75,
                          backgroundImage:
                              (_receiver?.avatarUrl?.isNotEmpty ?? false)
                                  ? NetworkImage(_receiver!.avatarUrl!)
                                  : null,
                          child:
                              !(_receiver?.avatarUrl?.isNotEmpty ?? false)
                                  ? const Icon(
                                    Icons.person,
                                    size: 80,
                                    color: Colors.white,
                                  )
                                  : null,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      _receiver?.name ?? 'Đang tải...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppSizes.font(context, SizeCategory.xxlarge),
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      widget.call.callType == CallType.video
                          ? 'Đang gọi video...'
                          : 'Đang gọi...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: AppSizes.font(context, SizeCategory.large),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Calling animation dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Cancel button
                Padding(
                  padding: EdgeInsets.all(
                    AppSizes.padding(context, SizeCategory.xlarge),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 35,
                          ),
                          onPressed: _handleCancel,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Hủy',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: AppSizes.font(context, SizeCategory.medium),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
