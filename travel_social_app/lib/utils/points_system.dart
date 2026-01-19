/// Hệ thống điểm số và thưởng
class PointsSystem {
  // Points for place-related actions
  static const int placeRequestApproved = 1000; // Place request được duyệt
  static const int placeRequestRejected =
      -100; // Place request bị từ chối (penalty)
  static const int reviewPlace = 100; // Viết review
  static const int reviewWithImages = 150; // Review có ảnh (bonus)
  static const int reviewHighQuality =
      200; // Review chất lượng cao (>100 ký tự + ảnh)

  // Points for social actions
  static const int createPost = 100; // Tạo post
  static const int createPostWithPlace = 150; // Post có tag địa điểm (bonus)
  static const int createPostWithImages = 120; // Post có ảnh
  static const int commentOnPost = 10; // Comment trên post
  static const int likePost = 5; // Like post
  static const int sharePost = 20; // Share post

  // Points for interaction
  static const int followUser = 10; // Follow người khác
  static const int receiveFollow = 5; // Được người khác follow
  static const int addFriend = 15; // Kết bạn
  static const int acceptFriendRequest = 10; // Chấp nhận lời mời kết bạn

  // Points for community
  static const int createCommunity = 200; // Tạo cộng đồng
  static const int joinCommunity = 20; // Tham gia cộng đồng
  static const int postInCommunity = 50; // Post trong cộng đồng

  // Points for activity tracking
  static const int viewPlace = 2; // Xem chi tiết địa điểm
  static const int searchPlace = 5; // Tìm kiếm địa điểm
  static const int getDirections = 10; // Lấy chỉ đường
  static const int savePlace = 30; // Lưu địa điểm
  static const int clickRecommendation = 3; // Click vào gợi ý

  // Daily/Weekly bonuses
  static const int dailyLoginBonus = 10; // Đăng nhập hàng ngày
  static const int weeklyActiveBonus = 100; // Hoạt động 7 ngày liên tiếp
  static const int monthlyActiveBonus = 500; // Hoạt động 30 ngày liên tiếp

  // Achievement bonuses
  static const int first10Reviews = 500; // 10 review đầu tiên
  static const int first50Reviews = 2000; // 50 review
  static const int first100Reviews = 5000; // 100 review
  static const int first10Posts = 300; // 10 post đầu tiên
  static const int first50Posts = 1500; // 50 post
  static const int first100Posts = 3000; // 100 post

  // Penalty (trừ điểm)
  static const int reportedContentRemoved = -200; // Nội dung vi phạm bị xóa
  static const int spamDetected = -500; // Phát hiện spam
  static const int accountWarning = -1000; // Cảnh cáo tài khoản

  /// Calculate points for review based on quality
  static int getReviewPoints({
    required String reviewText,
    required int imageCount,
    required double rating,
  }) {
    int points = reviewPlace;

    // Bonus for images
    if (imageCount > 0) {
      points += 50;
    }

    // Bonus for high quality (long text + images)
    if (reviewText.length > 100 && imageCount > 0) {
      points = reviewHighQuality;
    }

    // Bonus for detailed text
    if (reviewText.length > 200) {
      points += 50;
    }

    return points;
  }

  /// Calculate points for post based on content
  static int getPostPoints({
    required String postText,
    required int imageCount,
    required bool hasTaggedPlace,
    required bool isInCommunity,
  }) {
    int points = createPost;

    // Bonus for images
    if (imageCount > 0) {
      points += 20;
    }

    // Bonus for tagged place
    if (hasTaggedPlace) {
      points += 50;
    }

    // Bonus for community post
    if (isInCommunity) {
      points = postInCommunity;
    }

    // Bonus for long content
    if (postText.length > 200) {
      points += 30;
    }

    return points;
  }

  /// Get action description for point history
  static String getActionDescription(String action) {
    switch (action) {
      case 'placeRequestApproved':
        return 'Yêu cầu thêm địa điểm được duyệt';
      case 'placeRequestRejected':
        return 'Yêu cầu thêm địa điểm bị từ chối';
      case 'reviewPlace':
        return 'Viết đánh giá địa điểm';
      case 'createPost':
        return 'Tạo bài viết';
      case 'commentOnPost':
        return 'Bình luận bài viết';
      case 'likePost':
        return 'Thích bài viết';
      case 'sharePost':
        return 'Chia sẻ bài viết';
      case 'followUser':
        return 'Theo dõi người dùng';
      case 'addFriend':
        return 'Kết bạn';
      case 'createCommunity':
        return 'Tạo cộng đồng';
      case 'joinCommunity':
        return 'Tham gia cộng đồng';
      case 'dailyLoginBonus':
        return 'Thưởng đăng nhập hàng ngày';
      case 'weeklyActiveBonus':
        return 'Thưởng hoạt động tuần';
      case 'achievementBonus':
        return 'Thưởng thành tích';
      default:
        return 'Hoạt động khác';
    }
  }
}
