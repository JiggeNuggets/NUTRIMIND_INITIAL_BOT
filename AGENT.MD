# NutriMind Agent Tasks

## Overview
This document tracks all completed and remaining development tasks for the NutriMind Flutter app.

---

## Finished Tasks ✅

### Core App Structure
- [x] Set up Flutter project with necessary dependencies (Firebase, Provider, etc.)
- [x] Implement basic app navigation with main shell
- [x] Create authentication screens (login, register, auth gate)
- [x] Set up Firebase configuration and initialization

### User Interface
- [x] Design and implement home screen
- [x] Create community screen with post display
- [x] Build profile screen with edit functionality
- [x] Develop meal planner screen
- [x] Implement AI meal planner screen
- [x] Add onboarding screens (biometrics, goal, splash)
- [x] Restructure navigation to 4 tabs: Home, Log, Community, Profile
- [x] Add NutriBot chatbot FAB accessible from all tabs
- [x] Add BMI card to Profile screen
- [x] Limit today's meals on Home screen to 4 (one per meal type)

### Data Management
- [x] Create meal planner food data with calorie information
- [x] Set up user and post models
- [x] Implement providers for auth, community, and meal management
- [x] Add `recipe` and `cookingSteps` fields to `MealModel`
- [x] Extend `MealModel.copyWith()` to support `recipe` and `cookingSteps`
- [x] Add `updateMealRecipe()` to `MealProvider` — persists recipe to Firestore and updates local state

### Services
- [x] Integrate Firebase Auth for user authentication
- [x] Set up Firestore for data storage
- [x] Configure Firebase Storage for file uploads
- [x] Implement Groq service for AI meal narratives
- [x] Add `chat()` method to `GroqMealNarrativeService` (NutriBot)
- [x] Add `generateRecipeSteps()` to `GroqMealNarrativeService`
- [x] Create `StorageService` — wraps `image_picker` + Firebase Storage for cross-platform image uploads

### Authentication
- [x] Google Sign-In integration
- [x] User registration and login flows
- [x] Auth state management
- [x] `updateProfilePhoto()` added to `AuthProvider`

### AI Features
- [x] NutriBot chatbot (Groq multi-turn chat)
- [x] Food image analysis (Groq vision model)
- [x] BMR-based knapsack meal planner
- [x] AI recipe & cooking steps generation — now opens dedicated `GeneratedRecipeScreen`

### Image Upload
- [x] Profile photo upload: camera or gallery → Firebase Storage `profile_images/{uid}/profile.jpg` → Firestore `users/{uid}.photoUrl`
- [x] Post image upload: camera or gallery → Firebase Storage `post_images/{uid}/{uuid}.jpg` → Firestore `posts/{postId}.imageUrl`
- [x] `EditProfileScreen` — full image picker with preview (MemoryImage before upload, NetworkImage after)
- [x] `CreatePostScreen` — image picker with preview, remove, and change controls

### Recipe Navigation
- [x] Created `GeneratedRecipeScreen` — self-contained screen showing meal info, ingredients, macros, AI-generated recipe and steps
- [x] Auto-generates recipe on open (if not already saved); displays saved recipe immediately if it exists
- [x] Retry button on Groq failure
- [x] Save to Meal Log button — persists `recipe` and `cookingSteps` to Firestore via `MealProvider`
- [x] Meal cards simplified — single "Generate Recipe" / "View Recipe" button navigates to `GeneratedRecipeScreen`

### CI/CD Pipeline
- [x] Created `.github/workflows/flutter_ci.yml`
- [x] Triggers on push and PR to `main` / `master`
- [x] Steps: checkout → Flutter stable install → `flutter pub get` → `flutter analyze` → `flutter test` → `flutter build web`
- [x] Dummy Groq key injected via `--dart-define=GROQ_API_KEY=dummy_key_for_ci`
- [x] Existing `test/widget_test.dart` is Firebase-free smoke test — compatible with CI

### Provider Audit (completed 2026-04-21)
- [x] **`MultiProvider`** in `main.dart` — all three providers registered: `AuthProvider`, `MealProvider`, `CommunityProvider`
- [x] **`AuthProvider`** — connected to `AuthGate`, `LoginScreen`, `RegisterScreen`, `ProfileScreen`, `EditProfileScreen`, `BiometricsScreen`, `GoalScreen`
- [x] **`MealProvider`** — connected to `HomeScreen`, `MealPlanScreen`, `AiMealPlannerScreen`, `GeneratedRecipeScreen`
- [x] **`CommunityProvider`** — connected to `CommunityScreen`, `CreatePostScreen`, `PostDetailScreen`
- [x] Fixed `MealProvider.listenToMeals` stream subscription leak — old subscription now cancelled before new one starts; `dispose()` added
- [x] Fixed `CommunityProvider.listenToPosts` stream subscription leak — same fix; provider now sets `_loading = true` when switching category
- [x] Fixed `CommunityScreen` — `initState` now calls `listenToPosts('Trending')` directly (no longer relies on `MainShell` to do it)
- [x] Fixed `_PostsFeed` — shows `CircularProgressIndicator` while `community.loading == true` instead of jumping straight to "No posts"
- [x] Fixed `MealPlanScreen` — `mealProv.error` is now surfaced as a floating snackbar
- [x] Fixed `ProfileScreen._buildDSSSettings` — removed redundant double-`watch` on `AuthProvider`
- [x] Fixed all deprecated `withOpacity()` → `withValues(alpha:)` across all screens (`home_screen`, `profile_screen`, `biometrics_screen`, `splash_screen`)

---

## AI Agent Behaviors

