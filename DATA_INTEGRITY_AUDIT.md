# NutriMind Data Integrity Audit

Audit date: 2026-04-25

Scope: Home/Dashboard, Meal Log, AI Meal Planner, AI NutriBot, Scanner/Pantry, Community, Profile, Leaderboard/Badges, Notifications, Recipe Browser, and Weekly Grocery / Palengke List.

Goal: identify production-screen data that is still hardcoded, seeded, sample-backed, mock-backed, fallback-only, or missing persistence.

The original audit did not change app code. The Phase 1 remediation update below records the cleanup completed after the audit.

---

## Files Inspected

Production screens:

- `lib/screens/main/home_screen.dart`
- `lib/screens/main/meal_plan_screen.dart`
- `lib/screens/main/ai_meal_planner_screen.dart`
- `lib/screens/main/food_scanner_screen.dart`
- `lib/screens/main/nutribot_screen.dart`
- `lib/screens/main/chatbot_screen.dart`
- `lib/screens/main/community_screen.dart`
- `lib/screens/main/create_post_screen.dart`
- `lib/screens/main/post_detail_screen.dart`
- `lib/screens/main/user_profile_screen.dart`
- `lib/screens/main/profile_screen.dart`
- `lib/screens/main/notifications_screen.dart`
- `lib/screens/main/recipe_browser_screen.dart`
- `lib/screens/main/weekly_palengke_list_screen.dart`
- `lib/screens/auth/register_screen.dart`
- `lib/screens/onboarding/goal_screen.dart`
- `lib/screens/onboarding/biometrics_screen.dart`
- `lib/screens/main/edit_profile_screen.dart`

Providers, services, models, and data:

- `lib/providers/auth_provider.dart`
- `lib/providers/meal_provider.dart`
- `lib/providers/community_provider.dart`
- `lib/providers/notification_provider.dart`
- `lib/providers/nutribot_provider.dart`
- `lib/services/auth_service.dart`
- `lib/services/firestore_service.dart`
- `lib/services/meal_planner_service.dart`
- `lib/services/meal_planner_prompts.dart`
- `lib/services/palengke_service.dart`
- `lib/services/recipe_dataset_service.dart`
- `lib/services/recipe_api_service.dart`
- `lib/services/groq_meal_narrative_service.dart`
- `lib/services/nutribot_service.dart`
- `lib/services/engagement_service.dart`
- `lib/data/meal_planner_food_data.dart`
- `lib/models/user_model.dart`
- `lib/models/meal_model.dart`
- `lib/models/post_model.dart`
- `lib/models/notification_model.dart`
- `lib/models/recipe_model.dart`
- `lib/models/badge_model.dart`
- `lib/models/weekly_stats_model.dart`
- `backend/app/main.py`
- `backend/README.md`
- `assets/data/recipes_nutrition_sample.json`
- `backend/data/recipes_sample/recipes_sample.json`

Searches included:

- `TODO`, `FIXME`, `mock`, `sample`, `demo`, `placeholder`, `hardcoded`, `seed`, `default`, `fake`, `dummy`, `example`
- hardcoded `List`, `Map`, `const`, and static taxonomy/data patterns
- users, posts, comments, likes, followers, badges, leaderboard, notifications, recipes, local foods, prices, and Palengke terms

---

## Summary

No hardcoded sample users, sample Community posts, sample comments, fake followers, static leaderboard rows, or mock notification feeds were found in production Dart screens.

Resolved by the Phase 1 cleanup:

- seeded/default Meal Log entries for new users
- hardcoded weekly meal templates and the old weekly generation path
- hardcoded Home PHP 150 budget message
- static Home local food cards and inactive local-food `View All`
- scattered Community category/tag/report-reason constants, now centralized as app config
- scanner parser fallbacks that could save `Food item`, `300` calories, guessed meal type, or PHP `0` into Meal Log
- AI Meal Planner profile/budget fallbacks that could generate plans from PHP `150`, age `28`, weight `64kg`, height `168cm`, or assumed male profile data
- local Davao food dataset rows now carry source metadata and prototype-estimate labels

