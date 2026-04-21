# NutriMind Modern Design System v2.0
## Premium AI-Powered Nutrition & Meal Planning App

---

## 🎨 Design Philosophy

**Brand Personality:**
- Healthy & intelligent
- Friendly & motivating
- Futuristic yet warm
- Trustworthy & lightweight
- Calming & premium

**Visual Aesthetic:**
- Clean minimal layouts
- Soft pastel gradients
- Rounded cards & panels (16–28px)
- Subtle glassmorphism effects
- Airy spacing & breathing room
- Elegant typography
- Smooth, premium mobile feel

---

## 🌈 Enhanced Color Palette

### Primary Colors (Wellness Focus)
```
Primary Green       #2D6D4F  (Sage green - nature, health, growth)
Success Green       #4CAF50  (Bright green - positive, logged)
Accent Green        #81C784  (Light green - accents, highlights)
Soft Green          #E8F5E8  (Ultra light - backgrounds)
```

### Secondary Accent Colors (Wellness Accents)
```
Mint                #A8D8D8  (Fresh, clean, calming)
Pastel Blue         #B3D9FF  (Trust, calm, AI)
Pastel Purple       #E1BEE7  (Creative, wellness)
Pastel Pink         #F8BBD0  (Warm, friendly, health)
Warm Blush          #FFE0E0  (Soft, welcoming)
```

### Status & Feedback
```
Success             #4CAF50  (Green - accomplished)
Warning             #FF9800  (Orange - caution)
Error               #F44336  (Red - alert)
Info                #2196F3  (Blue - information)
```

### Neutral Palette
```
Surface White       #FFFFFF (Cards, panels)
Background Neutral  #FAFAFA (App background)
Light Gray          #F5F5F5 (Section backgrounds)
Medium Gray         #E8E8E8 (Dividers, borders)
Text Dark           #212121 (Primary text)
Text Mid            #757575 (Secondary text)
Text Light          #BDBDBD (Tertiary text)
```

---

## 📝 Typography System

### Font Family
**Primary Font:** `SF Pro Display` / `Roboto` / `-apple-system` (clean, modern, readable)

### Type Scale
```
Hero Title:         28–32px, FontWeight.w800, letter-spacing: -0.6
Section Title:      22–24px, FontWeight.w700
Card Title:         18–20px, FontWeight.w700
Body:               15–16px, FontWeight.w500
Label:              13–14px, FontWeight.w600
Caption:            11–12px, FontWeight.w400
```

### Line Heights
```
Headings:           1.2
Body Copy:          1.6
Labels:             1.4
```

---

## 🎯 Component Library

### Buttons

#### Primary Button (CTA)
- Background: Gradient (Primary Green → Accent Green)
- Text: White, Medium weight
- Padding: 14px vertical, 24px horizontal
- Border Radius: 12px
- Elevation: Soft shadow, no harsh borders
- State: Loading spinner overlay, disabled gray

#### Secondary Button
- Background: Soft Green (E8F5E8)
- Text: Primary Green
- Border: None
- Padding: Same as primary
- Border Radius: 12px

#### Outline Button
- Background: Transparent
- Border: 2px Primary Green
- Text: Primary Green
- Padding: 14px vertical, 24px horizontal
- Border Radius: 12px

#### Icon Button
- Size: 48x48px minimum
- Background: Soft Green circle or transparent
- Icon: Primary Green
- Hover: Slight fade

### Cards

#### Meal Card (Expandable)
```
Structure:
┌─────────────────────────────────────┐
│  🥗  Breakfast Title   ₱50  ✓       │
│      280 kcal  •  45% logged       │
│  [Expand Arrow]                     │
├─────────────────────────────────────┤
│  [Expanded Content - on tap]         │
│  • Ingredients: chip tags           │
│  • Macros: 20g protein, etc         │
│  • [View Recipe] button             │
└─────────────────────────────────────┘
```
- Background: White
- Border: 1px Light Gray (or green if logged)
- Border Radius: 16px
- Padding: 16px
- Shadow: Soft, 2–4px blur
- Interaction: Tap to expand, swipe to delete

