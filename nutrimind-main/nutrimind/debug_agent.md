# NutriMind DEBUG_AGENT.md (Bug-Fixing Control)

Last updated: 2026-04-27

---

# 🎯 PURPOSE

This agent is used ONLY for debugging.

Goal:

* Identify root cause
* Fix at the correct layer
* Prevent regressions

---

# 🚫 STRICT LIMITS

DO NOT:

* Add new features
* Redesign UI
* Refactor unrelated code
* Change working logic

ONLY:

* Fix the current bug

---

# 🟢 PREVIOUSLY ACTIVE TARGET (NOW RESOLVED)

## Firestore INTERNAL ASSERTION FAILED

### Status: RESOLVED (Phase 1 — 2026-04-26)

### Was Caused By:

* Empty or null `uid` passed to Firestore streams
* Invalid numeric values (NaN / Infinity)

### Fixes Applied:

* uid guards added to all 11 FirestoreService stream methods
* MealProvider guards in listenToMeals, selectDate, logMeal
* safeDouble(double? v) prevents NaN/Infinity
* Friendly error snackbars replace raw stack traces

---

# 🧠 DEBUG WORKFLOW (MANDATORY)

Follow EXACT order:

## 1. Reproduce

* Trigger the bug manually
* Identify exact screen / action

---

## 2. Trace Call Chain

Track flow:

UI → Provider → Service → Firestore

Example:
AI Planner → saveSelectedMeals → MealProvider.addPlannedMeal → FirestoreService.addMeal

---

## 3. Validate Inputs

Check BEFORE Firestore call:

### UID

Actual pattern (inline guard, no centralized helper):

```dart
if (uid.isEmpty) return Stream.value(const <MealModel>[]);
```

### Numbers

Actual code in `lib/utils/firestore_safety.dart`:

```dart
double safeDouble(double? v) {
  if (v == null || v.isNaN || v.isInfinite) return 0;
  return v;
}
```

Note: parameter is `double?`, not `dynamic`.

---

## 4. Fix at ROOT (not UI)

Bad:

* Showing snackbar only
* Catching error silently

Good:

* Fix provider/service logic
* Prevent invalid write/query

---

## 5. Test Full Flow

Test real scenario:

* Generate meal
* Save meal
* View Home
* View Weekly Plan
* View Palengke

---

# 🔴 FIRESTORE DEBUG RULES

## UID RULE

NEVER allow:

* `''`
* `null`

---

## STREAM RULE

```dart
if (uid.isEmpty) {
  return Stream.value(const <MealModel>[]);
}
```

---

## PATH RULE

INVALID:
users//meals ❌

VALID:
users/{uid}/meals ✅

---

## NUMERIC RULE

NEVER write:

* NaN
* Infinity

ALWAYS:

Actual code:

```dart
double safeDouble(double? v) {
  if (v == null || v.isNaN || v.isInfinite) return 0;
  return v;
}
```

---

# 🟡 UI DEBUG RULES

* Always check `mounted` before `setState`
* Replace raw errors with friendly message
* Do NOT rely on UI fixes

---

# 🧪 VALIDATION CHECKLIST

Before marking bug as fixed:

* [ ] No Firestore assertion errors
* [ ] Meal saves successfully
* [ ] Home loads meals
* [ ] Weekly plan visible
* [ ] Palengke loads correctly
* [ ] No empty uid used anywhere

---

# 🚨 COMMON BUG SOURCES

* Auth not ready (uid empty)
* Provider initialized too early
* Missing guards in streams
* Unsafe numeric values
* Wrong Firestore path

---

# 🤖 DEBUG AGENT RULES

When using AI:

* Analyze BEFORE editing
* Show exact file + line
* Modify minimal code only
* Do NOT guess fixes
* Explain WHY fix works

---

# 🧠 FINAL RULE

If the bug still exists:
👉 You did NOT fix the root cause

Repeat:
Trace → Validate → Fix → Test

---
