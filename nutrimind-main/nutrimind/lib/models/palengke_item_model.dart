import 'package:cloud_firestore/cloud_firestore.dart';

class PalengkeItemModel {
  const PalengkeItemModel({
    required this.id,
    required this.name,
    required this.estimatedPricePhp,
    required this.marketCategory,
    required this.isBought,
    required this.sourceMealIds,
    required this.createdAt,
    this.normalizedName = '',
    this.priceSource = '',
    this.priceSourceType = 'prototype_estimate',
    this.lastVerifiedDate,
    this.isPrototypeEstimate = true,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String normalizedName;
  final double estimatedPricePhp;
  final String marketCategory;
  final bool isBought;
  final List<String> sourceMealIds;
  final DateTime createdAt;
  final String priceSource;
  final String priceSourceType;
  final DateTime? lastVerifiedDate;
  final bool isPrototypeEstimate;
  final DateTime? updatedAt;

  PalengkeItemModel copyWith({
    String? id,
    String? name,
    String? normalizedName,
    double? estimatedPricePhp,
    String? marketCategory,
    bool? isBought,
    List<String>? sourceMealIds,
    DateTime? createdAt,
    String? priceSource,
    String? priceSourceType,
    DateTime? lastVerifiedDate,
    bool? isPrototypeEstimate,
    DateTime? updatedAt,
  }) {
    return PalengkeItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      estimatedPricePhp: estimatedPricePhp ?? this.estimatedPricePhp,
      marketCategory: marketCategory ?? this.marketCategory,
      isBought: isBought ?? this.isBought,
      sourceMealIds: sourceMealIds ?? this.sourceMealIds,
      createdAt: createdAt ?? this.createdAt,
      priceSource: priceSource ?? this.priceSource,
      priceSourceType: priceSourceType ?? this.priceSourceType,
      lastVerifiedDate: lastVerifiedDate ?? this.lastVerifiedDate,
      isPrototypeEstimate: isPrototypeEstimate ?? this.isPrototypeEstimate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'normalizedName': normalizedName,
        'estimatedPricePhp': estimatedPricePhp,
        'marketCategory': marketCategory,
        'isBought': isBought,
        'sourceMealIds': sourceMealIds,
        'createdAt': Timestamp.fromDate(createdAt),
        'priceSource': priceSource,
        'priceSourceType': priceSourceType,
        if (lastVerifiedDate != null)
          'lastVerifiedDate': Timestamp.fromDate(lastVerifiedDate!),
        'isPrototypeEstimate': isPrototypeEstimate,
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      };

  factory PalengkeItemModel.fromMap(Map<String, dynamic> map) {
    return PalengkeItemModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      normalizedName: map['normalizedName'] as String? ?? '',
      estimatedPricePhp: (map['estimatedPricePhp'] as num?)?.toDouble() ?? 0,
      marketCategory: map['marketCategory'] as String? ?? '',
      isBought: map['isBought'] as bool? ?? false,
      sourceMealIds: List<String>.from(map['sourceMealIds'] as List? ?? []),
      createdAt: _dateFromAny(map['createdAt']) ?? DateTime.now(),
      priceSource: map['priceSource'] as String? ?? '',
      priceSourceType:
          map['priceSourceType'] as String? ?? 'prototype_estimate',
      lastVerifiedDate: _dateFromAny(map['lastVerifiedDate']),
      isPrototypeEstimate: map['isPrototypeEstimate'] as bool? ?? true,
      updatedAt: _dateFromAny(map['updatedAt']),
    );
  }

  static DateTime? _dateFromAny(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