Remaining main data integrity risks:

- prototype Davao food prices/macros are still used by the optimizer until verified Firestore/backend data is available
- calorie-only fallback foods from static maps/Food-101 categories
- local academic recipe samples are now disclosed/guarded, but still need production recipe data
- Palengke prices/categories can now come from Firestore config, but prototype fallback maps remain until verified market records are populated
- badge/ranking rules are centralized as app-config product rules, but not yet Firestore/Remote Config driven
- hardcoded Community categories/tags/report reasons
- AI/NutriBot fallback responses that can become user-visible
- profile/biometric defaults that can affect non-planner profile/BMI screens if real data is missing

---

## Phase 1 Remediation Update

Completed on 2026-04-25:

- DI-001: Home AI Plan budget copy now uses the signed-in user's `dailyBudget`.
- DI-002: Home `Favorite Local Foods` no longer uses static cards; it reads Firestore `local_foods`.
- DI-003: The inactive Home local-food `View All` control was removed from the section.
- DI-004: New users are no longer seeded with default Meal Log entries.
- DI-005: The hardcoded `generateWeekMealPlan()` weekly template generator was removed.
- DI-006: Home and Meal Plan generation entry points now route users to the AI Meal Planner instead of creating static meals automatically.
- DI-018 to DI-020: Community categories, suggested tags, and report reasons are centralized in `lib/config/community_config.dart` as app config. They remain product taxonomy and can be moved to Firestore/Remote Config later if runtime updates are needed.
- DI-025: Food Scanner no longer defaults missing AI fields to generic saved values. Missing/low-confidence food name, calories, meal type, or price now require a Review Scan sheet before saving to Meal Log.
- DI-009 and DI-010: AI Meal Planner now requires completed profile and budget flags before generation. Missing daily budget, age, gender, height, or weight shows a Complete Profile First state/dialog with a Profile route instead of using fallback values.
- DI-007: Local Davao food records now include `source`, `sourceType`, `lastVerifiedDate`, and `isPrototypeEstimate` metadata. Planner copy labels local prices/macros as prototype estimates, not live market prices.
- DI-011: The AI Meal Planner recipe section now labels the bundled recipe asset as a prototype/non-production dataset and avoids showing missing price/macros as real values.
- DI-012: The recipe backend now exposes sample-data disclosure in `/health` and blocks bundled sample data in production unless explicitly allowed.
- DI-013: Release builds no longer silently depend on local Recipe API hosts; `RECIPE_API_BASE_URL` is required unless a local release override is explicitly enabled.
- DI-014: Recipe API mapping now reads provided nutrition and price fields when present, leaves missing prices unavailable, and keeps zero-value price/macros out of NutriBot recipe context.
- DI-015: Weekly Grocery / Palengke List now prefers Firestore `market_prices` / `local_foods` config for ingredient price/category data and labels fallback prices as prototype estimates.
- DI-016: Weekly Grocery / Palengke List now persists generated weekly list metadata and item `isBought` state under `users/{uid}/weekly_palengke_lists/{weekId}`.
- DI-017: Engagement points, badge thresholds, badge titles/descriptions/icons, and leaderboard ranking rules are centralized in `lib/config/engagement_config.dart` as app-config product rules. Newly awarded badges persist `ruleSource`.
- DI-021: Community likes migrated from array-based storage (`likes[]` on post document) to scalable subcollection (`posts/{postId}/likes/{uid}`). Aggregate `likeCount` field maintained on post document for UI. Legacy array preserved for backward compatibility during migration. New methods added: `toggleLike()`, `isPostLikedBy()`, `getLikeCount()`, `likeCountStream()` in FirestoreService. PostModel updated with `likeCount` field and updated `isLikedBy()` / `likeCount` getters. CommunityProvider updated to use new likeCount for optimistic UI.

Verification:

- `flutter analyze` passed with no issues found.
- Targeted `rg` checks found no remaining seeded meal method, weekly template generator, old seeded meal names, inactive local-food `View All`, or hardcoded Home `PHP 150` plan copy in `lib/**/*.dart`.

Still open:

- Firestore `local_foods` / `market_prices` must be populated with verified Davao/local food data and source metadata.
- The local Davao dataset is partially mitigated but still needs verified `local_foods` / `market_prices` production data. Recipe sample data is disclosed and guarded, but still needs a verified production source. Palengke price/category fallback maps are labeled as prototype estimates until market config is populated. Badge/ranking rules are centralized but still need Firestore/Remote Config if runtime tuning is required. Non-planner profile fallback labels remain to be cleaned up in later tasks.

---

## Hardcoded Data Findings

| ID | File path | Feature/screen affected | What data is hardcoded | Production-visible? | Recommended fix / replacement source | Priority |
| --- | --- | --- | --- | --- | --- | --- |
| DI-001 | `lib/screens/main/home_screen.dart` | Home/Dashboard | AI Plan card previously hardcoded `PHP 150/day` even though users have `dailyBudget` in Firestore. | No, resolved | Fixed: copy now uses `user.dailyBudget`. | High |
| DI-002 | `lib/screens/main/home_screen.dart` | Home/Dashboard | `Favorite Local Foods` list was static: Pomelo, Durian, Malunggay, Bangus, Saba Banana, prices, tags, and emoji. | No, resolved | Fixed: section reads Firestore `local_foods` and shows loading/empty/error states. Next: populate verified `local_foods` / `market_prices`. | High |
| DI-003 | `lib/screens/main/home_screen.dart` | Home/Dashboard | `View All` for local foods had an empty callback. | No, resolved | Fixed: inactive control removed until there is a real destination. | Medium |
| DI-004 | `lib/services/firestore_service.dart` | Meal Log / onboarding | New users were seeded with default Meal Log entries: Pomelo & Davao Honey, Grilled Tuna, Tuna Omelette, Saba Banana. | No, resolved | Fixed: new users now start with an empty Meal Log. | High |
| DI-005 | `lib/services/firestore_service.dart` | Meal Log / Home Generate Weekly Plan | `generateWeekMealPlan()` used hardcoded meal templates and rotated them across the week. | No, resolved | Fixed: hardcoded generator removed. Next: add saved `meal_plans` if weekly plan history is needed. | High |
| DI-006 | `lib/screens/main/meal_plan_screen.dart`, `lib/screens/main/home_screen.dart` | Meal Log / Home | Generate actions called the hardcoded `generateWeekMealPlan()` path. | No, resolved | Fixed: entry points route to AI Meal Planner; meals are saved only through user-confirmed planner/logging flows. | High |
| DI-007 | `lib/data/meal_planner_food_data.dart`, `lib/models/meal_planner_models.dart`, `lib/services/meal_planner_service.dart`, `lib/screens/main/ai_meal_planner_screen.dart` | AI Meal Planner | Local Davao food names, prices, calories, macros, ingredients, serving sizes, and notes are static prototype estimates. | Partially mitigated | Added `source`, `sourceType`, `lastVerifiedDate`, and `isPrototypeEstimate` metadata; UI and saved notes now disclose prototype estimated local prices/macros and avoid live-market wording. Still needs verified Firestore `local_foods` / `market_prices` with source/date/vendor metadata. | High |
| DI-008 | `lib/data/meal_planner_food_data.dart:51`, `lib/data/meal_planner_food_data.dart:1748`, `lib/services/meal_planner_service.dart:325` | AI Meal Planner | Calorie-only fallback food groups and Food-101 categories are static and lack price/macros/local availability. | Sometimes | Keep fallback out of strict production planning or replace with verified backend/local dataset records. Source: local verified dataset/backend API. | Medium |
| DI-009 | `lib/services/meal_planner_service.dart`, `lib/models/meal_planner_models.dart` | AI Meal Planner | Missing/invalid daily budget previously fell back to PHP 150. | No, resolved | Fixed: `dailyBudgetPhp` is required and the service throws if budget is not positive. Planner generation requires a configured budget first. | High |
| DI-010 | `lib/screens/main/ai_meal_planner_screen.dart`, `lib/providers/auth_provider.dart`, `lib/models/user_model.dart`, `lib/screens/onboarding/goal_screen.dart` | AI Meal Planner | Planner previously fell back to age 28, weight 64 kg, height 168 cm, male, PHP 150 budget, and 15 percent buffer when profile data was missing. | No, resolved | Fixed: planner fields no longer seed fake defaults; generation is gated by `profileCompleted` and `budgetConfigured`, with a Complete Profile First state/dialog. Goal selection no longer writes default biometrics before the biometrics step. | High |
| DI-011 | `lib/services/recipe_dataset_service.dart`, `lib/screens/main/ai_meal_planner_screen.dart`, `assets/data/recipes_nutrition_sample.json` | AI Meal Planner recipe dataset | AI Meal Planner loads a local academic/non-commercial sample recipe asset. | Partially mitigated | Fixed: planner UI now labels it as a prototype/non-production recipe dataset and hides missing price/macros instead of presenting them as real values. Still replace with a production recipe backend/API or Firestore `recipes` collection with allowed licensing and validated nutrition. | High |
| DI-012 | `backend/app/main.py`, `backend/README.md`, `backend/data/recipes_sample/recipes_sample.json` | Recipe Browser backend | Backend can use `backend/data/recipes_sample/recipes_sample.json`, a cleaned sample export. | Partially mitigated | Fixed: backend exposes `data_mode`, `is_sample_data`, and `data_warning` in `/health`; production refuses bundled sample data unless `RECIPE_API_ALLOW_SAMPLE_DATA=true`. Still point production to a verified dataset via `RECIPE_API_DATA_FILE`. | High |
| DI-013 | `lib/services/recipe_api_service.dart` | Recipe Browser | Recipe API base URL used local development hosts when not configured. | Partially mitigated | Fixed: release builds require `RECIPE_API_BASE_URL` unless a local release override is explicitly enabled; debug/profile still use local defaults. Still configure a hosted backend URL for production. | Medium |
| DI-014 | `lib/models/recipe_model.dart`, `lib/screens/main/recipe_browser_screen.dart`, `lib/widgets/nutribot/nutribot_launcher.dart` | Recipe Browser / NutriBot recipe context | API recipes previously left `estimatedPricePhp`, `protein`, `carbs`, and `fat` at `0` because backend fields were not mapped/provided. | Partially mitigated | Fixed: model maps provided API nutrition/price fields, UI shows `Price unavailable` when price is missing, and NutriBot omits zero price/macros. Still add verified nutrition and estimated cost fields to backend production recipes. | Medium |
| DI-015 | `lib/services/palengke_service.dart`, `lib/models/palengke_item_model.dart`, `lib/screens/main/weekly_palengke_list_screen.dart` | Weekly Grocery / Palengke List | Ingredient aliases, category mapping, and estimated prices previously came only from hardcoded maps. | Partially mitigated | Fixed: service loads price/category config from Firestore `market_prices` and `local_foods` when available; item records carry `priceSource`, `priceSourceType`, `lastVerifiedDate`, and `isPrototypeEstimate`; UI labels fallback prices as prototype estimates. Still populate verified market config and move remaining fallback alias taxonomy to config when ready. | High |
| DI-016 | `lib/services/palengke_service.dart`, `lib/screens/main/weekly_palengke_list_screen.dart` | Weekly Grocery / Palengke List | Palengke item list and bought state previously lived only in screen/service memory. | No, resolved | Fixed: generated weekly list metadata and item `isBought` state persist to `users/{uid}/weekly_palengke_lists/{weekId}/items/{itemId}`. | High |
| DI-017 | `lib/config/engagement_config.dart`, `lib/services/engagement_service.dart`, `lib/services/firestore_service.dart`, `lib/models/badge_model.dart` | Leaderboard/Badges/Profile | Points, badge thresholds, badge names, descriptions, icons, leaderboard query/display limits, and ranking tie-break rules were hardcoded inside services. | Partially mitigated | Fixed: centralized rules in `EngagementConfig` as app-config product rules; existing weekly stats, badge awards, and leaderboard display still use real Firestore activity data; newly awarded badges persist `ruleSource: app_config_product_rules`. Still move to Firestore/Remote Config `badge_rules` / `engagement_rules` if rules need runtime updates. | High |
| DI-018 | `lib/screens/main/community_screen.dart:25`, `lib/screens/main/create_post_screen.dart:23` | Community | Community post categories/tabs are hardcoded: Trending, Market Finds, Q&A, Health Forums. | Yes | Use a `community_categories` config collection or remote config; keep labels aligned with Firestore queries. | High |
| DI-019 | `lib/screens/main/create_post_screen.dart:30` | Community / Create Post | Suggested tags are hardcoded: Recipe, Diet Tip, Fresh Find, Davao Local, Budget Meal, Healthy, Seasonal, Bankerahan. | Yes | Load tag taxonomy from Firestore/backend config, or derive suggestions from post text/NutriBot with user confirmation. | Medium |
| DI-020 | `lib/widgets/post_report_dialog.dart:67` | Community moderation | Report reasons are hardcoded. | Yes | Store report reason taxonomy in backend/Firestore config so moderation policy can change without app release. | Medium |
| DI-021 | `lib/services/firestore_service.dart`, `lib/models/post_model.dart`, `lib/providers/community_provider.dart` | Community likes | Likes stored as `likes` array on post document (not scalable). | No, resolved | Fixed: likes now use subcollection `posts/{postId}/likes/{uid}` with aggregate `likeCount`; legacy array preserved for migration compatibility; UI unchanged. | High |
| DI-022 | `lib/services/nutribot_service.dart:93`, `lib/services/nutribot_service.dart:173` | AI NutriBot | NutriBot falls back to canned `_mockResponse()` nutrition advice when the API stream fails. | Partially mitigated | Fallback copy is generic (no claim it used user data); system prompt now explicitly forbids saying applied/updated/saved and instructs the bot to tell the user to edit screens themselves. Still pending: route to a production backend AI endpoint with explicit error/offline handling rather than a client-side mock. | Medium |
| DI-023 | `lib/widgets/nutribot/nutribot_panel.dart:483` | AI NutriBot | NutriBot actions, suggestions, and Apply prompts are hardcoded per context AND the "Apply" button previously implied the bot was writing changes to feature state when it only sends a chat prompt. | No, resolved | Fixed: renamed Apply button to "Use Suggestion", renamed `applyPrompt` → `suggestionPrompt` / `onApply` → `onUseSuggestion`, rewrote every suggestion prompt so it asks for advice only, and added a visible disclaimer under the Suggestion card: "NutriBot gives advice only. It will not change your meal plan, meal log, or post." Writing to feature state is intentionally unsupported. Still pending (Level 3): if a future Apply-to-feature workflow is added it must require explicit user confirmation, validated inputs, and a real provider/Firestore write — and until then the disclaimer + system prompt must remain. | Medium |
| DI-024 | `lib/models/nutribot_models.dart:103` | AI NutriBot | Quick chips are hardcoded per source. | Partially mitigated | Quick chips / primary actions remain hardcoded product copy but their behaviour is now explicit: tapping only sends the string to the bot as a chat prompt; no write-to-feature-state happens. Labels already describe the question, not an action ("Improve my post", "Analyze this meal", etc.), so they are not misleading in the Suggestion-Only model. Still optional: move to remote config if iteration without app release is needed. | Low |
| DI-025 | `lib/screens/main/food_scanner_screen.dart` | Scanner/Pantry | Scanner parser previously fell back to `Food item`, `300` calories, time-based meal type, and price `0` when AI fields were missing. These values could be saved to Meal Log. | No, resolved | Fixed: missing/low-confidence required fields open a Review Scan sheet; scanner saves require confirmed food name, calories, meal type, and positive price. | High |
| DI-026 | `lib/screens/main/food_scanner_screen.dart:381`, `lib/screens/main/food_scanner_screen.dart:433` | Scanner/Pantry | Budget warnings use fallback daily budget PHP 150 if user budget is missing. | Sometimes | Require `user.dailyBudget` or skip budget warning with a setup prompt. Source: Firestore/user input. | Medium |
| DI-027 | `lib/services/groq_meal_narrative_service.dart:312` | Generated Recipe / Meal Log | If Groq recipe JSON parsing fails, generic recipe description and generic cooking steps are returned. | Yes | Show a retry/error state instead of saving generic instructions, or validate JSON response before displaying/saving. Source: backend AI response/user confirmation. | Medium |
| DI-028 | `lib/services/groq_meal_narrative_service.dart:263` | Generated Recipe | Missing ingredients are replaced with `common pantry items` in the recipe prompt. | Sometimes | Require meal ingredients or ask the user to confirm ingredients before recipe generation. Source: Meal Log/user input. | Medium |
| DI-029 | `lib/models/user_model.dart:25`, `lib/models/user_model.dart:27`, `lib/models/user_model.dart:61` | Profile / BMI / AI Meal Planner | User model defaults location, gender, height, weight, age, daily budget, and budget buffer when Firestore fields are missing. | Yes | Treat missing required profile fields as incomplete onboarding; prompt user to finish setup before BMI/planning. Source: Firestore/user input. | High |
| DI-030 | `lib/screens/onboarding/goal_screen.dart:117`, `lib/screens/onboarding/biometrics_screen.dart:17` | Profile setup / BMI | Goal selection writes default biometrics before the biometrics screen; biometrics sliders also start at static defaults. | Yes | Save goal independently, then save biometrics only after user confirmation. Source: user input. | High |
| DI-031 | `lib/screens/main/edit_profile_screen.dart:38` | Profile | Edit Profile falls back to default location/biometrics if user data is missing. | Yes | Show missing data states and require explicit user input instead of defaulting silently. Source: Firestore/user input. | Medium |
| DI-032 | `lib/screens/main/profile_screen.dart:100`, `lib/screens/main/user_profile_screen.dart:33` | Profile / Community profile | Profile UI uses fallback labels such as `Health Enthusiast`, `Davao City`, and `NutriMind user` when profile data is missing. | Yes | Use explicit loading/error/missing-profile states; avoid displaying fallback identity as real profile data. Source: Firestore/user input. | Medium |
| DI-033 | `lib/screens/main/profile_screen.dart:338`, `lib/screens/main/profile_screen.dart:353` | Profile settings | Budget UI falls back to PHP 150 if profile data is missing. | Yes | Require a real budget value or show setup state before saving/displaying budget controls. Source: Firestore/user input. | Medium |
| DI-034 | `lib/services/meal_planner_prompts.dart:6`, `lib/services/meal_planner_prompts.dart:33` | AI Meal Planner narratives | Groq prompt examples are hardcoded and ported from prototype wording. Not directly saved as data unless the model follows them too closely. | No direct data write | Tighten prompts around real basket data and remove prototype examples if outputs become repetitive. Source: backend prompt config. | Low |
| DI-035 | `lib/screens/auth/register_screen.dart:94`, `lib/data/load_food101.py:4` | Auth hints / dev script | Example name hint and Food-101 one-example loader are static but not production data. | No | No urgent fix. Keep hints harmless; move dev script out of `lib/` if cleanup is needed. | Low |
| DI-036 | `lib/screens/main/recipe_browser_screen.dart:204`, `lib/screens/main/recipe_browser_screen.dart:646` | Recipe Browser | Generic image placeholder appears when recipe image URL is missing or broken. | Yes | Acceptable UI fallback; optional replacement is a branded empty image asset or backend image quality checks. | Low |

