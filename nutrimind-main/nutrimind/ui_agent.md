# NutriMind UI_AGENT.md (Design & UX Control)

Last updated: 2026-04-27

---

# 🎯 PURPOSE

This agent controls:

* UI design
* layout consistency
* user experience (UX)
* visual quality

Goal:
✔ clean
✔ modern
✔ simple
✔ demo-ready

---

# 🚫 STRICT LIMITS

DO NOT:

* redesign the whole app
* change working layouts unnecessarily
* add clutter
* add too many elements

ONLY:

* improve clarity
* fix UI issues
* maintain consistency

---

# 🎨 DESIGN STYLE (MANDATORY)

NutriMind style:

* Light background (white / soft green)
* Primary color: green
* Accent: soft green + gray
* Rounded UI
* Minimal look

**Theme status:**
* `ModernAppTheme.lightTheme` is the active global theme (set in `main.dart`)
* Legacy `AppTheme` constants are still imported/used in some screens
* When editing, prefer `ModernAppTheme` tokens over `AppTheme`

---

# 📐 SPACING RULES

* Horizontal padding: **16px**
* Vertical spacing: **12–20px**
* Between sections: **20–24px**

NEVER:
❌ cramped UI
❌ uneven spacing

---

# 🧱 CARD DESIGN

ALL cards must:

* Border radius: **16–24**
* Padding: **12–16**
* Soft shadow (not heavy)
* Clean background (white or light green)

---

# 🔘 BUTTON RULES

### Primary Button

* Green background
* White text
* Rounded (20–28 radius)
* Height: 48–56

### Secondary Button

* Outline or soft green
* Not dominant

---

# 🧾 TEXT RULES

### Titles

* Bold
* Clear
* Short

### Subtext

* Gray / muted
* Support only

### Body

* Simple words
* Easy to read

---

# 📱 SCREEN STRUCTURE

Every screen must have:

1. Header (title or greeting)
2. Main content (cards / lists)
3. Clear action (button or FAB)

---

# 🧠 UX RULES (VERY IMPORTANT)

### 1. ONE PRIMARY ACTION

Each screen must have:
👉 only ONE main action

---

### 2. FEEDBACK REQUIRED

Every action must show:

✔ Loading
✔ Success
✔ Error

---

### 3. NO DEAD BUTTONS

Every button must:

* do something
* or show message

---

### 4. USER MUST UNDERSTAND

User should NEVER think:

❌ “What is this?”
❌ “What do I press?”

---

# ⏳ LOADING STATES

NEVER freeze UI.

Use:

* CircularProgressIndicator
* Skeleton cards
* “Generating meal…” text

---

# ❌ ERROR UI

NEVER show raw errors like:

FIRESTORE INTERNAL ASSERTION FAILED ❌

ALWAYS show:

✔ "Something went wrong. Please try again."

---

# 🖼 IMAGE RULES

Use SafeFoodImage / SafeAvatar pattern:

Fallback order:

1. Local asset
2. Network image
3. Placeholder

NEVER:

* show broken image
* show empty space

---

# 🧩 COMPONENT CONSISTENCY

* Same button style everywhere
* Same card design everywhere
* Same spacing everywhere

NO mixing styles ❌

---

# 📊 SPECIAL SCREENS RULES

## 🏠 Home

* Greeting + summary
* Today’s meals
* Clean cards

---

## 🍽 Meal Log

* Clear list of meals
* Show planned vs logged
* Action buttons visible

---

## 🧠 AI Planner

* Show loading clearly
* Show generated meals cleanly
* Save button obvious

---

## 🛒 Palengke

* Group items clearly
* Show prices
* Show status (bought/not)

---

## 🤖 NutriBot

* Chat style UI
* Clear messages
* Loading/thinking indicator

---

# 🎯 DEMO SAFETY RULE

UI must NEVER:

❌ freeze
❌ show crash
❌ show raw error

ALWAYS:
✔ show fallback UI
✔ show placeholder
✔ remain usable

---

# ⚠️ COMMON UI MISTAKES

* Too many buttons ❌
* No spacing ❌
* Overloaded screen ❌
* Hidden actions ❌
* No feedback ❌

---

# 🤖 UI AGENT RULES

When using AI:

* Keep UI minimal
* Do NOT redesign full screen
* Improve only necessary parts
* Maintain style consistency
* Respect spacing rules

---

# 🚀 FINAL GOAL

UI must be:

✔ clean
✔ simple
✔ consistent
✔ understandable
✔ demo-ready

---

# 🧠 FINAL NOTE

Good UI is not:
❌ fancy
❌ complex

Good UI is:
✔ clear
✔ usable
✔ smooth

---
