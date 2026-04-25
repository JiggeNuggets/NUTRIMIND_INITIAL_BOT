# NutriMind Agent Status

Last updated: 2026-04-25

This document tracks the implementation status of the NutriMind Flutter/Firebase app. A feature is marked finished only when it works with real app state, Firestore, Firebase Storage, or a real backend/API path. UI-only, seeded, in-memory, hardcoded, or prototype-backed work belongs in partially finished or unfinished sections.

---

## 1. Project Overview

NutriMind is a Flutter health and nutrition app for meal planning, Meal Log tracking, Davao/local food guidance, community sharing, and AI-assisted nutrition support.

Core product areas:

- Firebase Authentication, onboarding, profile setup, and biometrics.
- Home dashboard, Meal Log, AI Meal Planner, and local budget-aware planning.
- Food Scanner with camera/gallery/manual logging.
- Community posts with likes, comments, follows, reports, and notifications.
- Profile, badges, milestones, and weekly ranking data.
- NutriBot as a global AI assistant layer across app features.

Product direction:

- Replace remaining placeholders and hardcoded production UI data with Firestore, backend, or verified local datasets.
- Make NutriBot context-aware and eventually actionable across Home, Meal Planner, Meal Log, Scanner/Pantry, Community, and Profile.
- Keep the UI calm, consistent, and production-ready across all screens.

---

## 2. Current Tech Stack

- Flutter and Dart.
- Firebase Core initialization through `firebase_options.dart`.
- Firebase Authentication for email/password, password reset, Google sign-in, and auth state.
- Cloud Firestore for users, Meal Log entries, Community posts, comments, notifications, follow data, reports, badges, and weekly stats.
- Firebase Storage for profile images and Community post images.
- Provider / ChangeNotifier for app state: `AuthProvider`, `MealProvider`, `CommunityProvider`, `NotificationProvider`, and `NutriBotController`.
- Groq API for NutriBot chat, meal narratives, food image analysis, and generated recipe steps.
- `camera` and `image_picker` for food scanning and image upload.
- Local bundled prototype recipe dataset in Flutter assets, plus a FastAPI recipe backend under `backend/` with sample-data disclosure and production guards.
- Local Davao food data with estimated prices/macros in `lib/data/meal_planner_food_data.dart`.

---

## 3. Finished Features

