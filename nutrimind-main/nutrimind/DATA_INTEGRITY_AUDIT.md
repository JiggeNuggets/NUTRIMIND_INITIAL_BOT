# NutriMind Data Integrity Audit

Last updated: 2026-04-25

This file tracks production-visible data integrity findings and follow-up work.

---

## Phase 2 Addendum: Pantry + Scanner Hub

### DI-P2-001: Center scanner button opened one scanner flow only

- File path: `lib/screens/main/main_shell.dart`
- Feature/screen affected: Center food input navigation
- What changed: Center action now opens `ScanOptionsScreen` so users choose Scan Meal, Add Pantry Item, Barcode Scan, or Manual Meal Log.
- Production-visible: yes
- Replacement source: real user-selected flow
- Status: resolved
- Priority: High

### DI-P2-002: Pantry feature had no Firestore-backed user data path

- File paths:
  - `lib/models/pantry_item_model.dart`
  - `lib/services/firestore_service.dart`
  - `lib/screens/main/pantry_screen.dart`
- Feature/screen affected: Scanner/Pantry
- What changed: Manual pantry items now save to `users/{uid}/pantry_items/{itemId}` with real Firebase user ID.
- Production-visible: yes
- Replacement source: Firestore
- Status: resolved for add/edit/delete/list
- Priority: High

### DI-P2-003: Barcode flow risked implying unsupported packaged-item data

- File path: `lib/screens/main/scan_options_screen.dart`
- Feature/screen affected: Barcode Scan
- What changed: Barcode Scan is shown as Coming Soon and labeled for supermarket/package items only. No fake barcode data is created.
- Production-visible: yes
- Replacement source: planned package/barcode backend or dataset
- Status: mitigated
- Priority: Medium

### DI-P2-004: Confirmed scans had no separate history record

- File paths:
  - `lib/models/scanned_item_model.dart`
  - `lib/services/firestore_service.dart`
  - `lib/screens/main/food_scanner_screen.dart`
  - `lib/screens/main/scan_history_screen.dart`
  - `lib/screens/main/scan_options_screen.dart`
- Feature/screen affected: Scanner / Scan History
- What changed: Confirmed scanner saves now write to `users/{uid}/scanned_items/{scanId}` after the existing Meal Log save path succeeds. Scan History lists the latest confirmed scans with loading, empty, error, retry, and delete states.
- Production-visible: yes
- Replacement source: Firestore
- Status: resolved for text history; image URL and confidence remain optional/unmapped until scanner upload/confidence data exists.
- Priority: High

---

## Remaining Scanner/Pantry Data Work

- Add scan image upload/image URL and scanner confidence mapping if those fields become available from the AI result or backend.
- Add reuse-to-log from Scan History if users need to log a past scan again.
- Decide how pantry items should feed AI Meal Planner, Weekly Palengke List, or shopping recommendations.
- Add packaged-item barcode scanning only after a real barcode/product data source exists.
- Keep palengke/wet-market items manual or category-based because many do not have reliable barcodes.
