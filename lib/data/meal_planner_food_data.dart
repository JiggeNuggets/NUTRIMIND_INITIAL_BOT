// Ported from AI-Meal-Planner `data.py` — calorie values per typical serving (kcal).

class MealPlannerFoodData {
  MealPlannerFoodData._();

  /// Breakfast groups → item → calories
  static const Map<String, Map<String, int>> breakfast = {
    'protein': {
      'eggs': 78,
      'greek_yogurt': 130,
      'cottage_cheese': 206,
      'turkey_slices': 104,
      'smoked_salmon': 117,
    },
    'whole_grains': {
      'whole_wheat_bread': 79,
      'oatmeal': 150,
      'quinoa': 222,
      'whole_grain_cereal': 120,
      'granola': 494,
    },
    'fruits': {
      'berries': 50,
      'bananas': 96,
      'apples': 52,
      'oranges': 62,
      'grapefruit': 52,
      'melon_slices': 30,
    },
    'vegetables': {
      'spinach': 7,
      'tomatoes': 18,
      'avocado': 160,
      'bell_peppers': 25,
      'mushrooms': 15,
    },
    'healthy_fats': {
      'nut_butter': 94,
      'nuts': 163,
      'chia_seeds': 58,
      'flaxseeds': 55,
      'avocado_slices': 50,
    },
    'dairy': {
      'milk': 103,
      'cheese': 113,
      'yogurt': 150,
      'dairy-free_alternatives': 80,
    },
    'other': {
      'honey': 64,
      'maple_syrup': 52,
      'coffee': 2,
      'jam': 49,
      'peanut_butter': 188,
      'cocoa_powder': 12,
    },
  };

  static const Map<String, Map<String, int>> lunch = {
    'protein': {
      'grilled_chicken_breast': 165,
      'salmon_fillet': 206,
      'tofu': 144,
      'lean_beef': 176,
      'shrimp': 99,
    },
    'whole_grains': {
      'brown_rice': 216,
      'quinoa': 222,
      'whole_wheat_pasta': 180,
      'barley': 270,
      'couscous': 176,
    },
    'vegetables': {
      'leafy_greens': 10,
      'broccoli': 55,
      'cauliflower': 25,
      'carrots': 41,
      'bell_peppers': 31,
      'cucumbers': 16,
      'tomatoes': 18,
      'zucchini': 17,
    },
    'legumes': {
      'chickpeas': 269,
      'lentils': 230,
      'black_beans': 227,
      'kidney_beans': 225,
      'edamame': 121,
    },
    'healthy_fats': {
      'avocado': 234,
      'nuts': 160,
      'seeds': 160,
      'olive_oil': 119,
      'coconut_oil': 121,
    },
    'dairy_or_dairy_alternatives': {
      'greek_yogurt': 130,
      'cottage_cheese': 206,
      'cheese': 113,
      'dairy-free_alternatives': 80,
    },
    'additional_toppings_condiments': {
      'sliced_avocado': 50,
      'hummus': 27,
      'salsa': 20,
      'salad_dressings': 73,
      'herbs_and_spices': 0,
    },
  };

  static const Map<String, Map<String, int>> dinner = {
    'proteins': {
      'chicken_breast': 165,
      'salmon': 206,
      'beef_steak': 250,
      'tofu': 144,
      'shrimp': 84,
      'lentils': 116,
    },
    'grains_and_starches': {
      'brown_rice': 216,
      'quinoa': 222,
      'sweet_potatoes': 180,
      'whole_wheat_pasta': 174,
      'couscous': 176,
      'barley': 193,
    },
    'vegetables': {
      'broccoli': 55,
      'cauliflower': 25,
      'green_beans': 31,
      'asparagus': 27,
      'brussels_sprouts': 38,
      'carrots': 41,
      'zucchini': 17,
    },
    'legumes': {
      'black_beans': 227,
      'chickpeas': 269,
      'kidney_beans': 333,
      'lentils': 353,
    },
    'healthy_fats': {
      'avocado': 160,
      'olive_oil': 119,
      'nuts': 160,
      'seeds': 150,
    },
    'dairy_or_dairy_alternatives': {
      'greek_yogurt': 59,
      'cheese': 113,
      'almond_milk': 40,
    },
    'sauces_and_condiments': {
      'tomato_sauce': 32,
      'soy_sauce': 8,
      'balsamic_vinegar': 14,
      'mustard': 10,
      'salsa': 15,
      'guacamole': 50,
      'hummus': 27,
    },
    'herbs_and_spices': {
      'basil': 22,
      'oregano': 5,
      'rosemary': 2,
      'thyme': 3,
      'cumin': 22,
      'paprika': 20,
      'garlic_powder': 9,
      'onion_powder': 7,
    },
  };

