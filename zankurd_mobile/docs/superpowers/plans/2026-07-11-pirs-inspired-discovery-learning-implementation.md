# Pirs-Inspired Discovery and Learning (Paket 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kategori, alt-kategori, öğrenme ve seviye yolu ekranlarını Paket 1'de kurulan Pirs-inspired açık/renkli görsel sisteme taşımak; logic, navigation ve store davranışını değiştirmemek.

**Architecture:** Paket 1 tokenları (`brandOrange`, `playGreen`, yumuşak gölge sözleşmesi) ve mevcut `ScreenIdentityHeader` yeniden kullanılır. Kategori görselleri/gradyanları korunur; yalnızca gölge yoğunluğu, yüzey rengi, chip/sekme stili ve tipografi ağırlığı yeni dile çekilir. Tüm callback, provider ve repository çağrıları aynen kalır.

**Tech Stack:** Flutter, Dart, Material 3, Provider, SharedPreferences, flutter_test, Playwright CLI; yeni dependency yok.

## Global Constraints

- Navigation, route, event handler, provider, repository, service, Supabase ve auth davranışı değişmeyecek.
- `MasteryStore`, `LevelProgressStore`, lesson tamamlama ve analytics çağrıları değişmeyecek.
- Mevcut kategori görselleri (`CategoryVisuals`) ve `AppTheme.categoryGradients` korunacak.
- Kart radius `16`; kalın 3D gölge ve güçlü glow kaldırılacak, ince border + yumuşak gölge gelecek.
- Kilim deseni yalnızca hero/banner yüzeylerinde kalacak; liste kartlarından kaldırılacak.
- Öğrenme ekranı kimlik rengi `AppTheme.playGreen` olacak (spec: Öğrenme yeşil `#58B96B`).
- Light mode birincil; dark mode eksiksiz okunabilir kalacak.
- Telefon 360 px'de RenderFlex overflow oluşmayacak.
- Yeni dependency ve büyük refactor yok.
- Çalışma `codex/pirs-inspired-package-02` branch'inde, `.worktrees/pirs-inspired-package-02` worktree'sinde yapılacak (superpowers:using-git-worktrees).

---

### Task 1: Kategori Sekmesi — Header ve Kart Gölgesi

**Files:**
- Modify: `lib/src/screens/categories_tab.dart:87-131` (header), `:161-177` (itemBuilder key), `:324-372` (mastery rozeti)
- Modify: `lib/src/theme/app_theme.dart:144-158` (`AppShadows.categoryCard`)
- Create: `test/categories_tab_test.dart`

**Interfaces:**
- Preserves: `CategoriesTab({repository, scrollController})`, `_load`, `_loadMastery`, Subcategory push callback'i.
- Produces: `ValueKey('categories-header-accent')`, her kartta `ValueKey('category-card-<kategori>')`, rozette `ValueKey('mastery-badge-<kategori>')`.

- [ ] **Step 1: Görsel sözleşme testlerini yaz**

`test/categories_tab_test.dart` dosyasını oluştur:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/categories_tab.dart';
import 'package:zankurd_mobile/src/screens/subcategory_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

