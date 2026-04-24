import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/meal_model.dart';
import '../models/palengke_item_model.dart';

class PalengkeService {
  PalengkeService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  static const publicMarket = 'Palengke / Public Market';
  static const supermarket = 'Supermarket';
  static const pantryItems = 'Pantry Items';

  static const marketCategories = [
    publicMarket,
    supermarket,
    pantryItems,
  ];

  static const prototypeDisclosure =
      'Palengke prices and categories are prototype estimates unless they come from Firestore market_prices or local_foods records with source/date metadata.';

  final FirebaseFirestore _db;
  final List<PalengkeItemModel> _items = [];
  final Map<String, _IngredientConfig> _ingredientConfigByName = {};
  final Map<String, String> _configAliasLookup = {};

  bool _marketConfigLoaded = false;
  String? _marketConfigError;
  String? _persistenceError;

  List<PalengkeItemModel> get items => List.unmodifiable(_items);
  bool get usingFirestoreMarketConfig => _ingredientConfigByName.isNotEmpty;
  bool get usesPrototypeEstimates =>
      _items.any((item) => item.isPrototypeEstimate);
  String? get marketConfigError => _marketConfigError;
  String? get persistenceError => _persistenceError;

  Future<void> loadMarketConfig({bool forceReload = false}) async {
    if (_marketConfigLoaded && !forceReload) return;

    _marketConfigLoaded = true;
    _marketConfigError = null;
    _ingredientConfigByName.clear();
    _configAliasLookup.clear();

    try {
      await _loadConfigCollection(
        collectionName: 'local_foods',
        fallbackSourceType: 'local_foods',
      );
      await _loadConfigCollection(
        collectionName: 'market_prices',
        fallbackSourceType: 'market_prices',
      );
    } catch (error) {
      _marketConfigError = error.toString();
      _ingredientConfigByName.clear();
      _configAliasLookup.clear();
    }
  }

  Future<List<PalengkeItemModel>> generateAndPersistWeeklyList({
    required String uid,
    required String weekId,
    required DateTime weekStart,
    required DateTime weekEnd,
    required List<MealModel> meals,
  }) async {
    _persistenceError = null;
    await loadMarketConfig();
    var savedItemsById = <String, PalengkeItemModel>{};
    if (uid.isNotEmpty) {
      try {
        savedItemsById = await _loadSavedItems(
          uid: uid,
          weekId: weekId,
        );
      } catch (error) {
        _persistenceError = error.toString();
      }
    }

    final generated = generateFromWeeklyMeals(
      meals,
      savedItemsById: savedItemsById,
    );

    if (uid.isNotEmpty) {
      try {
        await _persistWeeklyList(
          uid: uid,
          weekId: weekId,
          weekStart: weekStart,
          weekEnd: weekEnd,
        );
      } catch (error) {
        _persistenceError = error.toString();
      }
    }

    return generated;
  }

  List<PalengkeItemModel> generateFromWeeklyMeals(
    List<MealModel> meals, {
    Map<String, PalengkeItemModel> savedItemsById = const {},
  }) {
    final boughtState = {
      for (final item in _items) item.id: item.isBought,
      for (final item in savedItemsById.values) item.id: item.isBought,
    };
    final createdState = {
      for (final item in _items) item.id: item.createdAt,
      for (final item in savedItemsById.values) item.id: item.createdAt,
    };
    final sourceMealIdsByIngredient = <String, Set<String>>{};

    for (final meal in meals) {
      for (final ingredient in meal.ingredients) {
        final normalized = normalizeIngredientName(ingredient);
        if (normalized.isEmpty) continue;
        sourceMealIdsByIngredient
            .putIfAbsent(normalized, () => <String>{})
            .add(meal.id);
      }
    }

    final generated = sourceMealIdsByIngredient.entries.map((entry) {
      final id = _itemId(entry.key);
      final config = _ingredientConfigByName[entry.key];
      final hasConfiguredPrice =
          config != null && config.estimatedPricePhp != null;
      final estimatedPricePhp = hasConfiguredPrice
          ? config.estimatedPricePhp!
          : _prototypePrice(entry.key);
      final marketCategory =
          config?.marketCategory ?? _prototypeCategory(entry.key);
      final isPrototypeEstimate =
          hasConfiguredPrice ? config.isPrototypeEstimate : true;

      return PalengkeItemModel(
        id: id,
        name: _titleCase(entry.key),
        normalizedName: entry.key,
        estimatedPricePhp: estimatedPricePhp,
        marketCategory: marketCategory,
        isBought: boughtState[id] ?? false,
        sourceMealIds: entry.value.toList()..sort(),
        createdAt: createdState[id] ?? DateTime.now(),
        priceSource: hasConfiguredPrice
            ? config.source
            : 'NutriMind prototype Palengke fallback',
        priceSourceType:
            hasConfiguredPrice ? config.sourceType : 'prototype_estimate',
        lastVerifiedDate: hasConfiguredPrice ? config.lastVerifiedDate : null,
        isPrototypeEstimate: isPrototypeEstimate,
      );
    }).toList()
      ..sort((a, b) {
        final categoryCompare = marketCategories
            .indexOf(a.marketCategory)
            .compareTo(marketCategories.indexOf(b.marketCategory));
        if (categoryCompare != 0) return categoryCompare;
        return a.name.compareTo(b.name);
      });

    _items
      ..clear()
      ..addAll(generated);
    return items;
  }