  static List<String> breakfastGroupKeys() => breakfast.keys.toList()..sort();

  /// All category keys across breakfast / lunch / dinner (for allergy exclusions).
  static List<String> allGroupKeys() {
    final s = <String>{
      ...breakfast.keys,
      ...lunch.keys,
      ...dinner.keys,
    };
    final list = s.toList()..sort();
    return list;
  }

  // ==========================================
  // FOOD-101 DATASET INTEGRATION
  // ==========================================
  // Auto-generated from Food-101 dataset with estimated calorie values per serving
  static const Map<String, int> food101Categories = {
    'apple_pie': 400,
    'baby_back_ribs': 650,
    'baklava': 350,
    'beef_carpaccio': 250,
    'beef_tartare': 300,
    'beet_salad': 150,
    'beignets': 450,
    'bibimbap': 550,
    'bread_pudding': 380,
    'breakfast_burrito': 480,
    'bruschetta': 180,
    'caesar_salad': 220,
    'cannoli': 320,
    'caprese_salad': 280,
    'carrot_cake': 420,
    'ceviche': 200,
    'cheese_plate': 380,
    'cheesecake': 360,
    'chicken_curry': 450,
    'chicken_quesadilla': 520,
    'chicken_wings': 380,
    'chocolate_cake': 440,
    'chocolate_mousse': 290,
    'churros': 340,
    'clam_chowder': 320,
    'club_sandwich': 480,
    'crab_cakes': 350,
    'creme_brulee': 310,
    'croque_madame': 430,
    'cup_cakes': 280,
    'deviled_eggs': 160,
    'donuts': 300,
    'dumplings': 280,
    'edamame': 120,
    'eggs_benedict': 420,
    'escargots': 180,
    'falafel': 330,
    'filet_mignon': 380,
    'fish_and_chips': 580,
    'foie_gras': 280,
    'french_fries': 320,
    'french_onion_soup': 290,
    'french_toast': 350,
    'fried_calamari': 360,
    'fried_rice': 420,
    'frozen_yogurt': 150,
    'garlic_bread': 220,
    'gnocchi': 380,
    'greek_salad': 240,
    'grilled_cheese_sandwich': 380,
    'grilled_salmon': 320,
    'guacamole': 160,
    'gyoza': 250,
    'hamburger': 550,
    'hot_and_sour_soup': 180,
    'hot_dog': 480,
    'huevos_rancheros': 420,
    'hummus': 160,
    'ice_cream': 270,
    'lasagna': 480,
    'lobster_bisque': 340,
    'lobster_roll_sandwich': 420,
    'macaroni_and_cheese': 450,
    'macarons': 280,
    'miso_soup': 80,
    'mussels': 220,
    'nachos': 520,
    'omelette': 280,
    'onion_rings': 380,
    'oysters': 120,
    'pad_thai': 480,
    'paella': 450,
    'pancakes': 320,
    'panna_cotta': 250,
    'peking_duck': 380,
    'pho': 320,
    'pizza': 600,
    'pork_chop': 340,
    'poutine': 480,
    'prime_rib': 420,
    'pulled_pork_sandwich': 480,
    'ramen': 380,
    'ravioli': 360,
    'red_velvet_cake': 420,
    'risotto': 380,
    'samosa': 260,
    'sashimi': 180,
    'scallops': 240,
    'seaweed_salad': 90,
    'shrimp_and_grits': 420,
    'spaghetti_bolognese': 480,
    'spaghetti_carbonara': 520,
    'spring_rolls': 220,
    'steak': 380,
    'strawberry_shortcake': 320,
    'sushi': 280,
    'tacos': 380,
    'takoyaki': 280,
    'tiramisu': 340,
    'tuna_tartare': 220,
    'waffles': 310,
  };

  /// Get all food items including Food-101 categories
  static Map<String, int> getAllFoodItems() {
    final allItems = <String, int>{};

    // Add breakfast items
    for (final group in breakfast.values) {
      allItems.addAll(group);
    }

    // Add lunch items
    for (final group in lunch.values) {
      allItems.addAll(group);
    }

    // Add dinner items
    for (final group in dinner.values) {
      allItems.addAll(group);
    }

    // Add Food-101 categories
    allItems.addAll(food101Categories);

    return allItems;
  }

  /// Get total number of food items available
  static int get totalFoodItems => getAllFoodItems().length;
}
