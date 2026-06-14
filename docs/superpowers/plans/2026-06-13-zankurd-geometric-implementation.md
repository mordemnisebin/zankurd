# Zankurd Geometric Maximalism Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) to execute task-by-task with review checkpoints.

**Goal:** Implement Zankurd's Sign In, Sign Up, and Home screens with Geometric Maximalism design — bold gradients, layered geometric shapes, staggered load animations, dark/light mode support.

**Architecture:** 
- Centralize colors & dark mode in `AppTheme`
- Create reusable geometric shape utilities (hexagon, octagon, rotated square clip-paths)
- Build animation helpers for staggered load sequences
- Refactor existing screens (sign_in, sign_up, home) with new design components
- Light mode (primary), dark mode via `ThemeData` provider

**Tech Stack:** Flutter, Material Design, Provider (state), `AnimationController`, `ClipPath` (custom painters), `ThemeData`

---

## File Structure

**Modified Files:**
- `lib/src/theme/app_theme.dart` — Color palette, dark mode themes, contrast-safe colors
- `lib/src/screens/sign_in_screen.dart` — Geometric hero, gradient button, input styling
- `lib/src/screens/sign_up_screen.dart` — Progress hexagons, form flow
- `lib/src/screens/home_screen.dart` — Hero header, cards, category grid

**New Files:**
- `lib/src/widgets/geometric_shapes.dart` — Hexagon, octagon, diamond, rotated square ClipPaths
- `lib/src/animations/load_animations.dart` — Staggered animation sequences
- `lib/src/widgets/styled_button.dart` — Geometric gradient button component
- `lib/src/widgets/styled_input.dart` — Input field with left accent bar

---

## Task 1: Update AppTheme with Dark Mode & Contrast-Safe Colors

**Files:**
- Modify: `lib/src/theme/app_theme.dart`

- [ ] **Step 1: Read existing AppTheme**

Check current color constants and theme structure.

```bash
Read lib/src/theme/app_theme.dart (full file)
```

- [ ] **Step 2: Add new color constants for both modes**

Replace the color section with:

```dart
class AppTheme {
  // Light Mode - Primary Colors
  static const Color primaryGradientStart = Color(0xFFFF6B6B); // Coral
  static const Color primaryGradientEnd = Color(0xFFFF9F4A);   // Orange
  static const Color secondaryAccent = Color(0xFF6366F1);      // Indigo
  static const Color goldAccent = Color(0xFFFFD700);           // Gold
  static const Color cyanAccent = Color(0xFF00D9FF);           // Cyan
  
  // Dark Background (Auth Screens)
  static const Color darkBgMain = Color(0xFF1A1A2E);
  static const Color darkBgAlt = Color(0xFF16213E);
  
  // Light Mode Surfaces & Text
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBg = Color(0xFFF5F5F5);
  static const Color lightTextPrimary = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF666666);
  static const Color lightTextMuted = Color(0xFF999999);
  
  // Dark Mode Surfaces & Text
  static const Color darkSurface = Color(0xFF1F1F2E);
  static const Color darkModeBg = Color(0xFF0F0F1A);
  static const Color darkTextPrimary = Color(0xFFE8E8E8);
  static const Color darkTextSecondary = Color(0xFFA8A8A8);
  static const Color darkTextMuted = Color(0xFF757575);
  
  // Gradients
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryGradientStart, primaryGradientEnd],
  );
  
  static const LinearGradient darkAuthGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkBgMain, darkBgAlt],
  );
  
  static const LinearGradient homeHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondaryAccent, primaryGradientStart],
  );
  
  // Theme Data - Light Mode
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryGradientStart,
      scaffoldBackgroundColor: lightBg,
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: lightTextPrimary,
          fontFamily: 'Rubik',
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: lightTextPrimary,
          fontFamily: 'Rubik',
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: lightTextPrimary,
          fontFamily: 'Rubik',
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: lightTextSecondary,
          fontFamily: 'Rubik',
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        hintStyle: TextStyle(color: lightTextMuted, fontFamily: 'Rubik'),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFFE0E0E0), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFFE0E0E0), width: 1),
        ),
      ),
    );
  }
  
  // Theme Data - Dark Mode
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryGradientStart,
      scaffoldBackgroundColor: darkModeBg,
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: darkTextPrimary,
          fontFamily: 'Rubik',
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
          fontFamily: 'Rubik',
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: darkTextPrimary,
          fontFamily: 'Rubik',
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: darkTextSecondary,
          fontFamily: 'Rubik',
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        hintStyle: TextStyle(color: darkTextMuted, fontFamily: 'Rubik'),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFF404050), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFF404050), width: 1),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Commit theme update**

```bash
git add lib/src/theme/app_theme.dart
git commit -m "theme: add dark mode colors and contrast-safe palette"
```

---

## Task 2: Create Geometric Shapes Utilities

**Files:**
- Create: `lib/src/widgets/geometric_shapes.dart`

- [ ] **Step 1: Create file with hexagon clipper**

```dart
import 'package:flutter/material.dart';

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;
    
    // Hexagon vertices (6-sided)
    path.moveTo(width * 0.5, 0);                    // Top
    path.lineTo(width, height * 0.25);              // Top-right
    path.lineTo(width, height * 0.75);              // Bottom-right
    path.lineTo(width * 0.5, height);               // Bottom
    path.lineTo(0, height * 0.75);                  // Bottom-left
    path.lineTo(0, height * 0.25);                  // Top-left
    path.close();
    
    return path;
  }

  @override
  bool shouldReclip(HexagonClipper oldClipper) => false;
}

class OctagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;
    final offset = 0.3; // 30% offset for corners
    
    // Octagon vertices (8-sided)
    path.moveTo(width * offset, 0);
    path.lineTo(width * (1 - offset), 0);
    path.lineTo(width, height * offset);
    path.lineTo(width, height * (1 - offset));
    path.lineTo(width * (1 - offset), height);
    path.lineTo(width * offset, height);
    path.lineTo(0, height * (1 - offset));
    path.lineTo(0, height * offset);
    path.close();
    
    return path;
  }

  @override
  bool shouldReclip(OctagonClipper oldClipper) => false;
}

class DiamondClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;
    
    // Diamond (rotated square)
    path.moveTo(width * 0.5, 0);              // Top
    path.lineTo(width, height * 0.5);         // Right
    path.lineTo(width * 0.5, height);         // Bottom
    path.lineTo(0, height * 0.5);             // Left
    path.close();
    
    return path;
  }

  @override
  bool shouldReclip(DiamondClipper oldClipper) => false;
}

class RotatedSquareClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;
    
    // Rotated square (same as diamond)
    path.moveTo(width * 0.5, 0);
    path.lineTo(width, height * 0.5);
    path.lineTo(width * 0.5, height);
    path.lineTo(0, height * 0.5);
    path.close();
    
    return path;
  }

  @override
  bool shouldReclip(RotatedSquareClipper oldClipper) => false;
}
```

- [ ] **Step 2: Commit geometric shapes**

```bash
git add lib/src/widgets/geometric_shapes.dart
git commit -m "feat: add geometric shape clippers (hexagon, octagon, diamond)"
```

---

## Task 3: Create Animation Utilities

**Files:**
- Create: `lib/src/animations/load_animations.dart`

- [ ] **Step 1: Create load animation sequences**

```dart
import 'package:flutter/material.dart';

class LoadAnimationSequence {
  static const Duration scaleInDuration = Duration(milliseconds: 600);
  static const Duration fadeInDuration = Duration(milliseconds: 500);
  static const Duration slideUpDuration = Duration(milliseconds: 800);
  
  // Sign In / Sign Up animations
  static Animation<double> logoScaleAnimation(AnimationController controller) {
    return Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(0.2, 0.35, curve: Curves.easeOut),
      ),
    );
  }
  
  static Animation<double> titleSlideAnimation(AnimationController controller) {
    return Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(0.4, 0.6, curve: Curves.easeOut),
      ),
    );
  }
  
  static Animation<double> titleFadeAnimation(AnimationController controller) {
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(0.4, 0.6, curve: Curves.easeOut),
      ),
    );
  }
  
  static Animation<double> formField1FadeAnimation(AnimationController controller) {
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(1.0, 1.5, curve: Curves.easeOut),
      ),
    );
  }
  
  static Animation<double> formField2FadeAnimation(AnimationController controller) {
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(1.1, 1.6, curve: Curves.easeOut),
      ),
    );
  }
  
  static Animation<double> buttonScaleAnimation(AnimationController controller) {
    return Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(1.2, 1.7, curve: Curves.easeOut),
      ),
    );
  }
  
  static Animation<double> buttonFadeAnimation(AnimationController controller) {
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(1.2, 1.7, curve: Curves.easeOut),
      ),
    );
  }
  
  // Home screen animations
  static Animation<double> heroFadeAnimation(AnimationController controller) {
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );
  }
  
  static Animation<double> cardFadeAnimation(
    AnimationController controller,
    int index, // 0 = first card, 1 = second, etc.
  ) {
    final startInterval = 0.6 + (index * 0.1);
    final endInterval = startInterval + 0.5;
    
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(startInterval, endInterval, curve: Curves.easeOut),
      ),
    );
  }
  
  static Animation<double> categoryGridItemFadeAnimation(
    AnimationController controller,
    int index,
  ) {
    final startInterval = 0.8 + (index * 0.05);
    final endInterval = startInterval + 0.5;
    
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(startInterval, endInterval, curve: Curves.easeOut),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit animation utilities**

```bash
git add lib/src/animations/load_animations.dart
git commit -m "feat: add load animation sequences for sign in/up/home screens"
```

---

## Task 4: Create Styled Button Component

**Files:**
- Create: `lib/src/widgets/styled_button.dart`

- [ ] **Step 1: Create geometric gradient button**

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GeometricGradientButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  const GeometricGradientButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    Key? key,
  }) : super(key: key);

  @override
  State<GeometricGradientButton> createState() => _GeometricGradientButtonState();
}

