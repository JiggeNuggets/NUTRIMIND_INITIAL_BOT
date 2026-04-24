import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/meal_model.dart';
import '../models/post_model.dart';
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
    await _users.doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  Stream<UserModel?> userStream(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _users.doc(uid).update(data);
  }

  Future<void> updateUserProfile(UserModel user) async {
    await _users.doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  // Notifications

  Stream<List<NotificationModel>> notificationsStream(String uid) {
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
    final existing = await docRef.get();
    if (existing.exists) return;
    await docRef.set(notification.copyWith(id: id).toMap());
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
    return _followers(uid).snapshots().map((snapshot) => snapshot.docs.length);
  }

  Stream<int> followingCountStream(String uid) {
    return _following(uid).snapshots().map((snapshot) => snapshot.docs.length);
  }

  Stream<bool> isFollowingStream(String currentUid, String targetUid) {
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
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _meals(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((s) => s.docs
            .map((d) => MealModel.fromMap(d.data() as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.type.index.compareTo(b.type.index)));
  }

  Future<List<MealModel>> getMealsForDate(String uid, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final snap = await _meals(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    return snap.docs
        .map((d) => MealModel.fromMap(d.data() as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.type.index.compareTo(b.type.index));
  }

  Future<void> logMeal(String uid, String mealId) async {
    await _meals(uid).doc(mealId).update({
      'status': MealStatus.logged.name,
      'loggedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> addMeal(MealModel meal) async {
    await _meals(meal.userId).doc(meal.id).set(meal.toMap());
  }

  Future<void> deleteMeal(String uid, String mealId) async {
    await _meals(uid).doc(mealId).delete();
  }

  Future<void> updateMeal(
      String uid, String mealId, Map<String, dynamic> data) async {
    await _meals(uid).doc(mealId).update(data);
  }

  // ─── POSTS ──────────────────────────────────────

  Stream<List<PostModel>> postsStream({String? category}) {
    Query query = _posts.orderBy('createdAt', descending: true);
    if (category != null && category != 'Trending') {
      query = query.where('category', isEqualTo: category);
    }
    return query.limit(30).snapshots().map((s) => s.docs
        .map((d) => PostModel.fromMap(d.data() as Map<String, dynamic>))
        .where((post) => !post.isHiddenByModeration)
        .toList());
  }

  Stream<List<PostModel>> userPostsStream(String uid) {
    return _posts.where('userId', isEqualTo: uid).limit(50).snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => PostModel.fromMap(doc.data() as Map<String, dynamic>))
            .where((post) => !post.isHiddenByModeration)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  Future<PostModel?> getPost(String postId) async {
    final doc = await _posts.doc(postId).get();
    if (!doc.exists) return null;
    return PostModel.fromMap(doc.data() as Map<String, dynamic>);
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
    await _posts.doc(id).set(newPost.toMap());
    return id;
  }

  Future<void> deletePost(String postId) async {
    await _posts.doc(postId).delete();
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
    await _posts.doc(comment.postId).update({
      'commentCount': FieldValue.increment(1),
    });
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
