import 'package:cloud_firestore/cloud_firestore.dart';

enum MealType { breakfast, lunch, dinner, snack }
enum MealStatus { logged, ready, upcoming }

class MealModel {
  final String id;
  final String userId;
  final String name;
  final MealType type;
  final double price;
  final int calories;
  final MealStatus status;
  final DateTime date;
  final DateTime? loggedAt;
  final String? notes;
  final List<String> ingredients;
  final int protein;
  final int carbs;
  final int fat;
  final String? recipe;
  final List<String> cookingSteps;

  MealModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.price,
    required this.calories,
    this.status = MealStatus.upcoming,
    required this.date,
    this.loggedAt,
    this.notes,
    this.ingredients = const [],
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.recipe,
    this.cookingSteps = const [],
  });

  String get typeLabel {
    switch (type) {
      case MealType.breakfast: return 'Breakfast';
      case MealType.lunch: return 'Lunch';
      case MealType.dinner: return 'Dinner';
      case MealType.snack: return 'Snack';
    }
  }

  String get statusLabel {
    switch (status) {
      case MealStatus.logged: return 'Logged';
      case MealStatus.ready: return 'Ready to log';
      case MealStatus.upcoming: return 'Upcoming';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'type': type.name,
        'price': price,
        'calories': calories,
        'status': status.name,
        'date': Timestamp.fromDate(date),
        'loggedAt': loggedAt != null ? Timestamp.fromDate(loggedAt!) : null,
        'notes': notes,
        'ingredients': ingredients,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'recipe': recipe,
        'cookingSteps': cookingSteps,
      };

  factory MealModel.fromMap(Map<String, dynamic> map) => MealModel(
        id: map['id'] ?? '',
        userId: map['userId'] ?? '',
        name: map['name'] ?? '',
        type: MealType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => MealType.breakfast,
        ),
        price: (map['price'] ?? 0).toDouble(),
        calories: (map['calories'] ?? 0).toInt(),
        status: MealStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => MealStatus.upcoming,
        ),
        date: map['date'] != null
            ? (map['date'] as Timestamp).toDate()
            : DateTime.now(),
        loggedAt: map['loggedAt'] != null
            ? (map['loggedAt'] as Timestamp).toDate()
            : null,
        notes: map['notes'],
        ingredients: List<String>.from(map['ingredients'] ?? []),
        protein: (map['protein'] ?? 0).toInt(),
        carbs: (map['carbs'] ?? 0).toInt(),
        fat: (map['fat'] ?? 0).toInt(),
        recipe: map['recipe'] as String?,
        cookingSteps: List<String>.from(map['cookingSteps'] ?? []),
      );

  MealModel copyWith({
    MealStatus? status,
    DateTime? loggedAt,
    String? recipe,
    List<String>? cookingSteps,
  }) =>
      MealModel(
        id: id,
        userId: userId,
        name: name,
        type: type,
        price: price,
        calories: calories,
        status: status ?? this.status,
        date: date,
        loggedAt: loggedAt ?? this.loggedAt,
        notes: notes,
        ingredients: ingredients,
        protein: protein,
        carbs: carbs,
        fat: fat,
        recipe: recipe ?? this.recipe,
        cookingSteps: cookingSteps ?? this.cookingSteps,
      );
}
