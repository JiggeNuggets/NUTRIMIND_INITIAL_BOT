# NutriMind Agent Audit

Last updated: 2026-04-26 03:25 +08:00

## Audit Rules
- No assumptions were made.
- DONE means implemented and connected in the real app flow.
- PARTIAL means some code exists but it is incomplete, disconnected, UI-only, placeholder, or not fully verified.
- UNFINISHED means not implemented or only mentioned in docs/prompts.
- NEEDS FIX means implemented but broken, risky, or causing errors.

## Current App Directory
- Active Flutter app path: `C:\Users\wapak\Downloads\nutrimind-main\nutrimind-main\nutrimind`
- Active app reason: this nested app contains the current Meal Log, AI Meal Planner, Recipe Browser, SafeFoodImage/SafeAvatar, scanner history, pantry, NutriBot, and imageUrl save wiring.
- Other detected pubspec.yaml paths:
- `C:\Users\wapak\Downloads\nutrimind-main\pubspec.yaml` - older/stale Flutter package copy still present at repo root.
- `C:\Users\wapak\Downloads\nutrimind-main\nutrimind-main\nutrimind\pubspec.yaml` - active app.
- Initial commands run from repo root: `pwd`, `ls`, and a pubspec search. `bash find . -maxdepth 4 -name "pubspec.yaml"` was attempted but bash is not installed on this Windows machine, so the equivalent PowerShell command was used: `Get-ChildItem -Path . -Recurse -Filter pubspec.yaml -Depth 4`.

## Analyze Result
- Command run: `flutter pub get`
- Result: success in the active app directory.
- Notes: dependencies resolved; Flutter reported 26 packages with newer versions incompatible with current constraints.
- Command run: `flutter analyze`
- Result: PASS, `No issues found! (ran in 6.2s)`.
- Errors: none from the active app analyze run.
- Warnings/info: none from analyzer.
- Notes: required `rg` searches were run for TODO/FIXME, placeholder/mock/dummy/sample/hardcoded, profile update calls, image APIs, meal save paths, Groq/NutriBot, Firebase services, scanner/pantry/barcode/receipt, leaderboard/badges/notifications/follows/reports.

## Firebase Status
### DONE
- Firebase Core initializes in `lib/main.dart` with `DefaultFirebaseOptions.currentPlatform`.
- Firebase Auth is used for email/password sign up, email/password sign in, Google sign-in, password reset, auth state, and sign out.
- Firestore is used for users, meals, posts, comments, likes, reports, follows, notifications, pantry items, scanned items, weekly stats, badges, local food spotlight reads, market config reads, and weekly palengke lists.
- Firebase Storage is used for uploaded profile images and community post images.
### PARTIAL
- `firebase_options.dart` supports web, Windows, and Android only; iOS, macOS, and Linux throw unsupported errors.
- `local_foods` and `market_prices` are read if present, but no seed/rules workflow was confirmed in the repo.
- Notifications are Firestore in-app records only.
- Recipe API exists in `backend/`, but the Flutter Recipe Browser is hardcoded to local asset mode.
- Scanner history has an `imageUrl` model field, but scanner saves do not upload or pass an image URL.
### UNFINISHED
- No `firestore.rules` file was found.
- No `storage.rules` file was found.
- Push notifications and scheduled local notifications are not implemented.
- Admin/moderator review tooling for reports was not found.
### NEEDS FIX
- Two Flutter app copies exist with different Firebase config files. The root copy is stale and can confuse builds or audits.
- Firebase API keys are present in `firebase_options.dart` and `android/app/google-services.json`. This is normal for Firebase clients, but the project should enforce Firebase/App Check/API restrictions before production.
- A local `.env` exists at repo root with `GROQ_API_KEY` and `GROQ_MODEL`; `.env` is ignored, but it remains a push-protection risk if accidentally added.

## Feature Status

