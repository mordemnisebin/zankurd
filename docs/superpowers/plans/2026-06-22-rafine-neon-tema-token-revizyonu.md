# Rafine Neon — Tema/Token Revizyonu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zankurd'un mevcut kozmik neon kimliğini, net renk rolleri + tutarlı tipografi/kart/buton davranışlarıyla cilalamak (yeni layout/ekran yok).

**Architecture:** Tek bir `app_theme.dart` token kaynağı + tek bir kategori-görsel kaynağı (`CategoryVisuals`) kurulur; ekranlardaki dağınık, elle yazılmış stiller bu kaynaklara indirgenir. Değişiklik token + ortak bileşen davranışı düzeyinde; iş mantığı dokunulmaz.

**Tech Stack:** Flutter (Material 3), Dart, Provider; test: `flutter test`; lint: `dart analyze` (CLAUDE.md: `flutter analyze` LSP nedeniyle kullanılmaz).

**Notlar:**
- Tüm komutlar `zankurd_mobile/` dizininden çalıştırılır.
- Kategori sırası her yerde sabittir: `Ziman, Çand, Dîrok, Edebiyat, Cografya, Muzîk, Siyaset, Paradigma` (bu sıra `AppTheme.categoryGradients` index'i ile eşleşir).

---

### Task 1: Kategori görselleri için tek kaynak (`CategoryVisuals`)

Şu an kategori ikon `switch`'i en az 5 dosyada kopyalanmış (`category_grid.dart` içinde 2 kez, `categories_tab.dart`, `quiz_widgets.dart`, `subcategory_screen.dart`, `onboarding_screen.dart`). Tek kaynağa indir.

**Files:**
- Create: `lib/src/config/category_visuals.dart`
- Test: `test/category_visuals_test.dart`
- Modify: `lib/src/screens/home/category_grid.dart` (iki adet `_icon`), `lib/src/screens/categories_tab.dart`, `lib/src/screens/quiz/quiz_widgets.dart`, `lib/src/screens/subcategory_screen.dart`, `lib/src/screens/onboarding_screen.dart`

- [ ] **Step 1: Failing test yaz**

`test/category_visuals_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/category_visuals.dart';

void main() {
  const known = [
    'Ziman', 'Çand', 'Dîrok', 'Edebiyat',
    'Cografya', 'Muzîk', 'Siyaset', 'Paradigma',
  ];

  test('bilinen her kategori için ikon tanımlı', () {
    for (final cat in known) {
      expect(CategoryVisuals.icon(cat), isA<IconData>());
      expect(CategoryVisuals.icon(cat), isNot(Icons.category_outlined),
          reason: '$cat için özel ikon bekleniyor');
    }
  });

  test('bilinmeyen kategori fallback ikon döner', () {
    expect(CategoryVisuals.icon('Yok'), Icons.category_outlined);
  });

  test('imagePath bilinen kategoriler için png yolu döner', () {
    for (final cat in known) {
      expect(CategoryVisuals.imagePath(cat), endsWith('.png'));
    }
  });
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test test/category_visuals_test.dart`
Expected: FAIL — "Target of URI doesn't exist: 'package:zankurd_mobile/src/config/category_visuals.dart'"

- [ ] **Step 3: `CategoryVisuals` oluştur**

`lib/src/config/category_visuals.dart`:

```dart
import 'package:flutter/material.dart';

/// Kategori bazlı görsel kaynak (ikon + arka plan görseli) için tek doğruluk kaynağı.
/// Gradient için AppTheme.categoryGradient(index) kullanılmaya devam eder.
class CategoryVisuals {
  const CategoryVisuals._();

  static IconData icon(String category) => switch (category) {
        'Ziman' => Icons.translate_outlined,
        'Çand' => Icons.diversity_3_outlined,
        'Dîrok' => Icons.account_balance_outlined,
        'Edebiyat' => Icons.menu_book_outlined,
        'Cografya' => Icons.public_outlined,
        'Muzîk' => Icons.music_note_outlined,
        'Siyaset' => Icons.how_to_vote_outlined,
        'Paradigma' => Icons.psychology_outlined,
        _ => Icons.category_outlined,
      };

  static String imagePath(String category) => switch (category) {
        'Ziman' => 'assets/question_images/cat_ziman.png',
        'Çand' => 'assets/question_images/cat_cand.png',
        'Dîrok' => 'assets/question_images/cat_dirok.png',
        'Edebiyat' => 'assets/question_images/cat_edebiyat.png',
        'Cografya' => 'assets/question_images/cat_cografya.png',
        'Muzîk' => 'assets/question_images/cat_muzik.png',
        'Siyaset' => 'assets/question_images/cat_siyaset.png',
        'Paradigma' => 'assets/question_images/cat_paradigma.png',
        _ => 'assets/question_images/cat_ziman.png',
      };
}
```

- [ ] **Step 4: Testi çalıştır, geçtiğini gör**

Run: `flutter test test/category_visuals_test.dart`
Expected: PASS (3 test)

- [ ] **Step 5: Kopya `_icon`/`_imagePath`'leri `CategoryVisuals` ile değiştir**

`category_grid.dart`: dosyanın başına `import '../../config/category_visuals.dart';` ekle. `_CompactCategoryButton` ve `_CategoryCard` içindeki `IconData _icon(String cat) => switch ... ;` metotlarını sil; çağrıları `CategoryVisuals.icon(category)` yap. `_CategoryCard._imagePath` metodunu sil; `final image = CategoryVisuals.imagePath(category);` kullan.

`categories_tab.dart`, `quiz_widgets.dart`, `subcategory_screen.dart`, `onboarding_screen.dart`: her birinde kategori ikon `switch`'ini bulup sil, ilgili `import` ekleyip çağrıyı `CategoryVisuals.icon(<kategoriDeğişkeni>)` ile değiştir. (Her dosyada değişken adı farklı olabilir — `Icons.translate` geçen satırı referans al.)

- [ ] **Step 6: Analyze + tüm testler**

Run: `dart analyze && flutter test`
Expected: "No issues found!" ve tüm testler PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/src/config/category_visuals.dart test/category_visuals_test.dart lib/src/screens/home/category_grid.dart lib/src/screens/categories_tab.dart lib/src/screens/quiz/quiz_widgets.dart lib/src/screens/subcategory_screen.dart lib/src/screens/onboarding_screen.dart
git commit -m "refactor: kategori ikon/görsel kaynağını CategoryVisuals'ta birleştir"
```

---

### Task 2: Tipografi ölçeği — `w900` yükünü azalt

`textTheme`'de Display/Title `w900` kullanıyor; ölçeği Display `w800`, Title `w700` yap. Ekranlardaki elle yazılmış `FontWeight.w900` kullanımlarını da Title bağlamında `w700`, vurgulu başlıkta `w800` yap.

**Files:**
- Modify: `lib/src/theme/app_theme.dart:239-342` (appBarTheme + textTheme)

- [ ] **Step 1: `app_theme.dart` textTheme/appBar ağırlıklarını güncelle**

`dark()` içindeki `appBarTheme.titleTextStyle.fontWeight: FontWeight.w900` → `FontWeight.w800`.
`textTheme` içinde:
- `headlineSmall`: `fontWeight: FontWeight.w900` → `FontWeight.w800`
- `titleLarge`: `fontWeight: FontWeight.w900` → `FontWeight.w700`
- `titleMedium`: `FontWeight.w700` (değişmez)

- [ ] **Step 2: Ekranlardaki elle yazılmış `w900`'leri tara ve indir**

Run: `grep -rn "FontWeight.w900" lib/`
Her isabet için: kart/başlık metni ise `FontWeight.w700`, büyük hero/ekran başlığı ise `FontWeight.w800` yap. (`category_grid.dart`'taki kategori adı `w900` → `w800`; rozet/mastery etiketi gibi küçük çipler `w700`.)

- [ ] **Step 3: Analyze + testler**

Run: `dart analyze && flutter test`
Expected: "No issues found!" ve testler PASS.

- [ ] **Step 4: Görsel doğrulama (manuel)**

Run: `flutter run -d windows` (veya mevcut emülatör). Ana ekran ve quiz ekranında başlıkların aşırı kalın görünmediğini, hiyerarşinin korunduğunu doğrula.

- [ ] **Step 5: Commit**

```bash
git add lib/src/theme/app_theme.dart lib/src/screens/
git commit -m "style: tipografi agirlik olcegini sadelestir (w900 -> w700/w800)"
```

---

### Task 3: Renk rol disiplini — altın yalnız ödül, cyan emekli

`gold` yalnız coin/ödül/streak'te, `cyan` yalnız nadir bilgi vurgusunda kalsın. Mevcut hex değerleri korunur; sadece kullanım yerleri düzeltilir ve roller belgelenir.

**Files:**
- Modify: `lib/src/theme/app_theme.dart:60-94` (palet bloğuna rol doc-comment'leri)
- Modify: cyan/gold rolü dışı kullanan ekranlar (Step 2'de grep ile bulunur)

- [ ] **Step 1: Palet bloğuna rol yorumları ekle**

`app_theme.dart` dark palette bloğunda her renk grubunun üstüne tek satır rol notu ekle (kod davranışı değişmez), örn:

```dart
// Ödül rengi — YALNIZCA coin / ödül / streak göstergelerinde kullan.
static const gold = Color(0xFFFFD23F);

// Bilgi/ipucu vurgusu — nadir kullan (ör. joker ipucu). Genel aksan için kullanma.
static const cyan = Color(0xFF00F0FF);
```

- [ ] **Step 2: Rol-dışı `gold`/`cyan` kullanımlarını tara**

Run: `grep -rn "AppTheme.gold\|AppTheme.cyan\|AppTheme.brown" lib/`
- `AppTheme.cyan` dekoratif aksan olarak kullanılan yerlerde `AppTheme.violet` (ikincil) veya `AppTheme.accent` (primary) ile değiştir; yalnızca joker ipucu/bilgi bağlamında bırak.
- `AppTheme.gold` (ve alias `brown`) coin/ödül/streak dışında kullanılmışsa bağlama uygun primary/secondary'ye çevir.
Her değişiklik tek satır; iş mantığı değişmez.

- [ ] **Step 3: Analyze + testler**

Run: `dart analyze && flutter test`
Expected: "No issues found!" ve testler PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/src/theme/app_theme.dart lib/src/screens/ lib/src/widgets/
git commit -m "style: renk rollerini hizala (altin=odul, cyan=bilgi)"
```

---

### Task 4: Kart dekorasyon tutarlılığı — `AppTheme.cardDecoration`'a indir

Elle yazılmış `BoxDecoration(... borderRadius ... boxShadow ...)` blokları, gradient olmayan standart kartlarda `AppTheme.cardDecoration(context)` ile değiştirilir. (Gradient'li kategori/hero kartları kapsam dışı — onların kendi tasarımı var.)

**Files:**
- Modify: standart (gradient'siz) kart çizen ekranlar — Step 1'de grep ile listelenir (ör. `profile_screen.dart`, `settings_screen.dart`, `review_screen.dart`, `shop_screen.dart`, `widgets/app_panel.dart`)

- [ ] **Step 1: Aday dekorasyonları tara**

Run: `grep -rn "BoxDecoration(" lib/src/screens lib/src/widgets`
Şu kalıba uyanları seç: `color`/`surface` zeminli + `BorderRadius.circular(...)` + `boxShadow` olan, gradient **içermeyen** kartlar. Gradient içerenleri ATLA.

- [ ] **Step 2: Eşleşen dekorasyonları helper ile değiştir**

Her uygun yerde elle yazılmış dekorasyonu şununla değiştir:

```dart
decoration: AppTheme.cardDecoration(context),
```

Farklı köşe yarıçapı gereken iç öğelerde:

```dart
decoration: AppTheme.cardDecoration(context, radius: AppTheme.cardRadiusSmall),
```

İlgili dosyada `import '../theme/app_theme.dart';` yoksa ekle. Kullanılmayan kalan `import`/değişkenleri temizle.

- [ ] **Step 3: Analyze + testler**

Run: `dart analyze && flutter test`
Expected: "No issues found!" ve testler PASS.

- [ ] **Step 4: Görsel doğrulama (manuel)**

Run: `flutter run -d windows`. Profil, ayarlar ve mağaza ekranlarında kartların gölge/kenarlık/yarıçapının tek tip göründüğünü doğrula.

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/ lib/src/widgets/
git commit -m "refactor: standart kartlari AppTheme.cardDecoration'a indir"
```

---

### Task 5: Tıklanabilir kartlara basılma geri bildirimi (`PressableCard`)

Tıklanabilir kartlara hafif `scale 0.97` basılma + ripple ekleyen yeniden kullanılabilir bir sarmalayıcı oluştur ve kategori kartlarına uygula. (Abartılı animasyon yok — sadece polish.)

**Files:**
- Create: `lib/src/widgets/pressable_card.dart`
- Test: `test/pressable_card_test.dart`
- Modify: `lib/src/screens/home/category_grid.dart` (`_CategoryCard`'taki `GestureDetector`'ı sarmala)

- [ ] **Step 1: Failing widget test yaz**

`test/pressable_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/pressable_card.dart';

void main() {
  testWidgets('onTap tetiklenir ve child render olur', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PressableCard(
          onTap: () => tapped = true,
          child: const Text('selam'),
        ),
      ),
    ));

    expect(find.text('selam'), findsOneWidget);
    await tester.tap(find.text('selam'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test test/pressable_card_test.dart`
Expected: FAIL — "Target of URI doesn't exist: '.../pressable_card.dart'"

- [ ] **Step 3: `PressableCard`'ı uygula**

`lib/src/widgets/pressable_card.dart`:

```dart
import 'package:flutter/material.dart';

/// Dokununca hafifçe küçülen (scale 0.97) tıklanabilir kart sarmalayıcı.
class PressableCard extends StatefulWidget {
  const PressableCard({
    required this.child,
    required this.onTap,
    this.borderRadius = 20,
    super.key,
  });

  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  bool _pressed = false;

  void _set(bool v) {
    if (mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
```

- [ ] **Step 4: Testi çalıştır, geçtiğini gör**

Run: `flutter test test/pressable_card_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: `_CategoryCard`'a uygula**

`category_grid.dart`'a `import '../../widgets/pressable_card.dart';` ekle. `_CategoryCard.build` içindeki `GestureDetector(onTap: onTap, child: Container(...))` yapısını `PressableCard(onTap: onTap, borderRadius: AppTheme.cardRadius, child: Container(...))` ile değiştir (içteki `Container` ve altı aynı kalır).

- [ ] **Step 6: Analyze + tüm testler**

Run: `dart analyze && flutter test`
Expected: "No issues found!" ve tüm testler PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/src/widgets/pressable_card.dart test/pressable_card_test.dart lib/src/screens/home/category_grid.dart
git commit -m "feat: tiklanabilir kartlara basilma geri bildirimi (PressableCard)"
```

---

## Tamamlanma Doğrulaması (tüm task'lardan sonra)

- [ ] `dart analyze` → "No issues found!"
- [ ] `flutter test` → tüm testler geçer (önceki sayı korunur/artar)
- [ ] `flutter run -d windows` ile açık ve koyu temada: renk rolleri tutarlı, başlıklar dengeli, kartlar tek tip, kategori kartları dokunulunca tepki veriyor.