#### Nutrition Summary Card
```
Structure:
┌─────────────────────────────────────┐
│  ⭕ BMI: 22.5                       │
│  Normal Weight                      │
│  Height: 170cm  Weight: 65kg        │
│  Age: 28  •  Male                   │
│  [Advice text in secondary color]   │
└─────────────────────────────────────┘
```
- Gradient background (based on BMI category)
- White text overlay
- Large circular progress indicator
- Rounded 20px corners
- Premium shadow effect

#### Dashboard Summary Chip
```
[Icon] Label
Value (bold, large)
e.g., [🔥] CALORIES
      280 kcal
```
- Small, compact cards (3–4 per row)
- Background: Gradient or solid pastel
- Icons: 20–24px
- Numbers: Bold, 18–20px

### Input Fields

#### Text Input
- Background: White or soft background
- Border: Light gray (1px), focus: Primary green (2px)
- Border Radius: 12px
- Padding: 12px horizontal, 14px vertical
- Placeholder: Light gray text
- Focus State: Glow effect (soft shadow with primary color)

#### Search Field
- Prefix Icon: Magnifying glass
- Suffix Icon: Clear (X) on input
- Border Radius: 24px (pill shape)
- Padding: 12px left, 16px (icon + text)
- Background: Soft gray or light green

### Navigation

#### Bottom Navigation Bar
```
[Home Icon]  [Log Icon]  [Scan ◯]  [Community]  [Profile]
  Unselected   Unselected  Active   Unselected   Unselected
```
- Height: 76–80px (safe for safe area)
- Background: White
- Icon Size: 24px (unselected), 24px (selected, highlight green)
- Label Size: 10–11px
- Color: Light gray (unselected) → Primary Green (selected)
- Center Scan: Larger circle (60px), elevated, slight shadow
- No harsh dividers, soft top border only

#### Top Navigation (App Bar)
- Background: White or transparent (scrollable content)
- Title: Bold, 18–20px, centered
- Back Button: Left side, 18–20px icon
- Actions: Right side (bell, settings, etc.)
- Elevation: 0 until scroll, then soft shadow

### Chatbot FAB

#### NutriBot Floating Action Button
```
    ╭─────────╮
    │  🤖     │
    │ NutriBot│
    ╰─────────╯
```
- Size: 64px diameter
- Background: Gradient (Primary Green → Mint)
- Icon: White, 32px
- Label: "Ask NutriBot" (tooltip)
- Shadow: Elevated, 8–12px blur
- Position: Bottom right, 16px margin
- Interaction: Tap → slide up chatbot modal
- Hover: Subtle scale up (105%)

---

## 📱 Screen Designs

### 1. Home Screen (Dashboard)

**Layout:**
```
┌─ Status Bar ─────────────────────────┐
│ AppBar: "NutriMind"  [Bell] [Settings]│
├──────────────────────────────────────┤
│ "Good morning, John! 👋"             │
│ "Your nutrition summary for today"   │
│                                      │
│ ╔════════════════════════════════╗  │
│ ║  DAILY FOOD BUDGET             ║  │
│ ║  ████░░░░ 280 / 400 kcal      ║  │
│ ║  ₱1,200 spent / ₱1,500 budget ║  │
│ ╚════════════════════════════════╝  │
│                                      │
│ ┌─ TODAY'S MEALS ──────────────────┐ │
│ │ 🥞 Breakfast                     │ │
│ │ ₱50  280 kcal  [Expand △]       │ │
│ │                                  │ │
│ │ 🍚 Lunch                         │ │
│ │ ₱120 480 kcal  [Expand △]       │ │
│ │                                  │ │
│ │ [+ Add Meal]                     │ │
│ └──────────────────────────────────┘ │
│                                      │
│ ╔════════════════════════════════╗  │
│ ║  💡 AI MEAL PLANNER            ║  │
│ ║  Generate your weekly plan     ║  │
│ ║  [GENERATE PLAN →]             ║  │
│ ╚════════════════════════════════╝  │
│                                      │
│ ┌─ LOCAL FOOD SPOTLIGHT ──────────┐ │
│ │ [Image] Davao Pomelo Salad      │ │
│ │ Fresh & Healthy • ₱45          │ │
│ │ 220 kcal • 4g protein          │ │
│ └──────────────────────────────────┘ │
└──────────────────────────────────────┘
```

