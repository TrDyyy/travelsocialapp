import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reaction.dart';

/// Service quản lý reactions
class ReactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Thêm hoặc update reaction
  /// Nếu user đã react rồi thì update type, nếu chưa thì tạo mới
  Future<bool> addOrUpdateReaction({
    required String userId,
    required String targetId,
    required ReactionTargetType targetType,
    required ReactionType reactionType,
  }) async {
    try {
      // Tìm reaction hiện tại của user
      final existingReaction =
          await _firestore
              .collection('reactions')
              .where('userId', isEqualTo: userId)
              .where('targetId', isEqualTo: targetId)
              .where('targetType', isEqualTo: targetType.name)
              .limit(1)
              .get();

      if (existingReaction.docs.isNotEmpty) {
        // Update reaction type nếu đã tồn tại
        final docId = existingReaction.docs.first.id;
        await _firestore.collection('reactions').doc(docId).update({
          'reactionType': reactionType.name,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Tạo mới reaction
        final reaction = Reaction(
          userId: userId,
          targetId: targetId,
          targetType: targetType,
          reactionType: reactionType,
        );

        await _firestore.collection('reactions').add(reaction.toFirestore());

        // Tăng reactionCount của target
        await _incrementReactionCount(targetId, targetType);
      }

      return true;
    } catch (e) {
      print('Error adding/updating reaction: $e');
      return false;
    }
  }

  /// Xóa reaction của user
  Future<bool> removeReaction({
    required String userId,
    required String targetId,
    required ReactionTargetType targetType,
  }) async {
    try {
      final existingReaction =
          await _firestore
              .collection('reactions')
              .where('userId', isEqualTo: userId)
              .where('targetId', isEqualTo: targetId)
              .where('targetType', isEqualTo: targetType.name)
              .limit(1)
              .get();

      if (existingReaction.docs.isNotEmpty) {
        await _firestore
            .collection('reactions')
            .doc(existingReaction.docs.first.id)
            .delete();

        // Giảm reactionCount của target
        await _decrementReactionCount(targetId, targetType);
      }

      return true;
    } catch (e) {
      print('Error removing reaction: $e');
      return false;
    }
  }

  /// Toggle reaction: nếu đã react cùng type thì xóa, nếu khác type thì update, nếu chưa có thì thêm
  Future<bool> toggleReaction({
    required String userId,
    required String targetId,
    required ReactionTargetType targetType,
    required ReactionType reactionType,
  }) async {
    try {
      final existingReaction =
          await _firestore
              .collection('reactions')
              .where('userId', isEqualTo: userId)
              .where('targetId', isEqualTo: targetId)
              .where('targetType', isEqualTo: targetType.name)
              .limit(1)
              .get();

      if (existingReaction.docs.isNotEmpty) {
        final doc = existingReaction.docs.first;
        final currentReaction = Reaction.fromFirestore(doc);

        if (currentReaction.reactionType == reactionType) {
          // Xóa nếu react cùng type
          await removeReaction(
            userId: userId,
            targetId: targetId,
            targetType: targetType,
          );
        } else {
          // Update type nếu khác
          await doc.reference.update({
            'reactionType': reactionType.name,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // Thêm mới
        await addOrUpdateReaction(
          userId: userId,
          targetId: targetId,
          targetType: targetType,
          reactionType: reactionType,
        );
      }

      return true;
    } catch (e) {
      print('Error toggling reaction: $e');
      return false;
    }
  }

  /// Lấy tất cả reactions của một target
  Stream<List<Reaction>> getReactionsStream({
    required String targetId,
    required ReactionTargetType targetType,
  }) {
    return _firestore
        .collection('reactions')
        .where('targetId', isEqualTo: targetId)
        .where('targetType', isEqualTo: targetType.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Reaction.fromFirestore(doc)).toList(),
        );
  }

  /// Lấy reaction stats (với cache)
  Stream<ReactionStats> getReactionStatsStream({
    required String targetId,
    required ReactionTargetType targetType,
    String? currentUserId,
  }) {
    return getReactionsStream(
      targetId: targetId,
      targetType: targetType,
    ).map((reactions) => ReactionStats.fromReactions(reactions, currentUserId));
  }

  /// Lấy reaction của user hiện tại
  Future<ReactionType?> getUserReaction({
    required String userId,
    required String targetId,
    required ReactionTargetType targetType,
  }) async {
    try {
      final snapshot =
          await _firestore
              .collection('reactions')
              .where('userId', isEqualTo: userId)
              .where('targetId', isEqualTo: targetId)
              .where('targetType', isEqualTo: targetType.name)
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        final reaction = Reaction.fromFirestore(snapshot.docs.first);
        return reaction.reactionType;
      }

      return null;
    } catch (e) {
      print('Error getting user reaction: $e');
      return null;
    }
  }

  /// Lấy danh sách user IDs đã react
  Future<List<String>> getReactedUserIds({
    required String targetId,
    required ReactionTargetType targetType,
    ReactionType? reactionType,
  }) async {
    try {
      Query query = _firestore
          .collection('reactions')
          .where('targetId', isEqualTo: targetId)
          .where('targetType', isEqualTo: targetType.name);

      if (reactionType != null) {
        query = query.where('reactionType', isEqualTo: reactionType.name);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map(
            (doc) => (doc.data() as Map<String, dynamic>)['userId'] as String,
          )
          .toList();
    } catch (e) {
      print('Error getting reacted user IDs: $e');
      return [];
    }
  }

  /// Tăng reactionCount của target
  Future<void> _incrementReactionCount(
    String targetId,
    ReactionTargetType targetType,
  ) async {
    try {
      String collection;
      switch (targetType) {
        case ReactionTargetType.message:
          collection = 'messages';
          break;
        case ReactionTargetType.comment:
          collection = 'comments';
          break;
        case ReactionTargetType.review:
          collection = 'reviews';
          break;
        case ReactionTargetType.post:
          collection = 'posts';
          break;
      }

      await _firestore.collection(collection).doc(targetId).update({
        'reactionCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing reaction count: $e');
    }
  }

  /// Giảm reactionCount của target
  Future<void> _decrementReactionCount(
    String targetId,
    ReactionTargetType targetType,
  ) async {
    try {
      String collection;
      switch (targetType) {
        case ReactionTargetType.message:
          collection = 'messages';
          break;
        case ReactionTargetType.comment:
          collection = 'comments';
          break;
        case ReactionTargetType.review:
          collection = 'reviews';
          break;
        case ReactionTargetType.post:
          collection = 'posts';
          break;
      }

      await _firestore.collection(collection).doc(targetId).update({
        'reactionCount': FieldValue.increment(-1),
      });
    } catch (e) {
      print('Error decrementing reaction count: $e');
    }
  }

  /// Xóa tất cả reactions của một target (khi xóa message/comment/review)
  Future<void> deleteAllReactions({
    required String targetId,
    required ReactionTargetType targetType,
  }) async {
    try {
      final snapshot =
          await _firestore
              .collection('reactions')
              .where('targetId', isEqualTo: targetId)
              .where('targetType', isEqualTo: targetType.name)
              .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Error deleting all reactions: $e');
    }
  }

  /// Lấy owner ID của target (để gửi notification)
  Future<String?> getTargetOwnerId({
    required String targetId,
    required ReactionTargetType targetType,
  }) async {
    try {
      String collection;
      String ownerField;

      switch (targetType) {
        case ReactionTargetType.message:
          collection = 'messages';
          ownerField = 'senderId';
          break;
        case ReactionTargetType.comment:
          collection = 'comments';
          ownerField = 'userId';
          break;
        case ReactionTargetType.review:
          collection = 'reviews';
          ownerField = 'userId';
          break;
        case ReactionTargetType.post:
          collection = 'posts';
          ownerField = 'userId';
          break;
      }

      final doc = await _firestore.collection(collection).doc(targetId).get();

      if (doc.exists) {
        return (doc.data() as Map<String, dynamic>)[ownerField] as String?;
      }

      return null;
    } catch (e) {
      print('Error getting target owner ID: $e');
      return null;
    }
  }
}
