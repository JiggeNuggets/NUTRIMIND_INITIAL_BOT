# NutriMind CODE_AGENT.md (Clean Code Control)

Last updated: 2026-04-27

---

# 🎯 PURPOSE

This agent is used for:

* Writing new code
* Improving existing code
* Maintaining code quality
* Preventing bugs before they happen

---

# 🚫 STRICT LIMITS

DO NOT:

* Break working features
* Modify unrelated files
* Introduce new architecture
* Refactor everything at once

ONLY:

* Write clean, safe, minimal code
* Follow existing structure

---

# 🧠 CORE PRINCIPLE

👉 **Simple > Smart**

* Avoid complex logic
* Avoid over-engineering
* Code must be readable by YOU (not just AI)

---

# 🏗 ARCHITECTURE RULE (MANDATORY)

Follow STRICT flow:

UI → Provider → Service → Firestore

---

## 🔵 UI LAYER

Responsibilities:

* Display data
* Handle user interaction
* Call Provider

DO NOT:

* Call Firestore directly
* Contain business logic

---

## 🟢 PROVIDER LAYER

Responsibilities:

* Manage state
* Call Service
* Prepare data for UI

DO:

* Validate inputs (uid, values)
* Handle loading/error states

---

## 🟣 SERVICE LAYER

Responsibilities:

* Firestore reads/writes
* API calls

DO:

* Keep functions clean
* Handle Firestore structure

---

# 🔴 FIRESTORE SAFETY RULES

## UID VALIDATION (MANDATORY)

The project uses **inline guards** -- no centralized `validateUid` function exists.

Pattern used in `FirestoreService`:

```dart
Stream<List<MealModel>> mealsStream(String uid, DateTime date) {
  if (uid.isEmpty) return Stream.value(const <MealModel>[]);
  // ... Firestore query
}
```

Pattern used in `MealProvider`:

```dart
void listenToMeals(String uid) {
  if (uid.isEmpty) return;
  // ...
}
```

---

## NUMERIC SAFETY

Actual code in `lib/utils/firestore_safety.dart`:

```dart
double safeDouble(double? v) {
  if (v == null || v.isNaN || v.isInfinite) return 0;
  return v;
}
```

Note: parameter is `double?`, not `dynamic`.

---

## DOCUMENT CREATION RULE

ALWAYS ensure:

* id is not empty
* userId is valid
* values are sanitized

---

# 🧾 MODEL RULES

* Models must be simple
* Use `.toMap()` and `.fromMap()`
* Avoid logic inside models

Example:

```dart
class MealModel {
  final String id;
  final String userId;
  final String name;
  final double price;

  MealModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'price': price,
    };
  }
}
```

---

# 🧱 FUNCTION RULES

## GOOD FUNCTION

* Short
* Single purpose
* Easy to read

BAD:

```dart
void doEverything() { ... }
```

GOOD:

```dart
Future<void> addMeal(MealModel meal)
Future<void> fetchMeals(String uid)
```

---

# 🟡 ERROR HANDLING RULE

NEVER:

* Show raw errors to user

ALWAYS:

* Catch error
* Show friendly message

Example:

```dart
catch (_) {
  showError("Something went wrong. Please try again.");
}
```

---

# 🟣 ASYNC SAFETY

ALWAYS:

```dart
if (!mounted) return;
```

BEFORE:

* setState
* showing snackbar
* navigation

---

# 🖼 IMAGE HANDLING RULE

NEVER:

* pass empty string to NetworkImage

ALWAYS:

* validate first

```dart
imageUrl != null && imageUrl.isNotEmpty
  ? NetworkImage(imageUrl)
  : AssetImage('assets/images/placeholder.png')
```

---

# 🧪 CODE QUALITY RULES

* No duplicate logic
* No unused variables
* No long functions (>50 lines)
* No hardcoded values (use constants if needed)

---

# 🔁 REUSABILITY RULE

If code repeats:
👉 extract function

Example:

* safeDouble (exists in `lib/utils/firestore_safety.dart`)
* inline uid guards
* showError

---

# ⚠️ COMMON MISTAKES TO AVOID

* Calling Firestore in UI ❌
* Not validating uid ❌
* Writing NaN values ❌
* Huge functions ❌
* Ignoring async state ❌

---

# 🤖 CODE AGENT RULES

When using AI:

* Write minimal code only
* Follow architecture strictly
* Do not guess field names
* Do not create new patterns
* Match existing project style

---

# 🚀 FINAL GOAL

Code must be:

✔ Clean
✔ Stable
✔ Readable
✔ Easy to debug
✔ Safe for production

---

# 🧠 FINAL NOTE

This project is NOT about:
❌ fancy code
❌ complex patterns

This project IS about:
✔ working system
✔ reliable behavior
✔ clear structure

---