### App Structure / Navigation
Status: PARTIAL
Evidence:
- Files checked: `lib/main.dart`, `lib/screens/auth/auth_gate.dart`, `lib/screens/main/main_shell.dart`, `pubspec.yaml`, `assets/`.
- Real flow: `main.dart` initializes Firebase, registers Auth/Meal/Community/Notification providers, applies `ModernAppTheme.lightTheme`, and starts at `AuthGate`. Authenticated users enter `MainShell`, which has Home, Log, Community, Profile, a center Add Food action, and a NutriBot FAB.
- Notes: active app structure is connected. The repo still contains a stale root Flutter app and an empty `assets/images/` directory.

### Providers / State Management
Status: PARTIAL
Evidence:
- Files checked: `auth_provider.dart`, `meal_provider.dart`, `community_provider.dart`, `notification_provider.dart`, `nutribot_provider.dart`.
- Real flow: Provider is used for auth, meals, community, and notifications globally. NutriBot creates a local `NutriBotController` per panel.
- Notes: there is no dedicated profile provider; profile state is in `AuthProvider`. Several screens still call `FirestoreService` directly.

### Authentication
Status: DONE
Evidence:
- Files checked: `auth_service.dart`, `auth_provider.dart`, `auth_gate.dart`, `login_screen.dart`, `register_screen.dart`, onboarding screens.
- Real flow: Firebase Auth handles email/password, Google sign-in, password reset, auth stream, and logout. Firestore user docs are created on sign up and recovered if missing after login.
- Notes: no role system was found. New registration goes through goal/biometrics onboarding, but existing incomplete profiles are not forced back through onboarding.

### Home Dashboard
Status: PARTIAL
Evidence:
- Files checked: `home_screen.dart`, `meal_provider.dart`, `user_model.dart`, `safe_image.dart`.
- Real flow: Home reads real `AuthProvider.userModel` and `MealProvider.meals`, calculates budget, calories, macros, and today's logged meals, and shows meal cards with `SafeFoodImage`.
- Notes: profile avatar trims URL before `NetworkImage`. The local spotlight reads Firestore `local_foods`, but falls back to static Davao fruit copy when no document exists.

### Profile
Status: NEEDS FIX
Evidence:
- Files checked: `profile_screen.dart`, `edit_profile_screen.dart`, `auth_provider.dart`, `storage_service.dart`, `engagement_service.dart`.
- Real flow: Profile reads `AuthProvider.userModel`, streams badges and weekly ranking, updates budget settings through `AuthProvider.updateSettings`, uploads profile images to Firebase Storage, and writes profile fields to Firestore.
- Notes: `EditProfileScreen` writes name/location directly through `FirestoreService.updateUser`, then calls `AuthProvider.updateOnboarding`, which does not update local name/location. Firestore may save correctly, but the in-memory profile can remain stale until auth/profile refresh.

### Meal Logging
Status: PARTIAL
Evidence:
- Files checked: `meal_provider.dart`, `firestore_service.dart`, `meal_model.dart`, `meal_plan_screen.dart`, `food_scanner_screen.dart`, `ai_meal_planner_screen.dart`, `generated_recipe_screen.dart`.
- Real flow: Meal Log streams `users/{uid}/meals`, supports date selection, log, delete, recipe generation save, swap replacement, scanner/manual saves, AI Planner basket saves, and recipe-card saves from AI Planner.
- Notes: manual log and scanner meals intentionally save `imageUrl` as null. Recipe Browser itself displays recipes but does not have a direct save-to-log action; recipe-to-log save currently exists in AI Planner recipe cards.

### AI Meal Planner
Status: PARTIAL
Evidence:
- Files checked: `ai_meal_planner_screen.dart`, `meal_planner_service.dart`, `meal_planner_models.dart`, `meal_planner_food_data.dart`, `groq_meal_narrative_service.dart`.
- Real flow: UI builds BMR/budget-aware daily baskets from local Davao prototype food data, optional calorie-only fallback data, optional Groq descriptions, selected basket save, duplicate meal handling, and meal reminder notifications.
- Notes: Save Selected Meals calls `_saveSelectedMealsToLog` -> `_savePlannerDraftToMealLog` -> `MealProvider.addPlannedMeal`; no profile update method is called in this save path. The local planner model has `imageUrl`, but no actual `LocalMealPlannerFood` rows currently set image URLs, so planner meals normally save null imageUrl.

