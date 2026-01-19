import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/review.dart';
import '../../../models/place.dart';
import '../../../models/user_model.dart';
import '../../../models/reaction.dart';
import '../../../models/community.dart';
import '../../../models/violation_request.dart';
import '../../../services/review_service.dart';
import '../../../services/user_service.dart';
import '../../../services/place_service.dart';
import '../../../services/reaction_service.dart';
import '../../../services/community_service.dart';
import '../../../utils/constants.dart';
import '../../../widgets/reaction_button.dart';
import '../../../widgets/violation_report_dialog.dart';
import '../../profile/profile_screen.dart';
import 'write_review_screen.dart';
import '../social/post/create_post_screen.dart';
import 'package:intl/intl.dart';

/// Màn hình xem danh sách đánh giá
class ReviewsScreen extends StatefulWidget {
  final Place place;

  const ReviewsScreen({super.key, required this.place});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final _reviewService = ReviewService();
  final _userService = UserService();
  final _placeService = PlaceService();
  final _communityService = CommunityService();
  Review? _userReview;
  bool _isLoadingUserReview = true;

  @override
  void initState() {
    super.initState();
    _loadUserReview();
  }

  Future<void> _loadUserReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final review = await _reviewService.getUserReviewForPlace(
        user.uid,
        widget.place.placeId!,
      );
      setState(() {
        _userReview = review;
        _isLoadingUserReview = false;
      });
    } else {
      setState(() {
        _isLoadingUserReview = false;
      });
    }
  }

  Future<void> _navigateToWriteReview() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => WriteReviewScreen(
              place: widget.place,
              existingReview: _userReview,
            ),
      ),
    );

    if (result == true) {
      _loadUserReview();
    }
  }

  Future<void> _deleteReview(String reviewId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xóa đánh giá'),
            content: const Text('Bạn có chắc muốn xóa đánh giá này?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Xóa'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final success = await _reviewService.deleteReview(
        reviewId,
        widget.place.placeId!,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã xóa đánh giá'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
        _loadUserReview();
      }
    }
  }

  /// Báo cáo vi phạm đánh giá
  Future<void> _reportReview(Review review) async {
    await showDialog(
      context: context,
      builder:
          (context) => ViolationReportDialog(
            objectType: ViolatedObjectType.review,
            violatedObject: review,
          ),
    );
  }

  Future<void> _shareReview(Review review) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Hiển thị dialog để chọn nơi share
    final shareOption = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Chia sẻ đánh giá'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.public,
                    color: AppColors.primaryGreen,
                  ),
                  title: const Text('Public'),
                  subtitle: const Text('Chia sẻ công khai trên trang chủ'),
                  onTap: () => Navigator.pop(context, 'public'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.groups,
                    color: AppColors.primaryGreen,
                  ),
                  title: const Text('Nhóm cộng đồng'),
                  subtitle: const Text('Chia sẻ trong nhóm đã tham gia'),
                  onTap: () => Navigator.pop(context, 'community'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
            ],
          ),
    );

    if (shareOption == null) return;

    if (shareOption == 'public') {
      // Share public như cũ
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => CreatePostScreen(
                reviewToShare: review,
                placeToShare: widget.place,
              ),
        ),
      );

      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã chia sẻ đánh giá'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } else if (shareOption == 'community') {
      // Hiển thị danh sách communities để chọn
      final communities =
          await _communityService.getUserCommunitiesStream(user.uid).first;

      if (!mounted) return;

      if (communities.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn chưa tham gia nhóm nào')),
        );
        return;
      }

      final selectedCommunity = await showDialog<Community>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Chọn nhóm'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: communities.length,
                  itemBuilder: (context, index) {
                    final community = communities[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryGreen,
                        backgroundImage:
                            community.avatarUrl != null &&
                                    community.avatarUrl!.isNotEmpty
                                ? NetworkImage(community.avatarUrl!)
                                : null,
                        child:
                            community.avatarUrl == null ||
                                    community.avatarUrl!.isEmpty
                                ? Text(
                                  community.name[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                )
                                : null,
                      ),
                      title: Text(community.name),
                      subtitle: Text('${community.memberCount} thành viên'),
                      onTap: () => Navigator.pop(context, community),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
              ],
            ),
      );

      if (selectedCommunity != null && mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => CreatePostScreen(
                  reviewToShare: review,
                  placeToShare: widget.place,
                  groupCommunityId: selectedCommunity.communityId,
                ),
          ),
        );

        if (result == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Đã chia sẻ đánh giá vào ${selectedCommunity.name}',
              ),
              backgroundColor: AppColors.primaryGreen,
            ),
          );
        }
      }
    }
  }

  Future<void> _viewAllImages() async {
    final images = await _reviewService.getAllReviewImagesForPlace(
      widget.place.placeId!,
    );

    if (images.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có hình ảnh đánh giá nào')),
      );
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AllImagesScreen(images: images),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getSurfaceColor(context),
      appBar: AppBar(
        title: Text('Đánh giá'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            tooltip: 'Xem tất cả ảnh',
            onPressed: _viewAllImages,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header với thông tin tổng quan
          _buildHeader(),

          // Nút viết đánh giá
          if (!_isLoadingUserReview) _buildWriteReviewButton(),

          // Danh sách đánh giá
          Expanded(
            child: StreamBuilder<List<Review>>(
              stream: _reviewService.reviewsStreamByPlace(
                widget.place.placeId!,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.rate_review_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Chưa có đánh giá nào',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final reviews = snapshot.data!;

                return ListView.builder(
                  padding: EdgeInsets.all(
                    AppSizes.padding(context, SizeCategory.medium),
                  ),
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    return _buildReviewItem(review);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return StreamBuilder<Place?>(
      stream: _placeService.getPlaceStream(widget.place.placeId!),
      initialData: widget.place,
      builder: (context, snapshot) {
        final currentPlace = snapshot.data ?? widget.place;
        final rating = currentPlace.rating ?? 0.0;
        final reviewCount = currentPlace.reviewCount ?? 0;

        return Container(
          padding: EdgeInsets.all(
            AppSizes.padding(context, SizeCategory.large),
          ),
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.star, color: Colors.amber, size: 40),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$reviewCount đánh giá',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWriteReviewButton() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
      child: ElevatedButton.icon(
        onPressed: _navigateToWriteReview,
        icon: Icon(_userReview != null ? Icons.edit : Icons.add),
        label: Text(
          _userReview != null ? 'Chỉnh sửa đánh giá' : 'Viết đánh giá',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppSizes.radius(context, SizeCategory.medium),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewItem(Review review) {
    return FutureBuilder<UserModel?>(
      future: _userService.getUserById(review.userId),
      builder: (context, userSnapshot) {
        final user = userSnapshot.data;
        final currentUser = FirebaseAuth.instance.currentUser;
        final isOwnReview = currentUser?.uid == review.userId;

        return Card(
          margin: EdgeInsets.only(
            bottom: AppSizes.padding(context, SizeCategory.medium),
          ),
          color: AppTheme.getSurfaceColor(context),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppSizes.radius(context, SizeCategory.medium),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(
              AppSizes.padding(context, SizeCategory.medium),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User info và rating
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        // Navigate to profile screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    ProfileScreen(userId: review.userId),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        radius: 20,
                        backgroundImage:
                            (user?.avatarUrl?.isNotEmpty ?? false)
                                ? NetworkImage(user!.avatarUrl!)
                                : null,
                        backgroundColor: AppColors.primaryGreen,
                        child:
                            !(user?.avatarUrl?.isNotEmpty ?? false)
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                      ),
                    ),
                    SizedBox(
                      width: AppSizes.padding(context, SizeCategory.medium),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Tên người dùng với Flexible để tránh overflow
                              Flexible(
                                child: GestureDetector(
                                  onTap: () {
                                    // Navigate to profile screen
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => ProfileScreen(
                                              userId: review.userId,
                                            ),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    user?.name ?? 'Người dùng',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                              if (isOwnReview) ...[
                                SizedBox(
                                  width: AppSizes.padding(
                                    context,
                                    SizeCategory.small,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Bạn',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.primaryGreen,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              if (review.isCheckedIn) ...[
                                SizedBox(
                                  width: AppSizes.padding(
                                    context,
                                    SizeCategory.small,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withOpacity(
                                      0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified,
                                        size: 12,
                                        color: AppColors.primaryGreen,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Check-in',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.primaryGreen,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(
                            height: AppSizes.padding(
                              context,
                              SizeCategory.small,
                            ),
                          ),
                          Text(
                            review.createdAt != null
                                ? DateFormat(
                                  'dd/MM/yyyy HH:mm',
                                ).format(review.createdAt!)
                                : '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Menu cho tất cả reviews
                    PopupMenuButton(
                      icon: const Icon(Icons.more_vert),
                      itemBuilder:
                          (context) => [
                            // Share cho tất cả (cả review của người khác)
                            const PopupMenuItem(
                              value: 'share',
                              child: Row(
                                children: [
                                  Icon(Icons.share, size: 20),
                                  SizedBox(width: 8),
                                  Text('Chia sẻ'),
                                ],
                              ),
                            ),
                            // Edit và Delete chỉ cho review của mình
                            if (isOwnReview)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 20),
                                    SizedBox(width: 8),
                                    Text('Chỉnh sửa'),
                                  ],
                                ),
                              ),
                            if (isOwnReview)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete,
                                      size: 20,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Xóa',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            // Báo cáo cho review của người khác
                            if (!isOwnReview && currentUser != null)
                              const PopupMenuItem(
                                value: 'report',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.flag,
                                      size: 20,
                                      color: AppColors.error,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Báo cáo vi phạm',
                                      style: TextStyle(color: AppColors.error),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                      onSelected: (value) {
                        if (value == 'share') {
                          _shareReview(review);
                        } else if (value == 'edit') {
                          _navigateToWriteReview();
                        } else if (value == 'delete') {
                          _deleteReview(review.reviewId!);
                        } else if (value == 'report') {
                          _reportReview(review);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Rating stars
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < review.rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 20,
                    );
                  }),
                ),
                const SizedBox(height: 12),

                // Content
                Text(
                  review.content,
                  style: TextStyle(
                    fontSize: AppSizes.font(context, SizeCategory.medium),
                    color: AppTheme.getTextPrimaryColor(context),
                    height: 1.4,
                  ),
                ),

                // Images
                if (review.images != null && review.images!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: review.images!.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            _showImageDialog(review.images!, index);
                          },
                          child: Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                review.images![index],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.image_not_supported,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // Reaction button
                const SizedBox(height: 12),
                Row(
                  children: [
                    StreamBuilder<ReactionStats>(
                      stream: ReactionService().getReactionStatsStream(
                        targetId: review.reviewId!,
                        targetType: ReactionTargetType.review,
                        currentUserId: currentUser?.uid,
                      ),
                      initialData: ReactionStats.empty(),
                      builder: (context, snapshot) {
                        final stats = snapshot.data ?? ReactionStats.empty();
                        return ReactionButton(
                          targetId: review.reviewId!,
                          targetType: ReactionTargetType.review,
                          targetOwnerId: review.userId,
                          initialStats: stats,
                          showCount: true,
                          iconSize: 20,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImageDialog(List<String> images, int initialIndex) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Stack(
              children: [
                Center(
                  child: PageView.builder(
                    controller: PageController(initialPage: initialIndex),
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        child: Image.network(
                          images[index],
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.image_not_supported,
                              color: Colors.white,
                              size: 50,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

/// Màn hình xem tất cả ảnh đánh giá
class AllImagesScreen extends StatelessWidget {
  final List<String> images;

  const AllImagesScreen({super.key, required this.images});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getSurfaceColor(context),
      appBar: AppBar(
        title: Text('Tất cả ảnh (${images.length})'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: GridView.builder(
        padding: EdgeInsets.all(AppSizes.padding(context, SizeCategory.medium)),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.0,
        ),
        itemCount: images.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              _showImageDialog(context, images, index);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                AppSizes.radius(context, SizeCategory.small),
              ),
              child: Image.network(
                images[index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _showImageDialog(
    BuildContext context,
    List<String> images,
    int initialIndex,
  ) {
    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            child: Stack(
              children: [
                Center(
                  child: PageView.builder(
                    controller: PageController(initialPage: initialIndex),
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        child: Image.network(
                          images[index],
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.image_not_supported,
                              color: Colors.white,
                              size: 50,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
