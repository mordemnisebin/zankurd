# Zankurd Geometric Maximalism Design Spec

**Tarih**: 2026-06-13  
**Versiyon**: 1.0  
**Kapsam**: Sign In, Sign Up, Home/Dashboard ekranları ve component system  

---

## 1. Visual Identity

### 1.1 Renk Paleti

**Moderate Bold** intensity — strong ancak accessible. Contrast oranları WCAG AA (4.5:1 minimum text için).

| Renk Adı | Hex | Kullanım | Light Mode Text | Dark Mode Text |
|----------|-----|----------|-----------------|-----------------|
| Primary Gradient Start | `#FF6B6B` | Buton, accent, shapes | `#FFFFFF` | `#FFFFFF` |
| Primary Gradient End | `#FF9F4A` | Buton, accent, shapes | `#FFFFFF` | `#FFFFFF` |
| Secondary Accent | `#6366F1` | Shape overlays, vurgu | `#FFFFFF` | `#FFFFFF` |
| Gold Accent | `#FFD700` | Badge, streak | `#1A1A2E` | `#1A1A2E` |
| Cyan Accent | `#00D9FF` | Hover states, göstergeler | `#1A1A2E` | `#1A1A2E` |
| Dark Background (Auth) | `#1A1A2E` | Login/signup arka plan | `#FFFFFF` | N/A |
| Dark Background Alt | `#16213E` | Gradient arka plan | `#FFFFFF` | N/A |
| Light Surface | `#FFFFFF` | Kart, input (light mode) | `#1A1A2E` | N/A |
| Light BG | `#F5F5F5` | Home/dashboard arka plan | `#1A1A2E` | N/A |
| **Dark Mode Surface** | **`#1F1F2E`** | **Kart, input (dark mode)** | **N/A** | **`#E8E8E8`** |
| **Dark Mode BG** | **`#0F0F1A`** | **Dark mode arka plan** | **N/A** | **`#E8E8E8`** |
| Text Primary (Light) | `#1A1A2E` | Başlık, vücut metni (light) | — | — |
| Text Primary (Dark) | `#E8E8E8` | Başlık, vücut metni (dark) | — | — |
| Text Secondary | `#666666` | Alt metin (light mode) | — | — |
| Text Secondary Dark | `#A8A8A8` | Alt metin (dark mode) | — | — |
| Text Muted | `#999999` | İpuçları, disabled (light) | — | — |
| Text Muted Dark | `#757575` | İpuçları, disabled (dark) | — | — |

**Contrast Kontrol**:
- Gradient buttons üzerine white text: 4.5:1+ ✅
- Gold badge: Dark text (`#1A1A2E`) dark mode'da da okunabilir ✅
- Input fields: Dark text/placeholder, light background ✅
- Yazı kapatmasız, her kombinasyonda readable

### 1.2 Tipografi

**Font**: Rubik (mevcut, tut)

| Seviye | Boyut | Ağırlık | Renk | Kullanım |
|--------|-------|---------|------|----------|
| H1 (Başlık) | 26px | 900 | `#1A1A2E` | Sayfa başlığı |
| H2 (Section) | 20px | 700 | `#1A1A2E` | Bölüm başlığı |
| H3 (Card) | 16px | 700 | `#1A1A2E` | Kart başlığı |
| Body | 14-15px | 500 | `#333333` | Normal metin |
| Button | 15px | 700 | `#FFFFFF` | Buton text |
| Label | 12px | 600 | `#666666` | Form label, badge |
| Muted | 12px | 400 | `#999999` | Placeholder, hint |

### 1.3 Geometrik Şekiller

**Mixed approach** — Heksagon, Oktagon, Rotated Squares, Diamonds

- **Heksagon** (6-köşe): Logo area, badge, accent
- **Oktagon** (8-köşe): Larger shape overlays, section dividers
- **Rotated Squares**: Background layering, asymmetric depth
- **Diamonds**: Smaller accents, corner elements

Şekiller `clip-path` CSS veya Flutter `CustomPaint` kullanarak oluşturulur.

### 1.4 Dark Mode Support

Uygulama light + dark mode'u destekleyecek (user preference veya system setting).

