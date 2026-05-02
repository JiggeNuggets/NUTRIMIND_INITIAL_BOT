# NutriMind AGENT.md  
## Final Production Control + Stabilization Guide

Last updated: 2026-05-01

---

# 1. Project Overview

NutriMind is an AI-powered nutrition mobile app built using:

- Flutter
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Provider state management
- Local food dataset / fallback meal planning
- Optional AI services such as Groq / NutriBot

Main architecture:

```text
UI → Provider → Service → Firebase / Local Dataset

The project is currently in:

Stabilization + Real Device Testing + Defense Demo Preparation

The goal is not to add new features.
The goal is to make the existing app stable, usable, and demo-ready.

2. Active App Directory

Work only inside this folder:

C:\Users\wapak\Downloads\nutrimind-main\nutrimind-main\nutrimind

Never run Flutter commands from this outer folder:

C:\Users\wapak\Downloads\nutrimind-main

Before doing anything, confirm the folder:

pwd
dir pubspec.yaml

The correct folder must contain:

pubspec.yaml
lib
android
web
test
firebase.json
firestore.rules
storage.rules

If pubspec.yaml is missing, stop and move to the correct folder.

3. Global Agent Rules
Strict Rules

Do not:

Edit the outer stale folder.
Rewrite the whole app.
Add new features during stabilization.
Redesign the whole UI.
Refactor large parts of the app without approval.
Change Firebase rules unless the issue proves rules are the root cause.
Change auth/routing unless the current task is auth-related.
Change Meal Planner generation unless the task is Meal Planner-related.
Change Community/NutriBot/Profile logic unless the task specifically requires it.
Assume the cause of a bug without checking actual files/logs.
Hide real errors during debugging.

Always:

Work only in the active app folder.
Inspect actual files first.
Plan before editing.
Ask approval before implementation unless the user explicitly says implement now.
Keep fixes small and scoped.
Fix root cause, not symptoms.
Run checks after changes.
Report exact files changed.
Report manual test steps.
4. Standard Workflow

For every task:

1. Confirm active folder.
2. Inspect related files only.
3. Identify exact root cause.
4. Create smallest safe fix plan.
5. Ask approval.
6. Implement only approved scope.
7. Run checks.
8. Report results.
9. Suggest manual test path.

Use this output format for planning:

## Inspection Summary

## Root Cause

## Files / Lines Involved

## Proposed Fix Plan

| Step | File | Change | Reason | Risk |
|---|---|---|---|---|

## Manual Test Plan

## Approval Question

Use this output format after implementation:

## Implemented Changes

## Files Changed

## Checks

- flutter analyze:
- flutter test:

## Manual Tests Needed

## Notes / Remaining Risks
5. Required Checks

Run from the active app folder:

flutter analyze
flutter test

When testing web:

flutter run -d chrome

Optional build check:

flutter build web

If Flutter says:

No pubspec.yaml file found

then the terminal is in the wrong folder.

6. Current Phase

Current phase:

Stabilization + Demo Readiness + Real Device UI Polish

Current priority order:

1. Prevent crashes
2. Fix Firestore stream and uid safety
3. Fix meal logging and weekly save reliability
4. Fix Home ↔ Meal Log data consistency
5. Fix Community comment/like reliability
6. Fix responsive UI and popup alignment
7. Clean up after demo
7. Current Known Risks

Known risks:

Duplicate app folders may cause edits in the wrong place.
Firestore web streams can crash on Chrome.
User-scoped Firestore paths can fail if uid is null or empty.
Some streams were previously recreated inside build().
Weekly save may fail if Firestore reads/writes or model parsing fail.
Community comment/like actions may fail if aggregate updates are blocked.
Home and Meal Log must remain connected to the same meal source.
Some UI rows may overflow on small Android/iOS screens.
Some dialogs need scroll-safe layouts.
NutriBot/API fallback may hide real API issues.
Prototype datasets may not cover all food images.
8. Firestore Web Crash Policy
Critical Error

Watch for:

FIRESTORE INTERNAL ASSERTION FAILED
Unexpected state
onSnapshotUnsubscribe has not been initialized
permission-denied
Missing or insufficient permissions

If this appears:

Stop current phase.
Do not continue UI work.
Find the stream/query causing the crash.

Possible causes:

Empty/null uid used in user-scoped Firestore path.
Firestore .snapshots() stream created directly inside build().
StreamBuilder repeatedly cancels/starts on rebuild.
Provider cancels and immediately restarts stream for same date/category.
Browser localhost data/cache is corrupted.
Firestore package web listener bug triggered by listener churn.

Fix strategy:

Validate uid before user-scoped Firestore calls.
Never start .snapshots() with empty uid.
Cache streams where possible.
Do not create Firestore streams directly inside build().
Add same-date/same-category no-op guards in providers.
Cancel old stream safely before starting a new one.
Ignore stale stream callbacks after a new subscription starts.
Clear Chrome localhost site data when testing web cache issues.

Chrome reset steps:

chrome://settings/content/all
Search: localhost
Delete localhost / 127.0.0.1

Then restart:

flutter clean
flutter pub get
flutter run -d chrome
9. Firestore UID Safety
User-Scoped Paths

User-scoped Firestore paths include:

users/{uid}
users/{uid}/meals
users/{uid}/pantry
users/{uid}/scannedItems
users/{uid}/badges
users/{uid}/weeklyStats
users/{uid}/notifications
users/{uid}/palengkeLists

Before any read/write/stream to these paths, validate uid.

Preferred helper:

void validateUid(String? uid) {
  if (uid == null || uid.trim().isEmpty) {
    throw ArgumentError('Invalid uid');
  }
}

For streams:

if (uid == null || uid.trim().isEmpty) {
  return Stream.value([]);
}

Do not call:

.snapshots()

on a user path if uid is empty.

Bad:

FirebaseFirestore.instance
  .collection('users')
  .doc(uid)
  .collection('meals')
  .snapshots();

when uid == ''.

Good:

if (uid.trim().isEmpty) {
  return Stream.value([]);
}
return FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .collection('meals')
    .snapshots();
Global Collections

Do not blindly apply uid validation to global collections such as:

posts
recipes
local_foods

unless the query specifically uses the current user.

10. Provider Rules

UI should not directly manage Firestore business logic.

Preferred flow:

Screen → Provider → Service → Firestore

Avoid:

Screen → Firestore directly

Allowed exceptions:

Very small read-only UI streams may exist temporarily, but avoid creating them directly inside build().
If a stream is used in a widget, cache it in state and update it only when keys change.

Provider responsibilities:

Validate inputs.
Manage loading/error state.
Cancel streams safely.
Prevent duplicate subscriptions.
Clear stale errors on success.
Expose user-friendly error messages.
11. Stream Safety Rules

Do not create new Firestore streams directly inside build().

Bad:

StreamBuilder(
  stream: FirestoreService().someStream(id),
  builder: ...
)

Good:

late Stream<MyType> _stream;

@override
void initState() {
  super.initState();
  _stream = FirestoreService().someStream(widget.id);
}

@override
void didUpdateWidget(covariant MyWidget oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.id != widget.id) {
    _stream = FirestoreService().someStream(widget.id);
  }
}

Provider stream replacement should:

1. Check if new key is same as current key.
2. If same, do nothing.
3. If different, cancel old subscription.
4. Start new subscription.
5. Ignore stale callbacks from old subscription.
12. Meal Logging Rules

Meal logging must be reliable.

Required checks:

uid must not be empty.
mealId must not be empty.
Meal document ID must match the ID used for updates.
If Firestore document ID exists, prefer it as fallback for MealModel.id.
Clear stale provider error on successful log.
Do not show failure snackbar if the operation succeeded.
Home and Meal Log must read from the same source/provider.

If user sees:

Could not log meal. Please try again.

inspect:

meal_provider.dart
firestore_service.dart
meal_plan_screen.dart
home_screen.dart
firestore.rules

Common causes:

Stale mealProvider.error
Missing/stale meal ID
Firestore update failed
Wrong selected date
Home showing date different from Today
13. Home ↔ Meal Log Connection

Home “Today’s Meals” and Meal Log must be connected.

Expected behavior:

If a meal is saved/planned/logged for today, it appears on Home.
If a meal is logged in Meal Log, Home updates.
Home should not show disconnected dummy meals when real today meals exist.

Rules:

Home should use MealProvider for real user meals.
Home should filter by actual current date when label says “Today”.
Home should not silently hide extra meals of the same type.
If real data is empty, show a friendly empty state or demo fallback only if appropriate.
14. Weekly Save Debug Policy

If weekly save fails, collect logs starting with:

[WeeklySave]
[MealProvider.getMealsForWeek]
[MealProvider.addPlannedMeal]

Report:

last successful stage
first failing stage
exact exception
screen action that triggered it

Possible failing stages:

getMealsForWeek
addPlannedMeal
notificationCreation.mealReminders
notificationCreation.budgetWarning
notificationCreation.palengkeReminder

Rules:

Do not guess.
Use the debug stage logs.
Fix only the failing stage.
Remove noisy debug logs after final stabilization if needed.
15. Community Rules

Community actions must not fail because of non-critical aggregate updates.

For comments:

Creating the comment document is primary.
Updating commentCount is secondary.

If comment document succeeds but count update fails:

Do not fail the whole user action.
Log/debugPrint the aggregate update failure.
Show the comment as added if possible.

For likes:

Like/unlike should not create unstable streams in build.
Cache per-post like streams.
Stream should update only if post.id or uid changes.
Aggregate like count updates should be transaction-safe or best-effort depending on current implementation.

If user sees:

Could not add comment. Please try again.

inspect:

post_detail_screen.dart
community_provider.dart
firestore_service.dart
firestore.rules
16. Notification Rules

Notification creation must not block core user actions.

Examples:

Meal save
Weekly save
Budget warning
Palengke reminder
Comment notification
Like notification

If notification write fails:

Core action should still succeed if primary data write succeeded.
Log notification failure.
Do not keep Save button stuck.

Avoid slow notification patterns:

GET before SET for deterministic notification IDs

Preferred:

await docRef.set(data, SetOptions(merge: false));

when ID is deterministic and overwrite is safe.

17. Error Handling Rules

Never show raw technical errors to users:

Do not show:

FIRESTORE INTERNAL ASSERTION FAILED
LateInitializationError
onSnapshotUnsubscribe has not been initialized
Exception: ...

Show friendly messages:

Something went wrong. Please try again.
Could not load data. Please try again.
Could not save meal. Please try again.
Please check your connection and try again.

During debugging:

Log exact error to console using debugPrint or developer.log.
Keep user-facing message simple.
Do not swallow errors silently when debugging active failures.
18. Async / Mounted Safety

After every async call in a StatefulWidget, check:

if (!mounted) return;

Before:

setState(() {});
Navigator.push(...);
ScaffoldMessenger.of(context).showSnackBar(...);
showDialog(...);

Do not use BuildContext across async gaps without checking mounted.

19. Image Safety

Never pass empty string to NetworkImage.

Fallback order:

1. Exact local asset
2. Resolver/category local asset
3. Valid network image
4. Placeholder

Rules:

Use local food assets when available.
Do not show misleading food images.
If exact image is unavailable, show placeholder.
Example: Boiled Egg should not use tuna_omelette if no egg image exists.
Image widgets must handle broken URLs and empty paths.
20. AI Meal Planner Rules

The AI Meal Planner must remain demo-stable.

Expected demo path:

AI Planner → Generate daily plan → Save selected meals → Meal Log
AI Planner → Generate weekly plan → Save weekly plan → Meal Log / Palengke

Required behavior:

Loading state visible.
AI/API failure uses local fallback.
Local dataset fallback works.
Saved meals appear on correct date.
Weekly plan avoids obvious repetition when possible.
Weekly save does not duplicate meals.
Weekly save does not get stuck on “Saving...”.
Buttons reset after success/failure.

Do not:

Remove dummy/demo fallback meals.
Depend only on external AI/API.
Return blank meal plan during demo.
Rewrite planner service unless task requires it.
21. NutriBot / API Rules

NutriBot should not crash the app.

If API fails:

Return local fallback response.
Show friendly message.
Do not expose API errors to user.

Do not expose secrets in Flutter client if avoidable.

Do not change NutriBot during unrelated phases.

22. UI / Responsiveness Rules

Current UI goal:

Make existing app look clean on Android and iOS phones.
Do not redesign the whole theme.

Check:

320px width
360px width
390px width
large phone width
iOS notch/status bar
Android gesture navigation
keyboard open state

UI must avoid:

Yellow/black overflow warnings
Text clipping
Buttons too close
Cards touching screen edges
Bottom nav covering content
Dialogs too tall
Popups not scrollable
Fixed rows that overflow
Hardcoded widths where wrap/flex is needed

Preferred fixes:

SafeArea
SingleChildScrollView
LayoutBuilder
Wrap
Flexible
Expanded
ConstrainedBox
MediaQuery
Scroll-safe dialogs
Responsive stacking on small width
23. Popup / Dialog Rules

All dialogs and popups should be safe on small screens.

Rules:

Use insetPadding.
Use scrollable content for long dialogs.
Use max-height constraints for bottom sheets.
Avoid too many horizontal action buttons.
Use vertical buttons if actions overflow.
Keep dialogs centered and readable.

Check:

Saved dialog
Duplicate basket dialog
Manual log dialog
Swap sheet
Forgot password dialog
Image source dialog
Comment/report dialogs
24. Defense Demo Rules

During demo:

Use stable features only.

Recommended demo path:

1. Launch app
2. Login
3. Home
4. Meal Log
5. AI Meal Planner
6. Generate daily plan
7. Save meals
8. View Meal Log
9. Generate weekly plan
10. Save weekly plan
11. Open Palengke if stable
12. Show Profile

Avoid risky flows unless tested:

Scanner
NutriBot live API
Community heavy interactions
External image/API dependency

Demo fallback explanations:

The app uses a local food dataset for stable meal suggestions.
If exact food images are unavailable, it uses safe placeholders.
AI features have fallback responses to avoid demo interruption.
25. Testing Agent Checklist

Before demo:

[ ] Correct folder confirmed
[ ] flutter analyze passed
[ ] flutter test passed
[ ] App launches
[ ] No Firestore INTERNAL ASSERTION error
[ ] Login works
[ ] Logout/login again works
[ ] Home loads
[ ] Meal Log loads
[ ] Daily AI plan generates
[ ] Daily save works
[ ] Weekly plan generates
[ ] Weekly save works
[ ] Home shows today meals
[ ] Community does not crash
[ ] No stuck loading
[ ] No red error screen
[ ] No yellow overflow warning
[ ] Dialogs are scroll-safe
[ ] Bottom nav does not overlap content
26. Manual Test Flows
Auth Flow
Open app → Login/Register → Main app
Logout → Login again

Expected:

No stuck Splash
No infinite spinner
ProfileSetup appears only when needed
Meal Flow
Meal Log → Log Meal → Check Home

Expected:

Meal logs successfully
Home updates
No stale error snackbar
AI Planner Daily Flow
AI Planner → Generate → Save selected → Back to Meal Log

Expected:

Meals save
Correct images or placeholders
Correct selected date
AI Planner Weekly Flow
AI Planner → Weekly → Generate → Save weekly

Expected:

Weekly meals save
No duplicates on second save
No stuck Saving
Palengke can use saved ingredients
Community Flow
Community → Post detail → Add comment → Like/unlike

Expected:

Comment posts
Like updates
No Firestore crash
UI Flow
Small phone width → Home → Meal Log → AI Planner → Profile

Expected:

No overflow
No clipped text
Popups align correctly
Bottom nav safe
27. Fail Conditions

App is not ready if:

Crash occurs
Red error screen appears
Firestore internal assertion appears
User gets stuck loading
Save stays on Saving...
Meal cannot be logged
Weekly plan cannot be saved
Home and Meal Log disagree
Important button does nothing
Dialog overflows screen
Bottom nav covers content

If any fail condition happens:

Stop.
Capture logs.
Identify exact flow.
Fix root cause.
Retest.
28. Git / File Hygiene

Before final demo:

Check:

git status

Important files should not remain accidentally untracked if required:

firestore.rules
storage.rules
progress_dashboard_screen.dart
AGENT.md
TESTING_AGENT.md

Generated/build files should not be committed unless intentionally required:

build/
.dart_tool/
.flutter-plugins-dependencies
*.log

Do not delete files unless proven unused.

29. Final Agent Instruction

You are working on a stabilization-phase app.

Your priorities are:

1. Stability
2. Data integrity
3. Demo reliability
4. UI correctness
5. UX polish

Do not prioritize:

New features
Large redesigns
Experimental refactors
Unapproved architecture changes

Final rule:

If the user cannot complete the flow, it is broken.
Fix → test → report.