---

## Findings By Feature

### Home / Dashboard

- Local food cards now load from Firestore `local_foods`; verified records and market price metadata still need to be populated.
- The AI Plan card now uses the signed-in user's `dailyBudget`.
- Home weekly-plan entry now opens the AI Meal Planner instead of generating static meals.

Recommended sources:

- Firestore `local_foods`, `market_prices`, and user profile budget fields.
- Meal Planner optimizer or backend meal plan API.

### Meal Log

- New users start with an empty Meal Log.
- Static weekly meal template generation has been removed.
- Meal Log itself is Firestore-backed once entries are created.

Recommended sources:

- Firestore `meal_logs` and `meal_plans`.
- User-confirmed AI Meal Planner output.

### AI Meal Planner

- Uses a labeled prototype Davao food dataset and calorie-only Food-101 fallback items.
- Requires completed profile and configured budget before plan generation; missing required fields show a Complete Profile First state.
- Loads a local academic sample recipe asset in the planner section, now clearly labeled as a prototype/non-production recipe dataset.

Recommended sources:

- Firestore `local_foods`, Firestore `market_prices`, or backend food/pricing API with verified source/date/vendor metadata.
- Required user profile data from Firestore.
- Production recipe backend/API.

### AI NutriBot

- Uses real context and Groq when configured.
- Falls back to canned responses when AI streaming fails.
- Actions/suggestions are static UI config and Apply actions do not persist changes.

