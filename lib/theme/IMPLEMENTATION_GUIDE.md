# NutriMind Modern Design System
## Implementation Guide

---

## 📋 Quick Start

### Step 1: Update Main App Theme
In `lib/main.dart`, update to use the modern theme:

```dart
import 'package:flutter/material.dart';
import 'theme/modern_app_theme.dart';
import 'theme/app_theme.dart'; // Keep for compatibility

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const NutriMindApp());
}

class NutriMindApp extends StatelessWidget {
  const NutriMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MealProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
      ],
      child: MaterialApp(
        title: ModernAppTheme.appName,
        debugShowCheckedModeBanner: false,
        theme: ModernAppTheme.lightTheme, // ← Use modern theme
        home: const AuthGate(),
      ),
    );
  }
}
```

### Step 2: Update Component Imports
Replace old theme imports:

```dart
// OLD
import '../../theme/app_theme.dart';

// NEW
import '../../theme/modern_app_theme.dart';
import '../../widgets/modern_components.dart'; // For reusable components
```

---

## 🎨 Screen-by-Screen Implementation

### Home Screen Modernization

**File:** `lib/screens/main/home_screen.dart`

**Key Changes:**
1. Replace budget card with gradient version
2. Update meal cards with MealCard component
3. Add glassmorphism effects to summary cards
4. Implement smooth transitions

**Example:**

```dart
// OLD
Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    gradient: const LinearGradient(...),
    borderRadius: BorderRadius.circular(20),
  ),
  // ...
);

// NEW - Using modern theme
Container(
  padding: const EdgeInsets.all(ModernAppTheme.spacingLg),
  decoration: BoxDecoration(
    gradient: ModernAppTheme.gradientPrimary,
    borderRadius: BorderRadius.circular(ModernAppTheme.radiusXl),
    boxShadow: ModernAppTheme.shadowLg,
  ),
  // ...
);
```

### Meal Log Screen Modernization

**File:** `lib/screens/main/meal_plan_screen.dart`

**Key Changes:**
1. Replace existing meal cards with `MealCard` component
2. Update calendar selector styling
3. Modernize summary bar
4. Add smooth expand/collapse animations

**Example:**

```dart
// Use MealCard component instead of building custom widgets
MealCard(
  mealName: meal.name,
  mealType: meal.typeLabel,
  price: meal.price,
  calories: meal.calories,
  isLogged: meal.status == MealStatus.logged,
  ingredients: meal.ingredients,
  protein: meal.protein,
  carbs: meal.carbs,
  fat: meal.fat,
  onExpand: () => setState(() { /* toggle expand */ }),
  onRecipe: () => Navigator.push(...),
  onDelete: () => _deleteMeal(meal.id),
  onLog: () => _logMeal(meal.id),
)
```

### Profile Screen Modernization

**File:** `lib/screens/main/profile_screen.dart`

**Key Changes:**
1. Replace BMI card with `NutritionSummaryCard`
2. Update stats row with modern styling
3. Modernize settings list items
4. Add gradient backgrounds

**Example:**

```dart
// Use NutritionSummaryCard component
NutritionSummaryCard(
  bmi: bmi,
  bmiCategory: _getBmiCategory(bmi),
  height: user?.height ?? 170,
  weight: user?.weight ?? 65,
  age: user?.age ?? 28,
  gender: user?.gender ?? 'Male',
  advice: _getBmiAdvice(bmi),
)
```

### Button Modernization

**File:** Various screen files

**Replace all button styles:**

```dart
// OLD
ElevatedButton(
  onPressed: _handleSubmit,
  child: const Text('Submit'),
)

// NEW - Using PrimaryButton component
PrimaryButton(
  label: 'Submit',
  onPressed: _handleSubmit,
  isLoading: _isLoading,
  isDisabled: !_formValid,
)

// For secondary actions
SecondaryButton(
  label: 'Cancel',
  onPressed: _handleCancel,
)
```

### Input Field Modernization

**Files:** Authentication screens, profile editing

**Update InputDecorationTheme in modern_app_theme.dart is already applied globally:**

```dart
// The app theme automatically applies modern styling to:
TextFormField(
  decoration: InputDecoration(
    labelText: 'Email',
    hintText: 'you@example.com',
  ),
  // Will automatically use modern theme!
)
```

### Bottom Navigation Modernization

**File:** `lib/screens/main/main_shell.dart`

**Key Changes:**
1. Ensure center Scan button styling
2. Update bottom nav bar styling
3. Add smooth animations on tab change

**Already implemented with modern styling!** The app already has:
- Green center Scan button with shadow
- Clean bottom nav bar
- Smooth transitions

### Scanner Screen

**File:** `lib/screens/main/food_scanner_screen.dart`

**Already well-designed!** Just ensure it uses modern colors:

```dart
// Update color references
Icon(Icons.document_scanner_outlined, 
  color: ModernAppTheme.primaryGreen) // ← Use modern color

// Update button styling
Container(
  decoration: BoxDecoration(
    color: ModernAppTheme.primaryGreen,
    borderRadius: BorderRadius.circular(ModernAppTheme.radiusMd),
    boxShadow: ModernAppTheme.shadowLg,
  ),
)
```

---

## 🔄 Migration Checklist

### Phase 1: Foundation (1–2 hours)
- [ ] Update `main.dart` to use `ModernAppTheme`
- [ ] Replace all `AppTheme` imports with `ModernAppTheme`
- [ ] Update color references throughout codebase
- [ ] Test app runs without errors