### AI NutriBot
Status: PARTIAL
Evidence:
- Files checked: `nutribot_provider.dart`, `nutribot_service.dart`, `nutribot_models.dart`, `nutribot_launcher.dart`, `nutribot_panel.dart`, `main_shell.dart`.
- Real flow: NutriBot opens from FAB/app bar actions, receives context payloads from Home, Meal Log, AI Planner, Recipe Browser, Community, Profile, and Food Scanner, calls Groq chat when configured, and streams simulated tokens in the UI.
- Notes: NutriBot is advice-only and does not write to Firestore or app state. If Groq fails or is not configured, `NutribotService` returns local mock responses, which is useful for demos but can mask API outages.

### Recipes / Dataset
Status: PARTIAL
Evidence:
- Files checked: `recipe_browser_screen.dart`, `recipe_dataset_service.dart`, `recipe_api_service.dart`, `recipe_model.dart`, `assets/data/recipes_nutrition_sample.json`, `backend/app/main.py`, `backend/app/recipe_store.py`.
- Real flow: Recipe Browser loads the bundled local JSON asset because `_kLocalMode = true`, supports search/filter/details, uses `SafeFoodImage`, and exposes recipe context to NutriBot. Backend FastAPI endpoints exist for `/health`, `/recipes`, `/recipes/search`, and `/recipes/{id}`.
- Notes: the dataset is labeled prototype/non-production. Backend is not active in Flutter by default. Production recipe data and a hosted API URL are unfinished.

### Community
Status: NEEDS FIX
Evidence:
- Files checked: `community_screen.dart`, `create_post_screen.dart`, `post_detail_screen.dart`, `user_profile_screen.dart`, `community_provider.dart`, `post_model.dart`, `firestore_service.dart`, `storage_service.dart`.
- Real flow: Community streams posts from Firestore, creates posts, uploads post images to Storage, displays avatars with `SafeAvatar`, displays post images with `SafeFoodImage`, supports comments, likes, follows, reports, and in-app notifications.
- Notes: scalable likes are written to `posts/{postId}/likes/{uid}`, but the card liked-state check still relies on the legacy `likes` array. Counts update through `likeCount`, but the heart filled/unfilled state can be wrong for subcollection likes.

### Scanner / Barcode / Receipt / Pantry
Status: PARTIAL
Evidence:
- Files checked: `scan_options_screen.dart`, `food_scanner_screen.dart`, `scan_history_screen.dart`, `pantry_screen.dart`, `scanned_item_model.dart`, `pantry_item_model.dart`, `firestore_service.dart`.
- Real flow: Scan Options opens AI meal scan, manual meal log, pantry add flow, and scan history. Food scanner uses image picker/camera bytes with Groq vision, requires review for missing/generic values, saves reviewed scanner results to Meal Log and Scan History. Pantry supports manual Firestore CRUD.
- Notes: Barcode Scan is explicitly Coming Soon. Receipt scanner was not found. Pantry scanning/image analysis was not found. Scanner images are not uploaded to Storage, so scanner Meal Log and Scan History use fallback visuals.

### Notifications
Status: PARTIAL
Evidence:
- Files checked: `notification_provider.dart`, `notification_model.dart`, `notifications_screen.dart`, `notification_bell.dart`, `firestore_service.dart`.
- Real flow: Firestore-backed in-app notifications stream under `users/{uid}/notifications`, unread counts update the bell, and users can mark read/all-read/delete. Community and meal planner paths create notifications.
- Notes: no push notification service, scheduled local notifications, or OS notification permission flow was found.