**Design Details:**
- Background: Light green (soft, calming)
- Header: Large, friendly greeting
- Budget Card: Gradient (green → light green), with circular progress
- Meal Cards: White, expandable, clean layout
- CTA Buttons: Prominent, glowing green
- Spacing: 20px margins, 16px card padding

---

### 2. Meal Log Screen

**Layout:**
```
┌─ Status Bar ──────────────────────────┐
│ [← Back]  Meal Log  [🔄 Generate]    │
├────────────────────────────────────────┤
│ Week of April 21                       │
│ ┌─────────────────────────────────────┐│
│ │ M   T   W   T   F   S   S           ││
│ │[18] 19 [20] 21  22  23  24          ││
│ │                  ↑ Today            ││
│ └─────────────────────────────────────┘│
│                                        │
│ Summary: 1,240 kcal | ₱1,200 | 3 logged │
│                                        │
│ ┌─ BREAKFAST (9:30 AM) ───────────────┐│
│ │ 🥞 Pomelo Salad          45 kcal ✓ │
│ │ ┌─ Ingredients ─────────────────┐ │
│ │ │ Pomelo • Honey • Mint • Lime  │ │
│ │ │ Chia Seeds • Calamansi       │ │
│ │ └─────────────────────────────┘ │
│ │ ┌─ Nutrition ────────────────────┐│
│ │ │ 🔥 220 kcal  🥚 4g protein    ││
│ │ │ 🌾 52g carbs  🥑 1g fat       ││
│ │ └────────────────────────────────┘│
│ │ [🍳 View Recipe] [× Delete]       │
│ └─────────────────────────────────────┘│
│                                        │
│ ┌─ LUNCH ────────────────────────────┐│
│ │ 🍚 Grilled Tuna Steak [△ Expand]  │
│ │ ₱90 • 480 kcal • [Log This]       │
│ └─────────────────────────────────────┘│
│                                        │
│ [+ Add Manual Meal]                    │
└────────────────────────────────────────┘
```

**Design Details:**
- Calendar strip: Modern pill-shaped day selector (rounded corners)
- Summary bar: Compact, horizontal stats
- Meal cards: Large expandable sections with clear hierarchy
- Ingredient chips: Small, pastel backgrounds, bold text
- Macro display: Icon-based, easy to scan
- Delete: Swipe left to reveal delete action

---

### 3. Food Scanner Screen

**Layout (Camera Phase):**
```
┌────────────────────────────────────────┐
│         📷 Live Camera Feed           │
│     ╭──────────────────────╮          │
│     │   [Scan Frame]      │ <- Frame │
│     │   (green border)    │   for    │
│     │                    │   focus  │
│     ╰──────────────────────╯          │
│                                        │
│  🔄 [Flip] 📷 [CAPTURE] 🖼️ [Gallery] │
│                                        │
│  Bottom hint: "Point camera at food"  │
└────────────────────────────────────────┘
```

**Layout (Results Phase):**
```
┌────────────────────────────────────────┐
│         🍲 Scan Result                │
├────────────────────────────────────────┤
│ ┌─ Image Preview ────────────────────┐│
│ │     [Food Image Thumbnail]        ││
│ └────────────────────────────────────┘│
│                                        │
│ Grilled Tuna Steak                    │
│                                        │
│ 480 kcal  •  Lunch  •  ₱90            │
│                                        │
│ ┌─ Ingredients ──────────────────────┐│
│ │ Tuna • Soy Sauce • Calamansi      ││
│ │ Garlic • Ginger • Black Pepper    ││
│ └────────────────────────────────────┘│
│                                        │
│ "Great choice! Protein-rich meal.    │
│  Add to your daily plan?"             │
│                                        │
│ ┌──────────────────────────────────┐ │
│ │ [← Retake] [💾 Save to Log] ✓    │ │
│ └──────────────────────────────────┘ │
│                                        │
│ [Manual Log]                           │
└────────────────────────────────────────┘
```