### Phase 2: Components (2–3 hours)
- [ ] Implement `PrimaryButton` across all screens
- [ ] Implement `SecondaryButton` where needed
- [ ] Update `MealCard` usage in Meal Log screen
- [ ] Update `NutritionSummaryCard` in Profile screen
- [ ] Test all interactions

### Phase 3: Screens (3–4 hours)
- [ ] Modernize Home screen (colors, spacing, shadows)
- [ ] Modernize Profile screen
- [ ] Modernize Community screen
- [ ] Modernize Scanner screen
- [ ] Modernize Recipe screen

### Phase 4: Polish (2–3 hours)
- [ ] Add animations and transitions
- [ ] Fine-tune spacing and alignment
- [ ] Test responsive design on different screen sizes
- [ ] User testing and feedback

### Phase 5: Advanced (2–3 hours)
- [ ] Add dark mode support
- [ ] Implement accessibility improvements
- [ ] Optimize performance
- [ ] Final polish and refinement

---

## 🎨 Design Token Usage

### Colors

```dart
// Primary actions, branding
ModernAppTheme.primaryGreen
ModernAppTheme.successGreen
ModernAppTheme.accentGreen

// Secondary accents
ModernAppTheme.mint
ModernAppTheme.pastelBlue
ModernAppTheme.pastelPurple

// Status colors
ModernAppTheme.success
ModernAppTheme.warning
ModernAppTheme.error
ModernAppTheme.info

// Neutrals
ModernAppTheme.white
ModernAppTheme.textDark
ModernAppTheme.textMid
ModernAppTheme.textLight
```

### Spacing

```dart
// Always use spacing scale
Padding(
  padding: const EdgeInsets.all(ModernAppTheme.spacingLg),
  // ...
)

SizedBox(height: ModernAppTheme.spacingMd)

// Never use magic numbers!
```

### Border Radius

```dart
// Use consistent rounded corners
BorderRadius.circular(ModernAppTheme.radiusMd)
BorderRadius.circular(ModernAppTheme.radiusLg)
BorderRadius.circular(ModernAppTheme.radiusXl)
```

### Shadows

```dart
// Apply shadows consistently
boxShadow: ModernAppTheme.shadowMd,
boxShadow: ModernAppTheme.shadowLg,
```

### Typography

```dart
// Use predefined text styles
style: ModernAppTheme.heroTitle
style: ModernAppTheme.sectionTitle
style: ModernAppTheme.body
style: ModernAppTheme.caption
```

---

## 📱 Responsive Design Tips

### Mobile-First Approach
- Base design: 375–480px (iPhone SE to iPhone 12)
- Use `MediaQuery` for larger screens
- Test on multiple device sizes

### Flexible Layouts
```dart
// Good - Responsive
Column(
  children: [
    Flexible(child: MealCard(...)),
    Flexible(child: MealCard(...)),
  ],
)

// Bad - Fixed sizes
Column(
  children: [
    SizedBox(height: 200, child: MealCard(...)),
    SizedBox(height: 200, child: MealCard(...)),
  ],
)
```

---

## 🚀 Performance Optimization

### Image Optimization
- Use `Image.network` with `cacheHeight` and `cacheWidth`
- Implement image placeholder strategies
- Use `NetworkImage` for profile photos

### Animation Performance
- Limit simultaneous animations
- Use `SingleTickerProviderStateMixin` for single animations
- Prefer `Transform` over rebuilding widgets

### Build Optimization
- Use `const` constructors
- Implement `shouldRebuild()` in providers
- Use `RepaintBoundary` for complex widgets

---

## 🧪 Testing Checklist

### Visual Testing
- [ ] Verify colors match design system
- [ ] Check spacing and alignment
- [ ] Test on light backgrounds
- [ ] Verify button states (normal, pressed, disabled, loading)

### Interaction Testing
- [ ] Tap buttons and verify feedback
- [ ] Test form validation states
- [ ] Verify navigation transitions
- [ ] Test scroll performance

### Responsive Testing
- [ ] Test on iPhone SE (375px)
- [ ] Test on iPhone 14 Pro Max (430px)
- [ ] Test on tablets (iPad)
- [ ] Test landscape orientation

### Accessibility Testing
- [ ] Verify text contrast ratios (WCAG AA)
- [ ] Test with screen reader
- [ ] Verify tap target sizes (48x48px minimum)
- [ ] Test with text scaling

---

## 📚 Resources

### Design System Files
- `lib/theme/modern_app_theme.dart` - All design tokens
- `lib/theme/modern_design_system.md` - Full design documentation
- `lib/widgets/modern_components.dart` - Reusable components

### Flutter Documentation
- [Material 3 Design](https://m3.material.io/)
- [Flutter Widget Catalog](https://flutter.dev/docs/development/ui/widgets)
- [Responsive Design](https://flutter.dev/docs/development/ui/layout/responsive)

### Best Practices
- Use design tokens consistently
- Follow naming conventions
- Keep components reusable
- Document custom components

---

## 🎯 Next Steps

1. **Start with Phase 1** - Update theme and colors
2. **Implement components** - Use `PrimaryButton`, etc.
3. **Update screens incrementally** - One screen at a time
4. **Get user feedback** - Test with real users
5. **Iterate and refine** - Based on feedback

---

## 📞 Support

For questions or issues:
1. Check design system documentation
2. Review example implementations
3. Test with Flutter DevTools
4. Verify color contrast with accessibility tools

---

**Version:** 2.0  
**Last Updated:** April 21, 2026  
**Status:** Ready for Implementation
