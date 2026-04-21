import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final String location;
  final String goal;
  final String gender;
  final double height;
  final double weight;
  final int age;
  final double dailyBudget;
  final bool allowNonLocal;
  final double budgetBuffer;
  final bool isPremium;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.location = 'Davao City, Philippines',
    this.goal = 'nutrition',
    this.gender = 'Male',
    this.height = 168,
    this.weight = 64,
    this.age = 28,
    this.dailyBudget = 150,
    this.allowNonLocal = false,
    this.budgetBuffer = 15,
    this.isPremium = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
        'location': location,
        'goal': goal,
        'gender': gender,
        'height': height,
        'weight': weight,
        'age': age,
        'dailyBudget': dailyBudget,
        'allowNonLocal': allowNonLocal,
        'budgetBuffer': budgetBuffer,
        'isPremium': isPremium,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        uid: map['uid'] ?? '',
        name: map['name'] ?? '',
        email: map['email'] ?? '',
        photoUrl: map['photoUrl'],
        location: map['location'] ?? 'Davao City, Philippines',
        goal: map['goal'] ?? 'nutrition',
        gender: map['gender'] ?? 'Male',
        height: (map['height'] ?? 168).toDouble(),
        weight: (map['weight'] ?? 64).toDouble(),
        age: (map['age'] ?? 28).toInt(),
        dailyBudget: (map['dailyBudget'] ?? 150).toDouble(),
        allowNonLocal: map['allowNonLocal'] ?? false,
        budgetBuffer: (map['budgetBuffer'] ?? 15).toDouble(),
        isPremium: map['isPremium'] ?? false,
        createdAt: map['createdAt'] != null
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  UserModel copyWith({
    String? name,
    String? photoUrl,
    String? location,
    String? goal,
    String? gender,
    double? height,
    double? weight,
    int? age,
    double? dailyBudget,
    bool? allowNonLocal,
    double? budgetBuffer,
    bool? isPremium,
  }) =>
      UserModel(
        uid: uid,
        name: name ?? this.name,
        email: email,
        photoUrl: photoUrl ?? this.photoUrl,
        location: location ?? this.location,
        goal: goal ?? this.goal,
        gender: gender ?? this.gender,
        height: height ?? this.height,
        weight: weight ?? this.weight,
        age: age ?? this.age,
        dailyBudget: dailyBudget ?? this.dailyBudget,
        allowNonLocal: allowNonLocal ?? this.allowNonLocal,
        budgetBuffer: budgetBuffer ?? this.budgetBuffer,
        isPremium: isPremium ?? this.isPremium,
        createdAt: createdAt,
      );
}