- Firebase startup, `MaterialApp`, `ModernAppTheme`, and root Provider setup are implemented in `main.dart`.
- Authentication is backed by Firebase Auth and Firestore user documents: splash/auth gate, login, register, Google sign-in, password reset, and user document creation.
- User profile setup saves goal and confirmed biometric data such as gender, height, weight, and age; planner-specific generation requires completed profile and configured budget flags.
- Main shell navigation exists with Home, Meal Log, Community, Profile, and a center Food Input Hub action.
- Home dashboard reads real user and Meal Log state through providers; today's Meal Log section includes loading, empty, and error UI.
- Home local food recommendations read from Firestore `local_foods` with loading, empty, and error UI instead of static cards.
- Home AI Plan budget copy uses the signed-in user's `dailyBudget`.
- Meal Log is Firestore-backed under `users/{uid}/meals`; it starts empty for new users and supports selected-date loading, manual/scanned/planned/recipe entries, deletion, and saved generated recipes/cooking steps.
- Scan Options / Food Input Hub lets users choose Scan Meal, Add Pantry Item, Barcode Scan placeholder, or Manual Meal Log instead of sending every center-button tap to one scanner flow.
- Food Scanner supports camera preview, gallery fallback, Groq vision analysis, parser output, manual entry, and save-to-Meal-Log; missing, generic, or low-confidence scanner fields require review before saving.
- Pantry items are Firestore-backed under `users/{uid}/pantry_items`; users can add, edit, delete, and list manual pantry/palengke items with loading, empty, and error states.
- NutriBot has a reusable `NutriBotPanel`, `NutriBotController`, context prompts, fixed input, Groq-backed chat, and safe local fallback responses.
- NutriBot entry points exist for Home, Meal Log, AI Meal Planner, Food Scanner, Community post flows, Profile, and Recipe Browser.
- Community posts are Firestore-backed in the current `posts` collection; the feature supports categories, feed loading, create Community post, image upload, detail view, comments, delete controls, author profile navigation, follow/unfollow, and notifications.
- Community likes use `posts/{postId}/likes/{uid}` with an aggregate `likeCount`; legacy `likes[]` data is kept only for compatibility/migration fallback.
- Community post reporting exists through `posts/{postId}/reports/{reporterId}` and posts can move to `underReview` after the report threshold.
- Notifications are Firestore-backed under `users/{uid}/notifications`; unread counts, mark read/all read, delete, community notifications, and Meal Planner reminder records exist.
- Profile screen uses real user data for profile details, BMI, budget/buffer/local settings, Firestore-backed badges, and Firestore-backed weekly ranking stats.
- Engagement activity writes weekly stats and badges under `users/{uid}/weeklyStats` and `users/{uid}/badges` from real app actions.
- Weekly Grocery / Palengke List generates from saved Meal Log ingredients and persists weekly list items plus bought state under `users/{uid}/weekly_palengke_lists`.
- Firebase Storage uploads exist for profile images and Community post images.
- `state_views.dart` provides reusable loading, empty, error, and offline-aware UI components (`LoadingStateView`, `EmptyStateView`, `ErrorStateView`, `InlineErrorStateCard`) with an `isOfflineError` heuristic that detects `SocketException`, Firestore `unavailable`/`network-request-failed`/`deadline-exceeded`, and common web/network failure strings.
- Home, Meal Log, Community feed, Profile badges, Profile weekly ranking, and Notifications all render on-screen loading/empty/error states with retry buttons using the shared components. Retry reruns the underlying Firestore listener or stream subscription.

---

## 4. Partially Finished Features

- AI Meal Planner / DSS: profile and budget validation is real, BMR/budget computation works, and selected baskets can be saved to Meal Log. It is still partial because local Davao foods, prices, macros, and calorie fallback rows are prototype estimates, not verified production data.
- Home local food data source: UI reads Firestore `local_foods`, but the collection still needs sourced, verified production records and market-price governance.
- Weekly plan history: static template generation was removed; a dedicated `meal_plans` collection/history flow still needs to be added if weekly plans should persist separately from Meal Log entries.
- Weekly Grocery / Palengke List: generated from saved Meal Log ingredients, persists bought state to Firestore, and can use Firestore market config. It is still partial because fallback aliases, prices, and categories remain prototype estimates until verified `market_prices` / `local_foods` records are complete.
- Notifications: Firestore in-app records work, but push notifications and scheduled local notifications are not implemented.
- Badges and weekly ranking: backed by real activity counters, but badge definitions, points, thresholds, and ranking rules are app-config product rules rather than Firestore/Remote Config.
- Scanner/Pantry: scanner can save reviewed results to Meal Log, confirmed scans persist to `users/{uid}/scanned_items`, and manual pantry items persist to Firestore. It is still partial because scan image upload/image URL, confidence mapping, pantry-to-planner usage, and packaged-item barcode flow are missing.
- Meal Swap: Meal Log meals have a confirmed Swap flow with Cheaper, Higher Protein, and Lower Calorie alternatives from the existing planner food dataset. It is still partial because swap alternatives use prototype local prices/macros and do not yet update an unsaved AI Planner selected plan.
- Recipe Browser: UI/service path exists and sample/prototype data is disclosed, but production backend hosting, verified recipe data, and complete price/macro mapping are not wired.
- Async states: reusable state components are applied to Home, Meal Log, Community, Profile (badges + weekly ranking), and Notifications. Still missing on NutriBot retry, Recipe Browser detail flows, Edit Profile, Generated Recipe screen, create-post submit failures, and other modal/detail flows.
- NutriBot Apply actions: context-aware chat works, but Apply-to-feature-state is not implemented. The current "Use Suggestion" path is advice-only and does not write to Firestore or feature state.
- Community moderation: report storage and `underReview` status exist, but there is no admin/moderator review queue.
- Legacy data cleanup: Community uses the current `posts` collection, not `community_posts`; legacy `likes[]` may still exist on older documents for migration compatibility.