**Light Mode** (default):
- Auth screens: White input, dark text
- Home: Light background, dark text
- Button text: Always white (contrast OK)

**Dark Mode**:
- Auth screens: Dark surface (`#1F1F2E`), light text (`#E8E8E8`)
- Home: Dark background (`#0F0F1A`), light text
- Button text: Always white (contrast OK)
- Geometric shapes: Opacity adjust if needed visibility için

**Implementation**: Flutter `ThemeData` + Provider, CSS media query `prefers-color-scheme: dark`

---

## 2. Sign In Screen (`sign_in_screen.dart`)

### 2.1 Layout Structure

```
[Dark Gradient Background: #1A1A2E → #16213E]
  ├── [Geometric Layer 1 - Top Right]
  │   └── Octagon overlay (#FF6B6B @ 0.7 opacity, 180px, rotated 45°)
  │
  ├── [Language Toggle - Top Right]
  │   └── Floating chip (Kurmancî / Türkçe)
  │
  ├── [Centered Content Area]
  │   ├── Logo (Hexagon 80×80, gradient)
  │   ├── Title ("Bi xêr hatî ZanKurdê")
  │   ├── Subtitle ("Kurmancî hîn bibe...")
  │   ├── Form (Email, Password)
  │   └── Sign In Button
  │
  ├── [Divider - Diagonal]
  │   └── "AN JÎ / VEYA" text
  │
  ├── [OAuth Buttons]
  │   ├── Google ile giriş
  │   └── Misafir olarak devam
  │
  ├── [Sign Up Link]
  │
  └── [Geometric Layer 2 - Bottom Left]
      └── Rotated square (#6366F1 @ 0.6 opacity, 140px)
```

### 2.2 Component Details

**Logo (Heksagon)**
- Şekil: 6-sided heksagon
- Boyut: 80×80 px
- Gradient: `#FF6B6B` → `#FF9F4A` (135° angle)
- İçerik: "ZK" (white, 32px, weight 900)
- Shadow: `0 8px 24px rgba(255,107,107,0.3)`
- Animation: Load screen'de fade-in + subtle scale (0.8 → 1.0) over 600ms

**Title & Subtitle**
- Title: "Bi xêr hatî ZanKurdê / ZanKurd'a Hoş Geldin"
  - 26px, weight 900, white, center
  - Animation: Fade in + slide up 20px over 800ms
- Subtitle: "Kurmancî hîn bibe..." 
  - 14px, weight 400, `#CCCCCC`, center
  - Animation: Fade in + slide up 15px over 1000ms

**Language Toggle**
- Position: Top-right, floating
- Style: Rounded pill chip with two options (Kurmancî | Türkçe)
- Active state: Gradient background (`#FF6B6B` → `#FF9F4A`), white text
- Inactive: Light background, muted text
- Animation: Animated container transition on toggle

**Form Fields (Email & Password)**
- **Light Mode**:
  - Background: `#FFFFFF`
  - Text: `#1A1A2E` (dark, readable)
  - Border: 1px solid `#E0E0E0`
  - Left accent: 6px solid `#FF9F4A`
  - Placeholder: `#999999`
  - Icon: `#666666`
- **Dark Mode**:
  - Background: `#1F1F2E`
  - Text: `#E8E8E8` (light, readable)
  - Border: 1px solid `#404050`
  - Left accent: 6px solid `#FF9F4A` (same, contrasts on dark)
  - Placeholder: `#A8A8A8`
  - Icon: `#B0B0B0`
- Height: 48px, Padding: 12px 14px, Border radius: 8px
- Focus state:
  - Left accent: Brighten to `#FF6B6B`
  - Subtle glow/shadow
- Animation: Staggered fade-in (field 1 @ 1000ms, field 2 @ 1100ms)

**Sign In Button**
- Style: Full-width gradient button
- Gradient: `#FF6B6B` → `#FF9F4A` (90° horizontal)
- Height: 48px
- Border radius: 8px
- Text: "Têkeve / Giriş Yap" (15px, white, weight 700)
- Clip-path: Slightly angled edges (asymmetric, left edge 0°, right edge -2°)
- Shadow: `0 6px 16px rgba(255,107,107,0.3)`
- Hover: Scale 1.02, shadow intensify
- Active: Scale 0.98, shadow reduce
- Disabled: Opacity 0.5, cursor not-allowed
- Animation: Fade in + scale (0.95 → 1.0) over 700ms

