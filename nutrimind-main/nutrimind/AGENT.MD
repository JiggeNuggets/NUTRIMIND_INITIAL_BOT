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
- Main shell navigation exists with Home, Meal Log, Community, Profile, and a center Food Scanner action.
- Home dashboard reads real user and Meal Log state through providers; today's Meal Log section includes loading, empty, and error UI.
- Home local food recommendations read from Firestore `local_foods` with loading, empty, and error UI instead of static cards.
- Meal Log is Firestore-backed under `users/{uid}/meals`; it starts empty for new users and supports selected-date loading, manual/scanned/planned/recipe entries, deletion, and saved generated recipes/cooking steps.
- AI Meal Planner computes BMR targets only after required profile/budget fields are complete, uses budget constraints, consumes labeled prototype local Davao food candidates, generates AI narratives, and can save selected baskets into Meal Log.
- Food Scanner supports camera preview, gallery fallback, Groq vision analysis, parser output, manual entry, and save-to-Meal-Log; missing/low-confidence scanner fields require review before saving.
- NutriBot has a reusable `NutriBotPanel`, `NutriBotController`, context prompts, fixed input, Groq-backed chat, and local fallback responses.
- NutriBot entry points exist for Home, Meal Log, AI Meal Planner, Food Scanner, Community post flows, Profile, and Recipe Browser.
- Community posts are Firestore-backed in the current `posts` collection; the feature supports categories, feed loading, create post, image upload, detail view, comments, likes, delete controls, author profile navigation, follow/unfollow, and notifications.
- Community post reporting exists through `posts/{postId}/reports/{reporterId}` and posts can move to `underReview` after the report threshold.
- Notifications are Firestore-backed under `users/{uid}/notifications`; unread counts, mark read/all read, delete, community notifications, and Meal Planner reminder records exist.
- Profile screen uses real user data for profile details, BMI, budget/buffer/local settings, Firestore-backed badges, and Firestore-backed weekly ranking stats.
- Engagement activity writes weekly stats and badges under `users/{uid}/weeklyStats` and `users/{uid}/badges`.
- Firebase Storage uploads exist for profile images and Community post images.
- `state_views.dart` provides reusable loading, empty, error, and offline-aware UI components (`LoadingStateView`, `EmptyStateView`, `ErrorStateView`, `InlineErrorStateCard`) with an `isOfflineError` heuristic that detects `SocketException`, Firestore `unavailable`/`network-request-failed`/`deadline-exceeded`, and common web/network failure strings.
- Home, Meal Log, Community feed, Profile badges, Profile weekly ranking, and Notifications all render on-screen loading/empty/error states with retry buttons using the shared components. Retry reruns the underlying Firestore listener or stream subscription.

---

## 4. Partially Finished Features

- Home local food data source: UI now reads Firestore `local_foods`, but the collection still needs verified production records and market-price governance.
- Weekly plan history: static template generation was removed; a dedicated `meal_plans` collection/history flow still needs to be added if weekly plans should persist separately from Meal Log entries.
- Weekly Grocery & Palengke List: generated from saved Meal Log ingredients, persists bought state to Firestore, and can use Firestore market config; verified production market data still needs to be populated.
- Notifications: Firestore in-app records work, but push notifications and scheduled local notifications are not implemented.
- Badges and weekly ranking: backed by real activity counters; badge definitions, points, thresholds, and ranking rules are centralized as app-config product rules.
- Scanner/Pantry: scanner can save reviewed results to Meal Log, but pantry persistence, scanned item history, edit/delete pantry flows, and barcode flow are missing.
- Recipe Browser: UI/service path exists and sample/prototype data is disclosed, but production backend hosting and verified recipe data are not wired.
- Async states: reusable state components are now applied to Home, Meal Log, Community, Profile (badges + weekly ranking), and Notifications. Still missing on: NutriBot panel (chat error is inline-only, no retry affordance), Recipe Browser detail flows, Weekly Palengke List (uses its own variant), Edit Profile, Generated Recipe screen, create-post submit failures, and other modal/detail flows.
- NutriBot actions: context-aware chat works. The old "Apply" button has been renamed to "Use Suggestion" and is now explicitly Advice-Only — it sends a chat prompt, the bot replies as text, and nothing is written to Firestore or feature state. A disclaimer ("NutriBot gives advice only. It will not change your meal plan, meal log, or post.") is visible under the Suggestion card, and the system prompt forbids the bot from claiming it applied/updated/saved anything. A future Level-3 Apply-to-feature-state workflow is not implemented yet.
- Community post likes: implemented as an array on the Community post document; needs a scalable likes subcollection.
- Community moderation: report storage exists, but there is no admin/moderator review queue.

---

## 5. Unfinished / Needs Improvement

### Data Layer

- Continue replacing remaining hardcoded production data and fallbacks with Firestore, backend, or verified local datasets.
- Populate verified Weekly Grocery / Palengke List market config and compare estimated total cost with user budget.
- Add dedicated `pantry_items` and `scanned_items` storage for Scanner/Pantry history.
- Replace prototype Davao/local food prices, macros, serving sizes, and ingredient assumptions with verified Firestore/backend records before relying on them for production recommendations.
- Replace prototype recipe assets and backend sample recipe files with verified, licensed recipe/nutrition data before production release.
- Move engagement product rules from app config to Firestore/Remote Config if points, badges, milestones, or ranking policy need runtime updates.
- Add a clear migration path from `posts` to `community_posts` if the collection is renamed.

### UI/UX

- Apply loading, empty, error, and offline states to every async screen and detail flow.
- Finish a UI consistency pass across older screens that still mix `AppTheme` and newer design patterns.
- Improve Scanner/Pantry navigation, manual entry, scanned result review, edit/delete flows, and pantry item management.
- Add supermarket barcode scanning only for packaged/supermarket items.
- Keep palengke and wet-market items manual or category-based because many do not have reliable barcodes.
- Add moderator/admin affordances for reviewing reported or `underReview` Community posts.

