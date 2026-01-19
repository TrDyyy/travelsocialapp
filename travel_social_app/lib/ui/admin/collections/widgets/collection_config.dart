import 'package:cloud_firestore/cloud_firestore.dart';

/// Configuration class cho collection columns và formatting
class CollectionConfig {
  /// Get preferred column order cho mỗi collection
  static List<String> getPreferredOrder(String collectionName) {
    switch (collectionName) {
      case 'chats':
        return [
          'groupAvatar',
          'groupName',
          'chatType',
          'isPublic',
          'members',
          'lastMessage',
          'createdAt',
        ];

      case 'calls':
        return [
          'callType',
          'callStatus',
          'callerId',
          'receiverIds',
          'duration',
          'createdAt',
          'answeredAt',
          'endedAt',
        ];

      case 'friendships':
        return ['userId1', 'userId2', 'status', 'createdAt', 'updatedAt'];

      case 'reactions':
        return [
          'reactionType',
          'userId',
          'targetType',
          'targetId',
          'createdAt',
        ];

      case 'violationRequests':
        return [
          'status',
          'objectType',
          'violationType',
          'reporterId',
          'violationReason',
          'createdAt',
          'reviewedAt',
          'adminId',
        ];

      case 'userViolations':
        return [
          'userId',
          'violationType',
          'status',
          'actionLevel',
          'warningCount',
          'penaltyPoints',
          'createdAt',
          'adminId',
        ];

      case 'communities':
        return [
          'avatarUrl',
          'name',
          'description',
          'memberCount',
          'postCount',
          'createdAt',
        ];

      case 'notifications':
        return ['createdAt', 'imageUrl', 'title', 'body'];

      case 'placeEditRequests':
        return [
          'images',
          'placeName',
          'address',
          'typeName',
          'proposedBy',
          'status',
          'content',
          'location',
          'approvedAt',
          'createAt',
        ];

      case 'posts':
        return [
          'reviewId',
          'userId',
          'placeId',
          'type',
          'content',
          'mediaUrls',
          'likeCount',
          'commentCount',
          'createdAt',
          'updatedAt',
        ];

      case 'tourismTypes':
        return ['name', 'typeId', 'description'];

      default:
        // users và collections khác
        return [
          'name',
          'email',
          'role',
          'rank',
          'avatarUrl',
          'points',
          'bio',
          'createdAt',
          'phoneNumber',
        ];
    }
  }

  /// Get Vietnamese column titles
  static Map<String, String> getColumnTitles(String collectionName) {
    return {
      'id': 'ID',
      'name':
          collectionName == 'tourismTypes'
              ? 'Tên loại hình'
              : collectionName == 'communities'
              ? 'Tên cộng đồng'
              : 'Tên người dùng',
      'email': 'Email',
      'avatarUrl': 'Ảnh đại diện',
      'bio': 'Giới thiệu',
      'rank': 'Hạng',
      'dateBirth': 'Ngày sinh',
      'role': 'Vai trò',
      'points': 'Điểm',
      'phoneNumber': 'SĐT',
      'createdAt': 'Ngày tạo',
      // placeEditRequests
      'placeName': 'Tên địa điểm',
      'address': 'Địa chỉ',
      'typeName': 'Loại hình',
      'proposedBy': 'Người đề xuất',
      'status': 'Trạng thái',
      'content': 'Nội dung',
      'location': 'Tọa độ',
      'approvedAt': 'Ngày duyệt',
      'createAt': 'Ngày tạo yêu cầu',
      // tourismTypes
      'typeId': 'Mã loại hình',
      'description': 'Mô tả',
      // reviews
      'checkedInAt': 'Thời gian check-in',
      'isCheckedIn': 'Đã check-in',
      'rating': 'Đánh giá',
      'images': 'Hình ảnh',
      // posts
      'reviewId': 'Mã bài viết',
      'userId': 'Người đăng',
      'placeId': 'Địa điểm',
      'type': 'Loại bài',
      'mediaUrls': 'Hình ảnh',
      'likeCount': 'Lượt thích',
      'commentCount': 'Bình luận',
      'updatedAt': 'Ngày cập nhật',
      // notifications
      'title': 'Tiêu đề',
      'body': 'Nội dung',
      'isRead': 'Đã đọc',
      'imageUrl': 'Ảnh',
      'data': 'Dữ liệu kỹ thuật',
      // communities
      'adminId': 'Quản trị viên',
      'memberCount': 'Số thành viên',
      'postCount': 'Số bài viết',
      'memberIds': 'Danh sách thành viên',
      'pendingRequests': 'Yêu cầu chờ',
      'tourismTypes': 'Loại hình du lịch',
      'rules': 'Quy tắc',
      'coverImageUrl': 'Ảnh bìa',
      // chats
      'chatType': 'Loại',
      'groupName': 'Tên nhóm',
      'groupAvatar': 'Ảnh đại diện',
      'groupBackground': 'Ảnh nền',
      'groupAdmin': 'Quản trị viên',
      'isPublic': 'Công khai',
      'members': 'Thành viên',
      'lastMessage': 'Tin nhắn cuối',
      'lastMessageSenderId': 'Người gửi cuối',
      'lastMessageTime': 'Thời gian tin nhắn',
      'lastMessageImageCount': 'Số ảnh',
      'backgroundImages': 'Ảnh nền chat',
      // calls
      'callType': 'Loại',
      'callStatus': 'Trạng thái',
      'callerId': 'Người gọi',
      'receiverIds': 'Người nhận',
      'duration': 'Thời lượng',
      'answeredAt': 'Thời gian trả lời',
      'endedAt': 'Thời gian kết thúc',
      'agoraChannelName': 'Kênh Agora',
      'agoraToken': 'Token Agora',
      // friendships
      'userId1': 'Người dùng 1',
      'userId2': 'Người dùng 2',
      // reactions
      'reactionType': 'Loại biểu cảm',
      'targetType': 'Loại đối tượng',
      'targetId': 'ID đối tượng',
      // violationRequests
      'objectType': 'Loại đối tượng',
      'violationType': 'Loại vi phạm',
      'reporterId': 'Người báo cáo',
      'violationReason': 'Lý do vi phạm',
      'reviewedAt': 'Thời gian xét duyệt',
      'reviewNote': 'Ghi chú admin',
      // userViolations
      'actionLevel': 'Mức độ xử lý',
      'warningCount': 'Số lần cảnh báo',
      'penaltyPoints': 'Điểm trừ phạt',
      'bannedUntil': 'Cấm đến',
      'violatedObjectId': 'ID đối tượng vi phạm',
    };
  }