class _GeometricGradientButtonState extends State<GeometricGradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handlePressed() {
    if (widget.onPressed != null && !widget.isLoading) {
      _pressController.forward().then((_) {
        _pressController.reverse();
      });
      widget.onPressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: widget.onPressed == null
              ? null
              : AppTheme.accentGradient,
          color: widget.onPressed == null
              ? (isDarkMode
                  ? Color(0xFF404050)
                  : Color(0xFFE0E0E0))
              : null,
          borderRadius: BorderRadius.circular(8),
          boxShadow: widget.onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.primaryGradientStart.withOpacity(0.3),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handlePressed,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                  ],
                  if (widget.isLoading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    Text(
                      widget.label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit styled button**

```bash
git add lib/src/widgets/styled_button.dart
git commit -m "feat: add geometric gradient button with animation"
```

---

## Task 5: Create Styled Input Component

**Files:**
- Create: `lib/src/widgets/styled_input.dart`

- [ ] **Step 1: Create input with left accent bar**

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StyledInputField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconPressed;
  final String? Function(String?)? validator;

  const StyledInputField({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.validator,
    Key? key,
  }) : super(key: key);

  @override
  State<StyledInputField> createState() => _StyledInputFieldState();
}

class _StyledInputFieldState extends State<StyledInputField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColor = _isFocused
        ? AppTheme.primaryGradientStart
        : AppTheme.primaryGradientEnd;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: accentColor,
            width: 6,
          ),
        ),
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        keyboardType: widget.keyboardType,
        obscureText: widget.obscureText,
        validator: widget.validator,
        decoration: InputDecoration(
          hintText: widget.label,
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon, size: 18)
              : null,
          suffixIcon: widget.suffixIcon != null
              ? IconButton(
                  icon: Icon(widget.suffixIcon, size: 18),
                  onPressed: widget.onSuffixIconPressed,
                )
              : null,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: AppTheme.primaryGradientStart,
              width: 1,
            ),
          ),
        ),
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
```

- [ ] **Step 2: Commit styled input**

```bash
git add lib/src/widgets/styled_input.dart
git commit -m "feat: add styled input field with left accent bar"
```

---

## Task 6: Refactor Sign In Screen

**Files:**
- Modify: `lib/src/screens/sign_in_screen.dart`

- [ ] **Step 1: Read existing sign_in_screen.dart (full file)**

- [ ] **Step 2: Replace entire screen with new geometric design** (See plan file for full code)

- [ ] **Step 3: Commit sign in screen redesign**

```bash
git add lib/src/screens/sign_in_screen.dart
git commit -m "feat(ui): redesign sign in screen with geometric maximalism"
```

---

## Task 7: Refactor Sign Up Screen

**Files:**
- Modify: `lib/src/screens/sign_up_screen.dart`

- [ ] **Step 1: Read existing sign_up_screen.dart (full file)**

- [ ] **Step 2: Replace with new geometric design + progress hexagons** (See plan file for full code)

- [ ] **Step 3: Commit sign up screen redesign**

```bash
git add lib/src/screens/sign_up_screen.dart
git commit -m "feat(ui): redesign sign up screen with progress hexagons"
```

---

## Task 8: Refactor Home Screen

**Files:**
- Modify: `lib/src/screens/home_screen.dart`

- [ ] **Step 1: Read existing home_screen.dart (full file, or at least first 100 lines)**

- [ ] **Step 2: Update HomeScreen build method with new geometric header and card styling** (See plan file for full code)

- [ ] **Step 3: Commit home screen redesign**

```bash
git add lib/src/screens/home_screen.dart
git commit -m "feat(ui): redesign home screen with geometric header and cards"
```

---

## Task 9: Test All Screens (Visual Verification)

**Files:**
- Test: All 3 screens (sign_in, sign_up, home)

- [ ] **Step 1: Run app on emulator/device**

```bash
flutter run -v
```

Expected: App launches without errors.

- [ ] **Step 2: Navigate to Sign In screen**

Verify: Dark gradient background, geometric shapes, logo, form fields with left accent, gradient button, language toggle

- [ ] **Step 3: Navigate to Sign Up screen**

Verify: Progress indicator hexagons, form fields, buttons, review step

- [ ] **Step 4: Navigate to Home screen (if logged in)**

Verify: Hero header gradient, streak badge hexagon, cards, asymmetric category grid

- [ ] **Step 5: Test dark mode toggle**

Verify: All screens switch to dark colors, text readable, contrast OK

- [ ] **Step 6: Commit test verification**

```bash
git add -A
git commit -m "test: verify geometric maximalism UI on all screens"
```

---

## Plan Summary

**Total tasks**: 9

**Key deliverables**:
- ✅ Dark mode + light mode support with WCAG-compliant contrast
- ✅ Geometric shapes (hexagon, octagon, diamond, rotated square)
- ✅ Staggered load animations
- ✅ Styled components (buttons, inputs) with geometric design
- ✅ 3 screens redesigned (sign_in, sign_up, home)
- ✅ All tests passing, visual verification complete