---

## 5. Unfinished / Needs Improvement

### Data Layer

- Populate verified `local_foods` and `market_prices` records with source, source type, verification date, serving size, macros, and active/status flags.
- Replace prototype Davao/local food prices, macros, serving sizes, and ingredient assumptions before relying on them for production recommendations.
- Back Meal Swap alternatives with verified `local_foods` / `market_prices` records before treating swap recommendations as production nutrition or price guidance.
- Replace prototype recipe assets and backend sample recipe files with verified, licensed recipe/nutrition data before production release.
- Replace Palengke fallback alias, price, and category maps with verified Firestore/backend market config.
- Add scan image upload/image URL, confidence mapping, and optional reuse-to-log flow for Scan History; connect pantry items to planning where appropriate.
- Add a dedicated `meal_plans` collection/history flow if generated weekly plans must be revisited separately from saved Meal Log entries.
- Harden non-planner profile/default fallbacks so missing user fields do not silently look like confirmed profile data.
- Add a clear migration path from `posts` to `community_posts` if the collection is renamed.

### Backend / Config

- Configure a production Recipe API endpoint and prevent production builds from depending on local sample files.
- Move engagement product rules to Firestore/Remote Config if points, badges, milestones, or ranking policy need runtime updates.
- Move Community taxonomy/report reasons and Palengke market config to backend/Firestore config if product staff need to edit them without a release.
- Add collection constants/repositories for the final Firestore naming plan.
- Add backend support for push or scheduled notifications if out-of-app reminders are required.

### UI/UX

- Apply loading, empty, error, and offline states to every async screen and detail flow.
- Finish a UI consistency pass across older screens that still mix `AppTheme` and newer design patterns.
- Improve Scanner/Pantry scanned result history, reviewed scan editing, and pantry-to-planner flows.
- Add supermarket barcode scanning only for packaged/supermarket items.
- Keep palengke and wet-market items manual or category-based because many do not have reliable barcodes.
- Add moderator/admin affordances for reviewing reported or `underReview` Community posts.
- Add clear retry/error affordances to NutriBot chat failures and form-submission failures.

### AI / NutriBot

- Keep NutriBot advice-only until confirmed write workflows are implemented.
- Upgrade NutriBot from context-aware chat to actionable assistance that can safely apply edits to forms, drafts, meal plans, and logs.
- Pass structured screen context into NutriBot consistently: user goal, budget, selected date, Meal Log entries, scanned result, Community draft, recipe, or profile data.
- Add safe confirmation steps before NutriBot writes to Firestore or modifies user-entered content.
- Keep AI outputs grounded in app data and verified local food data instead of placeholders.

### Performance / Scalability

- Add pagination and Firestore indexes where feeds, comments, rankings, or history screens can grow large.
- Avoid unbounded listeners for large collections.
- Backfill or clean legacy Community `likes[]` data after the subcollection migration is fully verified.
- Add integration/widget tests around auth, Meal Log, scanner saves, Community post creation, NutriBot panel, notifications, and engagement.

### Security / Privacy

- Keep Groq/API keys out of source code and client builds; use secure backend or environment configuration.
- Review Firestore security rules for users, Meal Log entries, Community posts, comments, reports, notifications, badges, and ranking stats.
- Protect nutrition, biometrics, budget, and profile data from unintended public reads.
- Add moderation and reporting review flow before reported Community posts are hidden, restored, or removed.

---

## 6. Data / Firestore Collections Needed

### Already Used In Code