  /// Check if field should be hidden
  static bool shouldHideField(String collectionName, String fieldKey) {
    // Ẩn cột chung cho tất cả collections
    if (fieldKey == 'id' || fieldKey == 'placeId' || fieldKey == 'typeIds') {
      return true;
    }

    // Ẩn cột riêng cho từng collection
    switch (collectionName) {
      case 'users':
        return fieldKey == 'lastTokenUpdate' || fieldKey == 'fcmToken';

      case 'notifications':
        return fieldKey == 'data' ||
            fieldKey == 'isRead' ||
            fieldKey == 'userId' ||
            fieldKey == 'type';

      case 'communities':
        return fieldKey == 'adminId' ||
            fieldKey == 'coverImageUrl' ||
            fieldKey == 'memberIds' ||
            fieldKey == 'pendingRequests' ||
            fieldKey == 'tourismTypes' ||
            fieldKey == 'rules' ||
            fieldKey == 'updatedAt';

      case 'chats':
        return fieldKey == 'groupAdmin' ||
            fieldKey == 'groupBackground' ||
            fieldKey == 'lastMessageSenderId' ||
            fieldKey == 'lastMessageTime' ||
            fieldKey == 'lastMessageImageCount' ||
            fieldKey == 'backgroundImages';

      case 'calls':
        return fieldKey == 'agoraChannelName' ||
            fieldKey == 'agoraToken' ||
            fieldKey == 'chatId';

      case 'violationRequests':
        return fieldKey == 'violatedObject' || fieldKey == 'reviewNote';

      case 'userViolations':
        return fieldKey == 'bannedUntil' || fieldKey == 'violatedObjectId';

      default:
        return false;
    }
  }

  /// Format cell value based on data type and collection
  static String formatCellValue(
    String key,
    dynamic value,
    String collectionName,
    String Function(String?) getUserDisplayName,
    String Function(List<dynamic>?) getUserNames,
  ) {
    if (value == null || value == 'null') return '-';

    // Timestamp -> ngày
    if (value is Timestamp) {
      final d = value.toDate();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }

    final lowerKey = key.toLowerCase();

    // Hiển thị tên user thay vì userId
    if (lowerKey == 'userid' ||
        lowerKey == 'userid1' ||
        lowerKey == 'userid2' ||
        lowerKey == 'callerid' ||
        lowerKey == 'adminid' ||
        lowerKey == 'proposedby' ||
        lowerKey == 'senderid' ||
        lowerKey == 'groupadmin' ||
        lowerKey == 'reporterid') {
      return getUserDisplayName(value.toString());
    }

    // Hiển thị danh sách tên user cho array
    if ((lowerKey == 'receiverids' ||
            lowerKey == 'members' ||
            lowerKey == 'memberids') &&
        value is List) {
      return getUserNames(value);
    }

    // Hiển thị toạ độ GeoPoint
    if (collectionName == 'placeEditRequests' && value is GeoPoint) {
      return '(${value.latitude.toStringAsFixed(4)}, ${value.longitude.toStringAsFixed(4)})';
    }

    // URL ảnh / avatar / link: rút gọn
    if (lowerKey.contains('url') || lowerKey.contains('avatar')) {
      final s = value.toString();
      if (s.startsWith('http')) {
        return 'Link ảnh';
      }
    }

    final str = value.toString();
    if (str.length > 40) {
      return '${str.substring(0, 40)}...';
    }
    return str;
  }
}