  String normalizeIngredientName(String ingredient) {
    var normalized = _cleanIngredientName(ingredient);
    final configuredName = _configAliasLookup[normalized];
    if (configuredName != null) return configuredName;

    for (final entry in _prototypeAliases.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }

    normalized = normalized
        .replaceAll(
          RegExp(r'\b(fresh|chopped|minced|sliced|small|large)\b'),
          '',
        )
        .replaceAll(RegExp(r'\b(leaves|leaf|pieces|piece|cups|cup)\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return normalized;
  }

  double estimateIngredientPrice(String ingredient) {
    final normalized = normalizeIngredientName(ingredient);
    final configuredPrice =
        _ingredientConfigByName[normalized]?.estimatedPricePhp;
    return configuredPrice ?? _prototypePrice(normalized);
  }

  String categorizeIngredient(String ingredient) {
    final normalized = normalizeIngredientName(ingredient);
    return _ingredientConfigByName[normalized]?.marketCategory ??
        _prototypeCategory(normalized);
  }

  Future<void> toggleBought({
    required String uid,
    required String weekId,
    required String itemId,
  }) async {
    final idx = _items.indexWhere((item) => item.id == itemId);
    if (idx == -1) return;

    final updated = _items[idx].copyWith(
      isBought: !_items[idx].isBought,
      updatedAt: DateTime.now(),
    );
    _items[idx] = updated;

    if (uid.isNotEmpty) {
      await _persistBoughtState(uid, weekId, itemId, updated.isBought);
    }
  }

  Future<void> markAllAsBought({
    required String uid,
    required String weekId,
  }) async {
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(
        isBought: true,
        updatedAt: DateTime.now(),
      );
    }
    if (uid.isNotEmpty) {
      await _persistAllBoughtStates(uid, weekId);
    }
  }

  Future<void> resetBoughtItems({
    required String uid,
    required String weekId,
  }) async {
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(
        isBought: false,
        updatedAt: DateTime.now(),
      );
    }
    if (uid.isNotEmpty) {
      await _persistAllBoughtStates(uid, weekId);
    }
  }

  double calculateTotalCost() {
    return _items.fold(
      0,
      (total, item) => total + item.estimatedPricePhp,
    );
  }

  Future<void> _loadConfigCollection({
    required String collectionName,
    required String fallbackSourceType,
  }) async {
    final snapshot = await _db.collection(collectionName).limit(300).get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['isActive'] == false) continue;

      final config = _IngredientConfig.fromMap(
        id: doc.id,
        data: data,
        fallbackSourceType: fallbackSourceType,
      );
      if (config == null) continue;