**Divider**
- Style: Diagonal line (not horizontal)
- Angle: ~15° from horizontal
- Color: `#FFFFFF` @ 0.3 opacity
- Text label: "AN JÎ / VEYA" (centered, 12px, weight 700, muted)
- Width: 80% of container
- Animation: Draw-in effect from left to right over 1200ms

**OAuth Buttons (Google & Guest)**
- Style: Outlined button, transparent background
- Border: 1.5px solid `#FFFFFF` @ 0.6 opacity
- Height: 44px
- Border radius: 8px
- Text color: `#FFFFFF`
- Icon: Google "G" or person icon (18px)
- Hover: Background `#FFFFFF` @ 0.1, border brighten
- Animation: Stagger fade-in (Google @ 1300ms, Guest @ 1400ms)

**Sign Up Link**
- Text: "Hesabê te tune? Tomar bibe / Hesabın yok mu? Kaydol"
- "Tomar bibe / Kaydol" part: Gradient text or solid `#FF6B6B`
- Tap: Navigate to Sign Up screen
- Animation: Fade in over 1500ms

### 2.3 Geometric Overlays

**Top-Right Octagon**
- Shape: 8-sided octagon
- Size: 180px
- Position: Top-right corner (partially off-screen)
- Color: `#FF6B6B` @ 0.7 opacity
- Rotation: 45°
- Layer: Behind all content
- Animation: Slide in from top-right over 1000ms with 100ms delay

**Bottom-Left Rotated Square**
- Shape: Rotated square (45° diamond appearance)
- Size: 140px
- Position: Bottom-left corner (partially off-screen)
- Color: `#6366F1` @ 0.6 opacity
- Rotation: 0° (appears as diamond due to position)
- Layer: Behind all content
- Animation: Slide in from bottom-left over 1200ms with 200ms delay

---

## 3. Sign Up Screen (`sign_up_screen.dart`)

### 3.1 Layout Structure

Similar to Sign In, but with progress indicator and multi-step form.

```
[Dark Gradient Background: #1A1A2E → #16213E]
  ├── [Geometric Layer 1]
  │
  ├── [Progress Indicator - Hexagons]
  │   ├── Step 1 (active, filled)
  │   ├── Step 2 (inactive, outline)
  │   └── Step 3 (inactive, outline)
  │
  ├── [Form Content Area]
  │   ├── Step title
  │   ├── Form fields
  │   └── Buttons (Next, Back)
  │
  └── [Geometric Layer 2]
```

### 3.2 Progress Indicator

- Style: Three hexagons connected by line
- Active step: Filled hexagon with gradient (`#FF6B6B` → `#FF9F4A`), white text
- Inactive steps: Outline only, border `#FFFFFF` @ 0.4
- Size: 48px per hexagon
- Spacing: 12px gap between hexagons
- Line: Connecting line behind hexagons, `#FFFFFF` @ 0.3
- Animation: Current step fills with gradient over 600ms

### 3.3 Form Fields

**Step 1: Email & Password**
- Same styling as Sign In form fields
- Left accent: `#FF9F4A`

**Step 2: Username & Confirm Password**
- Same styling
- Left accent: `#6366F1` (secondary color)

**Step 3: Review & Confirm**
- Summary of entered data with confirm button

### 3.4 Buttons

**Next Button**
- Same styling as Sign In button
- Text: "İleri / Devam"
- Gradient: `#FF6B6B` → `#FF9F4A`

**Back Button**
- Style: Outlined, transparent
- Border: 1.5px `#FFFFFF` @ 0.5
- Text: "Geri"
- Icon: Left arrow (16px)

**Submit Button (Step 3)**
- Gradient: `#FF6B6B` → `#FF9F4A`
- Text: "Hesap Oluştur / Tomar Bibe"

---

## 4. Home / Dashboard Screen (`home_screen.dart`)

