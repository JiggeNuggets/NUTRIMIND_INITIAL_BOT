# NutriMind TESTING_AGENT.md (Validation & Demo Control)

Last updated: 2026-04-27

---

# 🎯 PURPOSE

This agent ensures:

✔ features actually work
✔ no crashes during demo
✔ user flows are complete
✔ bugs are caught before presentation

---

# 🚫 STRICT LIMITS

DO NOT:

* write new features
* redesign UI
* refactor large code

ONLY:

* test flows
* validate behavior
* report issues clearly

---

# 🧠 TESTING PRINCIPLE

👉 “If user cannot complete the flow, it is broken”

NOT:

* “code works”
* “UI looks fine”

---

# 🔴 CORE TEST FLOWS (MANDATORY)

## 1. AUTH FLOW

Steps:

* Open app
* Login / Register

Expected:
✔ user logs in successfully
✔ no crash
✔ redirects to main app

---

## 2. AI MEAL PLANNER FLOW

Steps:

1. Open AI Planner
2. Generate meals
3. Save selected meals
4. Press back while generating (should show confirmation dialog)

Expected:
* loading appears ("Generating meals...")
* meals display correctly
* save shows success dialog with "View My Plan" button
* pressing "View My Plan" navigates to Meal Log
* back while generating shows confirmation dialog

---

## 3. MEAL LOG FLOW

Steps:

1. Open Meal Log
2. Log a meal
3. Check list

Expected:
✔ meal appears
✔ no duplicate issues
✔ no Firestore error

---

## 4. WEEKLY PLAN + PALENGKE

Steps:

1. Save weekly plan
2. Open Palengke

Expected:
✔ ingredients show
✔ grouped correctly
✔ no empty state if meals exist

---

## 5. RECIPE FLOW

Steps:

1. Open Recipe Browser
2. View recipe

Expected:
✔ image loads
✔ data shows
✔ NutriBot context works

---

## 6. NUTRIBOT FLOW

Steps:

1. Open NutriBot
2. Ask question
3. Ask about meal/recipe

Expected:
✔ response appears
✔ loading indicator shows
✔ no crash

---

## 7. SCANNER FLOW

Steps:

1. Open scanner
2. Take photo
3. Save result

Expected:
✔ scan result shows
✔ save works
✔ no crash

---

## 8. PROFILE FLOW

Steps:

1. Edit profile
2. Save changes

Expected:
✔ data updates
✔ UI reflects change
✔ no stale data

---

## 9. COMMUNITY FLOW

Steps:

1. Create post
2. Like post

Expected:
✔ post appears
✔ like updates correctly

---

# 🟡 EDGE CASE TESTS

Test these situations:

* No internet
* Empty data
* Invalid inputs
* Fast navigation (back while loading)

Expected:
✔ app does not crash
✔ fallback UI appears

---

# 🔴 CRITICAL BUG CHECK

Before demo:

* [ ] No Firestore INTERNAL ASSERTION error
* [ ] No red error screen
* [ ] No broken navigation
* [ ] No dead buttons

---

# 🧪 UI TEST CHECK

* [ ] All buttons clickable
* [ ] Loading states visible
* [ ] Error messages friendly
* [ ] Images display or fallback

---

# ⚠️ FAIL CONDITIONS

App is considered **NOT READY** if:

❌ crash occurs
❌ feature does nothing
❌ data does not load
❌ user gets stuck

---

# 🎯 DEMO MODE RULE

During demo:

* Avoid risky flows
* Use stable features only
* Prepare fallback explanation

Example:
“Currently using local dataset for stability”

---

# 🤖 TESTING AGENT RULES

When using AI:

* simulate real user actions
* verify full flow, not just function
* report exact failure step
* do not assume success

---

# 🧠 FINAL RULE

If ANY core flow fails:
👉 app is NOT ready

Fix → retest → repeat

---


---

# 📁 ACTIVE FOLDER RULE

