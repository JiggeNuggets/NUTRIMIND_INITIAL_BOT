# NUTRIMIND Project Status

Generated: 2026-05-01

## Current Stage

P0 demo-ready testing stage.

UI polish is still paused until manual demo testing and APK testing pass.

---

## Correct Active Project Folder

Use only this folder:

```text
C:\Users\wapak\Downloads\nutrimind-main\nutrimind-main\nutrimind

Do not work from this outer stale folder:

C:\Users\wapak\Downloads\nutrimind-main

Before editing, always confirm:

pwd
dir pubspec.yaml

Correct folder should contain:

pubspec.yaml
lib
android
web
test
firebase.json
firestore.rules
storage.rules
STATUS.md
Completed P0 Fixes
1. Firestore / Storage Rules Setup

Status: Completed.

Firestore rules added.
Storage rules added.
Rules linked in firebase.json.

Do not change Firebase rules unless a direct bug proves rules are the cause.

2. Auth / Routing Phase 2 Fix

Status: Completed.

Main result:

AuthGate controls routing.
Splash Google sign-in no longer bypasses ProfileSetup / AuthGate.
Logout returns to root AuthGate.

Do not redesign auth/routing unless approved.

3. Auth Error UI Improvement

Status: Completed.

Main result:

Raw Firebase stack traces no longer show in Profile unavailable UI.
Recovery screen is scroll-safe.
Recovery screen has Retry and Sign out.
4. Profile UID Fallback

Status: Completed.

Main result:

User reads normalize uid from Firestore document ID when stored uid is missing or blank.
5. Food Image Resolver Fix

Status: Completed.

Main result:

Removed misleading Boiled Egg -> tuna_omelette mapping.
Added local asset-first resolver.
6. AI Meal Planner Phase 3 Partial Fix

Status: Completed.

Main result:

Other gender accepted.
Preferences wired.
Weekly repetition reduced.
Duplicate weekly save prevention added.
7. Save Hang Partial Fix

Status: Completed.

Main result:

Removed unnecessary selectDate during save.
Notification GET-before-SET changed to direct set.
30-second timeout added.
Weekly debug logs added.

Debug logs added:

[WeeklySave]
[MealProvider.getMealsForWeek]
[MealProvider.addPlannedMeal]
8. Home / Meal Connection Improvement

Status: Completed.

Main result:

Home Today meals use real today meals.
Home does not hide extra same-type meals.
9. Community Comments Best-Effort Aggregate

Status: Completed.

Main result:

commentCount aggregate update became best-effort after comment creation.
10. Stream Stabilization Earlier Work

Status: Completed.

Main result:

Community like stream cached.
Provider stream same-key guards added.

Remaining stream issues were handled later through Home/Profile and auth cleanup patches.

Latest P0 Patches
11. P0 Home + Profile Listener Stabilization Patch

Status: Completed.

Files changed:

lib/screens/main/home_screen.dart
lib/screens/main/profile_screen.dart
lib/services/engagement_service.dart

Changes:

home_screen.dart
Local-food spotlight changed from live snapshots() / StreamBuilder to cached one-shot get() / FutureBuilder.
Added 8-second timeout fallback.
Card keeps existing default content instead of hanging.
Home UI design unchanged.
MealProvider untouched.
profile_screen.dart
Badges changed from live StreamBuilder to cached one-shot FutureBuilder.
Weekly rankings changed from live StreamBuilder to cached one-shot FutureBuilder.
Added retry refresh.
Added 8-second timeout.
Added friendly empty states so spinners do not run forever.
Profile UI layout unchanged.
engagement_service.dart
Added getWeeklyLeaderboard() one-shot getter for Profile rankings.

Not touched:

Post Detail
Pantry
Scan History
User Profile
Firebase rules
Auth/routing
Meal Planner

Checks:

flutter analyze: passed, no issues found
flutter test: passed, all 4 tests passed
12. P0-A Auth-Scoped Provider Cleanup Patch

Status: Completed.

Files changed:

lib/main.dart
lib/providers/meal_provider.dart
lib/providers/notification_provider.dart
lib/providers/community_provider.dart
lib/screens/main/main_shell.dart

Purpose:

This fixed logout/login/account switching problems where old Firestore listeners could survive after logout or account switch.

Before:

Old account listener still running
→ user logs out
→ new account logs in
→ old listener still tries to read/write old user data
→ Firestore rejects it or web listener crashes
→ Profile unavailable / permission-denied / onSnapshotUnsubscribe

Changes:

lib/main.dart
Added auth-scoped cleanup wrapper around AuthGate.
When auth becomes unauthenticated or authenticated UID changes, it clears user-scoped provider state/listeners.
lib/providers/meal_provider.dart
Added clear/reset support for:
meal stream
meal list
selected date
error state
lib/providers/notification_provider.dart
Added safe cleanup for:
notification stream
unread-count stream
notification state
Added generation/stale callback guards.
Old listener callbacks can no longer update state after UID changes.
lib/providers/community_provider.dart
Added cleanup for posts stream/state because posts are auth-gated by Firestore rules.
lib/screens/main/main_shell.dart
Removed duplicate CommunityProvider.listenToPosts('Trending') startup.
CommunityScreen remains the owner of Trending posts listener.

Not touched:

Post Detail
Pantry
Scan History
User Profile
Firebase rules
Auth routing design
Meal Planner generation

Checks:

flutter analyze: passed, no issues found
flutter test: passed, all 4 tests passed

Manual result:

Account switching worked.
13. P0 Meal Write Stability Patch

Status: Completed.

Files changed:

lib/screens/main/ai_meal_planner_screen.dart
lib/screens/main/meal_plan_screen.dart
lib/providers/meal_provider.dart
lib/services/firestore_service.dart

Fixed failures:

Save to Day Plan timeout
Log Meal failed
Swap Meal failed
Save to Day Plan Root Cause

Code-level root cause:

Day Plan save wrote the core meal documents first.
But after core meal writes, the screen still awaited optional notification/reminder work with 30-second timeouts.
A reminder, budget warning, or Palengke reminder delay could show Save timed out even after meals were already saved.
MealProvider.addPlannedMeal() also awaited optional engagement/stat counters after the core write.

Fix:

Core meal write succeeds first.
Optional notification/reminder/engagement work is now best-effort and non-blocking.
Log Meal Root Cause

Code-level root cause:

Core log used:
users/{uid}/meals/{mealId}.update(...)
Failures from invalid/stale UID, empty mealId, missing document, or permission mismatch were collapsed into a generic provider error.
The screen also awaited optional budget-warning notification before showing success.

Fix:

Added UID validation.
Added mealId validation.
Added Firestore error logging.
Made budget-warning creation non-blocking.
Swap Meal Root Cause

Code-level root cause:

Swap used updateMeal(uid, mealId, ...) without service-level UID/mealId validation.
Firestore failures had limited logging.
Optional engagement counters after the core swap could delay the success path.

Fix:

Added validation/logging around update/delete/write helpers.
Made engagement counters non-blocking.
Optional Tasks Made Non-Blocking
Meal reminders
Log reminders
Budget warning notifications
Palengke reminders
Engagement/weekly stats counters
Badge/stat aggregate side effects

Important:

Core meal writes still fail loudly.
Optional side effects no longer block the main success path.

Checks:

flutter analyze: passed, no issues found
flutter test: passed, all 4 tests passed
14. P0 Demo Reliability Audit

Status: Completed.

No code changes were made during audit.

Findings:

Fresh-User Risks Found
profile_setup_screen.dart line 70
- Profile setup save had no timeout.
- Hanging Firestore update could leave save button spinning.

profile_setup_screen.dart line 87
- Save failure showed raw exception text in snackbar.

progress_dashboard_screen.dart line 150
- Fresh users triggered many sequential meal reads with no timeout.

community_screen.dart line 31
- Community started post stream immediately because IndexedStack mounts it at MainShell startup.
Possible Infinite Loading Found
auth_provider.dart line 43
- AuthGate could remain unknown/loading if profile fetch/create hangs.

auth_provider.dart line 309
- _resolveSignedInUser awaited Firestore without timeout.

auth_gate.dart line 20
- Unknown auth/profile state showed loading.

profile_setup_screen.dart line 70
- Profile save spinner could hang.

progress_dashboard_screen.dart line 215
- Dashboard FutureBuilder could spin while sequential reads hang.

weekly_palengke_list_screen.dart line 50
- Weekly Palengke load has no timeout.

post_detail_screen.dart line 399
- Comments stream can wait indefinitely.

pantry_screen.dart line 90
- Pantry stream can wait indefinitely if opened.

scan_history_screen.dart line 42
- Scan history stream can wait indefinitely if opened.
Raw Firebase Error Risks Found
profile_setup_screen.dart line 87
- Could not save profile: $e

recipe_browser_screen.dart line 200
- Displays snapshot.error.toString()

recipe_browser_screen.dart line 572
- List error may display raw _error
Remaining Risky Firestore Streams

Must watch before demo:

community_screen.dart line 31
- Starts posts listener at app shell mount.

community_screen.dart line 470
- Per-post like StreamBuilder; cached but can still create many listeners.

post_detail_screen.dart line 357
- Direct like stream inside build.

post_detail_screen.dart line 399
- Comments stream.

user_profile_screen.dart line 135
- Follower/following/post/follow status streams.

pantry_screen.dart line 90
- Direct pantry stream.

scan_history_screen.dart line 42
- Direct scan history stream.

Safe for now:

meal_provider.dart line 75
- Guarded provider meal stream.

notification_provider.dart line 70
- Guarded notification stream.

profile_screen.dart line 911
- Badges are now one-shot with timeout.

profile_screen.dart line 1003
- Rankings are now one-shot with timeout.
Release / Build Risks Found
AndroidManifest.xml line 1
- Release/main manifest did not declare android.permission.INTERNET.
- Debug/profile manifests had it, but release APK network/Firebase could fail on device.

build.gradle.kts line 37
- Release uses debug signing.
- Fine for local demo installs, not production release.

build.gradle.kts line 27
- App ID is still com.example.nutrimind.
- Store/distribution concern unless Firebase Android registration expects different package.
15. P0-Demo Must-Fix Patch

Status: Completed.

Files changed:

AndroidManifest.xml
profile_setup_screen.dart
auth_provider.dart
progress_dashboard_screen.dart

Changes:

AndroidManifest.xml
Added:
<uses-permission android:name="android.permission.INTERNET" />
Application ID unchanged.
Signing config unchanged.
profile_setup_screen.dart
Added 10-second timeout around profile setup save.
Save button should no longer spin forever.
Raw exception snackbar replaced with friendly retry/connection message.
Real error kept in debugPrint.
auth_provider.dart
Added 10-second timeout around profile fetch/create.
AuthGate can now move to existing friendly recovery state instead of spinning forever.
progress_dashboard_screen.dart
Added 8-second dashboard load timeout.
On timeout, dashboard logs the issue.
Dashboard falls back to existing empty progress state for fresh/demo users.

Checks:

flutter analyze: passed, no issues found
flutter test: passed, all 4 tests passed
Current Status Summary

Completed:

✅ Firestore/Storage rules setup
✅ Auth/routing Phase 2 fix
✅ Friendly auth/profile error UI
✅ Profile UID fallback
✅ Food image resolver fix
✅ AI Meal Planner Phase 3 partial fix
✅ Save hang partial fix
✅ Home/Meal connection improvement
✅ Community comment aggregate best-effort
✅ Home + Profile listener stabilization
✅ Auth/account-switch provider cleanup
✅ Meal write stability patch
✅ P0 demo reliability audit
✅ P0-Demo must-fix patch
✅ flutter analyze passed
✅ flutter test passed

Current stage:

P0 demo-ready testing stage
Current Concern

Community posts may still not be connected / not loading / not saving correctly.

Community was only partially stabilized:

Completed:



Still needs audit/fix if failing:

⚠️ Community lazy loading
⚠️ Community posts listener still starts when CommunityScreen mounts
⚠️ Per-post like streams may still be risky
⚠️ Post Detail comments/likes not fully hardened
⚠️ Need to confirm post read/write collection and Firestore rules
Manual Demo Test Needed

Run:

flutter run -d chrome
Fresh New Account Test
1. Register/login new account.
2. Complete profile setup.
3. Home loads.
4. Generate AI meal.
5. Save to Day Plan.
6. Meal Log loads.
7. Log Meal.
8. Swap Meal.
9. Progress Dashboard opens and does not spin forever.
10. Profile opens and does not spin forever.
11. Community posts load or show friendly empty/error state.
12. Create Community post if demo requires it.
13. Logout/login again.
Old Account Test
1. Login old account.
2. Home loads.
3. Meal Log loads.
4. Save to Day Plan.
5. Log Meal.
6. Swap Meal.
7. Open Progress Dashboard.
8. Open Profile.
9. Open Community.
10. Logout/login again.
Account Switching Test
Old account login
→ logout
→ new account login
→ logout
→ old account login again

Then:

Switch Home <-> Profile repeatedly for 1–2 minutes.
Open Community once, go back Home/Profile.
Logout/login again.

Watch console for:

FIRESTORE INTERNAL ASSERTION FAILED
onSnapshotUnsubscribe
LateInitializationError
permission-denied from old uid paths
Profile unavailable loop
Save timed out
empty uid
empty mealId
not-found
Community read failed
Community write failed
APK Build Test Needed

Run:

flutter build apk --release

APK output path:

build/app/outputs/flutter-apk/app-release.apk

Install APK on phone and verify:

Login works.
Profile setup works.
Home loads.
Firebase network access works.
Meal save/log/swap works.
Progress Dashboard opens.
Profile opens.
Community opens.
Logout/login works.
Next Recommended Audit

Because the previous chat was lost and Community may still be failing, run this next in Codex:

Full NUTRIMIND audit request after lost chat. Audit only. Do not edit yet.

Read these first:
1. AGENTS.md
2. TESTING_AGENT.md
3. STATUS.md

Active app folder:
C:\Users\wapak\Downloads\nutrimind-main\nutrimind-main\nutrimind

Before anything:
1. Confirm pwd.
2. Confirm pubspec.yaml exists.
3. Do not work from the outer stale folder:
   C:\Users\wapak\Downloads\nutrimind-main

Current known completed work:
1. Home + Profile listener stabilization completed.
2. Auth/account-switch provider cleanup completed.
3. Meal write stability patch completed.
4. P0-Demo must-fix patch completed.
5. flutter analyze passed previously.
6. flutter test passed previously.

Current concern:
I lost the previous chat and need a fresh audit of the current code state. Also, Community posts may still not be connected / not loading / not saving correctly.

Audit only. Do not modify code yet.

Audit focus:

A. Confirm current project state
- Verify STATUS.md matches actual files.
- Check if the patches described in STATUS.md are really present.

B. Community connection audit
Inspect:
- lib/screens/main/community_screen.dart
- lib/screens/main/post_detail_screen.dart
- lib/providers/community_provider.dart
- lib/services/firestore_service.dart
- lib/models/post_model.dart
- firestore.rules only for audit

Find:
1. Whether posts read from the correct Firestore collection.
2. Whether create post writes to the correct Firestore collection.
3. Whether Firestore rules allow authenticated users to read/write posts.
4. Whether CommunityProvider starts correctly when Community tab opens.
5. Whether CommunityProvider was cleared by auth cleanup and not restarted.
6. Whether empty Community state means real empty data, read failure, rules failure, or model parsing failure.
7. Whether post model parsing can fail from missing or invalid fields.
8. Whether likes/comments are separate issues from post list loading.

C. Remaining P0 demo risks
Audit:
- Profile setup
- AuthGate/AuthProvider
- Home
- AI Meal Planner
- Meal Log
- Save to Day Plan
- Log Meal
- Swap Meal
- Progress Dashboard
- Profile
- Community
- Notifications
- APK/release config

Find anything that can still cause:
- infinite spinner
- raw Firebase error in UI
- permission-denied
- missing uid
- missing mealId
- stale old-account listener
- Firestore web listener crash
- blank screen
- release APK no internet/Firebase issue

D. Remaining Firestore streams
List all remaining snapshots()/StreamBuilder usages and classify:
- Safe for demo
- Risky but okay if not opened
- Must fix before demo

E. Build/test readiness
Run only these checks after audit:
flutter analyze
flutter test

Do not run build APK yet unless I approve.

Required output:
A. Correct folder confirmation.
B. Exact files inspected.
C. Whether STATUS.md matches actual current code.
D. Community root cause findings.
E. Remaining P0 demo risks.
F. Remaining risky streams with file and line number.
G. Firebase rules findings for Community.
H. Release/APK risks.
I. Priority list:
   - P0-Demo must fix now
   - P0-Demo nice to fix
   - P1 later
J. Results of flutter analyze and flutter test.
K. No code changes made.
Next Steps After Audit
If Community is confirmed failing

Approve a focused Community patch only.

Possible scope:

1. Fix Community post read/write connection.
2. Add debug logs for Community read/write failures.
3. Add friendly empty/error state.
4. Ensure CommunityProvider restarts after auth cleanup.
5. Do not redesign Community UI.
6. Do not touch Post Detail unless separate approval is needed.
If Manual Test Passes

Move to:

P0-Demo nice-to-fix

Recommended next nice-to-fix:

Community lazy loading

Reason:

Audit found CommunityScreen may still start its post stream at MainShell startup because IndexedStack mounts all tabs.
This is not yet a must-fix if manual demo is stable.
But it would reduce startup listener load.
P0-Demo Nice-to-Fix Backlog

Not yet implemented unless later confirmed.

1. Prevent Community posts listener from starting until Community tab is selected.
2. Convert Post Detail like/comments streams to safer guarded/cached behavior.
3. Add timeout/friendly empty fallback to Weekly Palengke load.
P1 Later Backlog

Not for demo unless opened and failing.

1. Harden Pantry direct stream.
2. Harden Scan History direct stream.
3. Harden User Profile streams.
4. Replace raw Recipe Browser errors with friendly messages.
5. Clean release signing config for real distribution.
6. Change application ID from com.example.nutrimind if needed for real release.
7. Resume UI Phase 4 polish only after P0 stability and demo testing pass.
Important Rules for Future Codex Work

Always tell Codex:

Read AGENTS.md, TESTING_AGENT.md, and STATUS.md first.

Always confirm:

pwd
dir pubspec.yaml

Do not work from:

C:\Users\wapak\Downloads\nutrimind-main

Work only from:

C:\Users\wapak\Downloads\nutrimind-main\nutrimind-main\nutrimind

Do not do these unless specifically approved:

Do not redesign UI.
Do not change Firebase rules.
Do not change auth/routing design.
Do not change Meal Planner generation.
Do not touch Post Detail, Pantry, Scan History, or User Profile unless approved.
Do not start UI polish until P0 demo testing passes.

Correct order:

1. Stability
2. Data integrity
3. Demo reliability
4. APK/device testing
5. UI polish

## 16. Community Feed Loading Fix

Status: Completed.

Files changed:
- lib/services/firestore_service.dart
- lib/providers/community_provider.dart

Inspected:
- lib/models/post_model.dart

Root cause:
- Non-Trending Community tabs like Q&A used a Firestore query combining `where('category')` with `orderBy('createdAt')`.
- In the deployed Firebase environment, that indexed query could fail and make the provider show “Could not load community posts.”
- The posts collection and Firestore rules were not the cause.

Fix:
- `postsStream` now queries global `posts` ordered by `createdAt`.
- Category filtering is now done in memory.
- Empty categories now return an empty list so the friendly empty state can show.
- Malformed post documents are skipped individually with `debugPrint` including the failed document ID.
- Provider stream errors now log the selected category before showing the existing friendly UI error.

Unchanged:
- Firestore rules unchanged.
- Collection path unchanged: still global `posts`.
- Comments/likes subcollections unchanged.

Checks:
- flutter analyze: passed, no issues found.
- flutter test: passed, all 4 tests passed.

## 17. P0-Demo Date-Based Meal Log Preview Fix

Status: Completed.

Files changed:
- lib/providers/meal_provider.dart
- lib/screens/main/meal_plan_screen.dart

Fix:
- `MealProvider` now initializes `_selectedDate` as local date-only today.
- `MealPlanScreen.initState()` selects today on first mount.
- Meal Log opens on the current date by default.
- `MealProvider.selectDate()` normalizes selected dates to date-only.
- Old cached meals are cleared before starting the new date stream, so meals from the previous selected day do not show first.
- Daily saves use normalized `mealProvider.selectedDate`.
- Weekly saves still pass each planned day through `forDate`.
- `MealProvider.addPlannedMeal()` now normalizes `forDate` before storing.

Date filtering:
- `FirestoreService.mealsStream(uid, selectedDate)` loads meals where:
  - `date >= selected day local midnight`
  - `date < next day local midnight`

Checks:
- flutter analyze: passed, no issues found.
- flutter test: passed, all 4 tests passed.

## 19. UI-P1 Main Screen Polish Patch

Status: Completed.

Files changed:
- lib/screens/main/ai_meal_planner_screen.dart
- lib/screens/main/progress_dashboard_screen.dart
- lib/screens/main/profile_screen.dart
- lib/screens/main/community_screen.dart
- lib/screens/main/recipe_browser_screen.dart
- lib/screens/main/home_screen.dart

Fixes:
- Added `Center + ConstrainedBox(maxWidth: 560)` to AI Meal Planner, Progress Dashboard, Profile, Community, and Recipe Browser.
- Prevented Chrome/tablet layouts from stretching too wide.
- Mobile layout remains effectively unchanged.
- Recipe Browser no longer displays direct `_error!` text to users.
- Recipe Browser now shows: “Please check your connection and try again.”
- Home lower-card CTA text now uses `Expanded`, `maxLines: 1`, and ellipsis to prevent text/icon collision.
- AI Planner Groq config text was changed to a more demo-friendly message:
  “AI descriptions are optional; local meal suggestions remain available for demo stability.”

Unchanged:
- Business logic
- Firebase logic
- Providers
- Auth/routing
- Firestore rules
- Data models
- Architecture

Checks:
- flutter analyze: passed, no issues found.
- flutter test: passed, all 4 tests passed.

## 20. Auth UI-P1 Polish Patch

Status: Completed.

Files changed:
- lib/screens/auth/login_screen.dart
- lib/screens/auth/register_screen.dart
- lib/screens/onboarding/splash_screen.dart
- lib/screens/onboarding/profile_setup_screen.dart

Fixes:
- Added max-width constraints to Login, Register, Splash CTA/content area, and Profile Setup.
- Login maxWidth: 520.
- Register maxWidth: 520.
- Splash CTA/content maxWidth: 520.
- Profile Setup main body maxWidth: 560.
- Mobile layout remains effectively unchanged.
- Chrome/tablet layouts no longer stretch too wide.
- Replaced direct `auth.error!` user-facing snackbars with friendly messages.
- Real auth errors are still logged with `debugPrint`.
- Splash bottom CTA panel is wrapped in `SafeArea(top: false)` for safer bottom gesture/navigation spacing.

Friendly messages added:
- Login failure: “Could not sign in. Please check your details and try again.”
- Google sign-in failure: “Could not continue with Google. Please try again.”
- Register failure: “Could not create your account. Please check your details and try again.”
- Password reset failure: “Could not send reset link. Please check your email and try again.”

Unchanged:
- Auth behavior
- Firebase logic
- Providers
- Routing
- Firestore rules
- Validation rules
- Google button visual design

Checks:
- flutter analyze: passed, no issues found.
- flutter test: passed, all 4 tests passed.

## 21. Logo Branding Polish Patch

Status: Completed.

Files changed:
- lib/screens/auth/login_screen.dart
- lib/screens/onboarding/splash_screen.dart

Fixes:
- Added centered transparent NUTRIMIND logo to Login screen.
- Login logo uses `assets/images/nutrimind_logo_transparent.png`.
- Login logo is responsive, around 96–112px wide depending on screen width.
- Replaced Splash hero app mark output with transparent NUTRIMIND logo.
- Splash logo is centered and responsive, around 142–168px wide.
- Both logo widgets use `Image.asset`, `BoxFit.contain`, and `errorBuilder` fallback so missing asset will not crash the screen.

pubspec.yaml:
- Not changed.
- `assets/images/` was already declared.
- `flutter pub get` was not needed.

Unchanged:
- Auth logic
- Firebase logic
- Providers
- Routing
- Validation
- Firestore rules
- Dependencies/packages

Checks:
- flutter analyze: passed, no issues found.
- flutter test: passed, all 4 tests passed.

## 21. Logo Branding Polish Patch

Status: Completed.

Files changed:
- lib/screens/auth/login_screen.dart
- lib/screens/onboarding/splash_screen.dart

Logo path:
- `assets/images/food/logo/nutrimind_logo_transparent.png`

Fixes:
- Added centered transparent NUTRIMIND logo to Login screen.
- Replaced Splash hero app mark output with transparent NUTRIMIND logo.
- Both use `Image.asset`, `BoxFit.contain`, responsive sizing, and `errorBuilder` fallback.
- `pubspec.yaml` was not changed because `assets/images/` already covers the nested logo path.

Unchanged:
- Auth logic
- Firebase logic
- Providers
- Routing
- Validation
- Firestore rules
- Layout beyond logo asset path
- Packages

Checks:
- flutter analyze: passed, no issues found.
- flutter test: passed, all tests passed.

## 22. Splash/Login Logo Asset Filename Fix

Status: Completed.

Fix:
- Renamed logo asset from `nutrimind_logo_transparent.png.png` to `nutrimind_logo_transparent.png`.
- Splash and Login already used the correct path:
  `assets/images/food/logo/nutrimind_logo_transparent.png`
- No Dart code changes were needed.
- The old fallback icon appeared because the expected asset filename did not exist.

Checks:
- flutter analyze: passed, no issues found.
- flutter test: passed, all 4 tests passed.
## 23. Meal Log Day/Week Preview Navigation Fix

Status: Completed.

File changed:
- lib/screens/main/meal_plan_screen.dart

Root cause:
- Day chips were already tappable.
- `MealProvider.selectDate()` already refreshed meals correctly.
- But the visible week was fixed to the initial current week.
- There were no previous/next week controls.
- The 7-chip row was cramped on small screens, making other-day preview awkward.

Fixes:
- Added previous/next week chevrons.
- Added clearer selected-date header.
- Added horizontally scrollable day strip with larger tappable chips.
- Moving weeks selects the same weekday in the new week and refreshes the meal list.
- Tapping a day still calls `MealProvider.selectDate(uid, selectedDay)`.
- Provider clears old meals immediately on date change.
- `FirestoreService.mealsStream()` still filters by local midnight-to-midnight for the selected date.

Empty state:
- Days with no meals now show:
  “No meals for MMM d”
- Friendly message tells user to create a plan for that date or choose another day.

Unchanged:
- Firebase rules
- Auth/routing
- Meal Planner generation
- Community
- Pantry
- Scan History
- Post Detail
- User Profile

Checks:
- flutter analyze: passed, no issues found.
- flutter test: passed, all tests passed.

## 27. Weekly Meal Fallback Variety Fix

Status: Completed.

File changed:
- lib/screens/main/ai_meal_planner_screen.dart

Root cause:
- Weekly meal dates were correct.
- Weekly save correctly passed `forDate: dayPlan.date`.
- Meal Log correctly queried meals by selected date.
- The real issue was fallback variety.
- `_buildDemoFallbackPlan()` was fixed/hardcoded, so when fallback fired for multiple weekly days, all days showed the same fallback meals.

Fix:
- `_buildDemoFallbackPlan()` now accepts `dayIndex`.
- Weekly generation passes `dayIndex: i`.
- Emergency weekly fallback also builds each day with its own `dayIndex`.
- Fallback meals now rotate across 3 different Filipino meal sets:
  - Set A: Arroz Caldo, Chicken Adobo, Tinolang Manok, Fruit Cup
  - Set B: Champorado, Tuna Pandesal, Sinigang na Bangus, Ginisang Gulay + Grilled Fish, Boiled Saba
  - Set C: Garlic Rice with Egg, Taho, Monggo with Malunggay, Pandesal, Pinakbet, Peanuts
- Daily plan behavior remains unchanged because `dayIndex` defaults to 0.

Unchanged:
- Weekly date assignment
- Meal Log query
- Firestore rules
- Normal MealPlannerService generation path
- Save logic
- Providers

Checks:
- flutter analyze: passed, no issues found.
- flutter test: passed, all 4 tests passed.