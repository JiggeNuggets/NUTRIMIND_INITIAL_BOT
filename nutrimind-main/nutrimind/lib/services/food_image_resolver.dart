/// Maps meal names to bundled local `.jpg` asset images.
///
/// Two-tier matching: an exact-name map (after normalization) handles known
/// aliases like "Chicken Adobo", "Adobo Manok", "Classic Adobo"; a keyword
/// map catches longer or freeform names like "Spicy Pork Sisig with Rice".
///
/// Returns `null` when nothing matches — callers (e.g. `SafeFoodImage`) fall
/// back to the network image or the placeholder icon.
class FoodImageResolver {
  FoodImageResolver._();

  static const String _basePath = 'assets/images/food/';

  static String? resolve(String? mealName) {
    if (mealName == null) return null;
    final normalized = _normalize(mealName);
    if (normalized.isEmpty) return null;

    final exact = _exactMatches[normalized];
    if (exact != null) return '$_basePath$exact';

    for (final entry in _keywordMatches.entries) {
      if (normalized.contains(entry.key)) {
        return '$_basePath${entry.value}';
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
    // chicken_adobo
    'chicken adobo': 'chicken_adobo.jpg',
    'adobo manok': 'chicken_adobo.jpg',
    'classic adobo': 'chicken_adobo.jpg',
    'adobo': 'chicken_adobo.jpg',

    // bangus_sinigang
    'bangus sinigang': 'bangus_sinigang.jpg',
    'sinigang na bangus': 'bangus_sinigang.jpg',
    'paksiw na bangus': 'bangus_sinigang.jpg',
    'sinigang': 'bangus_sinigang.jpg',

    // tinola_manok
    'tinola manok': 'tinola_manok.jpg',
    'tinola': 'tinola_manok.jpg',

    // arroz_caldo
    'arroz caldo': 'arroz_caldo.jpg',
    'lugaw': 'arroz_caldo.jpg',
    'congee': 'arroz_caldo.jpg',

    // pinakbet
    'pinakbet': 'pinakbet.jpg',
    'pakbet': 'pinakbet.jpg',

    // tuna_omelette
    'tuna omelette': 'tuna_omelette.jpg',
    'tuna omelet': 'tuna_omelette.jpg',

    // tortang_talong
    'tortang talong': 'tortang_talong.jpg',
    'eggplant omelette': 'tortang_talong.jpg',

    // monggo_soup
    'monggo soup': 'monggo_soup.jpg',
    'mung bean soup': 'monggo_soup.jpg',
    'utan bisaya': 'monggo_soup.jpg',
    'monggo': 'monggo_soup.jpg',

    // lumpiang_sariwa
    'lumpiang sariwa': 'lumpiang_sariwa.jpg',
    'lumpia': 'lumpiang_sariwa.jpg',

    // champorado
    'champorado': 'champorado.jpg',
    'ginataang mais': 'champorado.jpg',
    'saba banana porridge': 'champorado.jpg',

    // pork_sisig
    'pork sisig': 'pork_sisig.jpg',
    'sisig': 'pork_sisig.jpg',

    // fried_rice
    'malunggay fried rice': 'fried_rice.jpg',
    'garlic fried rice': 'fried_rice.jpg',
    'fried rice': 'fried_rice.jpg',
    'sinangag': 'fried_rice.jpg',

    // grilled_liempo
    'grilled liempo': 'grilled_liempo.jpg',
    'inihaw na liempo': 'grilled_liempo.jpg',
    'liempo': 'grilled_liempo.jpg',

    // smoothie_bowl
    'durian smoothie': 'smoothie_bowl.jpg',
    'smoothie bowl': 'smoothie_bowl.jpg',
    'smoothie': 'smoothie_bowl.jpg',

    // grilled_fish
    'grilled tilapia': 'grilled_fish.jpg',
    'grilled tuna': 'grilled_fish.jpg',
    'grilled fish': 'grilled_fish.jpg',
    'inihaw na isda': 'grilled_fish.jpg',
    'fish rice meal': 'grilled_fish.jpg',
    'fish with rice': 'grilled_fish.jpg',

    // tuna
    'tuna with rice': 'grilled_fish.jpg',
    'tuna pandesal': 'tuna_omelette.jpg',
    'grilled tuna steak': 'grilled_fish.jpg',

    // chicken
    'chicken with rice': 'chicken_adobo.jpg',
    'chicken rice meal': 'chicken_adobo.jpg',
    'chicken afritada': 'chicken_adobo.jpg',
    'chicken inasal with rice': 'grilled_liempo.jpg',
    'grilled chicken': 'grilled_liempo.jpg',

    // pork
    'pork rice meal': 'pork_sisig.jpg',
    'pork adobo': 'pork_sisig.jpg',
    'pork adobo with rice': 'pork_sisig.jpg',

    // egg
    'rice and egg': 'fried_rice.jpg',
    'garlic rice with egg': 'fried_rice.jpg',
    'filipino egg breakfast plate': 'fried_rice.jpg',
    'boiled egg': 'tuna_omelette.jpg',

    // monggo
    'ginisang monggo': 'monggo_soup.jpg',
    'monggo with malunggay': 'monggo_soup.jpg',

    // vegetables
    'ginisang gulay': 'pinakbet.jpg',
    'chopsuey': 'pinakbet.jpg',
    'tokwa with vegetables': 'pinakbet.jpg',
    'adobong kangkong with tokwa': 'pinakbet.jpg',
    'law-uy vegetable soup': 'monggo_soup.jpg',

    // other dishes
    'sardines with rice': 'grilled_fish.jpg',
    'sayote with sardines': 'grilled_fish.jpg',
    'pancit bihon': 'lumpiang_sariwa.jpg',
    'kinilaw na isda': 'grilled_fish.jpg',
    'fish tinola': 'tinola_manok.jpg',
    'beef nilaga': 'tinola_manok.jpg',
    'ginataang gulay': 'pinakbet.jpg',
    'tinapa with rice': 'grilled_fish.jpg',
    'malunggay soup': 'monggo_soup.jpg',
    'malunggay egg drop soup': 'monggo_soup.jpg',
    'vegetable soup': 'monggo_soup.jpg',
    'oatmeal with banana': 'smoothie_bowl.jpg',
    'banana and peanut butter': 'smoothie_bowl.jpg',
    'pandesal with peanut butter': 'champorado.jpg',
    'boiled saba': 'champorado.jpg',

    // snacks
    'banana peanut snack bowl': 'smoothie_bowl.jpg',
    'healthy davao snack bowl': 'smoothie_bowl.jpg',
    'healthy davao fruit bowl': 'smoothie_bowl.jpg',
    'peanut butter sandwich': 'champorado.jpg',
    'kamote snack': 'champorado.jpg',
    'boiled saba snack': 'champorado.jpg',
    'cassava cake': 'champorado.jpg',
    'turon': 'champorado.jpg',
    'maruya': 'champorado.jpg',
    'fruit cup': 'smoothie_bowl.jpg',
    'buko juice': 'smoothie_bowl.jpg',

    // fallback plate names
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
    'porridge': 'arroz_caldo.jpg',
    'pakbet': 'pinakbet.jpg',
    'omelette': 'tuna_omelette.jpg',
    'omelet': 'tuna_omelette.jpg',
    'torta': 'tortang_talong.jpg',
    'monggo': 'monggo_soup.jpg',
    'lumpia': 'lumpiang_sariwa.jpg',
    'sisig': 'pork_sisig.jpg',
    'fried rice': 'fried_rice.jpg',
    'sinangag': 'fried_rice.jpg',
    'liempo': 'grilled_liempo.jpg',
    'pork belly': 'grilled_liempo.jpg',
    'tilapia': 'grilled_fish.jpg',
    'inihaw': 'grilled_fish.jpg',
    'smoothie': 'smoothie_bowl.jpg',
    'fruit bowl': 'smoothie_bowl.jpg',
    'bangus': 'bangus_sinigang.jpg',
    'sardine': 'grilled_fish.jpg',
    'inasal': 'grilled_liempo.jpg',
    'afritada': 'chicken_adobo.jpg',
    'nilaga': 'tinola_manok.jpg',
    'ginataan': 'pinakbet.jpg',
    'kinilaw': 'grilled_fish.jpg',
    'pancit': 'lumpiang_sariwa.jpg',
    'kamote': 'champorado.jpg',
    'cassava': 'champorado.jpg',
    'turon': 'champorado.jpg',
    'maruya': 'champorado.jpg',
    'taho': 'champorado.jpg',
  };
}