      _ingredientConfigByName[config.normalizedName] = config;
      _configAliasLookup[config.normalizedName] = config.normalizedName;
      for (final alias in config.aliases) {
        _configAliasLookup[_cleanIngredientName(alias)] = config.normalizedName;
      }
    }
  }

  Future<Map<String, PalengkeItemModel>> _loadSavedItems({
    required String uid,
    required String weekId,
  }) async {
    final snapshot = await _weeklyListItems(uid, weekId).get();
    return {
      for (final doc in snapshot.docs)
        doc.id: PalengkeItemModel.fromMap(doc.data()),
    };
  }

  Future<void> _persistWeeklyList({
    required String uid,
    required String weekId,
    required DateTime weekStart,
    required DateTime weekEnd,
  }) async {
    final batch = _db.batch();
    final listDoc = _weeklyListDoc(uid, weekId);
    final boughtCount = _items.where((item) => item.isBought).length;

    batch.set(
      listDoc,
      {
        'weekId': weekId,
        'weekStart': Timestamp.fromDate(weekStart),
        'weekEnd': Timestamp.fromDate(weekEnd),
        'itemCount': _items.length,
        'boughtCount': boughtCount,
        'totalEstimatedPricePhp': calculateTotalCost(),
        'usesPrototypeEstimates': usesPrototypeEstimates,
        'usingFirestoreMarketConfig': usingFirestoreMarketConfig,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    for (final item in _items) {
      batch.set(
        _weeklyListItems(uid, weekId).doc(item.id),
        {
          ...item.toMap(),
          'weekId': weekId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> _persistBoughtState(
    String uid,
    String weekId,
    String itemId,
    bool isBought,
  ) async {
    await _weeklyListItems(uid, weekId).doc(itemId).set(
      {
        'isBought': isBought,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await _weeklyListDoc(uid, weekId).set(
      {
        'boughtCount': _items.where((item) => item.isBought).length,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _persistAllBoughtStates(String uid, String weekId) async {
    final batch = _db.batch();
    for (final item in _items) {
      batch.set(
        _weeklyListItems(uid, weekId).doc(item.id),
        {
          'isBought': item.isBought,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    batch.set(
      _weeklyListDoc(uid, weekId),
      {
        'boughtCount': _items.where((item) => item.isBought).length,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  DocumentReference<Map<String, dynamic>> _weeklyListDoc(
    String uid,
    String weekId,
  ) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('weekly_palengke_lists')
        .doc(weekId);
  }

  CollectionReference<Map<String, dynamic>> _weeklyListItems(
    String uid,
    String weekId,
  ) {
    return _weeklyListDoc(uid, weekId).collection('items');
  }

  String _itemId(String normalizedName) {
    return normalizedName
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _titleCase(String value) {
    return value
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _cleanIngredientName(String ingredient) {
    var normalized = ingredient.toLowerCase().trim();
    normalized = normalized.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }

  double _prototypePrice(String normalized) {
    return _prototypePrices[normalized] ??
        _fallbackPrice(_prototypeCategory(normalized));
  }

  String _prototypeCategory(String normalized) {
    if (_prototypePantryItems.contains(normalized)) return pantryItems;
    if (_prototypeSupermarketItems.contains(normalized)) return supermarket;
    if (_prototypePublicMarketItems.contains(normalized)) return publicMarket;
    return publicMarket;
  }

  double _fallbackPrice(String category) {
    return switch (category) {
      pantryItems => 15,
      supermarket => 35,
      publicMarket => 35,
      _ => 25,
    };
  }
}

class _IngredientConfig {
  const _IngredientConfig({
    required this.normalizedName,
    required this.aliases,
    required this.estimatedPricePhp,
    required this.marketCategory,
    required this.source,
    required this.sourceType,
    required this.lastVerifiedDate,
    required this.isPrototypeEstimate,
  });

  final String normalizedName;
  final List<String> aliases;
  final double? estimatedPricePhp;
  final String marketCategory;
  final String source;
  final String sourceType;
  final DateTime? lastVerifiedDate;
  final bool isPrototypeEstimate;

  static _IngredientConfig? fromMap({
    required String id,
    required Map<String, dynamic> data,
    required String fallbackSourceType,
  }) {
    final rawName = _stringValue(
          data,
          const ['normalizedName', 'ingredientName', 'name'],
        ) ??
        id;
    final normalizedName = _normalize(rawName);
    if (normalizedName.isEmpty) return null;

    final rawCategory = _stringValue(
      data,
      const ['marketCategory', 'palengkeCategory', 'category', 'tag'],
    );
    final price = _numValue(
      data,
      const [
        'estimatedPricePhp',
        'pricePhp',
        'price',
        'currentPricePhp',
        'averagePricePhp',
      ],
    );

    return _IngredientConfig(
      normalizedName: normalizedName,
      aliases: _stringListValue(data['aliases']),
      estimatedPricePhp: price == null || price <= 0 ? null : price,
      marketCategory: _marketCategoryFrom(rawCategory, normalizedName),
      source: _stringValue(data, const ['source', 'vendor', 'marketName']) ??
          fallbackSourceType,
      sourceType: _stringValue(data, const ['sourceType', 'dataSourceType']) ??
          fallbackSourceType,
      lastVerifiedDate: _dateFromAny(
        data['lastVerifiedDate'] ?? data['priceDate'] ?? data['updatedAt'],
      ),
      isPrototypeEstimate: data['isPrototypeEstimate'] as bool? ?? false,
    );
  }

  static String? _stringValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static double? _numValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = num.tryParse(value);
        if (parsed != null) return parsed.toDouble();
      }
    }
    return null;
  }

  static List<String> _stringListValue(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static DateTime? _dateFromAny(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String _marketCategoryFrom(String? rawCategory, String normalized) {
    final value = rawCategory?.trim().toLowerCase() ?? '';
    if (value == PalengkeService.publicMarket.toLowerCase() ||
        value == 'palengke' ||
        value == 'public market' ||
        value == 'wet market') {
      return PalengkeService.publicMarket;
    }
    if (value == PalengkeService.supermarket.toLowerCase() ||
        value == 'grocery' ||
        value == 'packaged') {
      return PalengkeService.supermarket;
    }
    if (value == PalengkeService.pantryItems.toLowerCase() ||
        value == 'pantry' ||
        value == 'condiment') {
      return PalengkeService.pantryItems;
    }
    if (_prototypePantryItems.contains(normalized)) {
      return PalengkeService.pantryItems;
    }
    if (_prototypeSupermarketItems.contains(normalized)) {
      return PalengkeService.supermarket;
    }
    return PalengkeService.publicMarket;
  }

  static String _normalize(String value) {
    var normalized = value.toLowerCase().trim();
    normalized = normalized.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }
}

const _prototypeAliases = <String, String>{
  'malunggay': 'malunggay',
  'moringa': 'malunggay',
  'water spinach': 'kangkong',
  'kangkong': 'kangkong',
  'bok choy': 'pechay',
  'pechay': 'pechay',
  'saba banana': 'saba banana',
  'banana': 'banana',
  'pomelo': 'pomelo',
  'durian': 'durian',
  'calamansi': 'calamansi',
  'tomato': 'tomato',
  'onion': 'onion',
  'garlic': 'garlic',
  'ginger': 'ginger',
  'rice washing': 'rice',
  'glutinous rice': 'glutinous rice',
  'brown rice': 'rice',
  'rice': 'rice',
  'cooking oil': 'cooking oil',
  'olive oil': 'cooking oil',
  'oil': 'cooking oil',
  'soy sauce': 'soy sauce',
  'toyo': 'soy sauce',
  'vinegar': 'vinegar',
  'fish sauce': 'fish sauce',
  'salt': 'salt',
  'black pepper': 'pepper',
  'pepper': 'pepper',
  'canned tuna': 'canned tuna',
  'tuna': 'tuna',
  'bangus': 'bangus',
  'milkfish': 'bangus',
  'fish': 'fish',
  'chicken': 'chicken',
  'pork': 'pork',
  'egg': 'egg',
  'eggs': 'egg',
  'tofu': 'tofu',
  'soy tofu': 'tofu',
  'monggo': 'monggo',
  'mung bean': 'monggo',
  'canned sardines': 'canned sardines',
  'sardines': 'canned sardines',
  'oats': 'oats',
  'yogurt': 'yogurt',
  'coconut milk': 'coconut milk',
  'milk': 'milk',
  'peanut butter': 'peanut butter',
  'pandesal': 'pandesal',
  'bread': 'bread',
  'flour': 'flour',
  'sugar': 'sugar',
  'honey': 'honey',
  'davao honey': 'honey',
  'corn': 'corn',
  'kamote': 'kamote',
  'cassava': 'cassava',
  'eggplant': 'eggplant',
  'sayote': 'sayote',
  'chayote': 'sayote',
};

const _prototypePrices = <String, double>{
  'malunggay': 10,
  'kangkong': 15,
  'pechay': 20,
  'sayote': 20,
  'eggplant': 18,
  'tomato': 12,
  'calamansi': 10,
  'banana': 15,
  'saba banana': 18,
  'pomelo': 35,
  'durian': 80,
  'kamote': 20,
  'corn': 20,
  'cassava': 25,
  'tuna': 55,
  'bangus': 70,
  'fish': 50,
  'chicken': 60,
  'pork': 70,
  'egg': 12,
  'tofu': 20,
  'monggo': 20,
  'rice': 30,
  'glutinous rice': 35,
  'garlic': 10,
  'onion': 12,
  'ginger': 8,
  'cooking oil': 20,
  'salt': 5,
  'pepper': 5,
  'soy sauce': 15,
  'vinegar': 10,
  'fish sauce': 15,
  'sugar': 10,
  'flour': 20,
  'honey': 25,
  'canned tuna': 35,
  'canned sardines': 28,
  'oats': 35,
  'yogurt': 35,
  'milk': 25,
  'coconut milk': 25,
  'peanut butter': 35,
  'pandesal': 8,
  'bread': 25,
};

const _prototypePantryItems = {
  'rice',
  'glutinous rice',
  'garlic',
  'onion',
  'ginger',
  'cooking oil',
  'salt',
  'pepper',
  'soy sauce',
  'vinegar',
  'fish sauce',
  'sugar',
  'flour',
  'honey',
};

const _prototypeSupermarketItems = {
  'canned tuna',
  'canned sardines',
  'oats',
  'yogurt',
  'milk',
  'coconut milk',
  'peanut butter',
  'pandesal',
  'bread',
};

const _prototypePublicMarketItems = {
  'malunggay',
  'kangkong',
  'pechay',
  'sayote',
  'eggplant',
  'tomato',
  'calamansi',
  'banana',
  'saba banana',
  'pomelo',
  'durian',
  'kamote',
  'corn',
  'cassava',
  'tuna',
  'bangus',
  'fish',
  'chicken',
  'pork',
  'egg',
  'tofu',
  'monggo',
};