Recommended sources:

- Backend AI endpoint.
- Structured feature context from Firestore/providers.
- Confirmed Apply actions that write to Firestore/backend.

### Scanner / Pantry

- Scanner saves real user/AI-derived entries to Meal Log.
- Scanner results with missing/low-confidence required fields must be reviewed before they can be saved to Meal Log.
- No pantry/scanned item persistence exists yet.

Recommended sources:

- User confirmation/manual input for missing scanner fields.
- Firestore `scanned_items` and `pantry_items`.
- Backend scanner/barcode API for packaged items only.

### Community

- No hardcoded sample Community posts, comments, fake users, fake likes, or fake followers found.
- Category tabs, create-post categories, suggested tags, and report reasons are hardcoded.
- Likes are real but stored in an array on the Community post document.

Recommended sources:

- Firestore `community_categories`, `community_tags`, moderation config, and likes subcollection.

### Profile

- Profile and UserModel contain fallback values for location, biometrics, budget, and display identity.
- Badges and leaderboard stats are backed by real activity records; points, thresholds, badge definitions, and ranking rules are centralized as app-config product rules.

Recommended sources:

- Firestore user profile fields with required onboarding completion.
- Firestore/backend badge definition config.

### Leaderboard / Badges

- No static leaderboard rows found.
- Points, badge thresholds, titles, descriptions, icons, ranking limits, and ranking tie-breaks are centralized in app config.

