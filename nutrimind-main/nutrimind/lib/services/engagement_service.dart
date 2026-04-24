import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/engagement_config.dart';
import '../models/badge_model.dart';
import '../models/meal_model.dart';
import '../models/weekly_stats_model.dart';

enum WeeklyStatAction {
  mealLogged,
  scannedMeal,
  recipeSaved,
  postCreated,
  commentCreated,
  budgetFriendlyMeal,
  plannedMealSaved,
}

extension WeeklyStatActionX on WeeklyStatAction {
  String get key => switch (this) {
        WeeklyStatAction.mealLogged => 'mealLogged',
        WeeklyStatAction.scannedMeal => 'scannedMeal',
        WeeklyStatAction.recipeSaved => 'recipeSaved',
        WeeklyStatAction.postCreated => 'postCreated',
        WeeklyStatAction.commentCreated => 'commentCreated',
        WeeklyStatAction.budgetFriendlyMeal => 'budgetFriendlyMeal',
        WeeklyStatAction.plannedMealSaved => 'plannedMealSaved',
      };

  String get counterField => EngagementConfig.actionRuleFor(key).counterField;

  int get points => EngagementConfig.actionRuleFor(key).points;
}

class EngagementService {
  EngagementService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference _users() => _db.collection('users');

  CollectionReference _meals(String uid) =>
      _users().doc(uid).collection('meals');

  CollectionReference _weeklyStats(String uid) =>
      _users().doc(uid).collection('weeklyStats');

  CollectionReference _badges(String uid) =>
      _users().doc(uid).collection('badges');

  static String weekIdFor(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final monday = day.subtract(Duration(days: day.weekday - 1));
    return '${monday.year.toString().padLeft(4, '0')}-'
        '${monday.month.toString().padLeft(2, '0')}-'
        '${monday.day.toString().padLeft(2, '0')}';
  }

  Stream<List<WeeklyStatsModel>> weeklyLeaderboardStream({
    DateTime? anchorDate,
    int limit = EngagementConfig.leaderboardDisplayLimit,
  }) {
    final weekId = weekIdFor(anchorDate ?? DateTime.now());
    return _db
        .collectionGroup('weeklyStats')
        .where('weekId', isEqualTo: weekId)
        .limit(EngagementConfig.leaderboardQueryLimit)
        .snapshots()
        .map((snapshot) {
      final stats = snapshot.docs
          .map((doc) => WeeklyStatsModel.fromMap(doc.data()))
          .where((stat) => stat.points > 0)
          .toList()
        ..sort((a, b) => EngagementConfig.compareLeaderboardRows(
              aPoints: a.points,
              aDisplayName: a.displayName,
              bPoints: b.points,
              bDisplayName: b.displayName,
            ));
      return stats.take(limit).toList(growable: false);
    });
  }