- `users/{uid}`: user account/profile record. Example fields: `uid`, `email`, `displayName`, `photoUrl`, `goal`, `gender`, `height`, `weight`, `age`, budget/local settings, timestamps.
- `users/{uid}/meals/{mealId}`: Meal Log entry. Example fields: `name`, `mealType`, `calories`, `price`, `date`, `createdAt`, `protein`, `carbs`, `fat`, `ingredients`, `source`, `recipe`, `cookingSteps`.
- `users/{uid}/notifications/{notificationId}`: in-app notification. Example fields: `type`, `title`, `body`, `read`, `createdAt`, `sourceUserId`, `postId`.
- `users/{uid}/followers/{followerUid}` and `users/{uid}/following/{targetUid}`: follow graph records. Example fields: `userId`, `createdAt`.
- `users/{uid}/badges/{badgeId}`: earned badge record. Example fields: `badgeId`, `title`, `description`, `icon`, `earnedAt`, `sourceAction`, `ruleSource`.
- `users/{uid}/weeklyStats/{weekId}`: leaderboard/engagement record. Example fields: `weekId`, `points`, `mealsLogged`, `postsCreated`, `commentsCreated`, `streakDays`.
- `users/{uid}/pantry_items/{itemId}`: manual pantry ingredient record. Example fields: `name`, `quantity`, `unit`, `category`, `source`, `isPalengkeItem`, `createdAt`, `updatedAt`.
- `users/{uid}/scanned_items/{scanId}`: confirmed scan history record. Example fields: `name`, `calories`, `price`, `mealType`, `imageUrl`, `source`, `confidence`, `createdAt`, `updatedAt`.
- `users/{uid}/weekly_palengke_lists/{weekId}`: persisted generated grocery list. Example fields: `weekId`, `weekStart`, `weekEnd`, `itemCount`, `boughtCount`, `totalEstimatedPricePhp`, `usesPrototypeEstimates`, `usingFirestoreMarketConfig`, `updatedAt`.
- `users/{uid}/weekly_palengke_lists/{weekId}/items/{itemId}`: persisted Palengke item state. Example fields: `name`, `normalizedName`, `estimatedPricePhp`, `marketCategory`, `isBought`, `sourceMealIds`, `priceSource`, `priceSourceType`, `lastVerifiedDate`, `isPrototypeEstimate`.
- `local_foods/{foodId}`: Home and planner local food source. Example fields: `name`, `category`, `tag`, `pricePhp`, `unit`, `priceLabel`, `emoji`, `isActive`, `source`, `sourceType`, `lastVerifiedDate`, `isPrototypeEstimate`, `updatedAt`.
- `posts/{postId}`: Community post storage. Example fields: `userId`, `userName`, `userPhotoUrl`, `location`, `content`, `category`, `likes[]` (legacy, for migration), `likeCount` (aggregate from subcollection), `commentCount`, `imageUrl`, `createdAt`, `tags`, `reportCount`, `moderationStatus`, `isHiddenByModeration`.
- `posts/{postId}/comments/{commentId}`: Community post comment. Example fields: `userId`, `userName`, `userPhotoUrl`, `content`, `createdAt`.
- `posts/{postId}/likes/{uid}`: Community post like (scalable subcollection). Example fields: `uid`, `createdAt`.
- `posts/{postId}/reports/{reporterId}`: Community post report. Example fields: `reporterId`, `reason`, `details`, `createdAt`, `status`.

### Planned / Recommended Collections

- `user_profiles`
- `meal_logs`
- `meal_plans`
- `community_posts`
- `community_posts/{postId}/comments`
- `community_posts/{postId}/likes`
- `community_posts/{postId}/reports`
- `notifications`
- `badges`
- `badge_rules`
- `engagement_rules`
- `leaderboard_stats`
- `local_foods`
- `market_prices`: planned production market-price/config source for local foods and Palengke List. Example fields: `name`, `normalizedName`, `aliases`, `marketCategory`, `estimatedPricePhp`, `unit`, `source`, `sourceType`, `lastVerifiedDate`, `isPrototypeEstimate`, `isActive`.
- `recipes`: planned production recipe source. Example fields: `name`, `ingredients`, `ingredientLines`, `calories`, `protein`, `carbs`, `fat`, `estimatedPricePhp`, `servings`, `source`, `sourceType`, `license`, `lastVerifiedDate`, `isPrototypeDataset`.

### Naming And Migration Notes

