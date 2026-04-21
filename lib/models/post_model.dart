import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String location;
  final String content;
  final String category;
  final List<String> likes;
  final int commentCount;
  final String? imageUrl;
  final DateTime createdAt;
  final List<String> tags;

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
  });

  bool isLikedBy(String uid) => likes.contains(uid);
  int get likeCount => likes.length;

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'userPhotoUrl': userPhotoUrl,
        'location': location,
        'content': content,
        'category': category,
        'likes': likes,
        'commentCount': commentCount,
        'imageUrl': imageUrl,
        'createdAt': Timestamp.fromDate(createdAt),
        'tags': tags,
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
        commentCount: (map['commentCount'] ?? 0).toInt(),
        imageUrl: map['imageUrl'],
        createdAt: map['createdAt'] != null
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        tags: List<String>.from(map['tags'] ?? []),
      );

  PostModel copyWith({List<String>? likes, int? commentCount}) => PostModel(
        id: id,
        userId: userId,
        userName: userName,
        userPhotoUrl: userPhotoUrl,
        location: location,
        content: content,
        category: category,
        likes: likes ?? this.likes,
        commentCount: commentCount ?? this.commentCount,
        imageUrl: imageUrl,
        createdAt: createdAt,
        tags: tags,
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