Recommended sources:

- Firestore `leaderboard_stats` for user activity.
- Firestore/backend `badges`, `badge_rules`, or `engagement_rules` config if runtime changes are needed.

### Notifications

- No mock notification feed found.
- Notifications are Firestore-backed and generated from user actions.
- Notification text templates are static, but they are not fake data.

Recommended sources:

- Firestore notifications for in-app state.
- Push/local notification backend if out-of-app alerts are required.

### Recipe Browser

- Recipe Browser calls a backend API.
- Recipe Browser shows backend/sample dataset disclosure in the UI.
- Backend blocks bundled sample recipe data in production unless `RECIPE_API_ALLOW_SAMPLE_DATA=true` is explicitly set.
- Release builds require `RECIPE_API_BASE_URL`; debug/profile builds can still use local development hosts.
- API recipe mapping consumes provided nutrition and price fields; missing prices show as unavailable instead of PHP `0`.

Recommended sources:

- Hosted backend recipe API/database with production data and licensing.
- Backend nutrition/cost fields.

### Weekly Grocery / Palengke List

- Generated from saved Meal Log ingredients.
- Generated from saved Meal Log ingredients.
- Price/category data loads from Firestore `market_prices` / `local_foods` when available.
- Prototype fallback prices/categories are clearly labeled when Firestore market config is missing.
- Generated weekly list metadata and item `isBought` state persist under `users/{uid}/weekly_palengke_lists/{weekId}`.

