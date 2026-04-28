# NutriMind AI_PLANNER_AGENT.md (Decision Support System Control)

Last updated: 2026-04-27

---

# 🎯 PURPOSE

This agent controls:

✔ AI Meal Planner logic
✔ meal generation
✔ budget + calorie optimization
✔ saving meals to log

---

# 🧠 CORE CONCEPT

The AI Planner is a:

👉 **Decision Support System (DSS)**

NOT:
❌ random meal generator
❌ chatbot output

---

# 🎯 GOAL

Generate meals that are:

✔ within budget
✔ within calorie needs
✔ locally relevant (Davao foods)
✔ nutritionally balanced

---

# 🔴 INPUT VARIABLES

Planner must consider:

* user goal (lose / gain / maintain)
* daily budget
* calorie target (BMR-based)
* local food dataset
* user preferences (if available)

---

# 🟢 OUTPUT

Planner produces:

* breakfast
* lunch
* dinner
* snack

Each meal must have:

* name
* calories
* price
* macros (protein, carbs, fat)
* ingredients
* optional notes

---

# 🧠 GENERATION RULES

## CALORIE RULE

Total daily calories must:

✔ match target range
❌ not exceed excessively

---

## BUDGET RULE

Total cost must:

✔ stay within budget
✔ prioritize cheaper alternatives

---

## LOCAL FOOD RULE

Prefer:

✔ Davao / Filipino foods
✔ affordable ingredients

---

## BALANCE RULE

Meals must:

✔ include protein
✔ include carbs
✔ include fat

---

# 🔁 FALLBACK RULE

If full data not available:

* use calorie-only fallback dataset
* generate simple meals

---

# 🔴 SAVE FLOW (CRITICAL)

Planner must follow this EXACT path:

AI Planner
→ `_saveSelectedMealsToLog`
→ `_savePlannerDraftToMealLog`
→ `MealProvider.addPlannedMeal()`
→ `FirestoreService.addMeal()`
→ users/{uid}/meals

---

# ⚠️ SAVE RULES

Before saving:

## UID VALIDATION

Inline guard (no centralized helper):

```dart
if (uid.isEmpty) return;
```

---

## DATA VALIDATION

* meal name not empty
* calories valid
* price valid

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

## SAVE SUCCESS UX

After saving selected meals:
* Success dialog appears with "View My Plan" button (not just a snackbar)
* User can navigate to Meal Log directly from the dialog
* Pressing back while generating shows a confirmation dialog

---

# 🟡 IMAGE RULE

Planner meals:

* MAY have imageUrl
* MAY be null

Fallback handled by UI:
SafeFoodImage

---

# 🔵 DUPLICATE HANDLING

Planner must:

✔ avoid duplicate meals
✔ replace duplicates if needed

---

# 🧪 TEST FLOW

Test:

1. Open AI Planner
2. Generate meals
3. Save meals
4. Check Meal Log

Expected:

✔ meals appear
✔ no crash
✔ correct data

---

# ⚠️ FAILURE CONDITIONS

Planner is broken if:

❌ meals not saved
❌ Firestore error appears
❌ duplicate meals
❌ empty meals
❌ UI freezes

---

# 🎯 UX RULES

Planner must:

✔ show loading ("Generating meals...")
✔ show results clearly
✔ show Save button clearly

---

# 🤖 AI USAGE RULES

When using AI:

* do NOT hallucinate data
* use local dataset first
* keep results realistic

---

# 🧠 DSS EXPLANATION (FOR DEFENSE)

If asked:

👉 “What makes this AI?”

Answer:

“This is a Decision Support System that combines user input (budget, goals, calories) with structured food data to generate optimized meal plans.”

---

# 🚀 FINAL GOAL

Planner must be:

✔ reliable
✔ realistic
✔ fast
✔ stable

---

# 🧠 FINAL NOTE

This feature is:

👉 your strongest innovation
👉 your main selling point

Make sure it:
✔ works
✔ does not crash
✔ saves correctly

---
