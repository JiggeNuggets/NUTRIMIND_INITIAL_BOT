import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportPostResult {
  submitted,
  duplicate,
}

class ReportModel {
  const ReportModel({
    required this.reportId,
    required this.postId,
    required this.postOwnerId,
    required this.reporterId,
    required this.reporterName,
    required this.reason,
    this.details = '',
    this.status = 'open',
    required this.createdAt,
  });

  final String reportId;
  final String postId;
  final String postOwnerId;
  final String reporterId;
  final String reporterName;
  final String reason;
  final String details;
  final String status;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'reportId': reportId,
        'postId': postId,
        'postOwnerId': postOwnerId,
        'reporterId': reporterId,
        'reporterName': reporterName,
        'reason': reason,
        'details': details,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory ReportModel.fromMap(Map<String, dynamic> map) => ReportModel(
        reportId: map['reportId'] ?? '',
        postId: map['postId'] ?? '',
        postOwnerId: map['postOwnerId'] ?? '',
        reporterId: map['reporterId'] ?? '',
        reporterName: map['reporterName'] ?? '',
        reason: map['reason'] ?? '',
        details: map['details'] ?? '',
        status: map['status'] ?? 'open',
        createdAt: map['createdAt'] != null
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  ReportModel copyWith({
    String? reportId,
    String? postId,
    String? postOwnerId,
    String? reporterId,
    String? reporterName,
    String? reason,
    String? details,
    String? status,
    DateTime? createdAt,
  }) {
    return ReportModel(
      reportId: reportId ?? this.reportId,
      postId: postId ?? this.postId,
      postOwnerId: postOwnerId ?? this.postOwnerId,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      reason: reason ?? this.reason,
      details: details ?? this.details,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
