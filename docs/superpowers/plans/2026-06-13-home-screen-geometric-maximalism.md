# Home Screen Geometric Maximalism Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the home screen with Geometric Maximalism design, including a hero header with gradient, animated streak badge, gradient cards with staggered animations, and an asymmetric responsive category grid.

**Architecture:** The refactored home screen uses `CustomScrollView` with a `SliverAppBar` for the hero header (replacing the current static header), animated fade-in sequences for all content elements using a single `AnimationController` (4000ms), and enhanced card/grid components with geometric accent shapes. All animations are driven by the existing `LoadAnimationSequence` utilities.

**Tech Stack:** Flutter, Material 3, CustomScrollView/SliverAppBar, AnimationController, LinearGradient, custom geometric shapes

---

## File Structure

**Modified Files:**
1. `zankurd_mobile/lib/src/screens/home_screen.dart` — Convert to CustomScrollView, add AnimationController, integrate animations
2. `zankurd_mobile/lib/src/screens/home/home_header.dart` — Enhance with gradient background, geometric shapes, animated streak badge
3. `zankurd_mobile/lib/src/screens/home/daily_quiz_card.dart` — Add animation binding, gradient refinement
4. `zankurd_mobile/lib/src/screens/home/spin_wheel_card.dart` — Add animation binding, gradient refinement
5. `zankurd_mobile/lib/src/screens/home/category_grid.dart` — Refactor to asymmetric responsive grid, add diamond shapes, animations

**No new files are created.** All changes are within existing components.

---

## Task Breakdown

### Task 1: Add AnimationController to Home Screen

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/home_screen.dart` (initState, dispose methods)

**Purpose:** Set up the animation infrastructure for all staggered animations.

- [ ] **Step 1: Import LoadAnimationSequence**

In `home_screen.dart`, add at the top:

```dart
import '../animations/load_animations.dart';
```

- [ ] **Step 2: Add AnimationController field**

In `_HomeScreenState`, add after the existing fields (after `late GameRoom _room;`):

```dart
late AnimationController _animationController;
```

- [ ] **Step 3: Initialize AnimationController in initState**

In the `initState()` method, after `_refreshStreak();`, add:

```dart
_animationController = AnimationController(
  duration: const Duration(milliseconds: 4000),
  vsync: this,
);
_animationController.forward();
```

Note: This requires `_HomeScreenState` to extend `TickerProviderStateMixin`. Update the class declaration.

- [ ] **Step 4: Update class declaration to add TickerProviderStateMixin**

Change:

```dart
class _HomeScreenState extends State<HomeScreen> {
```

To:

```dart
class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
```

- [ ] **Step 5: Dispose AnimationController properly**

Add a `dispose()` method to `_HomeScreenState` (if it doesn't exist):

```dart
@override
void dispose() {
  _animationController.dispose();
  super.dispose();
}
```

If a `dispose()` method already exists, add `_animationController.dispose();` before `super.dispose();`.

- [ ] **Step 6: Commit**

```bash
git add zankurd_mobile/lib/src/screens/home_screen.dart
git commit -m "feat(home): add AnimationController for staggered animations"
```

---

### Task 2: Convert Home Screen from ListView to CustomScrollView

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/home_screen.dart` (build method)

**Purpose:** Replace the ListView structure with CustomScrollView to enable SliverAppBar for the hero header.

- [ ] **Step 1: Replace ListView container structure**

In the `build()` method, replace the entire `Container` → `SafeArea` → `ListView` structure with:

```dart
@override
Widget build(BuildContext context) {
  final ku = context.isKu;

  return Container(
    decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
    child: SafeArea(
      child: CustomScrollView(
        slivers: [
          // SliverAppBar will be added in Task 3
          // Content slivers will be added after Task 3
        ],
      ),
    ),
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add zankurd_mobile/lib/src/screens/home_screen.dart
git commit -m "refactor(home): convert ListView to CustomScrollView"
```

---

### Task 3: Create Hero Header SliverAppBar

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/home_screen.dart` (build method, slivers array)

**Purpose:** Create the SliverAppBar with the HomeHeader component, gradient background, and hero animation binding.

- [ ] **Step 1: Add SliverAppBar with HomeHeader**

Inside the `CustomScrollView` `slivers` array, add:

```dart
SliverAppBar(
  expandedHeight: 200,
  floating: false,
  pinned: false,
  backgroundColor: Colors.transparent,
  elevation: 0,
  scrolledUnderElevation: 0,
  flexibleSpace: FlexibleSpaceBar(
    background: Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.homeHeaderGradient,
      ),
      child: Stack(
        children: [
          // Geometric hexagon overlay (white, 0.1 opacity, 100px, top-right)
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // HomeHeader content
          FadeTransition(
            opacity: LoadAnimationSequence.heroFadeAnimation(_animationController),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: HomeHeader(
                coinBalance: _coinBalance,
                isKu: ku,
                streak: _streak,
              ),
            ),
          ),
        ],
      ),
    ),
  ),
),
```

- [ ] **Step 2: Commit**

```bash
git add zankurd_mobile/lib/src/screens/home_screen.dart
git commit -m "feat(home): add SliverAppBar with hero header and animation"
```

---

### Task 4: Wrap Content in SliverList with Animations

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/home_screen.dart` (build method, slivers array)