- The app feature should be called Community posts in product/UI documentation.
- The current Firestore collection is `posts`; do not rename it casually without a migration.
- Recommended migration: add repository constants, backfill `posts` into `community_posts` with the same IDs, update security rules/indexes, dual-read during transition, then remove old reads after verification.
- **DI-021 RESOLVED**: Likes migrated from `posts/{postId}/likes[]` array to `posts/{postId}/likes/{uid}` subcollection with aggregate `likeCount` field. Legacy `likes[]` array preserved for backward compatibility during migration. New FirestoreService methods: `toggleLike()`, `isPostLikedBy()`, `getLikeCount()`, `likeCountStream()`.
- Pantry item storage now exists under `users/{uid}/pantry_items`; confirmed scan history now exists under `users/{uid}/scanned_items`.
- Meal plans are stored as Meal Log documents today; a separate `meal_plans` collection would make weekly plan history clearer.

---

## 7. AI NutriBot Current Goal

NutriBot should be one global assistant, not a separate chatbot feature.

Connected areas:

- Home
- Meal Planner
- Meal Log
- Scanner/Pantry
- Community
- Profile
- Recipe Browser

Capability levels:

- Level 1 - Chat: done. Users can ask questions and receive advice.
- Level 2 - Context-aware: done. NutriBot receives screen/app context and gives targeted advice.
- Level 3 - Actionable: safe / limited. Today this is advice-only; no NutriBot action writes to Firestore, providers, or feature state.

Current level: Level 2 with an advice-only ceiling on Level 3 actions. The current "Use Suggestion" path sends a chat prompt only. The visible disclaimer says NutriBot will not change the meal plan, Meal Log, or Community post, and the system prompt forbids claims that it saved, updated, or applied changes.

Target level: Level 3. If Apply-to-feature-state is later added, every real-write action must:

- present an explicit confirmation dialog that shows the exact change,
- validate inputs before writing; calories, price, portions, and nutrition fields must come from trusted sources, not assumed from AI output,
- use existing provider/service paths such as `MealProvider.addManualMeal` or `CommunityProvider.createPost`; never use a bespoke write path,
- stay off in contexts where the bot does not have verified data for the affected fields.

---

## Data Integrity Status

Fully resolved:

- Seeded/default Meal Log entries and hardcoded weekly meal templates are removed.
- New users start with an empty Firestore-backed Meal Log.
- Scanner save flow blocks generic, missing, or low-confidence AI values until the user reviews and confirms them.
- AI Meal Planner blocks generation until daily budget, age, gender, height, and weight are confirmed.
- Home local food cards load from Firestore `local_foods` with loading, empty, and error states.
- Community posts, comments, follows, reports, notifications, and scalable likes are Firestore-backed.
- Weekly Palengke List generated items and bought state persist to Firestore.
- Manual Pantry items persist to Firestore with add, edit, delete, list, empty, loading, and error states.
- Confirmed scanner saves persist to Scan History with list, empty, error, retry, and delete states.
- Meal Swap requires user confirmation before replacing a Meal Log meal and does not claim unavailable alternatives.
- Engagement activity writes weekly stats and earned badges from real app actions.
- NutriBot is advice-only and does not fake saved, updated, or applied actions.

Remaining:

- `local_foods` and `market_prices` still need verified production Davao/local records.
- Local Meal Planner foods, recipe assets, and Palengke fallback maps remain prototype/sample datasets with disclosure.
- Meal Swap alternatives still depend on the prototype Meal Planner dataset.
- Production Recipe API/data source is not complete.
- Scan History image URL/confidence enrichment, packaged-item barcode flow, push notifications, moderation queue, and dedicated meal plan history are not complete.
- Engagement, Community taxonomy, and Palengke rules are app-config or fallback config, not fully remote-configurable.
- Firestore rules, API key handling, pagination/indexes, and test coverage still need a release review.

Overall readiness: suitable for prototype/demo or academic defense with clear dataset disclosures; not production-ready for live market-price, medical, or fully automated AI-write claims.

---

## 8. Rules for Future Development

