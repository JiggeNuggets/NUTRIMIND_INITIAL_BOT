import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/engagement_service.dart';
import '../models/notification_model.dart';
import '../models/post_model.dart';
import '../models/report_model.dart';
import '../models/user_model.dart';

class CommunityProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final EngagementService _engagementService = EngagementService();

  StreamSubscription<List<PostModel>>? _postsSubscription;
  String? _subscribedCategory;
  int _postsStreamGeneration = 0;
  bool _disposed = false;

  List<PostModel> _posts = [];
  bool _loading = false;
  String? _error;
  String _activeCategory = 'Trending';
  bool _isAddingComment = false;

  List<PostModel> get posts => _posts;
  bool get loading => _loading;
  String? get error => _error;
  String get activeCategory => _activeCategory;
  bool get isAddingComment => _isAddingComment;

  void listenToPosts(String category) {
    final nextCategory = category.trim().isEmpty ? 'Trending' : category;
    if ((_postsSubscription != null || _loading) &&
        _subscribedCategory == nextCategory &&
        (_loading || _error == null)) {
      _activeCategory = nextCategory;
      return;
    }
    unawaited(_subscribeToPosts(nextCategory));
  }

  Future<void> _subscribeToPosts(String category) async {
    final generation = ++_postsStreamGeneration;
    final previousSubscription = _postsSubscription;
    _postsSubscription = null;
    _activeCategory = category;
    _subscribedCategory = category;
    _loading = true;
    _posts = [];
    _error = null;
    notifyListeners();

    await previousSubscription?.cancel();
    if (_disposed || generation != _postsStreamGeneration) return;

    _postsSubscription =
        _firestoreService.postsStream(category: category).listen((posts) {
      if (_disposed || generation != _postsStreamGeneration) return;
      _posts = posts;
      _loading = false;
      _error = null;
      notifyListeners();
    }, onError: (Object error) {
      if (_disposed || generation != _postsStreamGeneration) return;
      debugPrint(
        '[Community] posts listener failed category=$category error=$error',
      );
      _posts = [];
      _loading = false;
      _subscribedCategory = null;
      _error = 'Could not load community posts. Please try again.';
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _postsStreamGeneration++;
    _postsSubscription?.cancel();
    super.dispose();
  }

  void clearAuthScopedState() {
    final previousSubscription = _postsSubscription;
    _postsSubscription = null;
    _subscribedCategory = null;
    _postsStreamGeneration++;
    unawaited(previousSubscription?.cancel());
    _posts = [];
    _loading = false;
    _error = null;
    _activeCategory = 'Trending';
    _isAddingComment = false;
    notifyListeners();
  }

  Future<bool> createPost({
    required String userId,
    required String userName,
    String? userPhotoUrl,
    String location = '',
    required String content,
    required String category,
    String? imageUrl,
    List<String> tags = const [],
  }) async {
    _loading = true;
    notifyListeners();
    try {
      final post = PostModel(
        id: '',
        userId: userId,
        userName: userName,
        userPhotoUrl: userPhotoUrl,
        location: location,
        content: content,
        category: category,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        tags: tags,
      );
      await _firestoreService.createPost(post);
      await _tryRecordActivity(
        userId: userId,
        displayName: userName,
        photoUrl: userPhotoUrl,
        actionType: WeeklyStatAction.postCreated,
      );
      _loading = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      developer.log(
        'createPost failed',
        error: e,
        stackTrace: st,
      );
      _error = 'Could not create post. Please try again.';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleLike(PostModel targetPost, UserModel? currentUser) async {
    final uid = currentUser?.uid ?? '';
    if (uid.isEmpty) {
      _error = 'Please sign in before liking posts.';
      notifyListeners();
      return;
    }

    final postId = targetPost.id;
    final idx = _posts.indexWhere((p) => p.id == postId);
    final post = idx == -1 ? targetPost : _posts[idx];

    // Query Firestore for the actual like state (source of truth)
    final currentlyLiked = await _firestoreService.isPostLikedBy(postId, uid);

    // Optimistic UI update
    final newLikeCount =
        currentlyLiked ? post.likeCount - 1 : post.likeCount + 1;
    if (idx != -1) {
      _posts[idx] = post.copyWith(likeCount: newLikeCount);
      notifyListeners();
    }

    try {
      await _firestoreService.toggleLike(postId, uid);
      if (!currentlyLiked && post.userId != uid && currentUser != null) {
        await _tryCreateNotification(
          post.userId,
          NotificationModel(
            id: 'like_${uid}_$postId',
            category: 'community',
            type: 'like',
            fromUserId: currentUser.uid,
            fromUserName: currentUser.name,
            fromUserPhotoUrl: currentUser.photoUrl,
            postId: postId,
            title: 'New like',
            message: '${currentUser.name} liked your post.',
            createdAt: DateTime.now(),
          ),
        );
      }
      _error = null;
    } catch (e) {
      final rollbackIdx = _posts.indexWhere((p) => p.id == postId);
      if (rollbackIdx != -1) {
        _posts[rollbackIdx] = post;
      }
      _error = 'Could not update like. Please try again.';
    }
    notifyListeners();
  }

  Future<void> deletePost(String postId, String currentUserId) async {
    try {
      await _firestoreService.deletePost(postId, currentUserId);
      _posts.removeWhere((p) => p.id == postId);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Could not delete post. Please try again.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addComment(CommentModel comment) async {
    if (_isAddingComment) return;
    _isAddingComment = true;
    notifyListeners();

    try {
      await _firestoreService.addComment(comment);
      await _tryRecordActivity(
        userId: comment.userId,
        displayName: comment.userName,
        photoUrl: comment.userPhotoUrl,
        actionType: WeeklyStatAction.commentCreated,
      );
      final idx = _posts.indexWhere((p) => p.id == comment.postId);
      PostModel? post;
      if (idx != -1) {
        post = _posts[idx];
        _posts[idx] =
            _posts[idx].copyWith(commentCount: _posts[idx].commentCount + 1);
      }
      post ??= await _firestoreService.getPost(comment.postId);
      if (post != null && post.userId != comment.userId) {
        await _tryCreateNotification(
          post.userId,
          NotificationModel(
            id: 'comment_${comment.userId}_${comment.postId}_${DateTime.now().microsecondsSinceEpoch}',
            category: 'community',
            type: 'comment',
            fromUserId: comment.userId,
            fromUserName: comment.userName,
            fromUserPhotoUrl: comment.userPhotoUrl,
            postId: comment.postId,
            title: 'New comment',
            message: '${comment.userName} commented on your post.',
            createdAt: DateTime.now(),
          ),
        );
      }
      _error = null;
      notifyListeners();
    } catch (e, st) {
      developer.log(
        'addComment failed',
        error: e,
        stackTrace: st,
      );
      _error = 'Could not add comment. Please try again.';
      notifyListeners();
      rethrow;
    } finally {
      _isAddingComment = false;
      notifyListeners();
    }
  }

  Stream<List<CommentModel>> commentsStream(String postId) {
    return _firestoreService.commentsStream(postId);
  }

  Stream<List<PostModel>> userPostsStream(String uid) {
    return _firestoreService.userPostsStream(uid);
  }

  Future<ReportPostResult> reportPost({
    required PostModel post,
    required UserModel reporter,
    required String reason,
    String details = '',
  }) async {
    if (reporter.uid.isEmpty) {
      _error = 'Please sign in before reporting posts.';
      notifyListeners();
      throw StateError(_error!);
    }
    if (post.userId == reporter.uid) {
      _error = 'You cannot report your own post.';
      notifyListeners();
      throw StateError(_error!);
    }

    try {
      final result = await _firestoreService.reportPost(
        ReportModel(
          reportId: reporter.uid,
          postId: post.id,
          postOwnerId: post.userId,
          reporterId: reporter.uid,
          reporterName: reporter.name,
          reason: reason,
          details: details.trim(),
          status: 'open',
          createdAt: DateTime.now(),
        ),
      );
      if (result == ReportPostResult.submitted) {
        final idx = _posts.indexWhere((p) => p.id == post.id);
        if (idx != -1) {
          final current = _posts[idx];
          final nextCount = current.reportCount + 1;
          _posts[idx] = current.copyWith(
            reportCount: nextCount,
            moderationStatus:
                nextCount >= 3 ? 'underReview' : current.moderationStatus,
          );
        }
      }
      _error = null;
      notifyListeners();
      return result;
    } catch (e) {
      _error = 'Could not submit report. Please try again.';
      notifyListeners();
      rethrow;
    }
  }

  Stream<int> followersCountStream(String uid) {
    return _firestoreService.followersCountStream(uid);
  }

  Stream<int> followingCountStream(String uid) {
    return _firestoreService.followingCountStream(uid);
  }

  Stream<bool> isFollowingStream(String currentUid, String targetUid) {
    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) {
      return Stream.value(false);
    }
    return _firestoreService.isFollowingStream(currentUid, targetUid);
  }

  Future<UserModel?> getUser(String uid) {
    return _firestoreService.getUser(uid);
  }

  Future<void> followUser({
    required UserModel currentUser,
    required UserModel targetUser,
  }) async {
    if (currentUser.uid == targetUser.uid) return;
    try {
      final alreadyFollowing = await _firestoreService.isFollowing(
        currentUser.uid,
        targetUser.uid,
      );
      await _firestoreService.followUser(
        currentUser: currentUser,
        targetUser: targetUser,
      );
      if (!alreadyFollowing) {
        await _tryCreateNotification(
          targetUser.uid,
          NotificationModel(
            id: 'follow_${currentUser.uid}',
            category: 'community',
            type: 'follow',
            fromUserId: currentUser.uid,
            fromUserName: currentUser.name,
            fromUserPhotoUrl: currentUser.photoUrl,
            title: 'New follower',
            message: '${currentUser.name} started following you.',
            createdAt: DateTime.now(),
          ),
        );
      }
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Could not follow this user. Please try again.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> unfollowUser({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) {
      return;
    }
    try {
      await _firestoreService.unfollowUser(
        currentUid: currentUid,
        targetUid: targetUid,
      );
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Could not unfollow this user. Please try again.';
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _tryCreateNotification(
    String targetUid,
    NotificationModel notification,
  ) async {
    try {
      await _firestoreService.createNotification(targetUid, notification);
    } catch (_) {
      // Notifications are best-effort so the primary community action can land.
    }
  }

  Future<void> _tryRecordActivity({
    required String userId,
    required String displayName,
    String? photoUrl,
    required WeeklyStatAction actionType,
  }) async {
    try {
      await _engagementService.updateWeeklyStatsForAction(
        uid: userId,
        displayName: displayName,
        photoUrl: photoUrl,
        actionType: actionType,
      );
    } catch (_) {
      // Stats and badges are best-effort so core community actions still land.
    }
  }
}