**Design Details:**
- Camera frame: Elegant green border, 4:3 or 1:1 ratio
- Result card: Clean white background, image at top
- Text hierarchy: Dish name (big), details (secondary), comment (tertiary)
- CTA: Large green "Save" button, prominent action
- Bottom sheet: Smooth slide-up, semi-transparent backdrop
- Manual log form: Clean structured inputs (name, calories, type, price)

---

### 4. AI Meal Planner Screen

**Layout:**
```
┌─ Top Bar ─────────────────────────────┐
│ [← Back]  AI Meal Planner  [Info] ⓘ  │
├───────────────────────────────────────┤
│ "Let's build your perfect meal plan"  │
│                                       │
│ ┌─ Breakfast ─────────────────────────┐│
│ │ 🥣 Smart Morning Bowl              ││
│ │ 320 kcal • 12g protein • ₱45       ││
│ │                                    ││
│ │ "Start your day with energizing    ││
│ │  locally-sourced fruits and grains.││
│ │ Packed with antioxidants & fiber"  ││
│ │                                    ││
│ │ [🔄 Regenerate] [💾 Add to Plan]  ││
│ └─────────────────────────────────────┘│
│                                        │
│ ┌─ Lunch ──────────────────────────────┐│
│ │ 🍚 Bangus Sinigang (Milkfish Stew)  ││
│ │ 420 kcal • 38g protein • ₱85       ││
│ │                                    ││
│ │ "A beloved Filipino classic with  ││
│ │  fresh milkfish, tamarind, and    ││
│ │  garden vegetables. Hearty & rich" ││
│ │                                    ││
│ │ [🔄 Regenerate] [💾 Add to Plan]  ││
│ └─────────────────────────────────────┘│
│                                        │
│ ┌─ Dinner ─────────────────────────────┐│
│ │ 🥘 Tinola Manok (Ginger Chicken)    ││
│ │ 350 kcal • 30g protein • ₱70       ││
│ │                                    ││
│ │ "Light, healing soup with tender   ││
│ │  chicken, chayote, and moringa.   ││
│ │ Perfect for evening wellness"      ││
│ │                                    ││
│ │ [🔄 Regenerate] [💾 Add to Plan]  ││
│ └─────────────────────────────────────┘│
│                                        │
│ ╔═════════════════════════════════════╗│
│ ║ 📊 Daily Summary                    ║│
│ ║ Calories: 1,090  Protein: 80g      ║│
│ ║ [✓ Looks Good] [🔄 Regenerate All] ║│
│ ╚═════════════════════════════════════╝│
└────────────────────────────────────────┘
```

**Design Details:**
- Meal cards: Large, with emoji icons
- Narrative: Formatted as readable paragraphs
- Nutrition badges: Inline, easy to scan
- Regenerate button: Icon + text, secondary color
- Add to Plan CTA: Primary green, prominent

---

### 5. Recipe Generation Screen

**Layout:**
```
┌─ Top Bar ───────────────────────────────┐
│ [← Back]  Recipe: Pomelo Salad  [💾]  │
├─────────────────────────────────────────┤
│                                         │
│ 🥗 Davao Pomelo Salad                  │
│ 220 kcal  •  Breakfast                │
│                                         │
│ ┌─ Ingredients ──────────────────────┐ │
│ │ Pomelo • Davao Honey • Mint       │ │
│ │ Lime Juice • Chia Seeds            │ │
│ └────────────────────────────────────┘ │
│                                         │
│ ┌─ Nutrition ────────────────────────┐ │
│ │ [🔥 220] [🥚 4g] [🌾 52g] [🥑 1g] │ │
│ │  kcal    protein  carbs    fat     │ │
│ └────────────────────────────────────┘ │
│                                         │
│ ┌─ Recipe Description ──────────────┐ │
│ │ A refreshing and vibrant salad    │ │
│ │ highlighting Davao's famous       │ │
│ │ pomelos. The sweetness of honey   │ │
│ │ balances with citrus brightness.  │ │
│ │ Perfect for a healthy start!      │ │
│ └────────────────────────────────────┘ │
│                                         │
│ ┌─ Cooking Steps ───────────────────┐ │
│ │ 1️⃣  Peel and segment pomelo       │ │
│ │                                   │ │
│ │ 2️⃣  Lightly toast chia seeds      │ │
│ │                                   │ │
│ │ 3️⃣  Combine in bowl with honey    │ │
│ │                                   │ │
│ │ 4️⃣  Add fresh mint & lime juice   │ │
│ │                                   │ │
│ │ 5️⃣  Chill for 10 mins, serve      │ │
│ └────────────────────────────────────┘ │
│                                         │
│ ╔═════════════════════════════════════╗│
│ ║ [← Back] [💾 Save to Meal Log] ✓   ║│
│ ╚═════════════════════════════════════╝│
└─────────────────────────────────────────┘
```