### Leaderboard / Badges / Milestones
Status: PARTIAL
Evidence:
- Files checked: `engagement_service.dart`, `engagement_config.dart`, `badge_model.dart`, `weekly_stats_model.dart`, `profile_screen.dart`.
- Real flow: meal logging, scanned meals, recipe saves, planned meal saves, posts, comments, and budget-friendly meals update weekly stats and award badges under user subcollections. Profile streams badges and collectionGroup weekly leaderboard.
- Notes: points, thresholds, badge definitions, and ranking rules are hardcoded in app config, not Firestore/Remote Config.

### UI / Responsive Design
Status: PARTIAL
Evidence:
- Files checked: `modern_app_theme.dart`, `app_theme.dart`, main screens, `state_views.dart`, `safe_image.dart`.
- Real flow: `ModernAppTheme.lightTheme` is applied by `MaterialApp`. Shared loading/empty/error views exist and are used in several Firestore-heavy screens. Safe image widgets prevent empty network image URLs in key food/avatar surfaces.
- Notes: many screens still import/use old `AppTheme` constants. Responsive handling is mostly scroll views and max-width constraints, not fully verified across all breakpoints.

### Documentation
Status: NEEDS FIX
Evidence:
- Files checked: root `AGENT.MD`, active app `AGENT.MD`, `CLAUDE.md`, `README.md`, backend docs.
- Real flow: docs exist, but several claims were stale or broader than code.
- Notes: `CLAUDE.md` says a Groq key is hardcoded as fallback, but current active code uses `String.fromEnvironment`. Root and nested agent docs disagreed before this audit.

## Data Path Verification

### Save Selected Meals to Log
- Entry point: `AiMealPlannerScreen` button labeled `Save Selected Meals to Log`.
- Functions called: `_saveSelectedMealsToLog` -> `_draftFromBasket` -> `_savePlannerDraftToMealLog`.
- Provider method: `MealProvider.addPlannedMeal(...)`.
- Firestore write: `FirestoreService.addMeal` writes to `users/{uid}/meals/{mealId}`.
- Fields saved: `id`, `userId`, `name`, `type`, `price`, `calories`, `status`, `date`, `loggedAt`, `notes`, `ingredients`, `protein`, `carbs`, `fat`, `recipe`, `cookingSteps`, `imageUrl`.
- Status: DONE for meal save path. ImageUrl is preserved if the basket source has one, but current local planner rows do not provide image URLs.

### Recipe to Meal Log
- Entry point: AI Meal Planner recipe card Save button.
- Functions called: `_saveRecipeToMealLog`.
- Provider method: `MealProvider.addRecipeMeal(...)`.
- Firestore write: `FirestoreService.addMeal` writes to `users/{uid}/meals/{mealId}`.
- Fields saved: recipe name, mapped meal type, estimated price, calories, macros, ingredients, notes, recipe description, cooking steps, and cleaned `recipe.imageUrl`.
- Status: DONE for the AI Planner recipe-card path. PARTIAL overall because `recipe_browser_screen.dart` displays recipes but does not include a direct save-to-log action.

### Scanner to Meal Log
- Entry point: `FoodScannerScreen` Save to Meal Log, Review & Save, or Manual Meal Log sheet.
- Functions called: `_saveAnalyzedMeal` or `_openScanReview` -> `_saveScannedMeal`; manual path `_saveManualMeal`.
- Provider method: `MealProvider.addManualMeal(...)`.
- Firestore write: `users/{uid}/meals/{mealId}` through `FirestoreService.addMeal`; scanner history writes `users/{uid}/scanned_items/{scanId}` through `addScannedItem`.
- Fields saved: meal name, type, price, calories, status, date/loggedAt, notes, ingredients, macros if provided. Scanner history saves name/calories/price/mealType/source/timestamps.
- Status: DONE for meal save. PARTIAL for image coverage because scanner image bytes are not uploaded and no imageUrl is saved.

