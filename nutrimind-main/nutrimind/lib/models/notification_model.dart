import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String category;
  final String type;
  final String? fromUserId;
  final String? fromUserName;
  final String? fromUserPhotoUrl;
  final String? postId;
  final String? mealId;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.category,
    required this.type,
    this.fromUserId,
    this.fromUserName,
    this.fromUserPhotoUrl,
    this.postId,
    this.mealId,
    required this.title,
    required this.message,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'category': category,
        'type': type,
        'fromUserId': fromUserId,
        'fromUserName': fromUserName,
        'fromUserPhotoUrl': fromUserPhotoUrl,
        'postId': postId,
        'mealId': mealId,
        'title': title,
        'message': message,
        'isRead': isRead,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    DateTime createdAt;
    if (rawCreatedAt is Timestamp) {
      createdAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is DateTime) {
      createdAt = rawCreatedAt;
    } else {
      createdAt = DateTime.now();
    }

    return NotificationModel(
      id: map['id'] ?? '',
      category: map['category'] ?? 'community',
      type: map['type'] ?? '',
      fromUserId: map['fromUserId'],
      fromUserName: map['fromUserName'],
      fromUserPhotoUrl: map['fromUserPhotoUrl'],
      postId: map['postId'],
      mealId: map['mealId'],
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      isRead: map['isRead'] ?? false,
      createdAt: createdAt,
    );
  }

  NotificationModel copyWith({
    String? id,
    String? category,
    String? type,
    String? fromUserId,
    String? fromUserName,
    String? fromUserPhotoUrl,
    String? postId,
    String? mealId,
    String? title,
    String? message,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      category: category ?? this.category,
      type: type ?? this.type,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUserName: fromUserName ?? this.fromUserName,
      fromUserPhotoUrl: fromUserPhotoUrl ?? this.fromUserPhotoUrl,
      postId: postId ?? this.postId,
      mealId: mealId ?? this.mealId,
      title: title ?? this.title,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 6) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
