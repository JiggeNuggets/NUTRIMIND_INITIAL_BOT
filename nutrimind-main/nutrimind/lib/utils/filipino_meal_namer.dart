/// Generates descriptive Filipino/Davao meal names from basket food items.
///
/// Instead of generic labels like "AI Breakfast", this produces names such as
/// "Chicken Adobo with Rice" or "Tinolang Manok Bowl" based on the actual
/// food items selected by the planner.
class FilipinoMealNamer {
  FilipinoMealNamer._();

  /// Build a descriptive meal name from a list of [itemNames] and a
  /// [slotLabel] (Breakfast / Lunch / Dinner / Snack).
  ///
  /// Returns a human-friendly Filipino meal name, never "AI Breakfast" etc.
  static String nameFromItems(List<String> itemNames, String slotLabel) {
    if (itemNames.isEmpty) return _fallback(slotLabel);

    final normalized = itemNames.map(_norm).toList();

    // 1. Check for a known Filipino dish name among the items.
    for (final item in itemNames) {
      final n = _norm(item);
      final known = _knownDishMap[n];
      if (known != null) return known;
    }

    // 2. Try ingredient-pair matching for composite names.
    final composite = _tryComposite(normalized, itemNames, slotLabel);
    if (composite != null) return composite;

    // 3. Use the most calorie-significant / longest-named item as the hero.
    final hero = _bestHero(itemNames);
    if (hero != null) {
      final hasRice = normalized.any((n) => n.contains('rice'));
      if (hasRice && !_norm(hero).contains('rice')) {
        return '$hero with Rice';
      }
      return hero;
    }

    return _fallback(slotLabel);
  }

  // ─── helpers ──────────────────────────────────────────────────────

  static String _norm(String s) => s.toLowerCase().trim().replaceAll('_', ' ');

