import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String location;
  final String content;
  final String category;
  final List<String> likes; // Legacy: array-based likes (for migration)
  final int _likeCount; // Scalable: aggregate count from subcollection
  final int commentCount;
  final String? imageUrl;
  final DateTime createdAt;
  final List<String> tags;
  final int reportCount;
  final String moderationStatus;
  final bool isHiddenByModeration;

  PostModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    this.location = '',
    required this.content,
    required this.category,
    this.likes = const [],
    this.commentCount = 0,
    this.imageUrl,
    required this.createdAt,
    this.tags = const [],
    this.reportCount = 0,
    this.moderationStatus = 'active',
    this.isHiddenByModeration = false,
    int likeCount = 0, // New: aggregate field from likes subcollection
  }) : _likeCount = likeCount;

  /// Check if user liked this post (supports both legacy array and new subcollection).
  bool isLikedBy(String uid) {
    if (uid.isEmpty) return false;
    // Check legacy array first for backward compatibility
    if (likes.contains(uid)) return true;
    // For new posts with subcollection, likeCount > 0 means someone liked
    // The actual user check is done via FirestoreService.isPostLikedBy()
    return false;
  }

  /// Get total like count (prefers aggregate field, falls back to legacy array).
  int get likeCount => _likeCount > 0 ? _likeCount : likes.length;
  bool get isUnderReview => moderationStatus == 'underReview';

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'userPhotoUrl': userPhotoUrl,
        'location': location,
        'content': content,
        'category': category,
        'likes':
            likes, // Legacy: kept for backward compatibility during migration
        'likeCount': likeCount, // New: aggregate from subcollection
        'commentCount': commentCount,
        'imageUrl': imageUrl,
        'createdAt': Timestamp.fromDate(createdAt),
        'tags': tags,
        'reportCount': reportCount,
        'moderationStatus': moderationStatus,
        'isHiddenByModeration': isHiddenByModeration,
      };

  factory PostModel.fromMap(Map<String, dynamic> map) => PostModel(
        id: map['id'] ?? '',
        userId: map['userId'] ?? '',
        userName: map['userName'] ?? '',
        userPhotoUrl: map['userPhotoUrl'],
        location: map['location'] ?? '',
        content: map['content'] ?? '',
        category: map['category'] ?? 'Trending',
        likes: List<String>.from(map['likes'] ?? []),
        likeCount: (map['likeCount'] ?? 0).toInt(), // New: aggregate field
        commentCount: (map['commentCount'] ?? 0).toInt(),
        imageUrl: map['imageUrl'],
        createdAt: map['createdAt'] != null
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        tags: List<String>.from(map['tags'] ?? []),
        reportCount: (map['reportCount'] ?? 0).toInt(),
        moderationStatus: map['moderationStatus'] ?? 'active',
        isHiddenByModeration: map['isHiddenByModeration'] ?? false,
      );

  PostModel copyWith({
    List<String>? likes,
    int? likeCount,
    int? commentCount,
    int? reportCount,
    String? moderationStatus,
    bool? isHiddenByModeration,
  }) =>
      PostModel(
        id: id,
        userId: userId,
        userName: userName,
        userPhotoUrl: userPhotoUrl,
        location: location,
        content: content,
        category: category,
        likes: likes ?? this.likes,
        likeCount: likeCount ?? _likeCount,
        commentCount: commentCount ?? this.commentCount,
        imageUrl: imageUrl,
        createdAt: createdAt,
        tags: tags,
        reportCount: reportCount ?? this.reportCount,
        moderationStatus: moderationStatus ?? this.moderationStatus,
        isHiddenByModeration: isHiddenByModeration ?? this.isHiddenByModeration,
      );

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 6) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}

class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String content;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'postId': postId,
        'userId': userId,
        'userName': userName,
        'userPhotoUrl': userPhotoUrl,
        'content': content,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory CommentModel.fromMap(Map<String, dynamic> map) => CommentModel(
        id: map['id'] ?? '',
        postId: map['postId'] ?? '',
        userId: map['userId'] ?? '',
        userName: map['userName'] ?? '',
        userPhotoUrl: map['userPhotoUrl'],
        content: map['content'] ?? '',
        createdAt: map['createdAt'] != null
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
}