- Do not add fake data to production screens.
- No hardcoded UI data in production screens.
- Every async screen must have loading, empty, error, and offline states.
- All user actions must persist to Firestore or a backend when persistence is expected.
- Keep UI design consistent with the modern NutriMind design system.
- Do not break navigation or existing route entry points.
- Do not remove existing working features unless explicitly requested.
- Use real Firebase data when possible.
- Keep code clean and simple; prefer existing Provider/service patterns.
- Keep Groq/API keys out of source code and client builds.
- Keep palengke/wet-market flow manual or category-based unless reliable barcode data exists.
- List changed files after every task.

---

## 9. Next Priority Checklist

### Phase 1: Data Integrity Remaining

- [ ] Populate and validate Firestore `local_foods` / `market_prices` with sourced Davao/local food records, macros, serving sizes, and verification dates.
- [ ] Repoint Meal Swap alternatives to verified local food/market data and add selected-plan swapping if needed.
- [ ] Replace prototype recipe assets/backend sample files with verified production recipe data and a production Recipe API endpoint.
- [ ] Replace remaining prototype Palengke alias, price, and category fallback maps with verified market config.
- [ ] Add scan image upload/image URL, confidence mapping, and optional reuse-to-log flow for Scan History; decide how pantry items should feed Meal Planner/Palengke flows.
- [ ] Add a dedicated `meal_plans` collection/history flow if generated plans must be revisited outside Meal Log entries.
- [ ] Define collection constants and target schemas for Meal Log, meal plans, Community posts, pantry items, scanned items, notifications, badges, and leaderboard stats.
- [ ] Backfill or clean legacy Community `likes[]` data after the likes subcollection migration is verified.
- [ ] Move engagement rules, Community taxonomy/report reasons, and Palengke market config to Firestore/Remote Config if runtime editing is needed.
- [ ] Harden profile/default fallbacks so missing user data never appears as confirmed production data.

### Phase 2: UX Stability

- [ ] Extend loading/empty/error/offline states to NutriBot retry, Recipe Browser detail, Edit Profile, Generated Recipe screen, create-post submit failures, and remaining modal/detail flows.
- [ ] Consolidate local state-message variants to use `lib/widgets/state_views.dart` where safe.
- [ ] Improve Scanner/Pantry reviewed scan editing, scanned history, and pantry-to-planner flow.
- [ ] Add supermarket barcode scanning for packaged items only.
- [ ] Keep palengke/wet-market item entry manual or category-based.
- [ ] Complete a final UI consistency pass across all screens.


### Phase 3: AI Integration

- [ ] Make NutriBot fully global with structured context from every major feature.
- [ ] Add safe Apply workflows for post improvement, meal plan edits, scanned result edits, and Meal Log suggestions.
- [ ] Require user confirmation before NutriBot writes to Firestore/backend.
- [ ] Keep NutriBot recommendations grounded in real app data and verified local food records.
- [ ] Add chat retry/offline handling and clearer AI failure states.

### Phase 4: Advanced Features

- [ ] Add real push/local notifications if out-of-app reminders are required.
- [ ] Move leaderboard, badge, milestone, and point rules from app config to Firestore/Remote Config if product needs runtime tuning.
- [ ] Add pagination and Firestore indexes for growing feeds, comments, rankings, and history screens.
- [ ] Add integration/widget tests for auth, Meal Log, Community posts, scanner saves, notifications, NutriBot, and engagement.
- [ ] Review Firestore rules, privacy, API key handling, and sensitive health-data access before release.

---

## 10. Known Risks

- Hardcoded data remains in non-planner profile fallback values, prototype Palengke fallback maps, and some product taxonomy/config.
- Badge/ranking rules are centralized in app config and labeled with `ruleSource`, but are not yet remotely configurable.
- Recipe sample paths are now disclosed and guarded, but production still needs verified recipe data and a hosted Recipe API configuration.
- Firestore `local_foods` may be empty or unverified until production records are added; the bundled planner dataset is explicitly labeled as prototype estimates.
- UI theme usage is inconsistent in older screens.
- Offline handling is now surfaced via `ErrorStateView` + `isOfflineError` heuristic on primary data-driven screens, but coverage is not complete across every async flow (chat, detail screens, form submissions).
- NutriBot is context-aware but does not yet write safe, confirmed changes back to the app.
- Local Davao food prices and macros are estimates and need verification before production reliance.
- Legacy Community `likes[]` arrays may remain on older documents until migration cleanup, but active like writes use a likes subcollection with aggregate `likeCount`.
- API key and AI backend handling need a production security review.