Widget wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child)),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MasteryStore.resetInstance();
  });

  testWidgets('header brandOrange aksan çizgisi taşır', (tester) async {
    await tester.pumpWidget(
      wrap(CategoriesTab(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final accent = tester.widget<Container>(
      find.byKey(const ValueKey('categories-header-accent')),
    );
    final decoration = accent.decoration as BoxDecoration;
    expect(decoration.color, AppTheme.brandOrange);
    expect(decoration.gradient, isNull);
    expect(find.text('Kategoriler'), findsOneWidget);
  });

  testWidgets('mastery rozeti seed edilen kategoride görünür', (tester) async {
    SharedPreferences.setMockInitialValues({'zankurd.mastery.Ziman': 25});
    MasteryStore.resetInstance();

    await tester.pumpWidget(
      wrap(CategoriesTab(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mastery-badge-Ziman')), findsOneWidget);
  });

  testWidgets('kart dokunuşu SubcategoryScreen açar', (tester) async {
    await tester.pumpWidget(
      wrap(CategoriesTab(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('category-card-Ziman')));
    await tester.pumpAndSettle();

    expect(find.byType(SubcategoryScreen), findsOneWidget);
  });

  testWidgets('360 px genişlikte overflow oluşmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(CategoriesTab(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Testlerin eksik key'ler nedeniyle başarısız olduğunu doğrula**

Run: `flutter test test/categories_tab_test.dart`

Expected: `categories-header-accent`, `category-card-Ziman`, `mastery-badge-Ziman` key'leri bulunamadığı için FAIL.

- [ ] **Step 3: Minimum görsel değişikliği uygula**

`app_theme.dart` içinde `AppShadows.categoryCard` (katı 5 px taban gölgesini kaldır, tek yumuşak gölge bırak):

```dart
static List<BoxShadow> categoryCard(Color color) {
  return [
    BoxShadow(
      color: color.withValues(alpha: 0.20),
      offset: const Offset(0, 8),
      blurRadius: 18,
      spreadRadius: -8,
    ),
  ];
}
```

`categories_tab.dart` header aksan çizgisi (gradient yerine düz brandOrange + key):

```dart
Container(
  key: const ValueKey('categories-header-accent'),
  width: 4,
  height: 44,
  margin: const EdgeInsets.only(right: AppSpacing.md),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(2),
    color: AppTheme.brandOrange,
  ),
),
```

Başlık stili `display` (w900) yerine `heading1` (w800):

```dart
Text(
  ku ? 'Kategorî' : 'Kategoriler',
  style: AppTypography.heading1.copyWith(
    color: AppTheme.textPrimaryColor(context),
    fontSize: 26,
  ),
),
```

`itemBuilder` içindeki `_CategoryCard` çağrısına key ekle (GestureDetector'a kadar inen ilk widget'a):

```dart
return _CategoryCard(
  key: ValueKey('category-card-$cat'),
  category: cat,
  ...
);
```

(`_CategoryCard` constructor'ına `super.key` ekle.)

Mastery rozeti: key ekle, glow `boxShadow` listesini kaldır (border ve scrim kalır):

```dart
child: Container(
  key: ValueKey('mastery-badge-${widget.category}'),
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
  decoration: BoxDecoration(
    color: Colors.black.withValues(alpha: 0.55),
    borderRadius: BorderRadius.circular(AppRadius.md),
    border: Border.all(
      color: AppTheme.gold.withValues(alpha: 0.60),
      width: 1.1,
    ),
  ),
  ...
),
```

- [ ] **Step 4: Testleri çalıştır**

Run: `flutter test test/categories_tab_test.dart test/categories_before_after_test.dart`

Expected: PASS. (`categories_before_after_test` screenshot üretir; PNG diff'i commit'e alma.)

- [ ] **Step 5: Commit**

```bash
git checkout -- docs/screenshots/phase2b
git add lib/src/screens/categories_tab.dart lib/src/theme/app_theme.dart test/categories_tab_test.dart
git commit -m "ui: soften category grid into light card language"
```

### Task 2: Alt-Kategori Kartları — Açık Yüzey

**Files:**
- Modify: `lib/src/screens/subcategory_screen.dart:106-124` (banner), `:256-300` (kart yüzeyi)
- Create: `test/subcategory_screen_test.dart`

**Interfaces:**
- Preserves: `SubcategoryScreen({repository, category})`, LevelScreen push callback'i, `_LevelChip`.
- Produces: her kartta `ValueKey('subcategory-card-<id>')`.

- [ ] **Step 1: Testleri yaz**

`test/subcategory_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/subcategory_config.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/level_screen.dart';
import 'package:zankurd_mobile/src/screens/subcategory_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

Widget wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LevelProgressStore.resetInstance();
  });

  testWidgets('kartlar açık yüzeyde tint border ile listelenir', (
    tester,
  ) async {
    final first = SubcategoryConfig.subcategories['Ziman']!.first;

    await tester.pumpWidget(
      wrap(
        SubcategoryScreen(
          repository: MockZanKurdRepository(),
          category: 'Ziman',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cardKey = ValueKey('subcategory-card-${first.id}');
    expect(find.byKey(cardKey), findsOneWidget);
    expect(find.text(first.nameTr), findsOneWidget);

    final card = tester.widget<Container>(
      find.descendant(
        of: find.byKey(cardKey),
        matching: find.byType(Container).first,
      ),
    );
    final decoration = card.decoration as BoxDecoration;
    expect(decoration.color, AppTheme.lightSurface);
    expect(decoration.gradient, isNull);
  });

  testWidgets('kart dokunuşu LevelScreen açar', (tester) async {
    final first = SubcategoryConfig.subcategories['Ziman']!.first;

    await tester.pumpWidget(
      wrap(
        SubcategoryScreen(
          repository: MockZanKurdRepository(),
          category: 'Ziman',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('subcategory-card-${first.id}')));
    await tester.pumpAndSettle();

    expect(find.byType(LevelScreen), findsOneWidget);
  });

  testWidgets('360 px genişlikte overflow oluşmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(
        SubcategoryScreen(
          repository: MockZanKurdRepository(),
          category: 'Ziman',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Testin eksik key ve gradient yüzey nedeniyle başarısız olduğunu doğrula**

Run: `flutter test test/subcategory_screen_test.dart`

Expected: `subcategory-card-<id>` key'i bulunamadığı için FAIL.

- [ ] **Step 3: Kart yüzeyini uygula**

`_SubcategoryCard.build` içinde dış `ClipRRect`'e key ver ve `Container` dekorasyonunu değiştir; kart içi kilim `CustomPaint` bloğunu tamamen kaldır (watermark ikon 0.10 opaklıkta kalır):

```dart
return ClipRRect(
  key: ValueKey('subcategory-card-${info.id}'),
  borderRadius: BorderRadius.circular(AppRadius.card),
  child: Container(
    decoration: BoxDecoration(
      color: AppTheme.surfaceColor(context),
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: tint.withValues(alpha: 0.22), width: 1.1),
      boxShadow: [
        BoxShadow(
          color: tint.withValues(alpha: 0.10),
          blurRadius: 14,
          offset: const Offset(0, 5),
          spreadRadius: -6,
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          right: -14,
          bottom: -18,
          child: Icon(icon, size: 92, color: tint.withValues(alpha: 0.10)),
        ),
        Material(
          // ... mevcut InkWell + Row içeriği AYNEN kalır ...
        ),
      ],
    ),
  ),
);
```

(`surface` lokal değişkeni ve `KilimPatternPainter` importu kullanılmıyorsa sil.)

Banner yumuşatma (`_CategoryBanner`): gölge `alpha: 0.25` → `0.16`; başlık `fontSize: 30` → `26` (w800 kalır). Banner'daki kilim filigranı hero yüzeyi olduğu için kalır.

- [ ] **Step 4: Testleri çalıştır**

Run: `flutter test test/subcategory_screen_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/subcategory_screen.dart test/subcategory_screen_test.dart
git commit -m "ui: move subcategory cards to light surfaces"
```

### Task 3: Öğrenme Ekranı — playGreen Kimliği

**Files:**
- Modify: `lib/src/screens/learning_screen.dart:83-176` (kimlik bandı), `:275-330` (`_CategoryTab`), `:352-377` (ders ikonu), `:199-202,525-531,566-571` (spinner/progress renkleri)
- Create: `test/learning_screen_test.dart`

**Interfaces:**
- Preserves: `LearningScreen({repository})`, `_selectCategory`, `_refreshCompleted`, `LessonDetailScreen` ve `_markCompleted` akışı.
- Consumes: `ScreenIdentityHeader` (mevcut widget) ve `AppTheme.playGreen`.
- Produces: her sekmede `ValueKey('learning-tab-<kategori>')`.

- [ ] **Step 1: Testleri yaz**

`test/learning_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/screen_identity_header.dart';

Widget wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void main() {
  testWidgets('kimlik bandı playGreen ScreenIdentityHeader olur', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final header = tester.widget<ScreenIdentityHeader>(
      find.byType(ScreenIdentityHeader),
    );
    expect(header.accent, AppTheme.playGreen);
    expect(find.text('Öğren'), findsOneWidget);
  });

  testWidgets('seçili sekme düz playGreen dolgu taşır', (tester) async {
    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final tab = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const ValueKey('learning-tab-everyday')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = tab.decoration as BoxDecoration;
    expect(decoration.color, AppTheme.playGreen);
    expect(decoration.gradient, isNull);
  });

  testWidgets('dersler mock repodan listelenir', (tester) async {
    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alfabê'), findsOneWidget);
  });

  testWidgets('360 px genişlikte overflow oluşmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Testin cyan band nedeniyle başarısız olduğunu doğrula**

Run: `flutter test test/learning_screen_test.dart`

Expected: `ScreenIdentityHeader` bulunamadığı ve sekme key'i olmadığı için FAIL.

- [ ] **Step 3: Kimliği uygula**

Özel cyan bandı (satır 91-175 `ClipRRect` bloğu) `ScreenIdentityHeader` ile değiştir:

```dart
Padding(
  padding: const EdgeInsets.fromLTRB(
    AppSpacing.page,
    AppSpacing.xs,
    AppSpacing.page,
    0,
  ),
  child: ScreenIdentityHeader(
    title: ku ? 'Kurmancî hîn bibe' : 'Kurmancî öğren',
    subtitle: ku ? 'Ders bi ders, mijar bi mijar' : 'Ders ders, konu konu ilerle',
    accent: AppTheme.playGreen,
    icon: Icons.school_rounded,
    compact: true,
  ),
),
```

(import ekle: `import '../widgets/screen_identity_header.dart';`)

`_CategoryTab` çağrısına key ver:

```dart
(cat) => _CategoryTab(
  key: ValueKey('learning-tab-$cat'),
  label: _categoryLabel(cat, ku),
  isSelected: cat == _selectedCategory,
  onTap: () => _selectCategory(cat),
),
```

(`_CategoryTab` constructor'ına `super.key` ekle.)

`_CategoryTab` dekorasyonu — gradient+glow yerine düz dolgu:

```dart
decoration: BoxDecoration(
  color: isSelected ? AppTheme.playGreen : Colors.transparent,
  borderRadius: BorderRadius.circular(14),
  border: Border.all(
    color: isSelected
        ? Colors.transparent
        : AppTheme.borderColor(context).withValues(alpha: 0.5),
    width: 1,
  ),
),
```

`_LessonCard` ikon kutusu — pembe accent yerine yeşil kimlik:

```dart
decoration: BoxDecoration(
  gradient: const LinearGradient(
    colors: [AppTheme.playGreen, Color(0xFF3E9A55)],
  ),
  borderRadius: BorderRadius.circular(14),
  boxShadow: [
    BoxShadow(
      color: AppTheme.playGreen.withValues(alpha: 0.24),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ],
),
```

Renk düzeltmeleri:
- Liste loading spinner: `color: AppTheme.cyan` → `color: AppTheme.playGreen`.
- `LessonDetailScreen` loading spinner: `AppTheme.primaryGradientStart` → `AppTheme.playGreen`.
- `LessonDetailScreen` `LinearProgressIndicator`: `color: AppTheme.primaryGradientStart` → `color: AppTheme.playGreen`.

- [ ] **Step 4: Testleri çalıştır**

Run: `flutter test test/learning_screen_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/learning_screen.dart test/learning_screen_test.dart
git commit -m "ui: give learning screen playGreen identity"
```

### Task 4: Seviye Yolu — Yumuşak Düğümler

**Files:**
- Modify: `lib/src/screens/level_screen.dart:196-206` (hero gölgesi), `:460-483` (düğüm gölge/tipografi), `:508-520` (etiket chip'i)
- Create: `test/level_screen_test.dart`

**Interfaces:**
- Preserves: `LevelScreen({repository, category, subCategory})`, `_openLevel`, `LevelProgressStore` işaretleme, `_levelColor` eşlemesi.

- [ ] **Step 1: Testleri yaz**

`test/level_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/level_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

Widget wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LevelProgressStore.resetInstance();
  });

  testWidgets('seviye yolu 5 düğümü ve final kupasını gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(LevelScreen(repository: MockZanKurdRepository(), category: 'Ziman')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Destpêk'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
  });

  testWidgets('düğüm numarası w800 ve yumuşak gölge taşır', (tester) async {
    await tester.pumpWidget(
      wrap(LevelScreen(repository: MockZanKurdRepository(), category: 'Ziman')),
    );
    await tester.pumpAndSettle();

    final numberText = tester.widget<Text>(find.text('1'));
    expect(numberText.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('etiket chip yüzey renginde kalır', (tester) async {
    await tester.pumpWidget(
      wrap(LevelScreen(repository: MockZanKurdRepository(), category: 'Ziman')),
    );
    await tester.pumpAndSettle();

    final label = find.ancestor(
      of: find.text('Destpêk'),
      matching: find.byType(Container),
    );
    final decoration =
        tester.widget<Container>(label.first).decoration as BoxDecoration;
    expect(decoration.color, AppTheme.lightSurface);
  });

  testWidgets('360 px genişlikte overflow oluşmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(LevelScreen(repository: MockZanKurdRepository(), category: 'Ziman')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Testin w900 ve tint-blend chip nedeniyle başarısız olduğunu doğrula**

Run: `flutter test test/level_screen_test.dart`

Expected: fontWeight `w900` ve chip rengi `alphaBlend` olduğu için FAIL.

- [ ] **Step 3: Düğümleri yumuşat**

`_LevelNode` daire gölgesi (glow azaltılır, "sıradaki" vurgusu korunur):

```dart
boxShadow: [
  BoxShadow(
    color: color.withValues(alpha: widget.isNext ? 0.32 : 0.20),
    blurRadius: widget.isNext ? 16 : 10,
    offset: const Offset(0, 5),
    spreadRadius: -2,
  ),
],
```

Düğüm numarası `fontWeight: FontWeight.w900` → `FontWeight.w800`.

Etiket chip'i düz yüzey olur (tint border kalır):

```dart
decoration: BoxDecoration(
  color: AppTheme.surfaceColor(context),
  borderRadius: BorderRadius.circular(AppRadius.sm),
  border: Border.all(color: color.withValues(alpha: 0.30)),
),
```

`_CategoryHero` gölgesi: `alpha: 0.25` → `0.16`.

- [ ] **Step 4: Testleri çalıştır**

Run: `flutter test test/level_screen_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/level_screen.dart test/level_screen_test.dart
git commit -m "ui: soften level path nodes and labels"
```

### Task 5: Paket Doğrulaması ve Görsel Kanıt

**Files:**
- Create: `docs/screenshots/pirs-inspired/package-02/` altındaki screenshotlar.

**Interfaces:**
- Produces: light/dark ve keşif/öğrenme akışı için doğrulama kanıtı.

- [ ] **Step 1: Format kontrolü**

Run:

```bash
dart format lib/src/screens/categories_tab.dart lib/src/screens/subcategory_screen.dart lib/src/screens/learning_screen.dart lib/src/screens/level_screen.dart lib/src/theme/app_theme.dart test/categories_tab_test.dart test/subcategory_screen_test.dart test/learning_screen_test.dart test/level_screen_test.dart
```

Expected: exit 0.

- [ ] **Step 2: Statik analiz**

Run: `dart analyze lib test`

Expected: `No issues found!`

- [ ] **Step 3: Odaklı ve tam testler**

Run:

```bash
flutter test test/categories_tab_test.dart test/subcategory_screen_test.dart test/learning_screen_test.dart test/level_screen_test.dart
flutter test
```

Expected: tüm testler PASS. Test koşusunun yeniden ürettiği `docs/screenshots/phase2b`/`phase2c` PNG'lerini `git checkout --` ile geri al.

- [ ] **Step 4: Release web build**

Run: `flutter build web --release` (önce `$env:TMP="C:\src\tmp"; $env:TEMP="C:\src\tmp"`)

Expected: `build/web` başarıyla oluşur.

- [ ] **Step 5: Playwright görsel matrisi**

Release build'i yerel sunucuda aç (`python -m http.server`), misafir girişiyle uygulamaya gir ve şu kareleri al:

```text
docs/screenshots/pirs-inspired/package-02/light-390x844-categories.png   (Kategorî sekmesi)
docs/screenshots/pirs-inspired/package-02/light-390x844-subcategory.png  (Ziman alt-kategori listesi)
docs/screenshots/pirs-inspired/package-02/light-390x844-levelpath.png    (bir alt-kategorinin seviye yolu)
docs/screenshots/pirs-inspired/package-02/light-390x844-learning.png     (Xwendin sekmesi)
docs/screenshots/pirs-inspired/package-02/dark-390x844-categories.png    (localStorage flutter.zankurd.themeMode="dark")
```

Her karede overflow, kesilen Kurmancî metin, 44 px altı action ve kalın glow olmadığını doğrula. Console error/warning ve 4xx/5xx asset isteği olmamalı.

- [ ] **Step 6: Logic diff audit**

Run:

```bash
git diff HEAD~4..HEAD -- lib/src/screens lib/src/theme
git diff --check HEAD~4..HEAD
```

`Navigator`, `repository.`, `Store.load`, `markLessonCompleted`, `logAnalyticsEvent` çağrılarında davranış farkı olmadığını doğrula.

- [ ] **Step 7: Final doğrulama commit'i**

```bash
git add docs/screenshots/pirs-inspired/package-02
git commit -m "docs: verify Pirs-inspired discovery and learning"
```

## Sonraki Paket

Bu paket görsel olarak onaylandıktan sonra ayrı planla Paket 3'e geçilir: `quiz_screen.dart`, `quiz_result_screen.dart`, cevap inceleme ve favori sorular. Bu dosyalar bu planda değiştirilmez.