**Design Details:**
- Hero section: Clear title + basics
- Ingredients: Chip-based, easy to read
- Macros: Icon-based cards, circular progress bars
- Description: Readable paragraph with line-height 1.6
- Steps: Numbered with emoji, clear hierarchy
- Save button: Primary CTA, prominent at bottom

---

### 6. Community Screen

**Layout:**
```
┌─ Top Bar ─────────────────────────────┐
│ [Search] 🔔 Community                 │
├───────────────────────────────────────┤
│ Tabs: [Trending] [Market] [Q&A] [Forums]│
├───────────────────────────────────────┤
│                                       │
│ ┌─ Post Card ─────────────────────────┐│
│ │ 👤 Maria Santos • Davao City  2m  ││
│ │ 📍 Market Finds                   ││
│ │                                   ││
│ │ "Found these fresh calamansi at  ││
│ │  the Agora Market! So affordable ││
│ │ and perfect for Filipino recipes" ││
│ │                                   ││
│ │ [🖼️ Image Preview]               ││
│ │                                   ││
│ │ [❤️ 24] [💬 8] [🔗 Share]        ││
│ └─────────────────────────────────────┘│
│                                        │
│ ┌─ Post Card ─────────────────────────┐│
│ │ 👤 Chef Ramon • Quezon City  15m   ││
│ │ 🏷️ Recipe                          ││
│ │                                    ││
│ │ "Easy Tinola Manok in 20 mins!    ││
│ │ My go-to after work dinner. Saves ││
│ │ time but tastes homemade 🍜"      ││
│ │                                    ││
│ │ [❤️ 156] [💬 42] [🔗 Share]       ││
│ └─────────────────────────────────────┘│
│                                        │
│ ┌─ Post Card ─────────────────────────┐│
│ │ 👤 Health Coach Anna  1h           ││
│ │ 💡 Health Forums                   ││
│ │                                    ││
│ │ "Q: Best way to meal prep for     ││
│ │ weight loss on a budget?"          ││
│ │                                    ││
│ │ [❤️ 8] [💬 15] [🔗 Share]         ││
│ └─────────────────────────────────────┘│
│                                        │
│                                        │
│        🎯 [+ Share a Find]            │
│        (Floating Action Button)       │
└────────────────────────────────────────┘
```

**Design Details:**
- Profile row: Avatar + name + time + category tag
- Content: Clean paragraph text
- Image preview: Thumbnail with overlay
- Engagement: Icons + counts, right-aligned
- FAB: Large green button, "Share a Find" text
- Post moderation: Clean, not cluttered

---

### 7. Profile Screen

