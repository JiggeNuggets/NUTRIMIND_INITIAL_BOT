/// Maps meal names to bundled local `.jpg` asset images.
///
/// The resolver is intentionally conservative: exact matches win, keyword
/// matches are limited to defensible local category fallbacks, and foods with
/// no trustworthy bundled image return null so callers can show a placeholder.
class FoodImageResolver {
  FoodImageResolver._();

  static const String basePath = 'assets/images/food/';

  static bool isLocalFoodAsset(String? value) {
    final trimmed = value?.trim();
    return trimmed != null && trimmed.startsWith(basePath);
  }

  static String? resolve(String? mealName) {
    if (mealName == null) return null;
    final normalized = _normalize(mealName);
    if (normalized.isEmpty) return null;

    final exact = _exactMatches[normalized];
    if (exact != null) return '$basePath$exact';

    for (final entry in _keywordMatches.entries) {
      if (normalized.contains(entry.key)) {
        return '$basePath${entry.value}';
      }
    }
    return null;
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static const Map<String, String> _exactMatches = {
    // Exact or close local dish matches.
    'arroz caldo': 'arroz_caldo.jpg',
    'lugaw': 'arroz_caldo.jpg',
    'champorado': 'champorado.jpg',
    'chicken adobo': 'chicken_adobo.jpg',
    'adobo manok': 'chicken_adobo.jpg',
    'classic adobo': 'chicken_adobo.jpg',
    'adobo': 'chicken_adobo.jpg',
    'tinolang manok': 'tinola_manok.jpg',
    'tinola manok': 'tinola_manok.jpg',
    'tinola': 'tinola_manok.jpg',
    'monggo soup': 'monggo_soup.jpg',
    'monggo with malunggay': 'monggo_soup.jpg',
    'ginisang monggo': 'monggo_soup.jpg',
    'mung bean soup': 'monggo_soup.jpg',
    'monggo': 'monggo_soup.jpg',
    'vegetable soup': 'monggo_soup.jpg',
    'malunggay soup': 'monggo_soup.jpg',
    'malunggay egg drop soup': 'monggo_soup.jpg',
    'law-uy vegetable soup': 'monggo_soup.jpg',
    'utan bisaya': 'monggo_soup.jpg',
    'grilled fish': 'grilled_fish.jpg',
    'grilled tilapia': 'grilled_fish.jpg',
    'grilled tuna': 'grilled_fish.jpg',
    'grilled tuna steak': 'grilled_fish.jpg',
    'inihaw na isda': 'grilled_fish.jpg',
    'fish rice meal': 'grilled_fish.jpg',
    'fish with rice': 'grilled_fish.jpg',
    'tuna with rice': 'grilled_fish.jpg',
    'sardines with rice': 'grilled_fish.jpg',
    'tinapa with rice': 'grilled_fish.jpg',
    'kinilaw na isda': 'grilled_fish.jpg',
    'bangus sinigang': 'bangus_sinigang.jpg',
    'sinigang na bangus': 'bangus_sinigang.jpg',
    'paksiw na bangus': 'bangus_sinigang.jpg',
    'sinigang': 'bangus_sinigang.jpg',
    'pinakbet': 'pinakbet.jpg',
    'pakbet': 'pinakbet.jpg',
    'ginisang gulay': 'pinakbet.jpg',
    'chopsuey': 'pinakbet.jpg',
    'tokwa with vegetables': 'pinakbet.jpg',
    'adobong kangkong with tokwa': 'pinakbet.jpg',
    'ginataang gulay': 'pinakbet.jpg',
    'tortang talong': 'tortang_talong.jpg',
    'eggplant omelette': 'tortang_talong.jpg',
    'tuna omelette': 'tuna_omelette.jpg',
    'tuna omelet': 'tuna_omelette.jpg',
    'tuna pandesal': 'tuna_omelette.jpg',
    'lumpiang sariwa': 'lumpiang_sariwa.jpg',
    'lumpia': 'lumpiang_sariwa.jpg',
    'pancit bihon': 'lumpiang_sariwa.jpg',
    'pork sisig': 'pork_sisig.jpg',
    'sisig': 'pork_sisig.jpg',
    'pork rice meal': 'pork_sisig.jpg',
    'pork adobo': 'pork_sisig.jpg',
    'pork adobo with rice': 'pork_sisig.jpg',
    'fried rice': 'fried_rice.jpg',
    'garlic fried rice': 'fried_rice.jpg',
    'malunggay fried rice': 'fried_rice.jpg',
    'sinangag': 'fried_rice.jpg',
    'rice and egg': 'fried_rice.jpg',
    'garlic rice with egg': 'fried_rice.jpg',
    'filipino egg breakfast plate': 'fried_rice.jpg',
    'grilled liempo': 'grilled_liempo.jpg',
    'inihaw na liempo': 'grilled_liempo.jpg',
    'liempo': 'grilled_liempo.jpg',

    // Conservative bowl/fruit fallbacks where no exact asset exists.
    'smoothie bowl': 'smoothie_bowl.jpg',
    'smoothie': 'smoothie_bowl.jpg',
    'durian smoothie': 'smoothie_bowl.jpg',
    'oatmeal with banana': 'smoothie_bowl.jpg',
    'banana and peanut butter': 'smoothie_bowl.jpg',
    'banana peanut snack bowl': 'smoothie_bowl.jpg',
    'healthy davao snack bowl': 'smoothie_bowl.jpg',
    'healthy davao fruit bowl': 'smoothie_bowl.jpg',
    'fruit cup': 'smoothie_bowl.jpg',
    'buko juice': 'smoothie_bowl.jpg',

    // Generic generated names with defensible local dish families.
    'davao filipino breakfast plate': 'fried_rice.jpg',
    'davao budget lunch plate': 'chicken_adobo.jpg',
    'home-style filipino dinner': 'tinola_manok.jpg',
  };

  static const Map<String, String> _keywordMatches = {
    'adobo': 'chicken_adobo.jpg',
    'sinigang': 'bangus_sinigang.jpg',
    'paksiw': 'bangus_sinigang.jpg',
    'tinola': 'tinola_manok.jpg',
    'lugaw': 'arroz_caldo.jpg',
    'champorado': 'champorado.jpg',
    'pakbet': 'pinakbet.jpg',
    'pinakbet': 'pinakbet.jpg',
    'tortang talong': 'tortang_talong.jpg',
    'eggplant omelette': 'tortang_talong.jpg',
    'tuna omelette': 'tuna_omelette.jpg',
    'tuna omelet': 'tuna_omelette.jpg',
    'monggo': 'monggo_soup.jpg',
    'vegetable soup': 'monggo_soup.jpg',
    'malunggay soup': 'monggo_soup.jpg',
    'lumpia': 'lumpiang_sariwa.jpg',
    'sisig': 'pork_sisig.jpg',
    'fried rice': 'fried_rice.jpg',
    'sinangag': 'fried_rice.jpg',
    'liempo': 'grilled_liempo.jpg',
    'bangus': 'bangus_sinigang.jpg',
    'tilapia': 'grilled_fish.jpg',
    'sardine': 'grilled_fish.jpg',
    'tinapa': 'grilled_fish.jpg',
    'kinilaw': 'grilled_fish.jpg',
    'grilled fish': 'grilled_fish.jpg',
    'fish with rice': 'grilled_fish.jpg',
    'smoothie': 'smoothie_bowl.jpg',
    'fruit bowl': 'smoothie_bowl.jpg',
    'fruit cup': 'smoothie_bowl.jpg',
    'oatmeal with banana': 'smoothie_bowl.jpg',
  };
}
