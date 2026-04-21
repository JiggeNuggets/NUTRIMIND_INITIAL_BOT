// Ported from AI-Meal-Planner `prompts.py` — used with Groq / OpenAI-compatible APIs.

class MealPlannerPrompts {
  MealPlannerPrompts._();

  static const String prePromptBreakfast =
      "I've got a basket full of breakfast items, and I'm looking for a mouthwatering morning meal. Your challenge: create a breakfast dish using most of these ingredients and give it a catchy name. Remember, breakfast sets the tone for the day! Here's the list of items for your culinary adventure:";

  static const String preBreakfast =
      "For breakfast, we have a delightful dish called 'Morning Glory Omelette.' Imagine a fluffy omelette packed with earthy mushrooms, colorful bell peppers, and a sprinkle of cheese. It's a sunrise on a plate, fueling you with energy and flavor. Now, it's your turn to craft a breakfast masterpiece from the list provided.";

  static const String prePromptLunch =
      "I've got a basket full of lunch ingredients, and I'm craving a delicious midday meal. Your task is to whip up a lunch dish using most of these ingredients and give it a mouthwatering name. Lunch should be both satisfying and nourishing. Here's the list of items for your culinary creativity:";

  static const String preLunch =
      "For lunch, we have an enticing creation called 'Garden Fresh Quinoa Salad.' Picture a vibrant salad with crisp greens, juicy tomatoes, and protein-packed quinoa. It's a burst of flavors and a healthy choice. Now, it's your turn to craft a lunch masterpiece from the list provided.";

  static const String prePromptDinner =
      "I've got a basket full of dinner ingredients, and I'm in the mood for a delectable evening meal. Your mission: create a dinner dish using most of these ingredients and give it an enticing name. Dinner should be a culinary adventure. Here's the list of items for your evening extravaganza:";

  static const String preDinner =
      "For dinner, we present a sensational dish known as 'Savory Spinach-Stuffed Chicken.' Envision tender chicken breasts stuffed with vibrant spinach and juicy tomatoes. It's a taste sensation that'll leave you craving more. Now, it's your turn to craft a dinner masterpiece from the list provided.";

  static const String negativePrompt =
      "Please exclude cooking instructions and limit your response to 100-150 words. I'm interested in the meal name, its ingredients, a brief description, and some nutritional insights. Let your culinary expertise shine!";

  static String exampleResponse(String name) =>
      "This is just an example but use your creativity: You can start with, Hello $name! I'm thrilled to be your meal planner for the day, and I've crafted a delightful and flavorful meal plan just for you. But fear not, this isn't your ordinary, run-of-the-mill meal plan. It's a culinary adventure designed to keep your taste buds excited while considering the calories you can intake. So, get ready!";

  static String userContentBreakfast({
    required String userName,
    required List<String> items,
  }) =>
      '${MealPlannerPrompts.prePromptBreakfast} $items '
      '${MealPlannerPrompts.exampleResponse(userName)} '
      '${MealPlannerPrompts.preBreakfast} '
      '${MealPlannerPrompts.negativePrompt}';

  static String userContentLunch({
    required String userName,
    required List<String> items,
  }) =>
      '${MealPlannerPrompts.prePromptLunch} $items '
      '${MealPlannerPrompts.exampleResponse(userName)} '
      '${MealPlannerPrompts.preLunch} '
      '${MealPlannerPrompts.negativePrompt}';

  static String userContentDinner({
    required String userName,
    required List<String> items,
  }) =>
      '${MealPlannerPrompts.prePromptDinner} $items '
      '${MealPlannerPrompts.exampleResponse(userName)} '
      '${MealPlannerPrompts.preDinner} '
      '${MealPlannerPrompts.negativePrompt}';
}
