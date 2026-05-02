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

  factory PostModel.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    final storedId = map['id']?.toString().trim() ?? '';
    return PostModel(
      id: storedId.isEmpty ? (documentId ?? '') : storedId,
      userId: map['userId']?.toString() ?? '',
      userName: map['userName']?.toString() ?? '',
      userPhotoUrl: map['userPhotoUrl']?.toString(),
      location: map['location']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      category: map['category']?.toString() ?? 'Trending',
      likes: _stringListOrEmpty(map['likes']),
      likeCount: _intOrZero(map['likeCount']),
      commentCount: _intOrZero(map['commentCount']),
      imageUrl: map['imageUrl']?.toString(),
      createdAt: _dateTimeOrNow(map['createdAt']),
      tags: _stringListOrEmpty(map['tags']),
      reportCount: _intOrZero(map['reportCount']),
      moderationStatus: map['moderationStatus']?.toString() ?? 'active',
      isHiddenByModeration: map['isHiddenByModeration'] is bool
          ? map['isHiddenByModeration'] as bool
          : false,
    );
  }

  static DateTime _dateTimeOrNow(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  static int _intOrZero(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static List<String> _stringListOrEmpty(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }

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
