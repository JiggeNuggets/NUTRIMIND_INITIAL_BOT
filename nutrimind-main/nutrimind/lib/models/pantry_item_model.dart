import 'package:cloud_firestore/cloud_firestore.dart';

class PantryItemModel {
  const PantryItemModel({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    this.source = 'manual',
    required this.isPalengkeItem,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final double quantity;
  final String unit;
  final String category;
  final String source;
  final bool isPalengkeItem;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'category': category,
        'source': source,
        'isPalengkeItem': isPalengkeItem,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory PantryItemModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PantryItemModel.fromMap(doc.id, data);
  }

  factory PantryItemModel.fromMap(String id, Map<String, dynamic> map) {
    final now = DateTime.now();
    return PantryItemModel(
      id: id,
      name: (map['name'] as String? ?? '').trim(),
      quantity: (map['quantity'] ?? 0).toDouble(),
      unit: map['unit'] as String? ?? 'pcs',
      category: map['category'] as String? ?? 'other',
      source: map['source'] as String? ?? 'manual',
      isPalengkeItem: map['isPalengkeItem'] as bool? ?? false,
      createdAt: _dateFromAny(map['createdAt']) ?? now,
      updatedAt: _dateFromAny(map['updatedAt']) ?? now,
    );
  }

  PantryItemModel copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    String? category,
    String? source,
    bool? isPalengkeItem,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PantryItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      source: source ?? this.source,
      isPalengkeItem: isPalengkeItem ?? this.isPalengkeItem,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _dateFromAny(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
