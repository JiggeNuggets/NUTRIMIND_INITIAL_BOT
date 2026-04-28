# NutriMind AGENT.md (FINAL – PRODUCTION CONTROL)

Last updated: 2026-04-27

---

# 🧠 PROJECT OVERVIEW

NutriMind is an AI-powered nutrition mobile app built with Flutter + Firebase.

Architecture:
UI → Provider → Service → Firestore

---

# 🎯 CURRENT PHASE

**Stabilization + Real Device Testing**

---

# 🔴 CURRENT CRITICAL BUG

## Firestore INTERNAL ASSERTION FAILED

### Status:

ACTIVE

### Root Cause:

At least one Firestore stream/query is using:

* empty uid (`''`)
* null uid

This creates invalid paths:
users//meals ❌

### Impact:

* Home data not loading
* Weekly plan not visible
* Palengke empty
* Meal Log broken
* Streams silently fail

### Fix Strategy (STRICT):

* Audit ALL Firestore queries and streams
* Add uid validation BEFORE any Firestore call
* Block invalid streams

---

# 🧾 APP DIRECTORY

Active app:
C:\Users\wapak\Downloads\nutrimind-main\nutrimind-main\nutrimind

⚠️ RULE:

* NEVER run from root app
* ALWAYS run nested app

---

# ✅ EXECUTION RULES (STRICT)

## 🔒 GENERAL

* DO NOT break working features
* DO NOT add new features during debugging
* ALWAYS fix root cause, not symptoms
* DO NOT refactor unrelated code

---

## 🔴 FIRESTORE RULES (CRITICAL)

### UID VALIDATION

```dart
void validateUid(String? uid) {
  if (uid == null || uid.isEmpty) {
    throw ArgumentError('Invalid uid');
  }
}
```

RULE:

* MUST be called before ANY Firestore read/write

---

### STREAM GUARD

```dart
if (uid == null || uid.isEmpty) {
  return Stream.value(<MealModel>[]);
}
```

RULE:

* NEVER start snapshots() with empty uid

---

### NUMERIC SAFETY

BAD:

```dart
price: price
```

GOOD:

```dart
price: safeDouble(price)
```

```dart
double safeDouble(dynamic value) {
  if (value == null) return 0;
  if (value.isNaN || value.isInfinite) return 0;
  return value.toDouble();
}
```

---

## 🔵 PROVIDER RULE

* UI MUST NEVER call Firestore directly
* ALL data must go through Provider/Service

---

## 🟣 UI SAFETY

```dart
if (!mounted) return;
```

RULE:

* ALWAYS check before setState after async

---

## ⚠️ ERROR HANDLING

NEVER show:
FIRESTORE INTERNAL ASSERTION FAILED

ALWAYS show:
"Something went wrong. Please try again."

---

## 🖼 IMAGE RULES

* NEVER pass empty string to NetworkImage

FALLBACK ORDER:

1. Local asset
2. Network image
3. Placeholder

---

## 🎯 DEMO SAFETY RULE (VERY IMPORTANT)

App must NEVER crash during demo.

Fallbacks REQUIRED:

* NutriBot → local response
* Images → placeholder
* Planner → local dataset
* Firestore → guarded queries

---

## 🧪 DEBUGGING MODE (STRICT)

Steps:

1. Identify failing feature
2. Trace full function chain
3. Find provider/service issue
4. Fix at ROOT level only
5. Test real user flow

DO NOT:

* patch UI only
* guess fixes
* ignore logs

---

# 🧩 SYSTEM STATUS (SUMMARY)

Meal Logging → PARTIAL
AI Planner → PARTIAL
Palengke → PARTIAL
Recipe Browser → PARTIAL
NutriBot → PARTIAL
Community → NEEDS FIX
Profile → NEEDS FIX

---

# ⚠️ KNOWN RISKS

* Duplicate Flutter apps
* Missing Firestore rules
* Missing Storage rules
* Prototype datasets
* Scanner images not uploaded
* NutriBot fallback hides API issues

---

# 🚀 PRIORITY ORDER

1. Fix Firestore uid issue (CRITICAL)
2. Fix Meal Logging reliability
3. Fix Weekly Plan + Palengke
4. Fix Profile state sync
5. Fix Community like state

---

# 🤖 AGENT USAGE RULES

When using AI:

* Follow Execution Rules STRICTLY
* Fix ONLY current critical bug first
* DO NOT modify unrelated features
* DO NOT redesign UI

Priority:

1. Stability
2. Data integrity
3. UI correctness
4. UX improvements

---

# 🧠 FINAL NOTE

This project is in **stabilization phase**

Goal:
✔ no crashes
✔ working features
✔ stable demo
✔ real functionality

NOT:
❌ adding features
❌ redesigning UI
❌ experimenting

---