  Stream<List<BadgeModel>> badgesStream(String uid) {
    if (uid.isEmpty) return Stream.value(const <BadgeModel>[]);
    return _badges(uid).orderBy('earnedAt', descending: true).snapshots().map(
        (snapshot) => snapshot.docs
            .map(
                (doc) => BadgeModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  Future<List<BadgeModel>> getUserBadges(String uid) async {
    if (uid.isEmpty) return const <BadgeModel>[];
    final snapshot =
        await _badges(uid).orderBy('earnedAt', descending: true).get();
    return snapshot.docs
        .map((doc) => BadgeModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> updateWeeklyStatsForAction({
    required String uid,
    required WeeklyStatAction actionType,
    String displayName = '',
    String? photoUrl,
    DateTime? occurredAt,
    double? dailyBudget,
  }) async {
    if (uid.isEmpty) return;

    final actionDate = occurredAt ?? DateTime.now();
    final weekId = weekIdFor(actionDate);
    final identity = await _resolveIdentity(uid, displayName, photoUrl);
    final ref = _weeklyStats(uid).doc(weekId);
    await ref.set(
      {
        'uid': uid,
        'displayName': identity.$1,
        'photoUrl': identity.$2,
        'weekId': weekId,
        actionType.counterField: FieldValue.increment(1),
        if (actionType.points > 0)
          'points': FieldValue.increment(actionType.points),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      },
      SetOptions(merge: true),
    );

    await checkAndAwardBadges(
      uid,
      sourceAction: actionType,
      actionDate: actionDate,
      dailyBudget: dailyBudget,
    );
  }

  Future<void> checkAndAwardBadges(
    String uid, {
    WeeklyStatAction? sourceAction,
    DateTime? actionDate,
    double? dailyBudget,
  }) async {
    if (uid.isEmpty) return;

    switch (sourceAction) {
      case WeeklyStatAction.mealLogged:
        await awardBadge(
          uid,
          _badge(EngagementConfig.firstMealLoggedBadge, sourceAction!.key),
        );
        if (dailyBudget != null && actionDate != null) {
          if (await _loggedDayIsUnderBudget(uid, actionDate, dailyBudget)) {
            await awardBadge(
              uid,
              _badge(EngagementConfig.budgetSaverBadge, sourceAction.key),
            );
          }
        }
        if (await _hasSevenDayMealLoggingStreak(uid)) {
          await awardBadge(
            uid,
            _badge(
              EngagementConfig.sevenDayMealLoggingStreakBadge,
              sourceAction.key,
            ),
          );
        }
        break;
      case WeeklyStatAction.scannedMeal:
        await awardBadge(
          uid,
          _badge(EngagementConfig.firstFoodScanBadge, sourceAction!.key),
        );
        break;
      case WeeklyStatAction.recipeSaved:
        await awardBadge(
          uid,
          _badge(EngagementConfig.recipeExplorerBadge, sourceAction!.key),
        );
        break;
      case WeeklyStatAction.postCreated:
        await awardBadge(
          uid,
          _badge(EngagementConfig.firstPostSharedBadge, sourceAction!.key),
        );
        break;
      case WeeklyStatAction.commentCreated:
        if (await _weeklyCounterAtLeast(
          uid,
          actionDate ?? DateTime.now(),
          WeeklyStatAction.commentCreated.counterField,
          EngagementConfig.communityHelperCommentThreshold,
        )) {
          await awardBadge(
            uid,
            _badge(EngagementConfig.communityHelperBadge, sourceAction!.key),
          );
        }
        break;
      case WeeklyStatAction.budgetFriendlyMeal:
        if (dailyBudget != null && actionDate != null) {
          if (await _loggedDayIsUnderBudget(uid, actionDate, dailyBudget)) {
            await awardBadge(
              uid,
              _badge(EngagementConfig.budgetSaverBadge, sourceAction!.key),
            );
          }
        }
        break;
      case WeeklyStatAction.plannedMealSaved:
        if (await _plannedMealsSavedThisWeek(
                uid, actionDate ?? DateTime.now()) >=
            EngagementConfig.consistentPlannerWeeklyMealThreshold) {
          await awardBadge(
            uid,
            _badge(EngagementConfig.consistentPlannerBadge, sourceAction!.key),
          );
        }
        break;
      case null:
        if (await _hasAnyLoggedMeal(uid)) {
          await awardBadge(
            uid,
            _badge(EngagementConfig.firstMealLoggedBadge, 'audit'),
          );
        }
        if (await _hasAnyPost(uid)) {
          await awardBadge(
            uid,
            _badge(EngagementConfig.firstPostSharedBadge, 'audit'),
          );
        }
        if (await _commentCountAtLeast(
          uid,
          EngagementConfig.communityHelperCommentThreshold,
        )) {
          await awardBadge(
            uid,
            _badge(EngagementConfig.communityHelperBadge, 'audit'),
          );
        }
        if (await _hasSevenDayMealLoggingStreak(uid)) {
          await awardBadge(
            uid,
            _badge(
              EngagementConfig.sevenDayMealLoggingStreakBadge,
              'audit',
            ),
          );
        }
        break;
    }
  }

  Future<void> awardBadge(String uid, BadgeModel badge) async {
    if (uid.isEmpty) return;
    final ref = _badges(uid).doc(badge.badgeId);
    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) return;
      transaction.set(ref, badge.toMap());
    });
  }

  Future<(String, String?)> _resolveIdentity(
    String uid,
    String displayName,
    String? photoUrl,
  ) async {
    if (displayName.trim().isNotEmpty) {
      return (displayName.trim(), photoUrl);
    }

    final userDoc = await _users().doc(uid).get();
    final data = userDoc.data() as Map<String, dynamic>?;
    final name = (data?['name'] as String?)?.trim();
    return (
      name == null || name.isEmpty ? 'User' : name,
      photoUrl ?? data?['photoUrl'] as String?,
    );
  }

  Future<bool> _hasAnyLoggedMeal(String uid) async {
    final snapshot = await _meals(uid)
        .where('status', isEqualTo: MealStatus.logged.name)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<bool> _hasAnyPost(String uid) async {
    final snapshot = await _db
        .collection('posts')
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<bool> _commentCountAtLeast(String uid, int threshold) async {
    final snapshot = await _db
        .collectionGroup('comments')
        .where('userId', isEqualTo: uid)
        .limit(threshold)
        .get();
    return snapshot.docs.length >= threshold;
  }

  Future<int> _plannedMealsSavedThisWeek(String uid, DateTime date) async {
    return _weeklyCounterValue(
      uid,
      date,
      WeeklyStatAction.plannedMealSaved.counterField,
    );
  }

  Future<bool> _weeklyCounterAtLeast(
    String uid,
    DateTime date,
    String field,
    int threshold,
  ) async {
    return await _weeklyCounterValue(uid, date, field) >= threshold;
  }

  Future<int> _weeklyCounterValue(
    String uid,
    DateTime date,
    String field,
  ) async {
    final weekId = weekIdFor(date);
    final doc = await _weeklyStats(uid).doc(weekId).get();
    final data = doc.data() as Map<String, dynamic>?;
    return (data?[field] ?? 0).toInt();
  }

  Future<bool> _loggedDayIsUnderBudget(
    String uid,
    DateTime date,
    double dailyBudget,
  ) async {
    if (dailyBudget <= 0) return false;
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final snapshot = await _meals(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    final logged = snapshot.docs
        .map((doc) => MealModel.fromMap(doc.data() as Map<String, dynamic>))
        .where((meal) => meal.status == MealStatus.logged)
        .toList(growable: false);
    if (logged.isEmpty) return false;
    final total = logged.fold<double>(0, (runningTotal, meal) {
      return runningTotal + meal.price;
    });
    return total <= dailyBudget;
  }

  Future<bool> _hasSevenDayMealLoggingStreak(String uid) async {
    final snapshot = await _meals(uid)
        .where('status', isEqualTo: MealStatus.logged.name)
        .limit(250)
        .get();
    final days = snapshot.docs
        .map((doc) => MealModel.fromMap(doc.data() as Map<String, dynamic>))
        .map((meal) => DateTime(meal.date.year, meal.date.month, meal.date.day))
        .toSet()
        .toList()
      ..sort();
    if (days.length < EngagementConfig.mealLoggingStreakDays) return false;

    var streak = 1;
    for (var i = 1; i < days.length; i++) {
      final diff = days[i].difference(days[i - 1]).inDays;
      if (diff == 1) {
        streak++;
        if (streak >= EngagementConfig.mealLoggingStreakDays) return true;
      } else if (diff > 1) {
        streak = 1;
      }
    }
    return false;
  }

  BadgeModel _badge(String badgeId, String sourceAction) {
    final now = DateTime.now();
    final definition = EngagementConfig.badgeDefinitionFor(badgeId);
    return BadgeModel(
      badgeId: badgeId,
      title: definition.title,
      description: definition.description,
      icon: definition.icon,
      earnedAt: now,
      sourceAction: sourceAction,
      ruleSource: EngagementConfig.rulesSource,
    );
  }
}
