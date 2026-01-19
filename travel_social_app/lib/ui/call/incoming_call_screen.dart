import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../models/call.dart';
import '../../models/user_model.dart';
import '../../states/call_provider.dart';
import '../../utils/constants.dart';
import '../../main.dart'; // Import to access MyApp.navigatorKey
import 'call_screen.dart';

/// Màn hình hiển thị cuộc gọi đến (overlay)
class IncomingCallScreen extends StatefulWidget {
  final Call call;

  const IncomingCallScreen({super.key, required this.call});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final AudioPlayer _audioPlayer = AudioPlayer();
  UserModel? _caller;
  bool _isLoading = false;
  bool _isNavigating = false;

  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadCallerInfo();
    _startRingtone();

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
    _stopRingtone();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCallerInfo() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.call.callerId)
              .get();
      if (doc.exists && mounted) {
        setState(() {
          _caller = UserModel.fromFirestore(doc);
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading caller info: $e');
    }
  }

  Future<void> _startRingtone() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('audio/ringtone.mp3'));
      debugPrint('🔔 Started ringtone from assets/audio/ringtone.mp3');
    } catch (e) {
      debugPrint('❌ Error starting ringtone: $e');
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await _audioPlayer.stop();
      debugPrint('🔕 Stopped ringtone');
    } catch (e) {
      debugPrint('❌ Error stopping ringtone: $e');
    }
  }

  Future<void> _handleAnswer() async {
    if (_isLoading || _isNavigating) return;

    // Stop ringtone immediately
    await _stopRingtone();

    setState(() {
      _isLoading = true;
      _isNavigating = true;
    });

    try {
      debugPrint('📞 Answering call: ${widget.call.id}');

      // Use GlobalKey to navigate from main app navigator
      final navigator = MyApp.navigatorKey.currentState;
      if (navigator == null) {
        debugPrint('❌ Navigator not available');
        return;
      }

      debugPrint('🚀 Navigating to CallScreen using GlobalKey...');

      // Create call with answered status for navigation
      final callForNavigation = widget.call.copyWith(
        callStatus: CallStatus.answered,
      );

      await navigator.push(
        MaterialPageRoute(
          builder:
              (context) =>
                  CallScreen(call: callForNavigation, shouldAnswerOnInit: true),
        ),
      );

      debugPrint('✅ CallScreen route completed');
    } catch (e) {
      debugPrint('❌ Error in _handleAnswer: $e');
      if (mounted) {
        // Use GlobalKey for ScaffoldMessenger too
        final messengerState = ScaffoldMessenger.maybeOf(
          MyApp.navigatorKey.currentContext!,
        );
        messengerState?.showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
        setState(() {
          _isLoading = false;
          _isNavigating = false;
        });
      }
    }
  }

  Future<void> _handleReject() async {
    if (_isLoading || _isNavigating) return;

    // Stop ringtone immediately
    await _stopRingtone();

    setState(() => _isLoading = true);

    try {
      final callProvider = Provider.of<CallProvider>(context, listen: false);
      await callProvider.rejectCall(widget.call.id, currentUserId);

      // Don't navigate here - let the Consumer handle it when status changes
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToCallScreen(Call call) {
    if (_isNavigating || !mounted) {
      debugPrint(
        '⚠️ Cannot navigate to CallScreen: isNavigating=$_isNavigating, mounted=$mounted',
      );
      return;
    }
    _isNavigating = true;

    debugPrint('🚀 Navigating to CallScreen for call: ${call.id}');

    // Navigate to CallScreen as a new route
    // The overlay will hide automatically when status changes
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => CallScreen(call: call)))
        .then((_) {
          debugPrint('✅ CallScreen route completed');
          if (mounted) {
            setState(() => _isNavigating = false);
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallProvider>(
      builder: (context, callProvider, _) {
        final currentCall = callProvider.currentCall;

        debugPrint(
          '🔄 IncomingCallScreen rebuild - currentCall: ${currentCall?.id}, status: ${currentCall?.callStatus}',
        );

        // Xử lý các trạng thái của cuộc gọi
        if (currentCall == null || currentCall.id != widget.call.id) {
          // Call đã bị cancel/ended - stop ringtone and hide overlay
          debugPrint('❌ Call ended or cancelled, hiding overlay');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _stopRingtone();
          });
          return const SizedBox.shrink();
        }

        // Nếu call được answer → chuyển sang CallScreen
        if (currentCall.callStatus == CallStatus.answered) {
          debugPrint('✅ Call answered, navigating to CallScreen...');
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _navigateToCallScreen(currentCall),
          );
          return const SizedBox.shrink();
        }

        // Nếu call bị reject/ended → stop ringtone and hide overlay
        if (currentCall.callStatus == CallStatus.rejected ||
            currentCall.callStatus == CallStatus.ended ||
            currentCall.callStatus == CallStatus.missed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _stopRingtone();
          });
          return const SizedBox.shrink();
        }

        // Hiển thị màn hình incoming call
        return _buildIncomingCallUI();
      },
    );
  }

  Widget _buildIncomingCallUI() {
    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 60),

            // Caller info
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
                          (_caller?.avatarUrl?.isNotEmpty ?? false)
                              ? NetworkImage(_caller!.avatarUrl!)
                              : null,
                      child:
                          !(_caller?.avatarUrl?.isNotEmpty ?? false)
                              ? Icon(
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
                  _caller?.name ?? 'Đang tải...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppSizes.font(context, SizeCategory.xxlarge),
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  widget.call.callType == CallType.video
                      ? 'Cuộc gọi video đến'
                      : 'Cuộc gọi thoại đến',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: AppSizes.font(context, SizeCategory.large),
                  ),
                ),
              ],
            ),

            // Action buttons
            Padding(
              padding: EdgeInsets.all(
                AppSizes.padding(context, SizeCategory.xlarge),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Reject button
                  _buildActionButton(
                    icon: Icons.call_end,
                    label: 'Từ chối',
                    color: Colors.red,
                    onPressed: _isLoading ? null : _handleReject,
                  ),

                  // Answer button
                  _buildActionButton(
                    icon:
                        widget.call.callType == CallType.video
                            ? Icons.videocam
                            : Icons.call,
                    label: 'Trả lời',
                    color: Colors.green,
                    onPressed: _isLoading ? null : _handleAnswer,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: onPressed == null ? Colors.grey : color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 35),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: AppSizes.font(context, SizeCategory.medium),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