---

## 11. Definition of Done

A feature is done only if:

- It uses real data from Firestore, Firebase Storage, backend APIs, or verified local datasets.
- It has loading, empty, error, and offline states for async flows.
- User actions persist to Firestore or backend when persistence is expected.
- It works across navigation and does not break existing routes.
- It contains no hardcoded placeholders or fake production UI data.
- It follows the current NutriMind UI/design system.
- It has been manually tested on the relevant flow.
- Changed files are listed after the task.

---

## Verification Notes

- This file reflects code inspected on 2026-04-25.
- Phase 1 data cleanup on 2026-04-25 removed seeded/default meals, removed hardcoded weekly templates, switched Home budget copy to `user.dailyBudget`, moved Home local foods to Firestore `local_foods`, removed the inactive local-food View All control, and centralized Community config.
- Scanner fallback cleanup on 2026-04-25 removed saveable defaults for missing AI fields and added required Review Scan confirmation before saving incomplete scanner results.
- AI Meal Planner profile validation on 2026-04-25 removed generation fallbacks for PHP 150, age 28, weight 64 kg, height 168 cm, and assumed male profile data; incomplete users now see Complete Profile First UI.
- Local Davao food dataset governance on 2026-04-25 added source/prototype metadata and UI disclosure that planner prices/macros are prototype estimates, not live market prices.
- Recipe dataset/backend cleanup on 2026-04-25 labeled sample recipe data as prototype/non-production, added release guards for `RECIPE_API_BASE_URL`, added backend sample-data disclosure/production blocking, and stopped showing missing recipe prices/macros as real values.
- Weekly Grocery / Palengke List cleanup on 2026-04-25 added Firestore persistence for generated weekly lists and bought state, reads Firestore market config when available, and labels fallback prices/categories as prototype estimates.
- Engagement rules cleanup on 2026-04-25 centralized points, counter fields, badge definitions, badge thresholds, leaderboard limits, and ranking tie-breaks in `lib/config/engagement_config.dart`; newly awarded badges persist `ruleSource`.
- Community audit on 2026-04-25 confirmed no hardcoded users, posts, comments, likes, follower counts, badges, or leaderboard values remain; feed, author profile, likes, comments, follows, badges, and weekly ranking all read/write through `FirestoreService` and `EngagementService`.
- Shared async states on 2026-04-25 added `lib/widgets/state_views.dart` (`LoadingStateView`, `EmptyStateView`, `ErrorStateView`, `InlineErrorStateCard`, `isOfflineError`) and wired it into Home (today's meals loading/error), Meal Log body (on-screen error with retry), Community feed (on-screen error with retry when feed is empty), Profile badges + weekly ranking (inline error card with retry that restarts the Firestore stream), and Notifications (error with retry). Retry buttons reuse the provider's existing `listenTo...` methods or bump a key on the stream.
- Phase 2 Pantry + Scanner Hub on 2026-04-25 added a center Food Input Hub, kept AI Scan Meal and Manual Meal Log flows working, added Barcode Scan as a coming-soon placeholder only, and added Firestore-backed manual pantry items under `users/{uid}/pantry_items`.
- Phase 2 Scanner History on 2026-04-25 added Firestore-backed confirmed scan history under `users/{uid}/scanned_items`; scanner validation remains unchanged and history writes only after confirmed scanner saves.
- Phase 2 Meal Swap on 2026-04-25 added confirmed Meal Log replacement using Cheaper, Higher Protein, and Lower Calorie alternatives from the existing Meal Planner dataset; prototype price/macro disclosure remains required.
- `flutter analyze` passed on 2026-04-25 with no issues found for the state-view files and all touched screens.