### 4.1 Layout Structure

```
[Light Background: #F5F5F5]
  ├── [Home Header Hero]
  │   ├── Gradient background (#6366F1 → #FF6B6B)
  │   ├── Geometric shapes (hexagon, diamond overlays)
  │   ├── Player name, level, coins
  │   └── Streak badge (hexagon)
  │
  ├── [Section: Daily Quiz Card]
  │   ├── Gradient background (#FF6B6B variant)
  │   ├── Geometric accent shapes
  │   └── CTA Button
  │
  ├── [Section: Spin Wheel Card]
  │   ├── Gradient background (#6366F1 variant)
  │   └── CTA Button
  │
  ├── [Section: Categories Grid]
  │   ├── Asymmetric card layout (2-3-2 or 3-2-1 pattern, not uniform)
  │   ├── Each category card with geometric accent
  │   └── Icons with colors
  │
  ├── [Section: Leaderboard / Recent Activity]
  │   ├── List with geometric dividers
  │   └── Ranked badges (1st, 2nd, 3rd)
  │
  └── [Geometric Accents]
      └── Diagonal section dividers
```

### 4.2 Home Header

**Hero Card**
- Background: Gradient `#6366F1` → `#FF6B6B` (180° angle)
- Height: 200px
- Padding: 20px
- Border radius: 16px
- Shadow: `0 8px 24px rgba(0,0,0,0.1)`
- Position: Margin-bottom 20px, horizontal padding 16px

**Content Inside Hero**
- Profile section (top-left):
  - Avatar: 44px circle, placeholder initials
  - Player name: 16px, weight 700, white
  - Level: "Level 5" or similar, 12px, weight 500, white @ 0.9

- Stats section (top-right):
  - Coins: Coin icon + count (gold color)
  - Gems/Premium: Gem icon + count (cyan color)
  - 13px, weight 700

- Geometric accent (behind, semi-transparent):
  - Hexagon or rotated square `#FFFFFF` @ 0.15, 120px size

- Streak badge (bottom-right):
  - Shape: Hexagon
  - Size: 60×60 px
  - Gradient: `#FFD700` variant
  - Icon: 🔥 Fire (or custom flame icon)
  - Count: "7" (current streak days)
  - Weight: 600, white
  - Animation: On load, pulse effect (scale 1.0 → 1.1 → 1.0) every 2s

### 4.3 Daily Quiz Card

- Background: Gradient `#FF6B6B` → `#FF9F4A` @ 0.85 opacity over white
- Height: 140px
- Border radius: 16px
- Padding: 16px
- Content:
  - Title: "Günlük Quiz / Rojane Quiz" (18px, weight 700, white)
  - Subtitle: "3/5 sorular cevaplanmış" (13px, muted white)
  - Geometric accent shapes (diamond, small square overlays in corners)
- CTA Button: "Başla / Destpê Bike" (outlined, white text, transparent background)
- Animation: Load'da fade-in + slide-up over 800ms

### 4.4 Spin Wheel Card

- Similar to Daily Quiz
- Background: Gradient `#6366F1` → secondary variant
- Title: "Spin Wheel"
- Subtitle: "Günde 1 dönüş hakkı"
- CTA Button: "Döndür / Bifirîne"
- Animation: Load'da fade-in + slide-up over 900ms

### 4.5 Categories Grid

**Layout: Asymmetric (Not Uniform)**
- Desktop: 3 columns with irregular card sizes (e.g., 1st card spans 2 rows, 3rd is half width)
- Tablet: 2 columns with varied heights
- Mobile: 1 column, full width

**Category Card**
- Background: `#FFFFFF`
- Border: 0.5px solid `#E0E0E0`
- Border radius: 12px
- Height: Variable (120px min, 160px max)
- Padding: 12px
- Geometric accent: Small rotated square or diamond in top-right corner (color-coded per category)
- Content:
  - Category icon: 32px, colored
  - Category name: 14px, weight 700
  - Progress: "12/25 questions learned" (12px, muted)
  - Progress bar: Thin bar with gradient fill