### AI / NutriBot

- Upgrade NutriBot from context-aware chat to actionable assistance that can safely apply edits to forms, drafts, meal plans, and logs.
- Pass structured screen context into NutriBot consistently: user goal, budget, selected date, Meal Log entries, scanned result, Community draft, recipe, or profile data.
- Add safe confirmation steps before NutriBot writes to Firestore or modifies user-entered content.
- Keep AI outputs grounded in app data and verified local food data instead of placeholders.

### Performance / Scalability

- Replace Community post like arrays with `community_posts/{postId}/likes/{uid}` and maintain aggregate `likeCount`.
- Add pagination and Firestore indexes where feeds, comments, rankings, or history screens can grow large.
- Avoid unbounded listeners for large collections.
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
- `pantry_items`
- `scanned_items`
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
- Pantry and scanned item collections do not exist yet.
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

- Level 1 - Chat only ✅: user asks questions; assistant replies without app context.
- Level 2 - Context-aware ✅: assistant receives screen/app context and gives targeted advice.
- Level 3 - Actionable (safe / limited): assistant can apply confirmed changes to forms, drafts, Meal Log entries, meal plans, or settings. **Currently OFF by design.** No NutriBot action writes to Firestore, providers, or feature state. The former "Apply" button is now "Use Suggestion" (advice only) with a visible disclaimer; the system prompt explicitly forbids the bot from claiming it applied / updated / saved anything.

Current level: Level 2 with an advice-only ceiling on Level 3 actions.

Target level: Level 3. If Apply-to-feature-state is later added, every real-write action must:

- present an explicit confirmation dialog that shows the exact change,
- validate inputs before writing (calories, price, portions, etc. must come from trusted sources, not assumed from AI output),
- use the existing provider/service paths (e.g. `MealProvider.addManualMeal`, `CommunityProvider.createPost`) — never a bespoke write,
- stay OFF in contexts where the bot does not have verified data for the affected fields.

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

### Phase 1: Data Integrity

- [x] Audit current screens and identify remaining hardcoded data.
- [x] Remove seeded/default Meal Log entries, remove hardcoded weekly meal templates, replace Home budget copy with the user's budget, and move Home local food cards to Firestore `local_foods`.
- [x] Centralize Community categories, suggested tags, and report reasons as app config while keeping Firestore-backed Community data flows intact.
- [x] Prevent scanner fallback values from being saved to Meal Log without user review.
- [x] Block AI Meal Planner generation until daily budget, age, gender, height, and weight are confirmed in user profile data.
- [x] Add source/prototype metadata to the local Davao planner dataset and label planner prices/macros as prototype estimates.
- [x] Label recipe sample datasets, guard release Recipe API configuration, and avoid presenting missing recipe price/macros as real values.
- [x] Persist Weekly Grocery / Palengke List generated items and bought state to Firestore.
- [x] Prefer Firestore `market_prices` / `local_foods` for Palengke price/category config and label prototype fallbacks.
- [x] Centralize engagement points, badge definitions, thresholds, and leaderboard ranking rules as app-config product rules.
- [ ] Populate and validate Firestore `local_foods` / `market_prices` with sourced Davao/local food records.
- [ ] Replace prototype recipe assets/backend sample files with verified production recipe data.
- [ ] Define collection constants and target schemas for Meal Log, meal plans, Community posts, pantry items, scanned items, notifications, badges, and leaderboard stats.
- [ ] Migrate Community post likes from array storage to a likes subcollection.
- [ ] Wire Davao/local food prices and macros into the optimizer with validated source notes.
- [ ] Replace remaining prototype Palengke alias/price/category fallback maps with verified market config.

### Phase 2: UX Stability

- [x] Ship reusable loading/empty/error/offline state components (`lib/widgets/state_views.dart`).
- [x] Apply states to Home (today's meals), Meal Log, Community feed, Profile badges, Profile weekly ranking, and Notifications — with retry on error.
- [ ] Extend states to NutriBot (retry last prompt), Recipe Browser detail, Edit Profile, Generated Recipe screen, create-post submit failure path, and remaining modal/detail flows.
- [ ] Consolidate local variants (`_StateBox`, `_StateMessage`, `_buildStateMessage`, `_recipeStateBox`, `_emptyMilestoneBox`) to use the shared components where safe.
- [ ] Improve Scanner/Pantry flow and add supermarket barcode scanning for packaged items only.
- [ ] Keep palengke/wet-market item entry manual or category-based.
- [ ] Complete a final UI consistency pass across all screens.

### Phase 3: AI Integration

- [ ] Make NutriBot fully global with structured context from every major feature.
- [ ] Add safe Apply workflows for post improvement, meal plan edits, scanned result edits, and Meal Log suggestions.
- [ ] Require user confirmation before NutriBot writes to Firestore/backend.
- [ ] Keep NutriBot recommendations grounded in real app data and verified local food records.

### Phase 4: Advanced Features

- [ ] Add real push/local notifications if out-of-app reminders are required.
- [ ] Move leaderboard, badge, milestone, and point rules from app config to Firestore/Remote Config if product needs runtime tuning.
- [ ] Add Community moderation/reporting queue.
- [ ] Add integration/widget tests for auth, Meal Log, Community posts, scanner saves, notifications, NutriBot, and engagement.
- [ ] Review Firestore rules, privacy, and sensitive health-data handling before release.

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
- Community post likes stored as arrays can become a scalability issue.
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
- `flutter analyze` passed on 2026-04-25 with no issues found for the state-view files and all touched screens.
