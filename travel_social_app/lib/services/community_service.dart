import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:travel_social_app/models/community.dart';
import 'package:travel_social_app/services/notification_service.dart';
import 'package:travel_social_app/services/user_service.dart';

class CommunityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final UserService _userService = UserService();

  /// Tạo community mới
  Future<String?> createCommunity(Community community) async {
    try {
      final docRef = await _firestore
          .collection('communities')
          .add(community.toFirestore());

      // Thêm admin vào memberIds
      await docRef.update({
        'memberIds': FieldValue.arrayUnion([community.adminId]),
      });

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating community: $e');
      return null;
    }
  }

  /// Lấy tất cả communities
  Stream<List<Community>> getCommunitiesStream() {
    return _firestore
        .collection('communities')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Community.fromFirestore(doc)).toList(),
        );
  }

  /// Lấy communities mà user là member
  Stream<List<Community>> getUserCommunitiesStream(String userId) {
    return _firestore
        .collection('communities')
        .where('memberIds', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Community.fromFirestore(doc)).toList(),
        );
  }

  /// Lấy community theo ID
  Future<Community?> getCommunityById(String communityId) async {
    try {
      final doc =
          await _firestore.collection('communities').doc(communityId).get();
      if (doc.exists) {
        return Community.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting community: $e');
      return null;
    }
  }

  /// Stream community theo ID
  Stream<Community?> getCommunityStream(String communityId) {
    return _firestore
        .collection('communities')
        .doc(communityId)
        .snapshots()
        .map((doc) => doc.exists ? Community.fromFirestore(doc) : null);
  }

  /// Cập nhật community (admin only)
  Future<bool> updateCommunity(
    String communityId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore.collection('communities').doc(communityId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating community: $e');
      return false;
    }
  }

  /// Upload ảnh community và trả về URL
  Future<String?> uploadCommunityImage(
    String communityId,
    File imageFile,
  ) async {
    try {
      final storage = FirebaseStorage.instance;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = storage.ref('community_images/${communityId}_$timestamp.jpg');

      await ref.putFile(imageFile);
      final downloadUrl = await ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading community image: $e');
      return null;
    }
  }

  /// Xóa community (admin only)
  Future<bool> deleteCommunity(String communityId) async {
    try {
      // Xóa tất cả posts trong community
      final postsSnapshot =
          await _firestore
              .collection('posts')
              .where('communityId', isEqualTo: communityId)
              .get();

      for (var doc in postsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Xóa community
      await _firestore.collection('communities').doc(communityId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting community: $e');
      return false;
    }
  }

  /// Thêm member vào community
  Future<bool> addMember(String communityId, String userId) async {
    try {
      await _firestore.collection('communities').doc(communityId).update({
        'memberIds': FieldValue.arrayUnion([userId]),
        'memberCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error adding member: $e');
      return false;
    }
  }

  /// Xóa member khỏi community (admin only)
  Future<bool> removeMember(String communityId, String userId) async {
    try {
      await _firestore.collection('communities').doc(communityId).update({
        'memberIds': FieldValue.arrayRemove([userId]),
        'memberCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error removing member: $e');
      return false;
    }
  }

  /// Rời khỏi community
  Future<bool> leaveCommunity(String communityId, String userId) async {
    try {
      final community = await getCommunityById(communityId);
      if (community == null) return false;

      // Admin không thể rời nếu còn members khác
      if (community.isAdmin(userId) && community.memberCount > 1) {
        return false;
      }

      await _firestore.collection('communities').doc(communityId).update({
        'memberIds': FieldValue.arrayRemove([userId]),
        'memberCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error leaving community: $e');
      return false;
    }
  }

  /// Tìm kiếm communities
  Future<List<Community>> searchCommunities(String query) async {
    try {
      final snapshot =
          await _firestore
              .collection('communities')
              .where('name', isGreaterThanOrEqualTo: query)
              .where('name', isLessThanOrEqualTo: query + '\uf8ff')
              .get();

      return snapshot.docs.map((doc) => Community.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error searching communities: $e');
      return [];
    }
  }

  /// Increment post count
  Future<void> incrementPostCount(String communityId) async {
    try {
      await _firestore.collection('communities').doc(communityId).update({
        'postCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error incrementing post count: $e');
    }
  }

  /// Decrement post count
  Future<void> decrementPostCount(String communityId) async {
    try {
      await _firestore.collection('communities').doc(communityId).update({
        'postCount': FieldValue.increment(-1),
      });
    } catch (e) {
      debugPrint('Error decrementing post count: $e');
    }
  }

  // ============= GROUP COMMUNITY FEATURES =============

  /// Gửi yêu cầu tham gia group
  Future<bool> requestJoinGroup(String communityId, String userId) async {
    try {
      // Cập nhật pending requests
      await _firestore.collection('communities').doc(communityId).update({
        'pendingRequests': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Lấy thông tin community và user
      final community = await getCommunityById(communityId);
      final user = await _userService.getUserById(userId);

      if (community != null && user != null) {
        // Gửi notification cho admin
        await _notificationService.sendGroupJoinRequestNotification(
          toUserId: community.adminId,
          fromUserId: userId,
          fromUserName: user.name,
          communityId: communityId,
          communityName: community.name,
          fromUserAvatar: user.avatarUrl,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error requesting join group: $e');
      return false;
    }
  }

  /// Duyệt yêu cầu tham gia group (admin only)
  Future<bool> approveJoinRequest(String communityId, String userId) async {
    try {
      // Cập nhật community
      await _firestore.collection('communities').doc(communityId).update({
        'pendingRequests': FieldValue.arrayRemove([userId]),
        'memberIds': FieldValue.arrayUnion([userId]),
        'memberCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Lấy thông tin community
      final community = await getCommunityById(communityId);

      if (community != null) {
        // Gửi notification cho user được duyệt
        await _notificationService.sendGroupJoinApprovedNotification(
          toUserId: userId,
          communityId: communityId,
          communityName: community.name,
          communityAvatar: community.avatarUrl,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error approving join request: $e');
      return false;
    }
  }

  /// Từ chối yêu cầu tham gia group (admin only)
  Future<bool> rejectJoinRequest(String communityId, String userId) async {
    try {
      // Cập nhật community
      await _firestore.collection('communities').doc(communityId).update({
        'pendingRequests': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Lấy thông tin community
      final community = await getCommunityById(communityId);

      if (community != null) {
        // Gửi notification cho user bị từ chối
        await _notificationService.sendGroupJoinRejectedNotification(
          toUserId: userId,
          communityId: communityId,
          communityName: community.name,
          communityAvatar: community.avatarUrl,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error rejecting join request: $e');
      return false;
    }
  }

  /// Lấy tất cả groups (public groups list)
  Future<List<Community>> getAllGroups() async {
    try {
      final snapshot =
          await _firestore
              .collection('communities')
              .orderBy('memberCount', descending: true)
              .get();

      return snapshot.docs.map((doc) => Community.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting all groups: $e');
      return [];
    }
  }

  /// Stream tất cả groups
  Stream<List<Community>> getAllGroupsStream() {
    return _firestore
        .collection('communities')
        .orderBy('memberCount', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Community.fromFirestore(doc)).toList(),
        );
  }

  /// Xóa bài post trong group (admin only)
  Future<bool> deletePostFromGroup(String postId, String communityId) async {
    try {
      // Xóa post
      await _firestore.collection('posts').doc(postId).delete();

      // Giảm post count
      await decrementPostCount(communityId);

      return true;
    } catch (e) {
      debugPrint('Error deleting post from group: $e');
      return false;
    }
  }

  /// Hủy yêu cầu tham gia group
  Future<bool> cancelJoinRequest(String communityId, String userId) async {
    try {
      await _firestore.collection('communities').doc(communityId).update({
        'pendingRequests': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error canceling join request: $e');
      return false;
    }
  }

  /// Thăng/hạ chức admin (admin only)
  Future<bool> toggleAdminRole(
    String communityId,
    String userId,
    bool makeAdmin,
  ) async {
    try {
      if (makeAdmin) {
        await _firestore.collection('communities').doc(communityId).update({
          'adminIds': FieldValue.arrayUnion([userId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore.collection('communities').doc(communityId).update({
          'adminIds': FieldValue.arrayRemove([userId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return true;
    } catch (e) {
      debugPrint('Error toggling admin role: $e');
      return false;
    }
  }
}
