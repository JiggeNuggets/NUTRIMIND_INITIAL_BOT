import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/engagement_config.dart';

class BadgeModel {
  const BadgeModel({
    required this.badgeId,
    required this.title,
    required this.description,
    required this.icon,
    required this.earnedAt,
    required this.sourceAction,
    this.ruleSource = EngagementConfig.rulesSource,
  });

  final String badgeId;
  final String title;
  final String description;
  final String icon;
  final DateTime earnedAt;
  final String sourceAction;
  final String ruleSource;

  Map<String, dynamic> toMap() => {
        'badgeId': badgeId,
        'title': title,
        'description': description,
        'icon': icon,
        'earnedAt': Timestamp.fromDate(earnedAt),
        'sourceAction': sourceAction,
        'ruleSource': ruleSource,
      };

  factory BadgeModel.fromMap(Map<String, dynamic> map) => BadgeModel(
        badgeId: map['badgeId'] ?? '',
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        icon: map['icon'] ?? 'emoji_events',
        earnedAt: map['earnedAt'] != null
            ? (map['earnedAt'] as Timestamp).toDate()
            : DateTime.now(),
        sourceAction: map['sourceAction'] ?? '',
        ruleSource: map['ruleSource'] ?? EngagementConfig.rulesSource,
      );
}