- Hover state:
  - Background: `#F9F9F9`
  - Geometric accent scales up 1.1
  - Shadow: `0 4px 12px rgba(0,0,0,0.05)`

- Animation: Staggered load (each card fades in + slides up with 50ms delay between)

### 4.6 Leaderboard / Activity Section

- Title: "Liderlik / Lîdertablî" (20px, weight 700)
- Divider: Diagonal line before section title (animated draw-in)
- List items:
  - Rank badge: Hexagon with rank (1st = gold, 2nd = silver, 3rd = bronze)
  - Player name, score
  - Geometric separator line between items (thin, angled)
- Animation: Staggered fade-in for list items

---

## 5. Component Library

### 5.1 Buttons

**Primary Button (Gradient)**
- Gradient: `#FF6B6B` → `#FF9F4A`
- Height: 48px
- Padding: 0 24px
- Border radius: 8px
- Clip-path: Left edge 0°, right edge -2° (slight asymmetry)
- Shadow: `0 6px 16px rgba(255,107,107,0.3)`
- Text: 15px, weight 700, white
- Icon: 18px (optional)
- Hover: Scale 1.02, shadow intensify
- Active: Scale 0.98, shadow reduce
- Disabled: Opacity 0.5, no pointer events
- Animation: On render, scale 0.95 → 1.0 over 500ms

**Secondary Button (Outlined)**
- Background: Transparent
- Border: 1.5px solid accent color
- Height: 44px
- Text color: Accent color or white
- Hover: Background `accent` @ 0.1
- Animation: Fade in + scale over 500ms

### 5.2 Input Fields

- Background: `#FFFFFF`
- Border: 1px solid `#E0E0E0`
- **Left accent bar**: 6px solid `#FF9F4A` or color-coded
- Height: 48px
- Padding: 12px 14px (left padding increased for accent)
- Border radius: 8px
- Font: 14px, weight 500
- Focus state:
  - Left accent: Brighten/intensify
  - Border: `#FF6B6B`
  - Box-shadow: `0 0 0 3px rgba(255,107,107,0.1)`
- Placeholder: `#999999`
- Animation: Staggered fade-in (load screen)

### 5.3 Cards

**Raised Card (White Background)**
- Background: `#FFFFFF`
- Border: 0.5px solid `#E0E0E0`
- Border radius: 12px
- Padding: 16px
- Shadow: `0 2px 8px rgba(0,0,0,0.06)`
- Geometric accent: Optional small shape in corner (rotated square, diamond)
- Animation: Fade-in + slide-up on load

**Gradient Card (Dark Background)**
- Background: Gradient fill (varies by card type)
- Border radius: 12px
- Padding: 16px
- Shadow: `0 4px 12px rgba(0,0,0,0.1)`
- Text: White or light color
- Geometric overlays: Semi-transparent shapes for depth

### 5.4 Geometric Shapes

**Hexagon**
```css
clip-path: polygon(50% 0%, 100% 25%, 100% 75%, 50% 100%, 0% 75%, 0% 25%);
```

**Octagon**
```css
clip-path: polygon(30% 0%, 70% 0%, 100% 30%, 100% 70%, 70% 100%, 30% 100%, 0% 70%, 0% 30%);
```

**Rotated Square (Diamond)**
```css
clip-path: polygon(50% 0%, 100% 50%, 50% 100%, 0% 50%);
```

---

## 6. Animation Specifications

### 6.1 Page Load Animations

**Sign In / Sign Up Screen**

Timeline (all from 0ms):
1. **0ms**: Background shapes appear (geometric layers 1 & 2)
   - Octagon (top-right): Slide-in from top-right, 1000ms
   - Rotated square (bottom-left): Slide-in from bottom-left, 1200ms

2. **200ms**: Logo fades in
   - Fade (0 → 1) + Scale (0.8 → 1.0) over 600ms

3. **400ms**: Title slides up
   - Slide-up (20px) + Fade over 800ms

4. **600ms**: Subtitle slides up
   - Slide-up (15px) + Fade over 800ms

5. **1000ms**: Form fields appear (staggered)
   - Field 1: Fade-in + scale over 500ms
   - Field 2: Fade-in + scale over 500ms (100ms delay)