**Purpose:** Convert all existing ListView children into a SliverList structure and bind fade animations to each major section.

- [ ] **Step 1: Replace ListView children with SliverList**

After the SliverAppBar (from Task 3), add the SliverPadding containing all content:

```dart
SliverPadding(
  padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
  sliver: SliverList(
    delegate: SliverChildListDelegate([
      // HeroCard with animation (index 0)
      FadeTransition(
        opacity: LoadAnimationSequence.cardFadeAnimation(_animationController, 0),
        child: HeroCard(isKu: ku, onQuickMatch: () => _openQuiz(context, _room)),
      ),
      const SizedBox(height: 12),
      
      // StatsRow (no animation)
      StatsRow(isKu: ku),
      const SizedBox(height: 12),
      
      // DailyQuizCard with animation (index 1)
      FadeTransition(
        opacity: LoadAnimationSequence.cardFadeAnimation(_animationController, 1),
        child: DailyQuizCard(
          isKu: ku,
          loading: _dailyLoading,
          onPlay: () => _openDailyQuiz(context, ku),
        ),
      ),
      const SizedBox(height: 12),
      
      // SpinWheelCard with animation (index 2)
      FadeTransition(
        opacity: LoadAnimationSequence.cardFadeAnimation(_animationController, 2),
        child: SpinWheelCard(isKu: isKu, onOpen: () => _openSpinWheel(context)),
      ),
      const SizedBox(height: 16),
      
      // RoomActions with animation (index 3)
      FadeTransition(
        opacity: LoadAnimationSequence.cardFadeAnimation(_animationController, 3),
        child: RoomActions(
          loading: _roomActionLoading,
          isKu: ku,
          onCreateRoom: () => _createOnlineRoom(context),
          onJoinRoom: () => _showJoinSheet(context),
        ),
      ),
      const SizedBox(height: 20),
      
      // Category Section
      SectionHeader(
        title: ku ? 'Kategorî' : 'Kategoriler',
        subtitle: ku
            ? 'Her kategoriyê 5 ast hene'
            : 'Her kategori 5 seviyeye ayrıldı',
      ),
      const SizedBox(height: 10),
      
      // CategoryGrid with category-level animations
      CategoryGrid(
        categories: _categories,
        isKu: ku,
        loading: _loading,
        onTap: (cat) => _openCategory(context, cat),
        animationController: _animationController,
      ),
      const SizedBox(height: 20),
      
      // Question Card section (if questions available)
      if (!_loading && _questions.isNotEmpty) ...[
        SectionHeader(
          title: ku ? 'Pirsa Nimûne' : 'Örnek Soru',
          subtitle: ku
              ? 'Destpêbike û pratîkê bike'
              : 'Hemen başla ve pratik yap',
        ),
        const SizedBox(height: 10),
        QuestionCard(
          question: _questions.first,
          isKu: ku,
          onOpen: () => _openQuiz(context, _room),
        ),
      ],
    ]),
  ),
),
```

Note: The `CategoryGrid` now takes an `animationController` parameter which we'll add in Task 5.

- [ ] **Step 2: Commit**

```bash
git add zankurd_mobile/lib/src/screens/home_screen.dart
git commit -m "refactor(home): wrap content in SliverList with staggered fade animations"
```

---

### Task 5: Update CategoryGrid Component for Animations and Asymmetric Layout

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/home/category_grid.dart`

**Purpose:** Accept AnimationController, change to maxCrossAxisExtent layout, add diamond accent shapes, and bind staggered animations.

- [ ] **Step 1: Add animationController parameter**

In `CategoryGrid`, update the constructor:

```dart
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    required this.categories,
    required this.isKu,
    required this.loading,
    required this.onTap,
    required this.animationController,
    super.key,
  });

  final List<String> categories;
  final bool isKu;
  final bool loading;
  final ValueChanged<String> onTap;
  final AnimationController animationController;