**Layout:**
```
┌─ Top Bar ────────────────────────────┐
│ NutriMind  [Edit] [Settings] ⚙️      │
├──────────────────────────────────────┤
│                                      │
│ ┌─ Profile Header ─────────────────┐│
│ │ 👤 [Image]  Maria Santos         ││
│ │ maria@example.com                ││
│ │ Health Enthusiast • Davao City   ││
│ └──────────────────────────────────┘│
│                                      │
│ ┌─ Stats Bar ──────────────────────┐│
│ │ 65 kg  •  170 cm  •  ₱1,500  • 4  ││
│ │ Weight    Height    Budget    Today's││
│ │                              Logs  │
│ └──────────────────────────────────┘│
│                                      │
│ ┌─ BMI Card ───────────────────────┐│
│ │  22.5 BMI  •  Normal Weight ✓    ││
│ │  ████░░░░░░░░░░░░░░  22.5        ││
│ │                                  ││
│ │  "Great! Maintain your healthy  ││
│ │  lifestyle. Keep up the good     ││
│ │  eating habits!"                 ││
│ └──────────────────────────────────┘│
│                                      │
│ ┌─ Achievements ────────────────────┐│
│ │ 🏆 7-Day Streak  🥗 50 Meals      ││
│ │ 🎯 Budget Master  📈 Progress     ││
│ └──────────────────────────────────┘│
│                                      │
│ ┌─ Account Settings ────────────────┐│
│ │ Edit Profile           [→]       ││
│ │ Notifications          [→]       ││
│ │ Privacy & Security     [→]       ││
│ │ Preferences            [→]       ││
│ │ App Settings           [→]       ││
│ │ About NutriMind        [→]       ││
│ │ [Logout]                         ││
│ └──────────────────────────────────┘│
└──────────────────────────────────────┘
```

**Design Details:**
- Profile header: Clean, avatar + name + subtitle
- Stats row: 4 metrics, easy to scan
- BMI card: Gradient (based on BMI category), circular progress
- Achievements: Icon grid, badge-style
- Settings list: Clean, minimal separators
- Logout: Red text, bottom placement

---

### 8. NutriBot Chatbot Screen

**Layout:**
```
┌─ Top Bar ───────────────────────────┐
│ 🤖 NutriBot                    [×]  │
├─────────────────────────────────────┤
│                                     │
│ 👤 "Hi! I'm NutriBot 🌿              │
│    Your personal nutrition          │
│    assistant. Ask me about:         │
│    • Nutrition & healthy eating     │
│    • Filipino & Davao recipes       │
│    • Meal planning & budgeting      │
│    • Cooking tips & techniques"     │
│                                     │
│ [👉 Suggest breakfast] [🍽️ Analyze meal]│
│ [📋 Plan meals] [❓ Davao foods?]   │
│                                     │
│ (Space for conversation)            │
│                                     │
│ 👤 "What are good Davao fruits     │
│    for weight loss?"                │
│                                     │
│ 🤖 "Great question! Here are some  │
│    excellent Davao fruits perfect  │
│    for weight loss:                │
│                                     │
│    🍌 Pomelo - Low cal, high fiber  │
│    🥭 Mango - Vitamin C boost       │
│    🍓 Pineapple - Digestive support │
│    🍒 Calamansi - Citrus freshness  │
│                                     │
│    Pro tip: Enjoy with protein!☘️"  │
│                                     │
│ ┌───────────────────────────────────┐│
│ │ Type a message...        [Send ➤] ││
│ └───────────────────────────────────┘│
│                                     │
└─────────────────────────────────────┘
```

**Design Details:**
- Header: Compact, close button on right
- Chat bubbles: User left (light gray), AI right (green gradient)
- Quick actions: Chip buttons, inline suggestions
- Input: Clean text field + send button
- Typing indicator: Soft animation (three dots)
- Scrollable: Smooth animation on new messages

---

## 🎬 Interactions & Animations

### Loading States
- Spinner: Rotating primary green circle
- Skeleton: Pulsing light gray placeholders
- Progress: Linear bar or circular indicator

### Button Interactions
- Tap: Scale down 95%, 150ms
- Hover: Slight color shift, shadow increase
- Pressed: Haptic feedback (if available)
- Disabled: Opacity 50%, no interaction

### Card Interactions
- Expand: Smooth height animation, 300ms
- Swipe: Delete action revealed, 200ms
- Load: Fade in from bottom, 250ms

### Navigation
- Push: Slide up from bottom, 200ms
- Pop: Slide down to bottom, 200ms
- Tab change: Crossfade, 150ms