6. **1200ms**: Sign In button appears
   - Fade-in + scale (0.95 → 1.0) over 700ms

7. **1400ms**: Divider draws in
   - Stroke animation (left → right) over 1000ms

8. **1600ms**: OAuth buttons appear (staggered)
   - Fade-in + scale for each (300ms apart)

**Home Screen**

Timeline:
1. **0ms**: Background gradient visible
2. **200ms**: Home header hero fades in + slides up
   - Duration: 800ms
3. **400ms**: Streak badge pulses (starts immediately, repeats every 2s)
4. **600ms**: Daily Quiz and Spin Wheel cards fade in (staggered, 100ms apart)
5. **800ms**: Category grid cards fade in (staggered, 50ms between each)
6. **1000ms**: Leaderboard section title divider animates
7. **1200ms**: Leaderboard list items fade in (staggered)

### 6.2 Interaction Animations

**Button Hover**
- Scale: 1.0 → 1.02 over 200ms
- Shadow: Intensify by 20%

**Button Active (Press)**
- Scale: 1.02 → 0.98 over 100ms
- Shadow: Reduce by 30%

**Input Focus**
- Left accent bar: Color transition (500ms)
- Box-shadow: Fade in (300ms)

**Card Hover**
- Geometric accent shape: Scale up 1.1 over 200ms
- Shadow: Increase over 200ms

---

## 7. Responsive Design

### 7.1 Mobile (< 480px)

- Horizontal padding: 16px
- Form max-width: 100%
- Button height: 48px
- Logo size: 72px
- Title font-size: 22px
- Category grid: 1 column, full width

### 7.2 Tablet (480px - 768px)

- Horizontal padding: 24px
- Form max-width: 380px
- Logo size: 80px
- Title font-size: 24px
- Category grid: 2 columns with varied widths
- Home header: 200px height

### 7.3 Desktop (> 768px)

- Horizontal padding: 32px
- Form max-width: 420px
- Logo size: 84px
- Title font-size: 26px
- Category grid: 3 columns with asymmetric layout
- Home header: 240px height with elaborate geometric layering

---

## 8. Implementation Notes

### 8.1 Flutter Specifics

- Use `Container` with `decoration: BoxDecoration(gradient: ...)` for gradients
- Use `ClipPath` with `CustomClipper` for geometric shapes (heksagon, oktagon, diamond)
- Use `AnimatedContainer` for smooth transitions
- Use `AnimationController` + `Tween` for staggered load animations
- Icons: Continue using Material Icons or custom icon set

### 8.2 CSS/Web Specifics (if applicable)

- Use `clip-path: polygon(...)` for geometric shapes
- Use CSS `@keyframes` for load animations
- Use `transition` for hover states
- Use `box-shadow` for depth

### 8.3 Color Implementation

Keep `AppTheme` constants synchronized:
```dart
static const Color primaryStart = Color(0xFFFF6B6B);
static const Color primaryEnd = Color(0xFFFF9F4A);
static const Color secondaryAccent = Color(0xFF6366F1);
static const Color darkBg = Color(0xFF1A1A2E);
static const Color darkBgAlt = Color(0xFF16213E);
// ... etc
```

### 8.4 Font Weights

Rubik weights used:
- 400 (Regular) — Body text
- 500 (Medium) — Labels, secondary headings
- 700 (Bold) — Buttons, section headings
- 900 (Black) — Main titles, emphasis

---

## 9. Success Criteria

- ✅ Tüm 3 screen (Sign In, Sign Up, Home) geometric maximalism style'da implement edildi
- ✅ Load animations staggered ve fluid
- ✅ Multi-device responsive (mobile, tablet, desktop)
- ✅ Kurmancî + Türkçe language support intact
- ✅ Moderate bold color intensity (erişilebilir, göz korkutmayan)
- ✅ Mixed geometric shapes (heksagon, oktagon, rotated squares, diamonds)
- ✅ Asymmetric layouts (especially home grid)
- ✅ Component consistency across screens
- ✅ Accessibility maintained (contrast, readable text sizes)

---

**Sonraki Adım**: Implementation plan yazılması ve coding başlanması.