Recommended sources:

- Firestore `market_prices`, `local_foods`, `pantry_items`, and `users/{uid}/weekly_palengke_lists`.

---

## Recommended Replacement Sources

Firestore:

- user profile and onboarding fields
- `meal_logs`
- `meal_plans`
- `community_posts`
- `community_posts/{postId}/comments`
- `community_posts/{postId}/likes`
- `community_categories`
- `community_tags`
- `pantry_items`
- `scanned_items`
- `users/{uid}/weekly_palengke_lists`
- `users/{uid}/weekly_palengke_lists/{weekId}/items`
- `notifications`
- `badges`
- `badge_rules`
- `engagement_rules`
- `leaderboard_stats`
- `local_foods`
- `market_prices`

Local verified dataset:

- Davao/local food names, serving sizes, macro estimates, source notes, and market price snapshots.
- Offline fallback data only when versioned, sourced, and clearly marked.

Backend API:

- production recipe database
- nutrition and cost lookup
- NutriBot/AI endpoint
- barcode lookup for packaged/supermarket items
- market price sync/import jobs

User input:

- biometrics
- budget
- location
- scanner correction fields
- pantry item creation/editing
- post content/tags where not AI-suggested

---

## Next Task Checklist After Audit

- [x] Remove or disable automatic seeded default Meal Log entries for new users.
- [x] Replace `generateWeekMealPlan()` hardcoded templates with AI Meal Planner routing or a future `meal_plans` collection.
- [x] Replace Home `Favorite Local Foods` static cards with Firestore `local_foods`.
- [x] Fix the Home AI Plan card so budget copy uses the signed-in user's real `dailyBudget`.
- [x] Require completed profile/budget/biometrics before AI Meal Planner generation.
- [x] Label AI Meal Planner local Davao dataset as prototype-estimated and add source/date/prototype metadata fields.
- [ ] Populate Firestore `local_foods` / `market_prices` with verified Davao/local food records and source metadata.
- [ ] Decide production source for Davao foods, macros, and market prices.
- [x] Persist generated Weekly Grocery / Palengke List and item bought state.
- [x] Load Palengke price/category config from Firestore when available and label prototype fallback estimates.
- [ ] Populate verified `market_prices` / `local_foods` records and remove reliance on prototype Palengke fallback maps.
- [x] Label recipe sample datasets and guard local Recipe API/sample-data configuration.
- [ ] Replace AI Meal Planner local recipe asset with backend/Firestore recipe source.
- [ ] Configure Recipe Browser with a production backend URL and production recipe data.
- [x] Centralize badge definitions, points, thresholds, and ranking rules as app-config product rules.
- [ ] Move badge definitions, points, and thresholds into Firestore/backend config if runtime updates are required.
- [ ] Move Community categories, tags, and report reasons into Firestore/backend config if they need runtime changes.
- [ ] Add `community_posts/{postId}/likes/{uid}` and migrate away from likes arrays.
- [x] Prevent scanner fallback values from being saved without user review.
- [ ] Make NutriBot Apply actions write only after explicit confirmation and validation.

---

## Audit Notes

- `rg` found no `TODO` or `FIXME` markers in production Dart files.
- `rg` found no hardcoded sample Community post/comment list in production screens.
- `rg` found no static mock notification list in production screens.
- Several hardcoded values are valid UI copy or product taxonomy. They are listed when they are production-visible and likely to affect data integrity, filtering, moderation, recommendations, or persisted records.