  static String? _bestHero(List<String> items) {
    if (items.isEmpty) return null;
    // Prefer multi-word items (they're usually the main dish).
    final sorted = List<String>.from(items)
      ..sort((a, b) => b.split(' ').length.compareTo(a.split(' ').length));
    final best = sorted.first;
    // Title-case.
    return best
        .split(' ')
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  static String _fallback(String slotLabel) {
    return switch (slotLabel.toLowerCase()) {
      'breakfast' => 'Davao Filipino Breakfast Plate',
      'lunch' => 'Davao Budget Lunch Plate',
      'dinner' => 'Home-Style Filipino Dinner',
      'snack' => 'Healthy Davao Snack Bowl',
      _ => 'Filipino Meal Plate',
    };
  }

  static String? _tryComposite(
    List<String> normalized,
    List<String> original,
    String slotLabel,
  ) {
    final all = normalized.join(' ');

    // chicken + rice combos
    if (all.contains('chicken') && all.contains('rice')) {
      if (all.contains('adobo')) return 'Chicken Adobo with Rice';
      if (all.contains('inasal')) return 'Chicken Inasal with Rice';
      if (all.contains('tinola')) return 'Tinolang Manok with Rice';
      return 'Chicken Rice Meal';
    }
    // fish combos
    if ((all.contains('fish') || all.contains('bangus') || all.contains('tilapia') || all.contains('tuna')) &&
        all.contains('rice')) {
      if (all.contains('bangus') || all.contains('sinigang')) {
        return 'Grilled Bangus with Rice';
      }
      if (all.contains('tuna')) return 'Tuna with Rice';
      if (all.contains('tilapia')) return 'Grilled Tilapia with Rice';
      return 'Fish Rice Meal';
    }
    // pork combos
    if (all.contains('pork') && all.contains('rice')) {
      if (all.contains('adobo')) return 'Pork Adobo with Rice';
      if (all.contains('sisig')) return 'Pork Sisig Rice Bowl';
      return 'Pork Rice Meal';
    }
    // egg combos
    if (all.contains('egg') && all.contains('rice')) {
      if (all.contains('garlic')) return 'Garlic Rice with Egg';
      return 'Filipino Egg Breakfast Plate';
    }
    if (all.contains('egg') && all.contains('talong')) {
      return 'Tortang Talong';
    }
    if (all.contains('egg') && all.contains('tuna')) {
      return 'Tuna Omelette';
    }
    // monggo
    if (all.contains('monggo') || all.contains('mung')) {
      return 'Ginisang Monggo';
    }
    // vegetables heavy
    if (all.contains('pinakbet') || all.contains('pakbet')) {
      return 'Pinakbet Plate';
    }
    if (all.contains('kangkong') ||
        all.contains('pechay') ||
        all.contains('sayote') ||
        all.contains('vegetable')) {
      if (all.contains('tokwa') || all.contains('tofu')) {
        return 'Tokwa with Vegetables';
      }
      return 'Ginisang Gulay';
    }
    // soup
    if (all.contains('soup') && all.contains('chicken')) {
      return 'Tinolang Manok';
    }
    if (all.contains('tinola')) return 'Tinolang Manok';
    if (all.contains('sinigang')) return 'Sinigang na Bangus';
    if (all.contains('nilaga')) return 'Beef Nilaga';

    // snack combos
    if (all.contains('banana') && all.contains('peanut')) {
      return 'Banana Peanut Snack Bowl';
    }
    if (all.contains('smoothie') || all.contains('fruit')) {
      if (slotLabel.toLowerCase() == 'snack') {
        return 'Healthy Davao Fruit Bowl';
      }
    }
    if (all.contains('pandesal') && all.contains('tuna')) {
      return 'Tuna Pandesal';
    }
    if (all.contains('pandesal') && all.contains('peanut')) {
      return 'Pandesal with Peanut Butter';
    }
    // porridge
    if (all.contains('arroz caldo') || all.contains('lugaw')) {
      return 'Arroz Caldo';
    }
    if (all.contains('champorado')) return 'Champorado';
    if (all.contains('oatmeal')) return 'Oatmeal with Banana';
    if (all.contains('taho')) return 'Taho';
    if (all.contains('tinapa')) return 'Tinapa with Rice';
    if (all.contains('sardine') && all.contains('rice')) {
      return 'Sardines with Rice';
    }

    return null;
  }

  /// Map of normalized item names/ids → proper Filipino dish name.
  static const Map<String, String> _knownDishMap = {
    // breakfast
    'rice and egg': 'Rice and Egg',
    'rice_and_egg': 'Rice and Egg',
    'tuna pandesal': 'Tuna Pandesal',
    'tuna_pandesal': 'Tuna Pandesal',
    'garlic rice with egg': 'Garlic Rice with Egg',
    'garlic_rice_with_egg': 'Garlic Rice with Egg',
    'banana and peanut butter': 'Banana and Peanut Butter',
    'banana_and_peanut_butter': 'Banana and Peanut Butter',
    'arroz caldo': 'Arroz Caldo',
    'arroz_caldo': 'Arroz Caldo',
    'pandesal with peanut butter': 'Pandesal with Peanut Butter',
    'pandesal_with_peanut_butter': 'Pandesal with Peanut Butter',
    'tinapa with rice': 'Tinapa with Rice',
    'tinapa_with_rice': 'Tinapa with Rice',
    'oatmeal with banana': 'Oatmeal with Banana',
    'oatmeal_with_banana': 'Oatmeal with Banana',
    'malunggay egg drop soup': 'Malunggay Egg Drop Soup',
    'malunggay_egg_drop_soup': 'Malunggay Egg Drop Soup',
    'boiled saba': 'Boiled Saba',
    'boiled_saba_breakfast': 'Boiled Saba',
    'champorado': 'Champorado',
    'lugaw': 'Lugaw',
    'taho': 'Taho',
    'taho small': 'Taho',
    'taho_small': 'Taho',
    'pandesal': 'Pandesal',
    'boiled egg': 'Boiled Egg',
    'boiled_egg': 'Boiled Egg',

    // lunch
    'chicken adobo': 'Chicken Adobo',
    'chicken_adobo': 'Chicken Adobo',
    'pork adobo': 'Pork Adobo',
    'pork_adobo': 'Pork Adobo',
    'tinolang manok': 'Tinolang Manok',
    'tinolang_manok': 'Tinolang Manok',
    'monggo with malunggay': 'Monggo with Malunggay',
    'monggo_with_malunggay': 'Monggo with Malunggay',
    'grilled fish': 'Grilled Fish',
    'grilled_fish': 'Grilled Fish',
    'fried fish': 'Fried Fish',
    'fried_fish': 'Fried Fish',
    'paksiw na isda': 'Paksiw na Isda',
    'paksiw_na_isda': 'Paksiw na Isda',
    'ginisang gulay': 'Ginisang Gulay',
    'ginisang_gulay': 'Ginisang Gulay',
    'tortang talong': 'Tortang Talong',
    'tortang_talong': 'Tortang Talong',
    'chicken with rice': 'Chicken with Rice',
    'chicken_with_rice': 'Chicken with Rice',
    'tuna with rice': 'Tuna with Rice',
    'tuna_with_rice': 'Tuna with Rice',
    'tokwa with vegetables': 'Tokwa with Vegetables',
    'tokwa_with_vegetables': 'Tokwa with Vegetables',
    'pinakbet': 'Pinakbet',
    'sinigang na bangus': 'Sinigang na Bangus',
    'sinigang_na_bangus': 'Sinigang na Bangus',
    'grilled chicken': 'Grilled Chicken',
    'grilled_chicken': 'Grilled Chicken',
    'vegetable soup': 'Vegetable Soup',
    'vegetable_soup': 'Vegetable Soup',
    'sardines with rice': 'Sardines with Rice',
    'sardines_with_rice': 'Sardines with Rice',
    'eggplant omelette': 'Eggplant Omelette',
    'eggplant_omelette': 'Eggplant Omelette',
    'malunggay soup': 'Malunggay Soup',
    'malunggay_soup': 'Malunggay Soup',
    'fish with rice': 'Fish with Rice',
    'fish_with_rice': 'Fish with Rice',
    'grilled tuna steak': 'Grilled Tuna Steak',
    'grilled_tuna_steak': 'Grilled Tuna Steak',
    'chopsuey': 'Chopsuey',
    'kinilaw na isda': 'Kinilaw na Isda',
    'kinilaw_na_isda': 'Kinilaw na Isda',
    'pancit bihon': 'Pancit Bihon',
    'pancit_bihon': 'Pancit Bihon',

    // dinner
    'chicken adobo dinner': 'Chicken Adobo',
    'chicken_adobo_dinner': 'Chicken Adobo',
    'pork adobo dinner': 'Pork Adobo',
    'pork_adobo_dinner': 'Pork Adobo',
    'tinolang manok dinner': 'Tinolang Manok',
    'tinolang_manok_dinner': 'Tinolang Manok',
    'monggo with malunggay dinner': 'Monggo with Malunggay',
    'monggo_with_malunggay_dinner': 'Monggo with Malunggay',
    'paksiw na isda dinner': 'Paksiw na Isda',
    'paksiw_na_isda_dinner': 'Paksiw na Isda',
    'ginisang gulay dinner': 'Ginisang Gulay',
    'ginisang_gulay_dinner': 'Ginisang Gulay',
    'tortang talong dinner': 'Tortang Talong',
    'tortang_talong_dinner': 'Tortang Talong',
    'tokwa with vegetables dinner': 'Tokwa with Vegetables',
    'tokwa_with_vegetables_dinner': 'Tokwa with Vegetables',
    'pinakbet dinner': 'Pinakbet',
    'pinakbet_dinner': 'Pinakbet',
    'sinigang na bangus dinner': 'Sinigang na Bangus',
    'sinigang_na_bangus_dinner': 'Sinigang na Bangus',
    'vegetable soup dinner': 'Vegetable Soup',
    'vegetable_soup_dinner': 'Vegetable Soup',
    'sardines with rice dinner': 'Sardines with Rice',
    'sardines_with_rice_dinner': 'Sardines with Rice',
    'malunggay soup dinner': 'Malunggay Soup',
    'malunggay_soup_dinner': 'Malunggay Soup',
    'fish with rice dinner': 'Fish with Rice',
    'fish_with_rice_dinner': 'Fish with Rice',
    'fish tinola': 'Fish Tinola',
    'fish_tinola': 'Fish Tinola',
    'chicken afritada': 'Chicken Afritada',
    'chicken_afritada': 'Chicken Afritada',
    'ginataang gulay': 'Ginataang Gulay',
    'ginataang_gulay': 'Ginataang Gulay',
    'beef nilaga': 'Beef Nilaga',
    'beef_nilaga': 'Beef Nilaga',
    'adobong kangkong with tokwa': 'Adobong Kangkong with Tokwa',
    'adobong_kangkong_with_tokwa': 'Adobong Kangkong with Tokwa',
    'chicken inasal with rice': 'Chicken Inasal with Rice',
    'chicken_inasal_with_rice': 'Chicken Inasal with Rice',
    'sayote with sardines': 'Sayote with Sardines',
    'sayote_with_sardines': 'Sayote with Sardines',
    'grilled bangus with rice': 'Grilled Bangus with Rice',
    'grilled_bangus_with_rice': 'Grilled Bangus with Rice',
    'law uy vegetable soup': 'Law-uy Vegetable Soup',
    'law_uy_vegetable_soup': 'Law-uy Vegetable Soup',
    'utan bisaya': 'Utan Bisaya',
    'utan_bisaya': 'Utan Bisaya',

    // snacks
    'banana': 'Banana Snack',
    'kamote snack': 'Kamote Snack',
    'kamote_snack': 'Kamote Snack',
    'boiled saba snack': 'Boiled Saba Snack',
    'boiled_saba_snack': 'Boiled Saba Snack',
    'boiled egg snack': 'Boiled Egg Snack',
    'boiled_egg_snack': 'Boiled Egg Snack',
    'corn': 'Sweet Corn Snack',
    'peanuts snack': 'Peanuts Snack',
    'peanuts_snack': 'Peanuts Snack',
    'yogurt snack': 'Yogurt Snack',
    'yogurt_snack': 'Yogurt Snack',
    'fruit cup': 'Fruit Cup',
    'fruit_cup': 'Fruit Cup',
    'pandesal snack': 'Pandesal Snack',
    'pandesal_snack': 'Pandesal Snack',
    'peanut butter sandwich': 'Peanut Butter Sandwich',
    'peanut_butter_sandwich': 'Peanut Butter Sandwich',
    'buko juice': 'Buko Juice',
    'buko_juice': 'Buko Juice',
    'turon': 'Turon',
    'maruya': 'Maruya',
    'pomelo slices': 'Pomelo Slices',
    'pomelo_slices': 'Pomelo Slices',
    'cassava cake small': 'Cassava Cake',
    'cassava_cake_small': 'Cassava Cake',
    'taho snack': 'Taho',
    'taho_snack': 'Taho',
  };
}
