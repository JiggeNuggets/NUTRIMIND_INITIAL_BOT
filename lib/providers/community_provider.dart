import 'dart:async';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/post_model.dart';

class CommunityProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  StreamSubscription<List<PostModel>>? _postsSubscription;

  List<PostModel> _posts = [];
  bool _loading = false;
  String? _error;
  String _activeCategory = 'Trending';

  List<PostModel> get posts => _posts;
  bool get loading => _loading;
  String? get error => _error;
  String get activeCategory => _activeCategory;

  void listenToPosts(String category) {
    _activeCategory = category;
    _loading = true;
    _posts = [];
    notifyListeners();
    _postsSubscription?.cancel();
    _postsSubscription =
        _firestoreService.postsStream(category: category).listen((posts) {
      _posts = posts;
      _loading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    super.dispose();
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
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleLike(String postId, String uid) async {
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;

    final post = _posts[idx];
    final liked = post.isLikedBy(uid);
    final newLikes = List<String>.from(post.likes);
    if (liked) {
      newLikes.remove(uid);
    } else {
      newLikes.add(uid);
    }
    _posts[idx] = post.copyWith(likes: newLikes);
    notifyListeners();

    // Persist async
    await _firestoreService.toggleLike(postId, uid);
  }

  Future<void> deletePost(String postId) async {
    await _firestoreService.deletePost(postId);
    _posts.removeWhere((p) => p.id == postId);
    notifyListeners();
  }

  Future<void> addComment(CommentModel comment) async {
    await _firestoreService.addComment(comment);
    final idx = _posts.indexWhere((p) => p.id == comment.postId);
    if (idx != -1) {
      _posts[idx] = _posts[idx].copyWith(
          commentCount: _posts[idx].commentCount + 1);
      notifyListeners();
    }
  }

  Stream<List<CommentModel>> commentsStream(String postId) {
    return _firestoreService.commentsStream(postId);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
