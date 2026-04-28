import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_safety.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String? photoUrl;
  final String location;
  final String goal;
  final String gender;
  final double height;
  final double weight;
  final int age;
  final double bmi;
  final String bmiCategory;
  final double dailyBudget;
  final bool allowNonLocal;
  final double budgetBuffer;
  final bool profileCompleted;
  final bool budgetConfigured;
  final bool isPremium;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.role = 'user',
    this.photoUrl,
    this.location = 'Davao City, Philippines',
    this.goal = 'nutrition',
    this.gender = 'Male',
    this.height = 168,
    this.weight = 64,
    this.age = 28,
    this.bmi = 0,
    this.bmiCategory = '',
    this.dailyBudget = 150,
    this.allowNonLocal = false,
    this.budgetBuffer = 15,
    this.profileCompleted = false,
    this.budgetConfigured = false,
    this.isPremium = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  static double computeBmi({
    required double heightCm,
    required double weightKg,
  }) {
    if (heightCm <= 0 || weightKg <= 0) return 0;
    final meters = heightCm / 100;
    if (meters <= 0) return 0;
    return safeDouble(weightKg / (meters * meters));
  }

  static String computeBmiCategory(double bmi) {
    if (bmi <= 0) return '';
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'role': role,
        'photoUrl': photoUrl,
        'location': location,
        'goal': goal,
        'gender': gender,
        'height': height,
        'weight': weight,
        'age': age,
        'bmi': bmi,
        'bmiCategory': bmiCategory,
        'dailyBudget': dailyBudget,
        'allowNonLocal': allowNonLocal,
        'budgetBuffer': budgetBuffer,
        'profileCompleted': profileCompleted,
        'budgetConfigured': budgetConfigured,
        'isPremium': isPremium,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final height = (map['height'] ?? 168).toDouble();
    final weight = (map['weight'] ?? 64).toDouble();
    final storedBmi = (map['bmi'] ?? 0).toDouble();
    final bmi = storedBmi > 0
        ? storedBmi
        : computeBmi(heightCm: height, weightKg: weight);
    final storedCategory = (map['bmiCategory'] ?? '').toString();
    final bmiCategory =
        storedCategory.isNotEmpty ? storedCategory : computeBmiCategory(bmi);
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: (map['role'] ?? 'user').toString(),
      photoUrl: map['photoUrl'],
      location: map['location'] ?? 'Davao City, Philippines',
      goal: map['goal'] ?? 'nutrition',
      gender: map['gender'] ?? 'Male',
      height: height,
      weight: weight,
      age: (map['age'] ?? 28).toInt(),
      bmi: bmi,
      bmiCategory: bmiCategory,
      dailyBudget: (map['dailyBudget'] ?? 150).toDouble(),
      allowNonLocal: map['allowNonLocal'] ?? false,
      budgetBuffer: (map['budgetBuffer'] ?? 15).toDouble(),
      profileCompleted: map['profileCompleted'] == true ||
          map['onboardingCompleted'] == true,
      budgetConfigured: map['budgetConfigured'] == true,
      isPremium: map['isPremium'] ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : (map['createdAt'] != null
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.now()),
    );
  }

  UserModel copyWith({
    String? name,
    String? role,
    String? photoUrl,
    String? location,
    String? goal,
    String? gender,
    double? height,
    double? weight,
    int? age,
    double? bmi,
    String? bmiCategory,
    double? dailyBudget,
    bool? allowNonLocal,
    double? budgetBuffer,
    bool? profileCompleted,
    bool? budgetConfigured,
    bool? isPremium,
    DateTime? updatedAt,
  }) =>
      UserModel(
        uid: uid,
        name: name ?? this.name,
        email: email,
        role: role ?? this.role,
        photoUrl: photoUrl ?? this.photoUrl,
        location: location ?? this.location,
        goal: goal ?? this.goal,
        gender: gender ?? this.gender,
        height: height ?? this.height,
        weight: weight ?? this.weight,
        age: age ?? this.age,
        bmi: bmi ?? this.bmi,
        bmiCategory: bmiCategory ?? this.bmiCategory,
        dailyBudget: dailyBudget ?? this.dailyBudget,
        allowNonLocal: allowNonLocal ?? this.allowNonLocal,
        budgetBuffer: budgetBuffer ?? this.budgetBuffer,
        profileCompleted: profileCompleted ?? this.profileCompleted,
        budgetConfigured: budgetConfigured ?? this.budgetConfigured,
        isPremium: isPremium ?? this.isPremium,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );
}
