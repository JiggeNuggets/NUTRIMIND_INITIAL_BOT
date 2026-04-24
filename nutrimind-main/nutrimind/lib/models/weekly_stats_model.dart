import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyStatsModel {
  const WeeklyStatsModel({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    required this.weekId,
    this.mealsLogged = 0,
    this.scannedMeals = 0,
    this.postsCreated = 0,
    this.commentsCreated = 0,
    this.recipesSaved = 0,
    this.budgetFriendlyMeals = 0,
    this.plannedMealsSaved = 0,
    this.points = 0,
    required this.updatedAt,
  });

  final String uid;
  final String displayName;
  final String? photoUrl;
  final String weekId;
  final int mealsLogged;
  final int scannedMeals;
  final int postsCreated;
  final int commentsCreated;
  final int recipesSaved;
  final int budgetFriendlyMeals;
  final int plannedMealsSaved;
  final int points;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'weekId': weekId,
        'mealsLogged': mealsLogged,
        'scannedMeals': scannedMeals,
        'postsCreated': postsCreated,
        'commentsCreated': commentsCreated,
        'recipesSaved': recipesSaved,
        'budgetFriendlyMeals': budgetFriendlyMeals,
        'plannedMealsSaved': plannedMealsSaved,
        'points': points,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory WeeklyStatsModel.fromMap(Map<String, dynamic> map) {
    return WeeklyStatsModel(
      uid: map['uid'] ?? '',
      displayName: map['displayName'] ?? 'User',
      photoUrl: map['photoUrl'],
      weekId: map['weekId'] ?? '',
      mealsLogged: (map['mealsLogged'] ?? 0).toInt(),
      scannedMeals: (map['scannedMeals'] ?? 0).toInt(),
      postsCreated: (map['postsCreated'] ?? 0).toInt(),
      commentsCreated: (map['commentsCreated'] ?? 0).toInt(),
      recipesSaved: (map['recipesSaved'] ?? 0).toInt(),
      budgetFriendlyMeals: (map['budgetFriendlyMeals'] ?? 0).toInt(),
      plannedMealsSaved: (map['plannedMealsSaved'] ?? 0).toInt(),
      points: (map['points'] ?? 0).toInt(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