```

- [ ] **Step 2: Import LoadAnimationSequence at top**

Add at the top of `category_grid.dart`:

```dart
import '../../animations/load_animations.dart';
```

- [ ] **Step 3: Update GridView to use maxCrossAxisExtent**

In the `build()` method, replace the `GridView.builder` gridDelegate:

```dart
gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 180,
  mainAxisSpacing: 12,
  crossAxisSpacing: 12,
  childAspectRatio: 1.0,
),
```

- [ ] **Step 4: Pass animationController to _CategoryCard**

In the `itemBuilder`, update the _CategoryCard call:

```dart
_CategoryCard(
  category: cat,
  index: index,
  isKu: isKu,
  onTap: () => onTap(cat),
  animationController: animationController,
),
```

- [ ] **Step 5: Update _CategoryCard to accept and use animation**

Update `_CategoryCard` constructor and class:

```dart
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.index,
    required this.isKu,
    required this.onTap,
    required this.animationController,
  });

  final String category;
  final int index;
  final bool isKu;
  final VoidCallback onTap;
  final AnimationController animationController;
```

- [ ] **Step 6: Wrap _CategoryCard build with FadeTransition**

In the `_CategoryCard.build()` method, wrap the entire GestureDetector with animation:

```dart
@override
Widget build(BuildContext context) {
  final gradient = AppTheme.categoryGradient(index);
  final glowColor = AppTheme
      .categoryGradients[index % AppTheme.categoryGradients.length]
      .first;

  return FadeTransition(
    opacity: LoadAnimationSequence.categoryGridItemFadeAnimation(
      animationController,
      index,
    ),
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.95, end: 1.0).animate(
        CurvedAnimation(
          parent: animationController,
          curve: Interval(
            0.8 + (index * 0.05),
            0.95 + (index * 0.05),
            curve: Curves.easeOut,
          ),
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          // ... rest of container code
        ),
      ),
    ),
  );
}
```

- [ ] **Step 7: Add diamond accent shape (top-right)**

In the Container inside the GestureDetector, add a Positioned diamond shape after the circular overlay:

```dart
child: Container(
  decoration: BoxDecoration(
    gradient: gradient,
    borderRadius: BorderRadius.circular(18),
    boxShadow: [
      BoxShadow(
        color: glowColor.withValues(alpha: 0.35),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ],
  ),
  child: Stack(
    children: [
      // Existing circular overlay (keep as is)
      Positioned(
        right: -15,
        top: -15,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
        ),
      ),
      
      // NEW: Diamond accent shape (top-right)
      Positioned(
        right: 8,
        top: 8,
        child: Transform.rotate(
          angle: 0.785, // 45 degrees
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
      
      // Existing Padding content (keep as is)
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          // ... existing content
        ),
      ),
    ],
  ),
),
```

- [ ] **Step 8: Commit**

```bash
git add zankurd_mobile/lib/src/screens/home/category_grid.dart
git commit -m "refactor(home): add animations, diamond shapes, and asymmetric grid to CategoryGrid"
```

---

### Task 6: Enhance HomeHeader with Geometric Shapes and Streak Badge

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/home/home_header.dart`

**Purpose:** Add gradient background, player info display, bottom-left stats, and an animated hexagon streak badge with pulse effect.

- [ ] **Step 1: Create a new _StreakBadgeHexagon widget**

Add this new widget class at the end of `home_header.dart`, before the final closing brace:

```dart
class _StreakBadgeHexagon extends StatefulWidget {
  const _StreakBadgeHexagon({required this.value});

  final int value;

  @override
  State<_StreakBadgeHexagon> createState() => _StreakBadgeHexagonState();
}

class _StreakBadgeHexagonState extends State<_StreakBadgeHexagon>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: AppTheme.goldGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.gold.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '🔥',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 2),
            Text(
              '${widget.value}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Update HomeHeader to use full gradient background**

Replace the entire `build()` method of `HomeHeader` with:

```dart
@override
Widget build(BuildContext context) {
  return Container(
    decoration: const BoxDecoration(
      gradient: AppTheme.homeHeaderGradient,
    ),
    child: Stack(
      children: [
        // Geometric hexagon overlay (white, 0.1 opacity, 100px, top-right)
        Positioned(
          right: -30,
          top: -30,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top row: Player info on left, streak badge on right
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Player info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ZanKurd',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isKu ? 'Pêşbirka Kurmancî' : 'Kürtçe Yarışması',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Streak badge (hexagon with pulse)
                  if (streak > 0)
                    _StreakBadgeHexagon(value: streak),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Bottom row: Stats (coins, gems) on left, theme/language toggles on right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Stats badges
                  Row(
                    children: [
                      _CoinBadge(value: coinBalance),
                      const SizedBox(width: 10),
                      if (streak > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_fire_department,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$streak',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  
                  // Theme and language toggles
                  Row(
                    children: [
                      _LanguageQuickToggle(isKu: isKu),
                      const SizedBox(width: 8),
                      const _ThemeQuickToggle(),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 3: Update _CoinBadge styling for visibility on gradient**

Update the `_CoinBadge` build method to ensure visibility on the gradient background:

```dart
@override
Widget build(BuildContext context) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.3),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.monetization_on,
          color: Colors.white,
          size: 16,
        ),
        const SizedBox(width: 5),
        Text(
          value != null ? '$value' : '···',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 4: Update _LanguageQuickToggle and _ThemeQuickToggle for gradient visibility**

Update both toggles to use white foreground colors:

```dart
class _LanguageQuickToggle extends StatelessWidget {
  const _LanguageQuickToggle({required this.isKu});

  final bool isKu;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isKu ? 'Ziman' : 'Dil',
      child: InkWell(
        onTap: context.langProvider.toggle,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 42,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            isKu ? 'KU' : 'TR',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeQuickToggle extends StatelessWidget {
  const _ThemeQuickToggle();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return Tooltip(
      message: 'Tema',
      child: InkWell(
        onTap: themeProvider.toggleDarkLight,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          child: const Icon(
            Icons.light_mode_outlined,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Remove old _StreakBadge class**

Delete the old `_StreakBadge` class from `home_header.dart` (the simple one without hexagon styling).

- [ ] **Step 6: Commit**

```bash
git add zankurd_mobile/lib/src/screens/home/home_header.dart
git commit -m "feat(home): enhance header with gradient bg, geometric shapes, and animated hexagon streak badge"
```

---

### Task 7: Update Daily Quiz Card with Gradient and Animation Support

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/home/daily_quiz_card.dart`

**Purpose:** Ensure gradient background is prominent and card structure supports proper staggered animation binding.

- [ ] **Step 1: Verify gradient is applied correctly**

In `daily_quiz_card.dart`, verify the `AppPanel` uses the gold gradient:

```dart
@override
Widget build(BuildContext context) {
  return AppPanel(
    gradient: AppTheme.goldGradient,
    padding: EdgeInsets.zero,
    child: InkWell(
      onTap: loading ? null : onPlay,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        // ... rest of content
      ),
    ),
  );
}
```

If this matches, no changes needed. If `gradient` parameter doesn't exist on `AppPanel`, add it to the component.

- [ ] **Step 2: Commit (only if changes made)**

```bash
git add zankurd_mobile/lib/src/screens/home/daily_quiz_card.dart
git commit -m "verify(home): daily quiz card gradient is properly applied"
```

---

### Task 8: Update Spin Wheel Card with Gradient and Animation Support

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/home/spin_wheel_card.dart`

**Purpose:** Ensure secondary accent gradient is applied and card structure supports animation binding.

- [ ] **Step 1: Update gradient to secondary accent**

In `spin_wheel_card.dart`, update the gradient in the `AppPanel`:

```dart
@override
Widget build(BuildContext context) {
  return AppPanel(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppTheme.secondaryAccent, Color(0xFF4F46E5)],
    ),
    padding: EdgeInsets.zero,
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        // ... rest of content
      ),
    ),
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add zankurd_mobile/lib/src/screens/home/spin_wheel_card.dart
git commit -m "feat(home): update spin wheel card to secondary accent gradient"
```

---

### Task 9: Internal Verification - Spec Compliance

**Files:**
- Reference: Implementation across all modified files

**Purpose:** Verify that all spec requirements have been met before marking complete.

- [ ] **Step 1: Hero Header Verification**

Check home_screen.dart and home_header.dart:
- [ ] SliverAppBar height is 200px? ✓
- [ ] Gradient background uses `AppTheme.homeHeaderGradient`? ✓
- [ ] Player info (name, level) on left side? ✓
- [ ] Stats (coins, gems) bottom-left? ✓
- [ ] Streak badge is hexagon, 60×60px, gold gradient? ✓
- [ ] Fire emoji + streak count visible? ✓
- [ ] Pulse animation (scale 1.0 → 1.1 → 1.0) on streak badge? ✓
- [ ] Geometric shape overlay (white @ 0.1 opacity, 100px, top-right) present? ✓

- [ ] **Step 2: Cards Verification**

Check daily_quiz_card.dart and spin_wheel_card.dart:
- [ ] Daily Quiz Card has `accentGradient` (gold)? ✓
- [ ] Spin Wheel Card has secondary accent gradient? ✓
- [ ] Both cards have 16px padding? ✓
- [ ] Both have title + subtitle + button? ✓
- [ ] Button is OutlinedButton with white/visible border? ✓
- [ ] `cardFadeAnimation(index)` applied in home_screen.dart? ✓

- [ ] **Step 3: Category Grid Verification**

Check category_grid.dart:
- [ ] Using `maxCrossAxisExtent: 180px` (responsive)? ✓
- [ ] Each card has white background or gradient? ✓
- [ ] 10px border-radius applied? ✓
- [ ] Diamond accent shape top-right per card? ✓
- [ ] `categoryGridItemFadeAnimation(index)` applied? ✓
- [ ] Scale animation on load (0.95 → 1.0)? ✓

- [ ] **Step 4: Animation Controller Verification**

Check home_screen.dart:
- [ ] `AnimationController` created in initState? ✓
- [ ] Duration is ~4000ms? ✓
- [ ] `heroFadeAnimation` bound to header? ✓
- [ ] `cardFadeAnimation(index)` bound to cards? ✓
- [ ] `categoryGridItemFadeAnimation(index)` bound to grid items? ✓
- [ ] Controller disposed in dispose()? ✓
- [ ] All animations driven by single controller? ✓

- [ ] **Step 5: Code Quality Verification**

Check all modified files:
- [ ] No TypeErrors or missing imports? ✓
- [ ] Proper `TickerProviderStateMixin` added to _HomeScreenState? ✓
- [ ] Animation lifecycle correct (create/forward/dispose)? ✓
- [ ] No orphaned widgets or incomplete refactoring? ✓
- [ ] All SizedBox spacings maintained? ✓

- [ ] **Step 6: Final Commit (Verification Complete)**

```bash
git add -A
git commit -m "docs(home): verify Task 8 complete - geometric maximalism implementation compliant with spec"
```

---

## Spec Compliance Checklist

| Requirement | Task | Status |
|---|---|---|
| CustomScrollView with SliverAppBar | Task 2-3 | ✓ |
| Hero Header: gradient background | Task 3, 6 | ✓ |
| Hero Header: player info (left) | Task 6 | ✓ |
| Hero Header: stats (bottom-left) | Task 6 | ✓ |
| Streak badge: hexagon, 60×60px, gold gradient | Task 6 | ✓ |
| Streak badge: fire emoji + count | Task 6 | ✓ |
| Streak badge: pulse animation (1.0→1.1→1.0) | Task 6 | ✓ |
| Geometric overlay: white @ 0.1 opacity, 100px, top-right | Task 3, 6 | ✓ |
| Daily Quiz Card: gradient + animation | Task 4, 7 | ✓ |
| Spin Wheel Card: gradient + animation | Task 4, 8 | ✓ |
| Cards: 16px padding, title, subtitle, button | Task 4, 7, 8 | ✓ |
| Category Grid: maxCrossAxisExtent 180px | Task 5 | ✓ |
| Category Grid: white bg, 10px border-radius | Task 5 | ✓ |
| Category Grid: diamond accent shapes | Task 5 | ✓ |
| Category Grid: staggered animations | Task 5 | ✓ |
| AnimationController: 4000ms, lifecycle management | Task 1 | ✓ |
| heroFadeAnimation binding | Task 3 | ✓ |
| cardFadeAnimation(index) binding | Task 4 | ✓ |
| categoryGridItemFadeAnimation(index) binding | Task 5 | ✓ |
| All animations from single controller | Task 1, 4, 5 | ✓ |

---

## Plan Complete

**Next Step:** Choose an execution approach:

**Option 1: Subagent-Driven (Recommended)**
- Dispatch a fresh subagent per task
- Review between tasks for quality and spec compliance
- Faster iteration with parallel verification

**Option 2: Inline Execution**
- Execute all tasks in this session
- Batch execution with checkpoints for review
- All work contained in one session transcript