### Smooth Transitions
- All state changes: 200–300ms duration
- Curves: `Curves.easeInOut` for most interactions
- Parallax: Subtle scroll effects on hero images

---

## 📐 Spacing & Layout Grid

**Base Unit:** 8px

### Margin & Padding Scale
```
xs:   4px  (minimal spacing)
sm:   8px  (small padding)
md:   12px (standard padding)
lg:   16px (card padding, section margins)
xl:   20px (large margins, section tops)
xxl:  24px (extra large spacing)
xxxl: 32px (screen margins)
```

### Safe Areas
- Left/Right margins: 16–20px minimum
- Top/Bottom: Safe area + 12px
- Gutters between elements: 8–16px

---

## 🔍 Accessibility

### Color Contrast
- Text on background: Min 4.5:1 (WCAG AA)
- Icons: Min 3:1 for decorative
- Status colors: Not sole indicator

### Typography
- Minimum font size: 14px for body
- Maximum line width: 70–80 characters
- Line height: 1.5–1.6 for readability

### Interactive Elements
- Minimum tap target: 48x48px
- Touch feedback: Visible state change
- Focus indicators: 2px outline or color change

### Dark Mode (Future)
- Invert colors intelligently
- Maintain contrast ratios
- Soft shadows on dark backgrounds

---

## 📦 Component Reusability

### Shared Components
- `PrimaryButton` - All CTAs
- `CardContainer` - All card layouts
- `MacroCard` - Nutrition display
- `MealItemTile` - List items
- `GradientBackground` - Premium feel
- `NutrientBadge` - Status indicators
- `LoadingSpinner` - Async states

### Consistent Patterns
- Top app bar: Always consistent header
- Bottom navigation: Persistent nav structure
- Floating action buttons: Consistent styling
- Input fields: Uniform validation states
- Dialog boxes: Consistent modal patterns

---

## 🎯 Implementation Priority

### Phase 1 (MVP Polish)
1. Update color palette in app_theme.dart
2. Modernize Home Screen
3. Redesign Meal Log cards
4. Update Scanner UI
5. Modernize Profile screen

### Phase 2 (Enhanced)
1. Recipe screen polish
2. Community feed redesign
3. Chatbot styling
4. Animation & micro-interactions
5. Dark mode support

### Phase 3 (Premium)
1. Advanced onboarding animations
2. Gesture-based interactions
3. Premium imagery & illustrations
4. Sound & haptic feedback
5. Advanced accessibility features

---

## 📱 Responsive Design

### Phone (320–480px)
- Single column layouts
- Full-width cards
- Stacked navigation
- Large touch targets

### Tablet (480–768px)
- Two-column layouts
- Optimized spacing
- Larger cards
- Side navigation option

### Desktop/Web (768px+)
- Three-column layouts
- Sidebar navigation
- Expanded cards
- Additional information panels

---

## ✨ Brand Guidelines

### Logo & Branding
- Primary icon: Leaf + green circle (health, growth)
- Secondary icon: AI chip (intelligence)
- Wordmark: "NutriMind" in bold sans-serif
- Tagline: "Your AI Nutrition Assistant"

### Photography & Imagery
- Food photography: Bright, natural, appetizing
- AI illustrations: Modern, geometric, minimal
- Icons: 24px base, simple, filled or outlined
- Illustrations: Soft, friendly, health-focused

---

## 📊 Metrics & Performance

### Performance Targets
- First paint: < 2s
- Interactive: < 3s
- Scroll FPS: 60fps
- Load animations: 200–300ms

### Usability Metrics
- Task completion: 95%+
- Time to log meal: < 30 seconds
- Time to scan food: < 60 seconds
- Chatbot response: < 2 seconds

---

## 🚀 Next Steps

1. **Update app_theme.dart** with enhanced color palette
2. **Create reusable components** (buttons, cards, inputs)
3. **Modernize existing screens** one by one
4. **Add animations** and micro-interactions
5. **Implement dark mode** support
6. **User testing** and refinement
7. **Polish and ship**

---

**NutriMind Design System v2.0**
Premium. Intelligent. Friendly. Health-Focused.
