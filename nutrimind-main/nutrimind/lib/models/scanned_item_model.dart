import 'package:cloud_firestore/cloud_firestore.dart';

class ScannedItemModel {
  const ScannedItemModel({
    required this.id,
    required this.name,
    required this.calories,
    required this.price,
    required this.mealType,
    this.imageUrl,
    this.source = 'scanner',
    this.confidence,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int calories;
  final double price;
  final String mealType;
  final String? imageUrl;
  final String source;
  final double? confidence;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'name': name,
        'calories': calories,
        'price': price,
        'mealType': mealType,
        if (imageUrl != null && imageUrl!.trim().isNotEmpty)
          'imageUrl': imageUrl,
        'source': source,
        if (confidence != null) 'confidence': confidence,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory ScannedItemModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ScannedItemModel.fromMap(doc.id, data);
  }

  factory ScannedItemModel.fromMap(String id, Map<String, dynamic> map) {
    final now = DateTime.now();
    return ScannedItemModel(
      id: id,
      name: (map['name'] as String? ?? '').trim(),
      calories: (map['calories'] ?? 0).toInt(),
      price: (map['price'] ?? 0).toDouble(),
      mealType: map['mealType'] as String? ?? 'snack',
      imageUrl: map['imageUrl'] as String?,
      source: map['source'] as String? ?? 'scanner',
      confidence: map['confidence'] == null
          ? null
          : (map['confidence'] as num).toDouble(),
      createdAt: _dateFromAny(map['createdAt']) ?? now,
      updatedAt: _dateFromAny(map['updatedAt']) ?? now,
    );
  }

  static DateTime? _dateFromAny(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
