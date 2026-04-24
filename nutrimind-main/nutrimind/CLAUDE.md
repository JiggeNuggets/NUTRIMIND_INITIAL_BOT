# NutriMind — CLAUDE.md

## Project Overview
NutriMind is a Flutter nutrition & meal planning app for Davao City, Philippines. It uses Firebase for auth/storage, Groq (LLaMA) for AI features, and a knapsack algorithm for budget-optimized meal planning.

## Tech Stack
- **Flutter** (Dart) — cross-platform mobile/web
- **Firebase** — Auth (email + Google), Firestore (users, meals, posts)
- **Groq API** — LLaMA 3.3-70b for chat/narratives, LLaMA 3.2-11b-vision for food image analysis
- **Provider** — state management

## Architecture
```
lib/
├── main.dart                   # Firebase init, MultiProvider, AuthGate routing
├── theme/app_theme.dart        # All colors, spacing, typography constants
├── models/                     # Dart data models (Firestore-serializable)
├── providers/                  # ChangeNotifier state (Auth, Meal, Community)
├── services/                   # Firestore CRUD, Groq API, Meal Planner algorithm
├── screens/
│   ├── auth/                   # Login, Register, AuthGate
│   ├── onboarding/             # Splash, Biometrics, Goal selection
│   └── main/                   # 4-tab shell + ChatbotScreen
│       ├── main_shell.dart     # Bottom nav (Home/Log/Community/Profile) + NutriBot FAB
│       ├── home_screen.dart    # Today's meals (max 4), budget card
│       ├── meal_plan_screen.dart # Meal Log: weekly calendar, expandable recipe/steps
│       ├── profile_screen.dart  # BMI card, DSS settings, milestones
│       ├── ai_meal_planner_screen.dart  # BMR + knapsack/greedy optimizer
│       ├── chatbot_screen.dart  # NutriBot AI chat (Groq)
│       └── community_screen.dart
└── data/meal_planner_food_data.dart  # Food-101 calorie database
```

## Navigation Structure (4 tabs)
| Tab | Screen | Purpose |
|-----|--------|---------|
| Home | HomeScreen | Daily budget, today's 3-4 meals |
| Log | MealPlanScreen | Weekly meal log with recipe & cooking steps |
| Community | CommunityScreen | Posts, Q&A, Market Finds |
| Profile | ProfileScreen | BMI, DSS settings, milestones |
| FAB | ChatbotScreen | NutriBot AI assistant (Groq chat) |

## Key Features
- **BMR-based meal planning**: Mifflin-St Jeor formula → knapsack DP for calorie optimization
- **Meal Log**: Each log entry is expandable — shows ingredients, macros, AI-generated recipe steps
- **BMI in Profile**: Calculated from user's weight/height; shows category + advice
- **NutriBot chatbot**: Multi-turn Groq conversation; answers nutrition/recipe questions
- **Food image analysis**: Camera/gallery → Groq vision → dish name, calories, ingredients

## Running the App
```bash
flutter run --dart-define=GROQ_API_KEY=<your_key>
# Optional: --dart-define=GROQ_MODEL=llama-3.3-70b-versatile
```

## Groq API Key
The key is hardcoded as a fallback in `groq_meal_narrative_service.dart`. For production, pass via `--dart-define=GROQ_API_KEY=...`.

## Firestore Structure
```
users/{uid}/
  meals/{mealId}   # MealModel (name, type, calories, price, ingredients, recipe, cookingSteps)
posts/{postId}/
  comments/{commentId}
```

## State Management Pattern
- `AuthProvider` — user model, auth status, settings updates
- `MealProvider` — meals for selected date, log/delete/generate
- `CommunityProvider` — posts stream, likes, comments

## Coding Conventions
- All colors from `AppTheme` constants — never use raw hex in widgets
- `withValues(alpha: x)` not `withOpacity(x)` (deprecated)
- Screens are `StatelessWidget` unless local state is needed
- Services are plain Dart classes (no ChangeNotifier)

## Recipe Generation Navigation Update