### Profile Update
- Entry point: `ProfileScreen._updateSettings`, `EditProfileScreen._save`, onboarding goal/biometrics screens.
- Functions called: `AuthProvider.updateSettings`, `AuthProvider.updateGoal`, `AuthProvider.updateOnboarding`, `AuthProvider.updateProfilePhoto`, and direct `FirestoreService.updateUser` in Edit Profile.
- Firestore/Auth write: Firestore `users/{uid}` updates; profile photo uploads to Storage `profile_images/{uid}/profile.jpg`.
- Fields saved: settings save `dailyBudget`, `allowNonLocal`, `budgetBuffer`, `budgetConfigured`; onboarding saves `goal`, `gender`, `height`, `weight`, `age`, `profileCompleted`; edit profile saves `name`, `location`, `height`, `weight`, `age`, `gender`, and optional `photoUrl`.
- Status: NEEDS FIX because Edit Profile can leave `AuthProvider.userModel.name/location` stale after saving.

### NutriBot Chat
- Entry point: NutriBot FAB/AppBar actions and `NutribotLauncher.open`.
- Service/provider: `NutriBotController` with `NutribotService`.
- API used: Groq OpenAI-compatible chat completions when `GROQ_API_KEY` is provided.
- Context connected: Home, Meal Log, AI Planner, Recipe Browser, Community, Profile, Food Scanner, and attached meal/recipe/profile payloads.
- Status: PARTIAL because it is context-aware and connected, but advice-only and can fall back to local mock responses.

### Swap Meal Replacement
- Entry point: Meal Log swap sheet in `meal_plan_screen.dart`.
- Functions called: `_openSwapSheet` -> `_replaceWithSwap`.
- Provider method: `MealProvider.replaceMealWithSwap(...)`.
- Firestore write: `FirestoreService.updateMeal` updates the existing `users/{uid}/meals/{mealId}` document.
- Fields saved: replacement name, price, calories, notes, ingredients, macros, null recipe, empty cooking steps, and cleaned replacement `imageUrl`.
- Status: DONE for the connected swap path. Current replacement dataset rows do not contain actual image URLs, so saved replacements usually fall back visually.

## Finished Today
Only list items proven by code changes or current implementation.
- No app feature code was added during this audit pass.
- `AGENT.MD` audit content was refreshed after checking the current repository.
- Active app `flutter pub get` and `flutter analyze` were run from the verified app directory.

## Still Unfinished
Only list items proven missing or incomplete.
- Barcode scanning is Coming Soon only.
- Receipt scanning was not found.
- Scanner image upload and scanner `imageUrl` persistence are not implemented.
- Pantry scanner/image analysis is not implemented.
- AI Planner local food rows have an `imageUrl` field but no populated image URLs.
- Recipe Browser has no direct save-to-Meal-Log button.
- Production recipe API hosting and verified recipe data are not wired into Flutter.
- Push notifications and scheduled local notifications are not implemented.
- Firestore and Storage security rules are absent from the repo.
- Admin/moderation review queue is absent.
- NutriBot cannot apply confirmed edits or writes to app state.
- Existing old meals are not backfilled with imageUrl.

## Needs Improvement / Bugs
Only list real problems found in code or analyze output.
- Community liked-state can be wrong for scalable subcollection likes because UI checks only the legacy `likes` array.
- Edit Profile can save name/location to Firestore but leave local `AuthProvider.userModel` stale.
- Root Flutter package is stale and still present, creating build/audit confusion.
- `RecipeBrowserScreen` is hardcoded to local asset mode with `_kLocalMode = true`.
- NutriBot falls back to local mock responses on Groq errors, which can hide API failures.
- Home local spotlight shows static fallback copy when `local_foods` is empty.
- No security rules files were found for Firestore or Storage.
- Firebase client API keys are committed as expected for Firebase apps but still need project restrictions before release.
- `.env` with Groq keys exists locally; it is ignored but should never be committed.
- Several docs are stale or inaccurate compared with current code.

