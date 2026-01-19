import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';
import '../../models/call.dart';
import '../../models/user_model.dart';
import '../../states/call_provider.dart';
import '../../config/call_config.dart';
import '../../utils/constants.dart';

/// Màn hình cuộc gọi với Agora RTC
class CallScreen extends StatefulWidget {
  final Call call;
  final bool shouldAnswerOnInit;

  const CallScreen({
    super.key,
    required this.call,
    this.shouldAnswerOnInit = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RtcEngine? _engine;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isCameraOn = true;
  bool _isJoined = false;
  int? _remoteUid;
  Timer? _durationTimer;
  int _callDuration = 0;
  List<UserModel> _participants = [];
  bool _isLoading = true;

  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get isVideoCall => widget.call.callType == CallType.video;
  bool get isCaller => widget.call.callerId == currentUserId;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();

    // If coming from IncomingCallScreen, answer the call first
    if (widget.shouldAnswerOnInit) {
      _answerCallInFirestore();
    }

    _initialize();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _leaveChannel();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _answerCallInFirestore() async {
    try {
      debugPrint('📞 Answering call in Firestore: ${widget.call.id}');
      final callProvider = Provider.of<CallProvider>(context, listen: false);
      await callProvider.answerCall(widget.call.id, currentUserId);
      debugPrint('✅ Call answered in Firestore successfully');
    } catch (e) {
      debugPrint('❌ Error answering call in Firestore: $e');
    }
  }

  Future<void> _initialize() async {
    try {
      await _requestPermissions();
      await _loadParticipants();
      await _initializeAgora();

      if (widget.call.callStatus == CallStatus.answered || isCaller) {
        _startDurationTimer();
      }
    } catch (e) {
      debugPrint('❌ Error initializing call: $e');
      if (mounted) {
        _showError('Không thể khởi tạo cuộc gọi: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _requestPermissions() async {
    final permissions = [
      Permission.microphone,
      if (isVideoCall) Permission.camera,
    ];

    for (final permission in permissions) {
      final status = await permission.request();
      if (!status.isGranted) {
        throw Exception('Cần cấp quyền ${permission.toString()} để tiếp tục');
      }
    }
  }

  Future<void> _loadParticipants() async {
    try {
      final allUserIds = [widget.call.callerId, ...widget.call.receiverIds];
      final docs = await Future.wait(
        allUserIds.map(
          (id) => FirebaseFirestore.instance.collection('users').doc(id).get(),
        ),
      );

      if (mounted) {
        setState(() {
          _participants =
              docs
                  .where((doc) => doc.exists)
                  .map((doc) => UserModel.fromFirestore(doc))
                  .toList();
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading participants: $e');
    }
  }

  Future<void> _initializeAgora() async {
    try {
      // Validate Agora configuration
      if (!CallConfig.isConfigured) {
        throw Exception(
          'Agora App ID chưa được cấu hình. Vui lòng cập nhật CallConfig.agoraAppId trong lib/config/call_config.dart',
        );
      }

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        RtcEngineContext(
          appId: CallConfig.agoraAppId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('✅ Joined channel: ${connection.channelId}');
            setState(() => _isJoined = true);
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('✅ Remote user joined: $remoteUid');
            setState(() => _remoteUid = remoteUid);
          },
          onUserOffline: (
            RtcConnection connection,
            int remoteUid,
            UserOfflineReasonType reason,
          ) {
            debugPrint('❌ Remote user offline: $remoteUid');
            setState(() => _remoteUid = null);
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('❌ Agora error: $err - $msg');
          },
        ),
      );

      if (isVideoCall) {
        await _engine!.enableVideo();
        await _engine!.startPreview();
      } else {
        await _engine!.disableVideo();
      }

      await _engine!.joinChannel(
        token: widget.call.agoraToken ?? '',
        channelId: widget.call.agoraChannelName ?? '',
        uid: 0,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      debugPrint('❌ Error initializing Agora: $e');
      rethrow;
    }
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _callDuration++);
      }
    });
  }

  Future<void> _leaveChannel() async {
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
      _engine = null;
    } catch (e) {
      debugPrint('❌ Error leaving channel: $e');
    }
  }

  Future<void> _endCall() async {
    try {
      final callProvider = Provider.of<CallProvider>(context, listen: false);
      await callProvider.endCall(widget.call.id, duration: _callDuration);

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Lỗi kết thúc cuộc gọi: $e');
    }
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _engine?.muteLocalAudioStream(_isMuted);
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    _engine?.setEnableSpeakerphone(_isSpeakerOn);
  }

  void _toggleCamera() {
    if (!isVideoCall) return;
    setState(() => _isCameraOn = !_isCameraOn);
    _engine?.muteLocalVideoStream(!_isCameraOn);
  }

  void _switchCamera() {
    if (!isVideoCall) return;
    _engine?.switchCamera();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    return Consumer<CallProvider>(
      builder: (context, callProvider, child) {
        // Auto-dismiss when call ended remotely
        if (callProvider.currentCall?.id == widget.call.id &&
            callProvider.currentCall?.callStatus == CallStatus.ended) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          });
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                // Video views
                if (isVideoCall) _buildVideoViews(),

                // Overlay controls
                _buildOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoViews() {
    return Stack(
      children: [
        // Remote video (full screen)
        if (_remoteUid != null)
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine!,
              canvas: VideoCanvas(uid: _remoteUid),
              connection: RtcConnection(
                channelId: widget.call.agoraChannelName,
              ),
            ),
          )
        else
          Center(
            child: Text(
              'Đang chờ người khác tham gia...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),

        // Local video (small corner)
        if (_isCameraOn)
          Positioned(
            top: 50,
            right: 20,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOverlay() {
    return Column(
      children: [
        // Top info
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (!isVideoCall || !_isJoined)
                CircleAvatar(
                  radius: 50,
                  backgroundImage:
                      _participants.isNotEmpty &&
                              (_participants.first.avatarUrl?.isNotEmpty ??
                                  false)
                          ? NetworkImage(_participants.first.avatarUrl!)
                          : null,
                  child:
                      _participants.isEmpty ||
                              !(_participants.first.avatarUrl?.isNotEmpty ??
                                  false)
                          ? Icon(Icons.person, size: 50, color: Colors.white)
                          : null,
                ),

              const SizedBox(height: 16),

              Text(
                _participants.isNotEmpty
                    ? _participants.first.name
                    : 'Đang tải...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _isJoined ? _formatDuration(_callDuration) : 'Đang kết nối...',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Bottom controls
        Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute
                  _buildControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    label: _isMuted ? 'Bật mic' : 'Tắt mic',
                    color: _isMuted ? Colors.red : Colors.white,
                    onPressed: _toggleMute,
                  ),

                  // Speaker (voice call only)
                  if (!isVideoCall)
                    _buildControlButton(
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                      label: _isSpeakerOn ? 'Loa thường' : 'Loa ngoài',
                      color: Colors.white,
                      onPressed: _toggleSpeaker,
                    ),

                  // Camera (video call only)
                  if (isVideoCall)
                    _buildControlButton(
                      icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                      label: _isCameraOn ? 'Tắt camera' : 'Bật camera',
                      color: _isCameraOn ? Colors.white : Colors.red,
                      onPressed: _toggleCamera,
                    ),

                  // Switch camera (video call only)
                  if (isVideoCall)
                    _buildControlButton(
                      icon: Icons.flip_camera_ios,
                      label: 'Đổi camera',
                      color: Colors.white,
                      onPressed: _switchCamera,
                    ),
                ],
              ),

              const SizedBox(height: 30),

              // End call button
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(Icons.call_end, color: Colors.white, size: 35),
                  onPressed: _endCall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: color, size: 28),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