When the user clicks "Generate Recipes", the app should not only expand inside the same meal card.

Instead, it should navigate to a dedicated recipe generation screen.

### Required Flow

User clicks:
Generate Recipes

Then navigate to:
GeneratedRecipeScreen or RecipeResultScreen

The new screen should show:
- meal name
- ingredients
- calories
- macros if available
- estimated price
- AI-generated recipe description
- step-by-step cooking instructions
- loading state while Groq is generating
- error message with retry button if generation fails
- Save to Meal Log button
- Back button

### Screen Behavior

If recipe data already exists in MealModel:
- display saved recipe and cookingSteps immediately

If recipe data does not exist:
- call `GroqMealNarrativeService.generateRecipeSteps(mealName, ingredients)`
- show loading UI
- display generated recipe result
- allow user to save it

### Firestore Rule

After generation, save the result back to Firestore:

MealModel.recipe = generated description
MealModel.cookingSteps = generated steps

This prevents the app from generating the same recipe again every time the user opens the screen.

### Do Not Break

Do not break:
- existing 4-tab navigation
- NutriBot FAB
- MealProvider
- Firebase Auth
- Firestore meal saving
- Groq chatbot
- food image analysis
- knapsack meal planner

## Recipe & Nutrition Dataset Integration

NutriMind will use the Hugging Face dataset `datahiveai/recipes-with-nutrition` as the prototype recipe dataset for the meal planner feature.

### Dataset Purpose
Use this dataset for:
- Recipe suggestions
- Meal planner recommendations
- Calorie-based meal filtering
- Ingredient display
- Diet and health label filtering
- Meal type classification such as breakfast, lunch/dinner, snack
- Nutrient reference for prototype testing

### Important License Note
The dataset uses CC BY-NC 4.0, so it must only be used for academic, non-commercial, and prototype purposes.

### Integration Rule
Do not import the Hugging Face Python dataset directly inside Flutter.

Instead, preprocess the dataset first using Python, then export a cleaned JSON file for Flutter.

Recommended flow:

Hugging Face Dataset
→ Python cleaning script
→ cleaned JSON file
→ Flutter asset OR Firestore seed data
→ Meal planner UI

### Flutter Integration Plan
Create a cleaned dataset file:

assets/data/recipes_nutrition_sample.json

Each recipe object should follow this format:

{
  "name": "Chicken Vegetable Soup",
  "mealType": "lunch/dinner",
  "dishType": "soup",
  "calories": 450,
  "servings": 2,
  "ingredients": [
    "chicken",
    "carrot",
    "cabbage",
    "garlic"
  ],
  "dietLabels": ["Balanced"],
  "healthLabels": ["High-Protein"],
  "estimatedPricePhp": 120,
  "protein": 25,
  "carbs": 40,
  "fat": 12
}

### Local Food Adaptation
Because NutriMind is for Davao City, the app should prioritize common and affordable Filipino/Davao ingredients when recommending meals.

Examples:
- rice
- egg
- chicken
- fish
- monggo
- malunggay
- banana
- vegetables
- canned tuna
- tofu

### Meal Planner Rules
The meal planner should filter recipes using:
- user calorie goal from BMR
- budget limit
- meal type
- available ingredients
- estimated price
- nutrition needs

The knapsack algorithm should optimize meals based on:
- calories
- price
- protein
- user goal
- budget

### Do Not Do
- Do not load the full 39k dataset directly inside Flutter if it slows the app.
- Do not expose private API keys.
- Do not use the dataset for commercial use.
- Do not replace verified nutrition sources completely with this dataset.

### Recommended Implementation
For prototype:
1. Use Python to select 300–1000 useful recipes.
2. Clean the columns needed by NutriMind.
3. Export to JSON.
4. Add the JSON file to Flutter assets.
5. Load it using rootBundle.
6. Convert each item into a RecipeModel.
7. Use it in the AI meal planner and meal log.

For future version:
- Store cleaned recipes in Firestore.
- Add admin panel for recipe management.
- Use USDA FoodData Central as the verified nutrition reference.