### NutriBot (`ChatbotScreen`)
- **Service**: `GroqMealNarrativeService.chat(message, history)`
- **Model**: `llama-3.3-70b-versatile`
- **System persona**: Expert Filipino nutrition assistant, Davao local foods focus
- **Entry point**: Green FAB (robot icon) on every main tab

### Recipe Generation (`GeneratedRecipeScreen`)
- **Service**: `GroqMealNarrativeService.generateRecipeSteps(mealName, ingredients)`
- **Output**: `{"description": "...", "steps": ["Step 1...", ...]}`
- **Trigger**: "Generate Recipe" / "View Recipe" button on expanded meal card in `MealPlanScreen`
- **Navigation**: `Navigator.push` → `GeneratedRecipeScreen(meal: meal)`
- **Caching**: Saved to `MealModel.recipe` + `MealModel.cookingSteps` in Firestore after user taps "Save to Meal Log"
- **If already saved**: Recipe displayed immediately, no Groq call made

### Meal Narrative (`AiMealPlannerScreen`)
- **Service**: `GroqMealNarrativeService.generateForBasket(slot, items, userName)`
- **Output**: 100–150 word narrative per meal slot

### Food Image Analysis
- **Service**: `GroqMealNarrativeService.analyzeFoodImageBytes(imageBytes)`
- **Model**: `llama-3.2-11b-vision-preview`
- **Entry point**: "Scan Food Image" button inside `AiMealPlannerScreen`

---

## Meal Plan Rules
- Max **4 meals per day**: breakfast, lunch, dinner, snack (one per type)
- Home screen shows today's 4 meals only
- Log screen shows meals for any selected date (7-day week view)
- Meal log cards expand to show: ingredients, macros, and a navigate-to-recipe button

## BMI Thresholds
| Range | Category | Color |
|-------|----------|-------|
| < 18.5 | Underweight | Blue |
| 18.5–24.9 | Normal | Green |
| 25–29.9 | Overweight | Orange |
| ≥ 30 | Obese | Red |

---

## Unfinished Tasks ❌

### Data Enhancement
- [ ] Expand meal planner food data with more Davao local items
- [ ] Add nutritional information for all food items
- [ ] Integrate Hugging Face `datahiveai/recipes-with-nutrition` dataset (CC BY-NC 4.0 — prototype/non-commercial only)
  - Python cleaning script → `assets/data/recipes_nutrition_sample.json`
  - Load via `rootBundle` → `RecipeModel` list
  - Use in AI meal planner and meal log

### UI/UX Improvements
- [ ] Implement meal basket selection UI (save AI planner baskets to meal log)
- [ ] Enhance community features (follows, notifications)
- [ ] Add meal plan saving and history
- [ ] Improve responsive design for different screen sizes

### Build & Deployment
- [ ] Create build scripts for Android, iOS, and Windows
- [ ] Add Google Sign-In SHA-1 to Firebase Console for mobile builds
- [ ] Deploy to Android/iOS — update `android/app/google-services.json`

### Testing
- [ ] Add integration tests for critical flows (login, meal log, post creation)
- [ ] Add widget tests for `HomeScreen`, `MealPlanScreen`, `CommunityScreen`
- [ ] Validate Groq API integration with mock responses in tests

### Security and Performance
- [ ] Move Groq API key to secure CI secret / `.env` (currently passed via `--dart-define`)
- [ ] Add user data encryption for sensitive fields
- [ ] Optimize app performance and bundle size
- [ ] Implement offline data caching
- [ ] Add rate limiting for Groq API calls

### Advanced Features
- [ ] Add personalized meal recommendations
- [ ] Implement social features (sharing meal plans)
- [ ] Create admin panel for content management
- [ ] Add analytics and user behavior tracking
- [ ] Milestones / badges backed by real data (currently hardcoded)
- [ ] Weekly leaderboard backed by real Firestore data (currently hardcoded)
### Scanner Navigation Update

- [x] Restore scanner as the center navigation action
  - [x] Add a center Scan button/icon between Log and Community
  - [x] Scanner is easy to access from the main navigation
  - [x] The Scan button opens the Food Scanner screen
  - [x] The Food Scanner screen supports real-time camera access
  - [x] The Food Scanner screen also supports gallery upload
  - [x] The Food Scanner screen includes a Manual Log option
  - [x] Manual Log allows users to type food name, calories, price, and meal type manually
  - [x] Scanned food results are savable to Meal Log
  - [x] Manual food entries are savable to Meal Log

#### Scanner Flow (Implemented ✅)

**Camera Flow:**
User opens app  
→ taps center Scan button (green circle)  
→ Food Scanner screen opens  
→ camera opens in real time  
→ user captures food image  
→ Groq vision analyzes the food  
→ app shows dish name, estimated calories, ingredients, and nutrition comment  
→ user can save result to Meal Log  

**Manual Log Flow:**
User opens Scan screen  
→ taps Manual Log button  
→ enters food name, calories, price, meal type, and notes  
→ saves entry to Meal Log
---

## Groq API Setup
```bash
flutter run --dart-define=GROQ_API_KEY=your_key_here
# Optional model override:
flutter run --dart-define=GROQ_MODEL=llama-3.3-70b-versatile
```

## CI/CD (GitHub Actions)
```
.github/workflows/flutter_ci.yml
```
Triggers on push/PR to `main` or `master`. Runs analyze → test → build web.

## Next Steps
1. Integrate the recipe/nutrition dataset (see Data Enhancement above)
2. Add integration tests for login, meal logging, and post creation flows
3. Deploy to Android — update `google-services.json` and add SHA-1 in Firebase Console
4. Expand food database with more Davao local ingredients
