import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/meal_model.dart';
import '../models/pantry_item_model.dart';
import '../models/post_model.dart';
import '../models/scanned_item_model.dart';
import '../models/notification_model.dart';
import '../models/report_model.dart';
import '../models/weekly_stats_model.dart';
import '../config/engagement_config.dart';
import 'engagement_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ─── Collections ────────────────────────────────
  CollectionReference get _users => _db.collection('users');
  CollectionReference get _posts => _db.collection('posts');
  CollectionReference _meals(String uid) =>
      _db.collection('users').doc(uid).collection('meals');
  CollectionReference _pantryItems(String uid) =>
      _db.collection('users').doc(uid).collection('pantry_items');
  CollectionReference _scannedItems(String uid) =>
      _db.collection('users').doc(uid).collection('scanned_items');
  CollectionReference _notifications(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');
  CollectionReference _followers(String uid) =>
      _db.collection('users').doc(uid).collection('followers');
  CollectionReference _following(String uid) =>
      _db.collection('users').doc(uid).collection('following');
  CollectionReference _comments(String postId) =>
      _db.collection('posts').doc(postId).collection('comments');
  CollectionReference _reports(String postId) =>
      _db.collection('posts').doc(postId).collection('reports');
  CollectionReference _likes(String postId) =>
      _db.collection('posts').doc(postId).collection('likes');

  // ─── USER ───────────────────────────────────────

  Future<void> createUser(UserModel user) async {
    if (user.uid.isEmpty) {
      throw ArgumentError('Firestore write requires non-empty user id');
    }
    await _users.doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    final safeUid = uid.trim();
    if (safeUid.isEmpty) return null;
    final doc = await _users.doc(safeUid).get();
    if (!doc.exists) return null;
    return _userFromDoc(doc);
  }

  Stream<UserModel?> userStream(String uid) {
    final safeUid = uid.trim();
    if (safeUid.isEmpty) return Stream.value(null);
    return _users.doc(safeUid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return _userFromDoc(doc);
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    final safeUid = uid.trim();
    if (safeUid.isEmpty) {
      throw ArgumentError('Firestore write requires non-empty user id');
    }
    await _users.doc(safeUid).update(data);
  }

  Future<void> updateUserProfile(UserModel user) async {
    if (user.uid.trim().isEmpty) {
      throw ArgumentError('Firestore write requires non-empty user id');
    }
    await _users.doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  UserModel _userFromDoc(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
    final storedUid = data['uid']?.toString().trim() ?? '';
    data['uid'] = storedUid.isEmpty ? doc.id : storedUid;
    return UserModel.fromMap(data);
  }

  // Notifications

  Stream<List<NotificationModel>> notificationsStream(String uid) {
    if (uid.isEmpty) return Stream.value(const <NotificationModel>[]);
    return _notifications(uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                NotificationModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  Stream<int> unreadNotificationCountStream(String uid) {
    if (uid.isEmpty) return Stream.value(0);
    return _notifications(uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> createNotification(
    String targetUid,
    NotificationModel notification,
  ) async {
    final id = notification.id.isNotEmpty ? notification.id : _uuid.v4();
    final docRef = _notifications(targetUid).doc(id);
    await docRef.set(
      notification.copyWith(id: id).toMap(),
      SetOptions(merge: false),
    );
  }

  Future<void> markNotificationAsRead(
    String uid,
    String notificationId,
  ) async {
    await _notifications(uid).doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllNotificationsAsRead(String uid) async {
    final unread = await _notifications(uid)
        .where('isRead', isEqualTo: false)
        .limit(300)
        .get();
    if (unread.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String uid, String notificationId) async {
    await _notifications(uid).doc(notificationId).delete();
  }

  // Follows

  Stream<int> followersCountStream(String uid) {
    if (uid.isEmpty) return Stream.value(0);
    return _followers(uid).snapshots().map((snapshot) => snapshot.docs.length);
  }

  Stream<int> followingCountStream(String uid) {
    if (uid.isEmpty) return Stream.value(0);
    return _following(uid).snapshots().map((snapshot) => snapshot.docs.length);
  }

  Stream<bool> isFollowingStream(String currentUid, String targetUid) {
    if (currentUid.isEmpty || targetUid.isEmpty) return Stream.value(false);
    return _following(currentUid)
        .doc(targetUid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<bool> isFollowing(String currentUid, String targetUid) async {
    final doc = await _following(currentUid).doc(targetUid).get();
    return doc.exists;
  }

  Future<void> followUser({
    required UserModel currentUser,
    required UserModel targetUser,
  }) async {
    if (currentUser.uid == targetUser.uid) return;
    final now = Timestamp.fromDate(DateTime.now());
    final batch = _db.batch();
    batch.set(_followers(targetUser.uid).doc(currentUser.uid), {
      'uid': currentUser.uid,
      'name': currentUser.name,
      'photoUrl': currentUser.photoUrl,
      'createdAt': now,
    });
    batch.set(_following(currentUser.uid).doc(targetUser.uid), {
      'uid': targetUser.uid,
      'name': targetUser.name,
      'photoUrl': targetUser.photoUrl,
      'createdAt': now,
    });
    await batch.commit();
  }

  Future<void> unfollowUser({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid == targetUid) return;
    final batch = _db.batch();
    batch.delete(_followers(targetUid).doc(currentUid));
    batch.delete(_following(currentUid).doc(targetUid));
    await batch.commit();
  }

  // ─── MEALS ──────────────────────────────────────

  Stream<List<MealModel>> mealsStream(String uid, DateTime date) {
    if (uid.isEmpty) return Stream.value(const <MealModel>[]);
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _meals(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((s) => s.docs.map(_mealFromDoc).toList()
          ..sort((a, b) => a.type.index.compareTo(b.type.index)));
  }

  Future<List<MealModel>> getMealsForDate(String uid, DateTime date) async {
    if (uid.isEmpty) return const <MealModel>[];
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final snap = await _meals(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    return snap.docs.map(_mealFromDoc).toList()
      ..sort((a, b) => a.type.index.compareTo(b.type.index));
  }

  MealModel _mealFromDoc(QueryDocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
    if (data['id'] != doc.id) {
      data['id'] = doc.id;
    }
    return MealModel.fromMap(data);
  }

  Future<void> logMeal(String uid, String mealId, {int? calories}) async {
    final safeUid = _requiredId(uid, 'uid', 'logMeal');
    final safeMealId = _requiredId(mealId, 'mealId', 'logMeal');
    if (calories != null && calories <= 0) {
      throw ArgumentError('Calories must be greater than zero.');
    }
    try {
      final update = <String, dynamic>{
        'status': MealStatus.logged.name,
        'loggedAt': Timestamp.fromDate(DateTime.now()),
      };
      if (calories != null) update['calories'] = calories;
      await _meals(safeUid).doc(safeMealId).update(update);
    } catch (e, st) {
      _logMealWriteFailure(
        operation: 'logMeal',
        uid: safeUid,
        mealId: safeMealId,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> addMeal(MealModel meal) async {
    final safeUid = _requiredId(meal.userId, 'uid', 'addMeal');
    final safeMealId = _requiredId(meal.id, 'mealId', 'addMeal');
    try {
      await _meals(safeUid).doc(safeMealId).set(meal.toMap());
    } catch (e, st) {
      _logMealWriteFailure(
        operation: 'addMeal',
        uid: safeUid,
        mealId: safeMealId,
        date: meal.date,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> deleteMeal(String uid, String mealId) async {
    final safeUid = _requiredId(uid, 'uid', 'deleteMeal');
    final safeMealId = _requiredId(mealId, 'mealId', 'deleteMeal');
    try {
      await _meals(safeUid).doc(safeMealId).delete();
    } catch (e, st) {
      _logMealWriteFailure(
        operation: 'deleteMeal',
        uid: safeUid,
        mealId: safeMealId,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> updateMeal(
      String uid, String mealId, Map<String, dynamic> data) async {
    final safeUid = _requiredId(uid, 'uid', 'updateMeal');
    final safeMealId = _requiredId(mealId, 'mealId', 'updateMeal');
    try {
      await _meals(safeUid).doc(safeMealId).update(data);
    } catch (e, st) {
      _logMealWriteFailure(
        operation: 'updateMeal',
        uid: safeUid,
        mealId: safeMealId,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  String _requiredId(String value, String field, String operation) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('$operation requires non-empty $field');
    }
    return trimmed;
  }

  void _logMealWriteFailure({
    required String operation,
    required String uid,
    required String mealId,
    DateTime? date,
    required Object error,
    StackTrace? stackTrace,
  }) {
    final firestoreCode =
        error is FirebaseException ? ' code=${error.code}' : '';
    final firestoreMessage =
        error is FirebaseException ? ' message=${error.message}' : '';
    developer.log(
      '[MealWrite] operation=$operation uid=$uid mealId=$mealId '
      'date=${date?.toIso8601String() ?? 'n/a'}$firestoreCode$firestoreMessage',
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }

  // Pantry

  Stream<List<PantryItemModel>> pantryItemsStream(String uid) {
    if (uid.isEmpty) return Stream.value(const <PantryItemModel>[]);
    return _pantryItems(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(PantryItemModel.fromDoc)
            .where((item) => item.name.trim().isNotEmpty)
            .toList());
  }

  Future<String> addPantryItem({
    required String uid,
    required String name,
    required double quantity,
    required String unit,
    required String category,
    required bool isPalengkeItem,
  }) async {
    if (uid.isEmpty) {
      throw ArgumentError('Firestore write requires non-empty user id');
    }
    final id = _uuid.v4();
    final now = DateTime.now();
    final item = PantryItemModel(
      id: id,
      name: name.trim(),
      quantity: quantity,
      unit: unit,
      category: category,
      source: 'manual',
      isPalengkeItem: isPalengkeItem,
      createdAt: now,
      updatedAt: now,
    );
    await _pantryItems(uid).doc(id).set(item.toMap());
    return id;
  }

  Future<void> updatePantryItem({
    required String uid,
    required String itemId,
    required String name,
    required double quantity,
    required String unit,
    required String category,
    required bool isPalengkeItem,
  }) async {
    if (uid.isEmpty) {
      throw ArgumentError('Firestore write requires non-empty user id');
    }
    await _pantryItems(uid).doc(itemId).update({
      'name': name.trim(),
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'source': 'manual',
      'isPalengkeItem': isPalengkeItem,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deletePantryItem(String uid, String itemId) async {
    await _pantryItems(uid).doc(itemId).delete();
  }

  // Scanned item history

  Stream<List<ScannedItemModel>> listenToScannedItems(String uid) {
    if (uid.isEmpty) return Stream.value(const <ScannedItemModel>[]);
    return _scannedItems(uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(ScannedItemModel.fromDoc)
            .where((item) =>
                item.name.trim().isNotEmpty &&
                item.calories > 0 &&
                item.price > 0)
            .toList());
  }

  Future<String> addScannedItem({
    required String uid,
    required String name,
    required int calories,
    required double price,
    required String mealType,
    String? imageUrl,
    double? confidence,
  }) async {
    if (name.trim().isEmpty || calories <= 0 || price <= 0) {
      throw ArgumentError('Scanned items require name, calories, and price.');
    }
    if (uid.isEmpty) {
      throw ArgumentError('Firestore write requires non-empty user id');
    }

    final id = _uuid.v4();
    final now = DateTime.now();
    final item = ScannedItemModel(
      id: id,
      name: name.trim(),
      calories: calories,
      price: price,
      mealType: mealType,
      imageUrl: imageUrl,
      source: 'scanner',
      confidence: confidence,
      createdAt: now,
      updatedAt: now,
    );
    await _scannedItems(uid).doc(id).set(item.toMap());
    return id;
  }

  Future<void> deleteScannedItem(String uid, String scanId) async {
    await _scannedItems(uid).doc(scanId).delete();
  }

  // ─── POSTS ──────────────────────────────────────

  Stream<List<PostModel>> postsStream({String? category}) {
    final selectedCategory = category?.trim();
    final categoryFilter = selectedCategory == null ||
            selectedCategory.isEmpty ||
            selectedCategory == 'Trending'
        ? null
        : selectedCategory;
    final query = _posts
        .orderBy('createdAt', descending: true)
        .limit(categoryFilter == null ? 30 : 100);

    return query.snapshots().map((s) {
      final posts = <PostModel>[];
      for (final doc in s.docs) {
        try {
          final post = PostModel.fromMap(
            doc.data() as Map<String, dynamic>,
            documentId: doc.id,
          );
          if (post.isHiddenByModeration) continue;
          if (categoryFilter != null && post.category != categoryFilter) {
            continue;
          }
          posts.add(post);
        } catch (e, st) {
          debugPrint(
            '[Community] post parse failed docId=${doc.id} '
            'category=${category ?? 'Trending'} error=$e\n$st',
          );
        }
      }
      return posts;
    }).handleError((Object error, StackTrace stackTrace) {
      debugPrint(
        '[Community] posts stream failed category=${category ?? 'Trending'}: '
        '$error\n$stackTrace',
      );
      throw error;
    });
  }

  Stream<List<PostModel>> userPostsStream(String uid) {
    if (uid.isEmpty) return Stream.value(const <PostModel>[]);
    return _posts.where('userId', isEqualTo: uid).limit(50).snapshots().map(
      (snapshot) {
        final posts = <PostModel>[];
        for (final doc in snapshot.docs) {
          try {
            final post = PostModel.fromMap(
              doc.data() as Map<String, dynamic>,
              documentId: doc.id,
            );
            if (!post.isHiddenByModeration) posts.add(post);
          } catch (e, st) {
            debugPrint(
              '[Community] user post parse failed docId=${doc.id} uid=$uid error=$e\n$st',
            );
          }
        }
        return posts..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      },
    ).handleError((Object error, StackTrace stackTrace) {
      debugPrint(
          '[Community] user posts stream failed uid=$uid: $error\n$stackTrace');
      throw error;
    });
  }

  Future<PostModel?> getPost(String postId) async {
    final doc = await _posts.doc(postId).get();
    if (!doc.exists) return null;
    try {
      return PostModel.fromMap(
        doc.data() as Map<String, dynamic>,
        documentId: doc.id,
      );
    } catch (e, st) {
      debugPrint(
          '[Community] getPost parse failed postId=$postId error=$e\n$st');
      rethrow;
    }
  }

  Future<String> createPost(PostModel post) async {
    final id = _uuid.v4();
    final newPost = PostModel(
      id: id,
      userId: post.userId,
      userName: post.userName,
      userPhotoUrl: post.userPhotoUrl,
      location: post.location,
      content: post.content,
      category: post.category,
      imageUrl: post.imageUrl,
      createdAt: DateTime.now(),
      tags: post.tags,
    );
    try {
      await _posts.doc(id).set(newPost.toMap());
    } catch (e, st) {
      debugPrint(
          '[Community] createPost write failed postId=$id error=$e\n$st');
      rethrow;
    }
    return id;
  }

  Future<void> deletePost(String postId, String uid) async {
    final postRef = _posts.doc(postId);

    await _db.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);

      if (!postDoc.exists) {
        throw StateError('Post not found.');
      }

      final data = postDoc.data() as Map<String, dynamic>;

      if (data['userId'] != uid) {
        throw StateError('Only the author can delete this post.');
      }

      transaction.delete(postRef);
    });
  }

  // ─── LIKES (Scalable Subcollection) ─────────────

  /// Toggle like using scalable subcollection approach.
  /// Creates posts/{postId}/likes/{uid} document and maintains likeCount.
  /// Falls back to legacy array if subcollection doesn't exist yet.
  Future<void> toggleLike(String postId, String uid) async {
    final likeRef = _likes(postId).doc(uid);
    final postRef = _posts.doc(postId);
    final doc = await likeRef.get();

    if (doc.exists) {
      // Unlike: remove from subcollection
      await _db.runTransaction((transaction) async {
        transaction.delete(likeRef);
        transaction.update(postRef, {'likeCount': FieldValue.increment(-1)});
      });
    } else {
      // Check for legacy likes array for migration compatibility
      final postDoc = await postRef.get();
      final postData = postDoc.data() as Map<String, dynamic>;
      final legacyLikes = List<String>.from(postData['likes'] ?? []);

      if (legacyLikes.isNotEmpty && !postData.containsKey('likeCount')) {
        // Migrate: convert legacy array to subcollection + likeCount
        await _db.runTransaction((transaction) async {
          // Add all legacy likes to subcollection
          for (final legacyUid in legacyLikes) {
            transaction.set(_likes(postId).doc(legacyUid), {
              'uid': legacyUid,
              'createdAt': Timestamp.fromDate(
                  postData['createdAt']?.toDate() ?? DateTime.now()),
            });
          }
          // Set likeCount from migrated array
          transaction.update(postRef, {
            'likeCount': legacyLikes.length,
            'likes': FieldValue.delete(), // Remove legacy array
          });
        });
        // After migration, add the new like
        await _db.runTransaction((transaction) async {
          transaction.set(likeRef, {
            'uid': uid,
            'createdAt': Timestamp.fromDate(DateTime.now()),
          });
          transaction.update(postRef, {'likeCount': FieldValue.increment(1)});
        });
      } else {
        // Normal like: add to subcollection
        await _db.runTransaction((transaction) async {
          transaction.set(likeRef, {
            'uid': uid,
            'createdAt': Timestamp.fromDate(DateTime.now()),
          });
          // Use set with merge for posts that might not have likeCount yet
          transaction.update(postRef, {'likeCount': FieldValue.increment(1)});
        });
      }
    }
  }

  /// Check if a post is liked by a specific user (uses subcollection).
  Future<bool> isPostLikedBy(String postId, String uid) async {
    final likeRef = _likes(postId).doc(uid);
    final doc = await likeRef.get();
    if (doc.exists) return true;

    // Fallback: check legacy likes array
    if (uid.isEmpty) return false;
    final postDoc = await _posts.doc(postId).get();
    final postData = postDoc.data() as Map<String, dynamic>;
    final legacyLikes = List<String>.from(postData['likes'] ?? []);
    return legacyLikes.contains(uid);
  }

  /// Stream that emits true/false when a user's like status changes on a post.
  Stream<bool> isPostLikedByStream(String postId, String uid) {
    if (uid.isEmpty) return Stream.value(false);
    return _likes(postId).doc(uid).snapshots().map((doc) => doc.exists);
  }

  /// Get like count for a post (uses likeCount field, fallback to legacy array).
  Future<int> getLikeCount(String postId) async {
    final postDoc = await _posts.doc(postId).get();
    final postData = postDoc.data() as Map<String, dynamic>;

    // Use aggregate likeCount if available
    if (postData.containsKey('likeCount')) {
      return (postData['likeCount'] ?? 0).toInt();
    }

    // Fallback: count legacy array
    final legacyLikes = List<String>.from(postData['likes'] ?? []);
    return legacyLikes.length;
  }

  /// Stream of like count for real-time updates.
  Stream<int> likeCountStream(String postId) {
    return _posts.doc(postId).snapshots().map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('likeCount')) {
        return (data['likeCount'] ?? 0).toInt();
      }
      return List<String>.from(data['likes'] ?? []).length;
    });
  }

  Future<ReportPostResult> reportPost(
    ReportModel report, {
    int reviewThreshold = 3,
  }) async {
    final postRef = _posts.doc(report.postId);
    final reportRef = _reports(report.postId).doc(report.reporterId);

    return _db.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);
      if (!postDoc.exists) {
        throw StateError('Post no longer exists.');
      }

      final existingReport = await transaction.get(reportRef);
      if (existingReport.exists) {
        return ReportPostResult.duplicate;
      }

      final postData = postDoc.data() as Map<String, dynamic>;
      final reportCount = (postData['reportCount'] ?? 0).toInt() + 1;
      final currentStatus = postData['moderationStatus'] ?? 'active';
      final nextStatus =
          reportCount >= reviewThreshold ? 'underReview' : currentStatus;

      transaction.set(
        reportRef,
        report.copyWith(reportId: report.reporterId).toMap(),
      );
      transaction.update(postRef, {
        'reportCount': reportCount,
        'moderationStatus': nextStatus,
        'isHiddenByModeration': postData['isHiddenByModeration'] ?? false,
      });
      return ReportPostResult.submitted;
    });
  }

  // ─── COMMENTS ───────────────────────────────────

  Stream<List<CommentModel>> commentsStream(String postId) {
    return _comments(postId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs
            .map((d) => CommentModel.fromMap(d.data() as Map<String, dynamic>))
            .toList());
  }

  Future<void> addComment(CommentModel comment) async {
    if (comment.userId.isEmpty) {
      throw ArgumentError('Firestore write requires non-empty user id');
    }
    final id = _uuid.v4();
    final newComment = CommentModel(
      id: id,
      postId: comment.postId,
      userId: comment.userId,
      userName: comment.userName,
      userPhotoUrl: comment.userPhotoUrl,
      content: comment.content,
      createdAt: DateTime.now(),
    );
    await _comments(comment.postId).doc(id).set(newComment.toMap());
    try {
      await _posts.doc(comment.postId).update({
        'commentCount': FieldValue.increment(1),
      });
    } catch (e, st) {
      developer.log(
        'Comment created but failed to update post commentCount',
        error: e,
        stackTrace: st,
        level: 900,
      );
    }
  }

  // ─── LEADERBOARD ────────────────────────────────

  Future<List<Map<String, dynamic>>> getLeaderboard(
      {DateTime? weekDate}) async {
    final weekId = EngagementService.weekIdFor(weekDate ?? DateTime.now());
    final snap = await _db
        .collectionGroup('weeklyStats')
        .where('weekId', isEqualTo: weekId)
        .limit(EngagementConfig.leaderboardQueryLimit)
        .get();
    final stats = snap.docs
        .map((d) => WeeklyStatsModel.fromMap(d.data()))
        .where((stat) => stat.points > 0)
        .toList()
      ..sort((a, b) => EngagementConfig.compareLeaderboardRows(
            aPoints: a.points,
            aDisplayName: a.displayName,
            bPoints: b.points,
            bDisplayName: b.displayName,
          ));
    return stats
        .take(EngagementConfig.leaderboardDisplayLimit)
        .map((stat) => stat.toMap())
        .toList();
  }

  // ─── GENERATE NEW MEAL PLAN ─────────────────────
}
