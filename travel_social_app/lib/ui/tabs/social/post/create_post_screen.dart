import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/post.dart';
import '../../../../models/review.dart';
import '../../../../models/place.dart';
import '../../../../models/user_model.dart';
import '../../../../states/post_provider.dart';
import '../../../../services/media_service.dart';
import '../../../../services/place_service.dart';
import '../../../../services/user_service.dart';
import '../../../../services/friend_service.dart';
import '../../../../services/activity_tracking_service.dart';
import '../../../../services/points_tracking_service.dart';
import '../../../../utils/constants.dart';
import '../../../../widgets/editable_image_grid.dart';
import '../../place/widgets/search_bar_widget.dart';

/// Màn hình tạo/chỉnh sửa post
class CreatePostScreen extends StatefulWidget {
  final Post? existingPost; // Nếu có thì là edit
  final Review? reviewToShare; // Nếu share review
  final Place? placeToShare;
  final String? groupCommunityId; // ID của group nếu tạo post trong group

  const CreatePostScreen({
    super.key,
    this.existingPost,
    this.reviewToShare,
    this.placeToShare,
    this.groupCommunityId,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _mediaService = MediaService();
  final _placeService = PlaceService();
  final _userService = UserService();
  final _friendService = FriendService();
  final _activityService = ActivityTrackingService();
  final _pointsService = PointsTrackingService();
  final _contentController = TextEditingController();

  List<File> _selectedMediaFiles = [];
  List<String> _existingMediaUrls = []; // Ảnh/video cũ khi edit
  List<String> _mediaToDelete = []; // Media cần xóa
  bool _isLoading = false;

  // New fields for tagging
  Place? _taggedPlace;
  List<UserModel> _taggedFriends = [];
  Feeling? _selectedFeeling;

  @override
  void initState() {
    super.initState();

    // Load data nếu edit
    if (widget.existingPost != null) {
      _contentController.text = widget.existingPost!.content;
      if (widget.existingPost!.mediaUrls != null) {
        _existingMediaUrls = List.from(widget.existingPost!.mediaUrls!);
      }
      _selectedFeeling = widget.existingPost!.feeling;
      // Load tagged place and friends if needed
      _loadExistingTags();
    }
  }

  Future<void> _loadExistingTags() async {
    if (widget.existingPost?.taggedPlaceId != null) {
      final place = await _placeService.getPlaceById(
        widget.existingPost!.taggedPlaceId!,
      );
      if (place != null && mounted) {
        setState(() {
          _taggedPlace = place;
        });
      }
    }

    if (widget.existingPost?.taggedUserIds != null) {
      final friends = <UserModel>[];
      for (final userId in widget.existingPost!.taggedUserIds!) {
        final user = await _userService.getUserById(userId);
        if (user != null) {
          friends.add(user);
        }
      }
      if (mounted) {
        setState(() {
          _taggedFriends = friends;
        });
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await _mediaService.pickImages();
    if (images.isNotEmpty) {
      setState(() {
        _selectedMediaFiles.addAll(images);
      });
    }
  }

  Future<void> _pickVideo() async {
    try {
      final video = await _mediaService.pickVideo();
      if (video != null) {
        setState(() {
          _selectedMediaFiles.add(video);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    final photo = await _mediaService.takePhoto();
    if (photo != null) {
      setState(() {
        _selectedMediaFiles.add(photo);
      });
    }
  }

  Future<void> _recordVideo() async {
    try {
      final video = await _mediaService.recordVideo();
      if (video != null) {
        setState(() {
          _selectedMediaFiles.add(video);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _removeMediaFile(int index) {
    setState(() {
      _selectedMediaFiles.removeAt(index);
    });
  }

  void _removeExistingMedia(int index) {
    setState(() {
      final mediaUrl = _existingMediaUrls.removeAt(index);
      _mediaToDelete.add(mediaUrl);
    });
  }

  Future<void> _submitPost() async {
    final content = _contentController.text.trim();

    // Validate: Phải có content HOẶC media (mới hoặc cũ)
    final hasContent = content.isNotEmpty;
    final hasNewMedia = _selectedMediaFiles.isNotEmpty;
    final hasExistingMedia = _existingMediaUrls.isNotEmpty;

    if (!hasContent && !hasNewMedia && !hasExistingMedia) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập nội dung hoặc thêm ảnh/video'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Vui lòng đăng nhập');
      }

      if (widget.existingPost != null) {
        // === EDIT POST ===

        // Xóa media cũ đã bị remove
        if (_mediaToDelete.isNotEmpty) {
          await _mediaService.deleteMedia(_mediaToDelete);
        }

        // Upload media mới
        List<String> newMediaUrls = [];
        if (_selectedMediaFiles.isNotEmpty) {
          newMediaUrls = await _mediaService.uploadMedia(
            _selectedMediaFiles,
            'posts/${user.uid}_${DateTime.now().millisecondsSinceEpoch}',
          );

          if (newMediaUrls.isEmpty && _selectedMediaFiles.isNotEmpty) {
            throw Exception('Không thể upload media');
          }
        }

        // Gộp media cũ + mới
        final finalMediaUrls = [..._existingMediaUrls, ...newMediaUrls];

        // Update post - luôn truyền tất cả giá trị (null/empty = xóa tag)
        final postProvider = Provider.of<PostProvider>(context, listen: false);
        final success = await postProvider.updatePost(
          widget.existingPost!.postId!,
          content,
          finalMediaUrls, // Có thể là [] nếu xóa hết media
          taggedPlaceId: _taggedPlace?.placeId, // null = xóa place tag
          taggedPlaceName: _taggedPlace?.name,
          taggedUserIds:
              _taggedFriends
                  .map((u) => u.userId)
                  .toList(), // [] = xóa friend tags
          feeling: _selectedFeeling, // null = xóa feeling
        );

        if (success && mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Đã cập nhật bài viết'),
              backgroundColor: AppColors.primaryGreen,
            ),
          );
        } else {
          throw Exception('Không thể cập nhật bài viết');
        }
      } else {
        // === CREATE NEW POST ===

        final postType =
            widget.reviewToShare != null
                ? PostType.reviewShare
                : PostType.normal;

        final post = Post(
          userId: user.uid,
          type: postType,
          content: content,
          reviewId: widget.reviewToShare?.reviewId,
          placeId: widget.placeToShare?.placeId,
          taggedPlaceId: _taggedPlace?.placeId,
          taggedPlaceName: _taggedPlace?.name,
          taggedUserIds:
              _taggedFriends.isNotEmpty
                  ? _taggedFriends.map((u) => u.userId).toList()
                  : null,
          feeling: _selectedFeeling,
          communityId: widget.groupCommunityId, // Thêm groupCommunityId
        );

        final postProvider = Provider.of<PostProvider>(context, listen: false);
        final success = await postProvider.createPost(
          post,
          _selectedMediaFiles.isNotEmpty ? _selectedMediaFiles : null,
        );

        if (success && mounted) {
          // Track post with place activity
          if (_taggedPlace != null) {
            await _activityService.trackPostWithPlace(
              postId:
                  DateTime.now().millisecondsSinceEpoch
                      .toString(), // Temporary ID
              placeId: _taggedPlace!.placeId!,
              placeTypeId: _taggedPlace!.typeId,
            );
          }

          // Award points for post
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
          if (currentUserId != null) {
            await _pointsService.awardPost(
              userId: currentUserId,
              postId: DateTime.now().millisecondsSinceEpoch.toString(),
              postText: _contentController.text.trim(),
              imageCount: _selectedMediaFiles.length,
              hasTaggedPlace: _taggedPlace != null,
              isInCommunity: widget.groupCommunityId != null,
            );
          }

          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Đã đăng bài viết'),
              backgroundColor: AppColors.primaryGreen,
            ),
          );
        } else {
          throw Exception('Không thể tạo bài viết');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: AppColors.primaryGreen,
                  ),
                  title: const Text('Chọn ảnh từ thư viện'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImages();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.video_library,
                    color: AppColors.primaryGreen,
                  ),
                  title: const Text('Chọn video từ thư viện'),
                  subtitle: Text(
                    'Tối đa ${MediaService.maxVideoSizeMB}MB',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickVideo();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt,
                    color: AppColors.primaryGreen,
                  ),
                  title: const Text('Chụp ảnh'),
                  onTap: () {
                    Navigator.pop(context);
                    _takePhoto();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.videocam,
                    color: AppColors.primaryGreen,
                  ),
                  title: const Text('Quay video'),
                  subtitle: Text(
                    'Tối đa ${MediaService.maxVideoSizeMB}MB',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _recordVideo();
                  },
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if editing a review share post (không được edit media)
    final isEditingReviewShare =
        widget.existingPost != null &&
        widget.existingPost!.type == PostType.reviewShare;

    return Scaffold(
      backgroundColor: AppTheme.getSurfaceColor(context),
      appBar: AppBar(
        title: Text(
          widget.existingPost != null ? 'Chỉnh sửa bài viết' : 'Tạo bài viết',
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitPost,
            child:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Text(
                      'Đăng',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.large)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Content input
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                hintText: 'Bạn đang nghĩ gì?',
                border: InputBorder.none,
                hintStyle: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              maxLines: null,
              minLines: 5,
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 16),

            // Review share card (nếu có)
            if (widget.reviewToShare != null && widget.placeToShare != null)
              _buildReviewShareCard(),

            // Media preview (chỉ hiển thị nếu KHÔNG phải edit review share)
            if (!isEditingReviewShare &&
                (_existingMediaUrls.isNotEmpty ||
                    _selectedMediaFiles.isNotEmpty))
              _buildMediaPreview(),

            const SizedBox(height: 16),

            // Add media button (ẨN nếu đang edit review share)
            if (!isEditingReviewShare)
              OutlinedButton.icon(
                onPressed: _showMediaOptions,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Thêm ảnh/video'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: const BorderSide(color: AppColors.primaryGreen),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),

            const SizedBox(height: 12),

            // Tag options
            _buildTagOptions(),

            // Thông báo nếu đang edit review share
            if (isEditingReviewShare)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Bài chia sẻ đánh giá chỉ có thể chỉnh sửa nội dung',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
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

  Widget _buildReviewShareCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.getBorderColor(context)),
        borderRadius: BorderRadius.circular(8),
        color: AppTheme.getSurfaceColor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.rate_review,
                size: 16,
                color: AppTheme.getIconPrimaryColor(context),
              ),
              const SizedBox(width: 8),
              Text(
                'Chia sẻ đánh giá',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.getTextSecondaryColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.reviewToShare!.content,
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.medium),
              color: AppTheme.getTextPrimaryColor(context),
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < widget.reviewToShare!.rating
                    ? Icons.star
                    : Icons.star_border,
                color: Colors.amber,
                size: 16,
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            widget.placeToShare!.name,
            style: TextStyle(
              fontSize: AppSizes.font(context, SizeCategory.medium),
              fontWeight: FontWeight.w600,
              color: AppTheme.getTextSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview() {
    return EditableImageGrid(
      existingImageUrls: _existingMediaUrls,
      newImages: _selectedMediaFiles,
      onRemoveExisting: _removeExistingMedia,
      onRemoveNew: _removeMediaFile,
      displayMode: 'grid',
      supportVideo: true, // Enable video support
    );
  }

  Widget _buildTagOptions() {
    debugPrint(
      '🏷️ Building tag options: ${_taggedFriends.length} friends, place: ${_taggedPlace?.name}, feeling: ${_selectedFeeling?.displayName}',
    );

    return Column(
      children: [
        // Tagged location
        if (_taggedPlace != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 16,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tại ${_taggedPlace!.name}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() => _taggedPlace = null),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

        // Tagged friends
        if (_taggedFriends.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.people,
                  size: 16,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cùng với ${_taggedFriends.map((u) => u.name).join(", ")}',
                    style: const TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() => _taggedFriends.clear()),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

        // Feeling
        if (_selectedFeeling != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(
                  _selectedFeeling!.emoji,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đang cảm thấy ${_selectedFeeling!.displayName.toLowerCase()}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() => _selectedFeeling = null),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: _buildTagButton(
                onPressed: _showPlacePicker,
                icon: Icons.location_on,
                label: 'Địa điểm',
                context: context,
              ),
            ),

            SizedBox(width: AppSizes.padding(context, SizeCategory.small)),
            Flexible(
              child: _buildTagButton(
                onPressed: _showFriendsPicker,
                icon: Icons.person_add,
                label: 'Bạn bè',
                context: context,
              ),
            ),

            SizedBox(width: AppSizes.padding(context, SizeCategory.small)),

            Flexible(
              child: _buildTagButton(
                onPressed: _showFeelingPicker,
                icon: Icons.mood,
                label: 'Cảm xúc',
                context: context,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTagButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required BuildContext context,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: AppSizes.icon(context, SizeCategory.small)),
      label: Text(
        label,
        style: TextStyle(fontSize: AppSizes.font(context, SizeCategory.small)),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryGreen,
        side: BorderSide(color: AppColors.primaryGreen),
      ),
    );
  }

  void _showFeelingPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bạn đang cảm thấy thế nào?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...Feeling.values.map((feeling) {
                  return ListTile(
                    leading: Text(
                      feeling.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(feeling.displayName),
                    onTap: () {
                      setState(() {
                        _selectedFeeling = feeling;
                      });
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ],
            ),
          ),
    );
  }

  void _showPlacePicker() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chọn địa điểm',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Use PlaceSearchBar for autocomplete
                  Flexible(
                    child: PlaceSearchBar(
                      onPlaceSelected: (prediction) async {
                        // Get place details from prediction
                        final placeId = prediction['place_id'];
                        if (placeId != null) {
                          // Check if place exists in database
                          final existingPlace = await _placeService
                              .getPlaceById(placeId);

                          if (existingPlace != null) {
                            // Place exists in database
                            setState(() {
                              _taggedPlace = existingPlace;
                            });
                            if (mounted) Navigator.pop(context);
                          } else {
                            // Get place details from Google API
                            final placeDetails = await _placeService
                                .getPlaceDetails(placeId);
                            if (placeDetails != null && mounted) {
                              final geometry = placeDetails['geometry'];
                              final location = geometry['location'];
                              final lat = location['lat'];
                              final lng = location['lng'];
                              final name =
                                  placeDetails['name'] ??
                                  prediction['description'];
                              final address =
                                  placeDetails['formatted_address'] ?? '';

                              // Create temporary Place object for tagging
                              final tempPlace = Place(
                                placeId: placeId,
                                name: name,
                                address: address,
                                googlePlaceId: placeId,
                                location: GeoPoint(lat, lng),
                                description: '',
                                typeId: '',
                                createdBy: '',
                              );

                              setState(() {
                                _taggedPlace = tempPlace;
                              });
                              if (mounted) Navigator.pop(context);
                            }
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Gợi ý: Tìm kiếm địa điểm bằng tên hoặc địa chỉ',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showFriendsPicker() async {
    List<UserModel> friends = [];
    bool isLoading = true;
    Set<String> selectedFriendIds = Set.from(
      _taggedFriends.map((f) => f.userId),
    );

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setModalState) {
              if (isLoading) {
                final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                if (currentUserId == null) {
                  setModalState(() {
                    isLoading = false;
                  });
                  return const Center(child: Text('Vui lòng đăng nhập'));
                }

                _friendService
                    .friendsStream(currentUserId)
                    .first
                    .then((friendships) async {
                      // Get user details for each friend
                      List<UserModel> userList = [];
                      for (var friendship in friendships) {
                        final friendId =
                            friendship.userId1 == currentUserId
                                ? friendship.userId2
                                : friendship.userId1;
                        final user = await _userService.getUserById(friendId);
                        if (user != null) userList.add(user);
                      }
                      setModalState(() {
                        friends = userList;
                        isLoading = false;
                      });
                    })
                    .catchError((e) {
                      setModalState(() {
                        isLoading = false;
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Lỗi tải danh sách bạn bè: $e'),
                          ),
                        );
                      }
                    });
              }

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Gắn thẻ bạn bè',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _taggedFriends =
                                  friends
                                      .where(
                                        (f) => selectedFriendIds.contains(
                                          f.userId,
                                        ),
                                      )
                                      .toList();
                            });
                            debugPrint(
                              '✅ Tagged ${_taggedFriends.length} friends',
                            );
                            Navigator.pop(context);
                          },
                          child: const Text('Xong'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (friends.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Bạn chưa có bạn bè nào'),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 400),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: friends.length,
                          itemBuilder: (context, index) {
                            final friend = friends[index];
                            final isSelected = selectedFriendIds.contains(
                              friend.userId,
                            );

                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (checked) {
                                setModalState(() {
                                  if (checked == true) {
                                    selectedFriendIds.add(friend.userId);
                                  } else {
                                    selectedFriendIds.remove(friend.userId);
                                  }
                                });
                              },
                              title: Text(friend.name),
                              subtitle: Text(friend.email),
                              secondary: CircleAvatar(
                                backgroundImage:
                                    friend.avatarUrl != null &&
                                            friend.avatarUrl!.isNotEmpty
                                        ? NetworkImage(friend.avatarUrl!)
                                        : null,
                                child:
                                    friend.avatarUrl == null ||
                                            friend.avatarUrl!.isEmpty
                                        ? Text(
                                          friend.name
                                              .substring(0, 1)
                                              .toUpperCase(),
                                        )
                                        : null,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
    );
  }
}
