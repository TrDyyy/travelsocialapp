import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Service quản lý admin operations
class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Kiểm tra user có phải admin không
  Future<bool> isAdmin(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        return data?['role'] == 'admin';
      }
      return false;
    } catch (e) {
      debugPrint('Error checking admin: $e');
      return false;
    }
  }

  /// Lấy tất cả collections
  Future<List<String>> getAllCollections() async {
    // Firestore không có API để list collections, nên ta hardcode
    return [
      'users',
      'places',
      'placeEditRequests',
      'tourismTypes',
      'reviews',
      'posts',
    ];
  }

  /// Lấy documents từ collection
  Future<List<Map<String, dynamic>>> getCollectionData(
    String collectionName, {
    int limit = 100,
    DocumentSnapshot? lastDocument,
  }) async {
    Query query = _firestore.collection(collectionName).limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snapshot = await query.get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {'id': doc.id, ...data};
    }).toList();
  }

  /// Đếm số documents trong collection
  Future<int> getCollectionCount(String collectionName) async {
    try {
      final snapshot =
          await _firestore.collection(collectionName).count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ Error counting $collectionName: $e');
      return 0; // Return 0 if collection doesn't exist or permission denied
    }
  }

  /// Thêm document mới
  Future<String?> addDocument(
    String collectionName,
    Map<String, dynamic> data,
  ) async {
    try {
      final docRef = await _firestore.collection(collectionName).add(data);
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding document: $e');
      return null;
    }
  }

  /// Cập nhật document
  Future<bool> updateDocument(
    String collectionName,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.collection(collectionName).doc(documentId).update(data);
      return true;
    } catch (e) {
      debugPrint('Error updating document: $e');
      return false;
    }
  }

  /// Xóa document
  Future<bool> deleteDocument(String collectionName, String documentId) async {
    try {
      await _firestore.collection(collectionName).doc(documentId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting document: $e');
      return false;
    }
  }

  /// Lấy thống kê tổng quan
  Future<Map<String, int>> getDashboardStats() async {
    try {
      final users = await _firestore.collection('users').count().get();
      final places = await _firestore.collection('places').count().get();
      final requests =
          await _firestore.collection('placeEditRequests').count().get();
      final reviews = await _firestore.collection('reviews').count().get();

      return {
        'users': users.count ?? 0,
        'places': places.count ?? 0,
        'requests': requests.count ?? 0,
        'reviews': reviews.count ?? 0,
      };
    } catch (e) {
      debugPrint('Error getting stats: $e');
      return {};
    }
  }

  /// Lấy place edit requests đang chờ duyệt
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    try {
      // Dùng query đơn giản không cần composite index
      final snapshot =
          await _firestore
              .collection('placeEditRequests')
              .where('status', isEqualTo: 'Đã tiếp nhận')
              .get();

      // Sort by createAt ở client side
      final docs =
          snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

      // Sort descending by createAt
      docs.sort((a, b) {
        final aTime = (a['createAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final bTime = (b['createAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });

      debugPrint('📋 Found ${docs.length} pending requests');
      return docs.take(50).toList();
    } catch (e) {
      debugPrint('❌ Error getting pending requests: $e');

      // Fallback: lấy tất cả rồi filter
      try {
        debugPrint('🔄 Fallback: Getting all requests...');
        final allSnapshot =
            await _firestore.collection('placeEditRequests').limit(100).get();

        final pendingRequests =
            allSnapshot.docs
                .where((doc) {
                  final status =
                      doc.data()['status']?.toString().toLowerCase() ?? '';
                  return status.contains('tiếp nhận') ||
                      status.contains('pending') ||
                      status.contains('chờ');
                })
                .map((doc) {
                  final data = doc.data();
                  data['id'] = doc.id;
                  return data;
                })
                .toList();

        // Sort by createAt
        pendingRequests.sort((a, b) {
          final aTime =
              (a['createAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
          final bTime =
              (b['createAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });

        debugPrint(
          '📋 Found ${pendingRequests.length} pending requests (fallback)',
        );
        return pendingRequests.take(50).toList();
      } catch (fallbackError) {
        debugPrint('❌ Fallback also failed: $fallbackError');
        return [];
      }
    }
  }

  /// Duyệt place edit request và tạo Place mới
  Future<bool> approveRequest(String requestId) async {
    try {
      // Lấy data từ request
      final requestDoc =
          await _firestore.collection('placeEditRequests').doc(requestId).get();

      if (!requestDoc.exists) {
        debugPrint('Request not found');
        return false;
      }

      final requestData = requestDoc.data()!;

      // Xử lý typeId - có thể là typeId hoặc typeName
      String? typeId = requestData['typeId'];

      // Nếu không có typeId hoặc typeId là tên (string dài), tìm typeId từ typeName
      if (typeId == null || typeId.isEmpty || typeId.length > 30) {
        final typeName = requestData['typeName'] ?? requestData['typeId'];
        if (typeName != null) {
          // Tìm typeId từ tourismTypes collection dựa vào name
          final typeSnapshot =
              await _firestore
                  .collection('tourismTypes')
                  .where('name', isEqualTo: typeName)
                  .limit(1)
                  .get();

          if (typeSnapshot.docs.isNotEmpty) {
            typeId = typeSnapshot.docs.first.id;
            debugPrint('🔍 Found typeId: $typeId for typeName: $typeName');
          } else {
            debugPrint('⚠️ Could not find typeId for typeName: $typeName');
          }
        }
      }

      // Tạo Place mới với data từ request
      final placeData = {
        'name': requestData['name'] ?? requestData['placeName'],
        'address': requestData['address'],
        'googlePlaceId': requestData['googlePlaceId'], // Lưu Google Place ID
        'location': requestData['location'],
        'typeId': typeId ?? 'unknown',
        'description': requestData['description'] ?? requestData['content'],
        'images': requestData['images'] ?? [],
        'createAt': FieldValue.serverTimestamp(),
        'updateAt': FieldValue.serverTimestamp(),
        'createdBy': requestData['userId'] ?? requestData['proposedBy'],
        'status': 'active',
        'rating': 0.0,
        'reviewCount': 0,
        'viewCount': 0,
      };

      // Thêm Place vào collection places
      final placeRef = await _firestore.collection('places').add(placeData);

      // Update request status
      await _firestore.collection('placeEditRequests').doc(requestId).update({
        'status': 'Đã duyệt',
        'approvedAt': FieldValue.serverTimestamp(),
        'placeId': placeRef.id, // Lưu reference đến place đã tạo
      });

      debugPrint('✅ Approved request $requestId, created place ${placeRef.id}');
      return true;
    } catch (e) {
      debugPrint('Error approving request: $e');
      return false;
    }
  }

  /// Từ chối place edit request
  Future<bool> rejectRequest(String requestId, String reason) async {
    try {
      await _firestore.collection('placeEditRequests').doc(requestId).update({
        'status': 'Từ chối',
        'rejectionReason': reason,
      });
      return true;
    } catch (e) {
      debugPrint('Error rejecting request: $e');
      return false;
    }
  }

  /// Lấy user statistics cho biểu đồ
  Future<Map<String, int>> getUserStatsByRank() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      final rankCounts = <String, int>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final rank = data['rank'] ?? 'Kẻ du mục';
        rankCounts[rank] = (rankCounts[rank] ?? 0) + 1;
      }

      return rankCounts;
    } catch (e) {
      debugPrint('Error getting user stats: $e');
      return {};
    }
  }

  /// Lấy place statistics theo tourism type
  Future<Map<String, int>> getPlaceStatsByType() async {
    try {
      // Lấy tất cả tourismTypes trước để map typeId -> typeName
      final typesSnapshot = await _firestore.collection('tourismTypes').get();
      final typeIdToName = <String, String>{};

      for (var typeDoc in typesSnapshot.docs) {
        final typeName = typeDoc.data()['name'] ?? typeDoc.id;
        typeIdToName[typeDoc.id] = typeName;
      }

      // Lấy places và đếm theo typeName
      final snapshot = await _firestore.collection('places').get();
      final typeCounts = <String, int>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final typeId = data['typeId'] ?? 'unknown';

        // Convert typeId -> typeName
        final typeName = typeIdToName[typeId] ?? typeId;
        typeCounts[typeName] = (typeCounts[typeName] ?? 0) + 1;
      }

      debugPrint('📊 Place stats by type: $typeCounts');
      return typeCounts;
    } catch (e) {
      debugPrint('Error getting place stats: $e');
      return {};
    }
  }

  /// Lấy thống kê requests theo tháng (6 tháng gần nhất)
  Future<Map<String, int>> getRequestStatsByMonth() async {
    try {
      final now = DateTime.now();
      final sixMonthsAgo = DateTime(now.year, now.month - 6, now.day);

      final snapshot =
          await _firestore
              .collection('placeEditRequests')
              .where(
                'createAt',
                isGreaterThan: Timestamp.fromDate(sixMonthsAgo),
              )
              .get();

      final monthCounts = <String, int>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final createAt = (data['createAt'] as Timestamp).toDate();
        final monthKey = '${createAt.month}/${createAt.year}';
        monthCounts[monthKey] = (monthCounts[monthKey] ?? 0) + 1;
      }

      return monthCounts;
    } catch (e) {
      debugPrint('Error getting request stats: $e');
      return {};
    }
  }
}