## Risk List
- Firebase config risks: duplicate app copies and different Firebase config files; missing rules files; no App Check/rules evidence.
- Image loading risks: no empty `NetworkImage("")` path found in active app; remaining risk is missing image data for planner/scanner/swap sources, not unsafe loading.
- API key/secrets risks: local `.env` has Groq key fields; Firebase client keys are in app config; docs must not encourage hardcoded secrets.
- Disconnected UI risks: barcode scan is UI-only/coming-soon; receipt scan absent; Recipe Browser save-to-log absent.
- Old theme vs modern theme mismatch: `ModernAppTheme` is applied globally, but many screens still use old `AppTheme`.
- Mock/placeholder data risks: recipe asset sample, planner local food data, Food-101 fallback, Palengke fallback maps, NutriBot mock fallback, and Home spotlight fallback.
- Broken navigation risks: root stale Flutter app may be run by mistake; active app navigation itself is connected.
- Community risks: report storage exists, but no moderator review queue; liked-state can desync for current user.
- Profile risks: local profile state can stay stale after Edit Profile.
- Production data risks: local Davao prices and recipe nutrition values are prototype estimates, not verified live market/medical data.

## Next Recommended Work Order
Prioritize based on actual code state:
1. Remove or clearly quarantine the stale root Flutter app so only the active nested app is built and audited.
2. Add Firestore and Storage rules, then verify all active collections and upload paths against them.
3. Fix Community liked-state by reading `posts/{postId}/likes/{uid}` or otherwise connecting `FirestoreService.isPostLikedBy`.
4. Fix Edit Profile so `AuthProvider.userModel` updates name/location immediately after save.
5. Decide whether Recipe Browser should save recipes to Meal Log; if yes, wire it through `MealProvider.addRecipeMeal`.
6. Add scanner image upload or explicitly keep scanner images local-only with documented fallback behavior.
7. Replace prototype planner/recipe/palengke datasets with verified or remotely configurable data before production.
8. Configure production Recipe API with `RECIPE_API_BASE_URL` and remove the hardcoded local mode for release.
9. Add push/local notifications only after in-app notification behavior is stable.
10. Add integration/widget tests for auth, planner save, recipe save, scanner save, community likes/reports, profile update, and image fallback behavior.

## Execution Rules (STRICT)

### General
- Do NOT modify working features
- Do NOT introduce new features during debugging phase
- Always fix root cause, not symptoms

### Firestore (CRITICAL)
- NEVER call Firestore with empty uid
- ALWAYS validate uid before any query or write

Actual pattern used (inline guard, no centralized helper):

```dart
if (uid.isEmpty) return Stream.value(const <MealModel>[]);
```

- ALWAYS sanitize numbers using `safeDouble(double? v)` from `lib/utils/firestore_safety.dart`

### Streams
- NEVER start snapshots() if uid is empty
- Return safe fallback: `Stream.value(const <T>[])`

### UI Safety
- ALWAYS check mounted before setState

if (!mounted) return;

### Error Handling
- NEVER expose raw Firebase errors to UI
- ALWAYS show user-friendly message

### Images
- NEVER pass empty string to NetworkImage
- ALWAYS fallback to asset or placeholder

### Debugging Mode
- Identify exact failing function
- Trace full call chain
- Fix at root (provider/service), not UI only

## Previously Critical Bug (Now Resolved)

### Firestore INTERNAL ASSERTION FAILED

Status: RESOLVED (Phase 1 — 2026-04-26)

Cause (was):
- Firestore stream/query methods accepted empty uid, creating paths like `users//meals`

Fixes applied:
- uid guards added to all 11 FirestoreService stream methods
- MealProvider guards in listenToMeals, selectDate, logMeal
- MainShell checks uid.isNotEmpty before starting listeners
- safeDouble(double? v) prevents NaN/Infinity writes
- Friendly error snackbars replace raw stack traces
- Logo 404 fixed (splash_screen no longer loads missing PNG)

Verification: `flutter analyze` → No issues found.