Always work only in:

`C:\Users\wapak\Downloads\nutrimind-main\nutrimind-main\nutrimind`

Never test, edit, or run Flutter commands from:

`C:\Users\wapak\Downloads\nutrimind-main`

Before testing, confirm:

```powershell
pwd
dir pubspec.yaml

✅ REQUIRED COMMAND CHECKS

Run from the active app folder:

flutter analyze
flutter test
flutter run -d chrome

The app is not ready if:

flutter analyze has errors
flutter test fails
app cannot launch
🔥 FIRESTORE WEB CRASH CHECK

Watch terminal and Chrome Console for:

FIRESTORE INTERNAL ASSERTION FAILED
Unexpected state
onSnapshotUnsubscribe has not been initialized
permission-denied
Missing or insufficient permissions

If these appear:

Stop testing.
Copy the exact log.
Identify which screen caused it.
Do not continue to new phases.
🍱 WEEKLY SAVE DEBUG CHECK

If weekly save fails, collect logs beginning with:

[WeeklySave]
[MealProvider.getMealsForWeek]
[MealProvider.addPlannedMeal]URGENT BUG FIX. Plan first, do not edit yet.

Active app folder:
C:\Users\wapak\Downloads\nutrimind-main\nutrimind-main\nutrimind

Current issues:
1. Meal Log / Home meal action shows:
   “Could not log meal. Please try again.”
2. Community comment action shows:
   “Could not add comment. Please try again.”
3. Home and Meal Log should be connected:
   - If a meal is saved/planned/logged in Meal Log for today, it should appear/update on Home.
   - Home should not use disconnected dummy data if real logged/planned meals exist.

Rules:
- Do not redesign UI.
- Do not change auth/routing.
- Do not change Meal Planner generation.
- Do not change Firebase rules unless proven required.
- Inspect first.
- No assumptions.
- Focus only on:
  a. log meal failure
  b. add comment failure
  c. Home ↔ Meal Log data connection
- Ask approval before implementation.

Inspect:
1. lib/screens/main/home_screen.dart
2. lib/screens/main/meal_plan_screen.dart
3. lib/providers/meal_provider.dart
4. lib/models/meal_model.dart
5. lib/services/firestore_service.dart
6. lib/screens/main/community_screen.dart
7. lib/screens/main/post_detail_screen.dart
8. lib/providers/community_provider.dart
9. firestore.rules

Find:
A. For “Could not log meal”
- Which function triggers the snackbar
- Whether FirestoreService.logMeal() fails
- Whether mealProvider.error is stale or real
- Whether mealId/userId/date/status is invalid
- Whether Firestore rules block the update
- Whether Home and Meal Log read from the same provider/source

B. For “Could not add comment”
- Which function triggers the snackbar
- Whether comment creation fails due to rules
- Whether required fields are missing
- Whether postId/userId/comment text is invalid
- Whether comment count update is blocked by rules

C. For Home ↔ Meal Log connection
- Does Home read MealProvider.meals or a separate stream?
- Does Home load today’s meals from the same selected user/date?
- Does logging a meal update Home immediately?
- If not, what is the smallest safe way to connect them?

Output:
1. Root cause for log meal failure
2. Root cause for add comment failure
3. Root cause for Home/Meal Log disconnect
4. Exact files and line numbers
5. Smallest safe fix plan
6. Ask approval before implementation

Report:

last successful stage
first failed stage
exact error message
📱 RESPONSIVENESS TEST

Test Android/iOS-like sizes:

320px width
360px width
390px width
large phone width

Check:

no overflow warning
no clipped text
no bottom nav overlap
dialogs are scroll-safe
keyboard does not cover forms
buttons are aligned
cards have clean padding

So your `TESTING_AGENT.md` is good, but add those because your current biggest risks are:

```text id="phmlrl"
1. Wrong folder
2. Firestore web listener crash
3. Weekly save failure
4. Small-phone UI overflow