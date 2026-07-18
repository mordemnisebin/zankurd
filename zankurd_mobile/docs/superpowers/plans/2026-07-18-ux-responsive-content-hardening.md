# ZanKurd UX, Responsive ve İçerik Sağlamlaştırma Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ZanKurd'un onaylı koyu tasarımını koruyarak doğrulanmış responsive, akış, metin, erişilebilirlik ve kalite-aracı kusurlarını gidermek.

**Architecture:** Mevcut ekran ve ortak widget'lar yerinde iyileştirilir. Her davranış önce widget/unit test ile kırmızıya düşürülür; ardından en küçük üretim değişikliği yapılır. Yeni paket veya paralel tasarım bileşeni eklenmez.

**Tech Stack:** Flutter, Dart, `flutter_test`, mevcut Provider/tema/widget altyapısı, Flutter web ve Playwright CLI.

## Global Constraints

- Repository/provider/model/servis ve oyun kuralları değişmeyecek.
- Yeni bağımlılık ve geniş refactor yapılmayacak.
- Kurmancî metinler doğal, tutarlı ve doğru özel karakterli olacak.
- Hedef genişlikler: 320, 360, 390, 430, 768, 1024, 1366 ve 1440 px.
- Light/dark, yüzde 200 metin ölçeği, tablet ve landscape korunacak.
- Canlı Supabase'e doğrudan yazılmayacak.
- Her üretim değişikliğinden önce ilgili testin beklenen nedenle başarısız olduğu görülecek.

---

### Task 1: Soru kaynağı keşfini dışlanan dizinlerde güvenli yap

**Files:**
- Modify: `tool/question_quality/src/discovery.dart:14`
- Test: `test/question_quality/source_readers_and_discovery_test.dart:128`

**Interfaces:**
- Consumes: `Directory root`
- Produces: mevcut `List<DiscoveredSource> discoverPotentialQuestionSources(Directory root)` imzasını korur.

- [ ] **Step 1: Recursive kaynak taramasının geri gelmesini engelleyen testi yaz**

```dart
test('discovery filters directories before descending into them', () {
  final source = File('tool/question_quality/src/discovery.dart')
      .readAsStringSync();

  expect(source, isNot(contains('recursive: true')));
  expect(source, contains('_sourceFiles(root, root)'));
});
```

- [ ] **Step 2: Testi çalıştır ve mevcut recursive taramanın davranışı yüzünden başarısız olduğunu doğrula**

Run: `dart test test/question_quality/source_readers_and_discovery_test.dart`

Expected: kaynakta `recursive: true` bulunduğu için FAIL.

- [ ] **Step 3: Recursive `listSync` yerine filtreli dizin yürüyüşü uygula**

```dart
Iterable<File> _sourceFiles(Directory root, Directory current) sync* {
  for (final entity in current.listSync(followLinks: false)) {
    final relative = entity.absolute.path
        .replaceAll('\\', '/')
        .substring(root.absolute.path.replaceAll('\\', '/').length)
        .replaceFirst(RegExp(r'^/+'), '');
    if (_excluded(relative.toLowerCase())) continue;
    if (entity is Directory) {
      yield* _sourceFiles(root, entity);
    } else if (entity is File) {
      yield entity;
    }
  }
}
```

`discoverPotentialQuestionSources` döngüsünü `_sourceFiles(root, root)` üzerinden çalıştır.

- [ ] **Step 4: Hedef testi ve kalite gate'ini çalıştır**

Run: `dart test test/question_quality/source_readers_and_discovery_test.dart`

Run: `dart run tool/question_quality/question_quality_audit.dart gate`

Expected: test PASS; gate geçici `build/` yolu nedeniyle çökmemeli.

---

### Task 2: Küçük ekran responsive köklerini düzelt

**Files:**
- Modify: `lib/src/screens/profile_name_gate_screen.dart:80`
- Modify: `lib/src/screens/profile_screen.dart:250`
- Modify: `lib/src/screens/leaderboard_screen.dart:440`
- Modify: `lib/src/screens/level_screen.dart:50`
- Modify: `lib/src/screens/quiz_result_screen.dart:1020`
- Test: `test/profile_before_after_test.dart`
- Test: `test/leaderboard_result_profile_test.dart`
- Test: `test/result_before_after_test.dart`

**Interfaces:**
- Consumes: mevcut ekran constructor'ları ve repository test doubles.
- Produces: aynı constructor ve navigasyon davranışlarını koruyan responsive widget ağacı.

- [ ] **Step 1: 320/360 profil ve profil adı taşma testlerini yaz**

Her boyut için `tester.view.physicalSize`, `devicePixelRatio = 1` ayarla; ekranı pump et ve şunu doğrula:

```dart
expect(tester.takeException(), isNull);
expect(find.textContaining('OVERFLOWED'), findsNothing);
```

- [ ] **Step 2: Testleri çalıştır ve doğrulanmış overflow nedeniyle başarısız olduklarını gör**

Run: `flutter test test/profile_before_after_test.dart`

Expected: 320 ve 360 senaryolarında FAIL.

- [ ] **Step 3: Profil gridini sabit aspect ratio yerine içeriğe uygun extent ile düzelt**

```dart
gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: constraints.maxWidth > 600 ? 4 : 2,
  mainAxisSpacing: 10,
  crossAxisSpacing: 10,
  mainAxisExtent: MediaQuery.textScalerOf(context).scale(82),
),
```

`_StatTile` içinde gereksiz `mainAxisSize.min` kullanma; değer ve etiket tek satır kalır.

- [ ] **Step 4: Profil adı ekranını tek kaydırılabilir akışta güvenli minimumlara taşı**

Dar/yatay ekranda hero içeriğini ve formu `CustomScrollView`/mevcut `SingleChildScrollView` ile erişilebilir tut; hero yüksekliğini sabit flex toplamına bağlama. Klavye inset'ini `MediaQuery.viewInsetsOf(context).bottom` ile alt padding'e ekle.

- [ ] **Step 5: Liderlik 320 testini yaz ve kırmızıya düşür**

```dart
expect(find.text('6560'), findsOneWidget);
expect(tester.takeException(), isNull);
```

Run: `flutter test test/leaderboard_result_profile_test.dart`

Expected: podyum puanı/sekme genişliği testi FAIL.

- [ ] **Step 6: Liderlik sekme ve podyumunu dar genişliğe uyarla**

Sekmelerde 320 px için kısa Kurmancî/Türkçe etiketleri kullan; puan kapsülündeki metni `FittedBox(fit: BoxFit.scaleDown)` ile tek satırda tut ve slot yatay padding'ini dar genişlikte azalt.

- [ ] **Step 7: Sonuç overflow testini yeniden etkinleştir ve kırmızıya düşür**

`skip: true` kaldır; 320x568 ve 200% text scale senaryolarını ekle.

Run: `flutter test test/result_before_after_test.dart`

Expected: mevcut ekran FAIL.

- [ ] **Step 8: Sonuç eylemlerini dikey ve kaydırılabilir hiyerarşiye geçir**

Birincil ve ikincil eylemleri tam genişlikte tut; tersiyer menüyü tek ikon düğmesine taşı. Alt içerik safe-area ve keyboard inset içinde kalmalı.

- [ ] **Step 9: Seviye hero yüksekliğini responsive azalt**

`height: 200 + topInset` yerine dar ekranda yaklaşık `148 + topInset`, geniş ekranda en fazla `176 + topInset` kullan; mevcut içerik ve Hero etiketi korunur.

- [ ] **Step 10: Tüm hedef responsive testleri çalıştır**

Run: `flutter test test/profile_before_after_test.dart test/leaderboard_result_profile_test.dart test/result_before_after_test.dart`

Expected: PASS, overflow exception yok.

---

### Task 3: Eylem hiyerarşisini ve ilk kullanım akışını sadeleştir

**Files:**
- Modify: `lib/src/screens/quiz_result_screen.dart:1020`
- Modify: `lib/src/widgets/quiz_tutorial_overlay.dart:109`
- Modify: `lib/src/screens/onboarding_screen.dart:276`
- Modify: `lib/src/screens/categories_tab.dart:19`
- Test: `test/quiz_result_visual_test.dart`
- Test: `test/auth_onboarding_test.dart`
- Test: `test/onboarding_hierarchy_test.dart`
- Test: `test/kulturel_modern_home_test.dart`

**Interfaces:**
- Quiz sonucu mevcut navigasyon callback'lerini korur.
- Tutorial saklama/bitirme davranışını korur, yalnız adım sayısı değişir.

- [ ] **Step 1: Sonuç ekranında yalnız bir dolu ana buton ve bir inceleme butonu bekleyen testi yaz**

```dart
expect(find.byKey(const ValueKey('result-play-again-button')), findsOneWidget);
expect(find.byKey(const ValueKey('result-review-button')), findsOneWidget);
expect(find.byKey(const ValueKey('result-more-button')), findsOneWidget);
expect(find.byKey(const ValueKey('result-share-button')), findsNothing);
expect(find.byKey(const ValueKey('result-rate-button')), findsNothing);
```

Run: `flutter test test/quiz_result_visual_test.dart`

Expected: `result-more-button` bulunmadığı için FAIL.

- [ ] **Step 2: Paylaş/değerlendir/liderlik eylemlerini `PopupMenuButton` içine taşı**

Mevcut callback'leri silme; `PopupMenuButton<_ResultMoreAction>` seçiminde aynı callback'leri çağır. Yanlışları inceleme ikincil buton, ana sayfa tek metin bağlantısı olur.

- [ ] **Step 3: Quiz öğretiminin iki adımdan oluşmasını bekleyen testi yaz**

Timer + cevap alanı adımları kalır; combo, joker ve sonraki soru bilgileri bağlamsal UI'da zaten görünür olduğu için turdan çıkar.

Run: `flutter test test/auth_onboarding_test.dart`

Expected: mevcut 5 adım nedeniyle FAIL.

- [ ] **Step 4: Tutorial listesini iki adıma indir ve metni doğal Kurmancî yap**

İlk açıklama: `Di 15 çirkeyan de bersiva xwe hilbijêre.`

İkinci açıklama: `Bersiva rast hilbijêre û pûan qezenc bike.`

- [ ] **Step 5: Onboarding içeriğinin temel değer önerisine odaklandığını test et**

İlk üç sayfada öğrenme, quiz ve günlük alışkanlık kalır; joker/oda/turnuva ayrıntıları bulunmaz.

Run: `flutter test test/onboarding_hierarchy_test.dart`

Expected: eski dördüncü sayfa ayrıntıları nedeniyle FAIL.

- [ ] **Step 6: Dördüncü sayfayı basit başlangıç sayfasına çevir**

Yeni başlık `Dest pê bike / Hemen başla`; üç madde kategori seç, kısa quiz çöz, açıklamadan öğren akışını anlatır.

- [ ] **Step 7: Yakında kategorilerini sona atan testi yaz ve uygula**

`_orderedCategories` getter'ı mevcut `_questionCounts` değerine göre `count < 20` olanları stabil biçimde sona taşır; kart indeksleri ve görsel renk eşlemesi kategori kimliğinden gelmeye devam eder.

- [ ] **Step 8: İlgili akış testlerini çalıştır**

Run: `flutter test test/quiz_result_visual_test.dart test/auth_onboarding_test.dart test/onboarding_hierarchy_test.dart test/kulturel_modern_home_test.dart`

Expected: PASS.

---

### Task 4: Kurmancî metin ve terminolojiyi düzelt

**Files:**
- Modify: `lib/src/screens/home_screen.dart:541`
- Modify: `lib/src/screens/app_shell.dart:138`
- Modify: `lib/src/screens/profile_name_gate_screen.dart:150`
- Modify: `lib/src/screens/subcategory_screen.dart:241`
- Modify: `lib/src/models/quiz_question.dart:95`
- Modify: `lib/src/screens/friends_screen.dart:478`
- Modify: `lib/src/screens/leaderboard_screen.dart:889`
- Modify: `lib/src/widgets/quiz_tutorial_overlay.dart:109`
- Test: `test/l10n_copy_consistency_test.dart`

**Interfaces:**
- Kullanıcıya görünen metinler değişir; iş mantığı ve saklanan kategori/oda kimlikleri değişmez.

- [ ] **Step 1: Bozuk ve Türkçe kalan sabitleri yasaklayan kaynak testini yaz**

Test ilgili dosyaları okuyup şu değerlerin bulunmadığını doğrular:

```dart
const forbidden = [
  'Amadeyî yanga nû?',
  'Pêşbirktî',
  'Lîstikê û serlêderên bibike',
  '15 saniyede bersivê bide',
  "isKu ? 'Entık'",
  "ku ? 'Çevrimiçi'",
  'Barekî hilbijêre',
];
```

Run: `dart test test/l10n_copy_consistency_test.dart`

Expected: FAIL.

- [ ] **Step 2: Görünür metinleri doğrulanmış sade karşılıklarla değiştir**

- `Amadeyî pêşbirka nû yî?`
- `Hemû pêşbirk û lîstikên te li vir in.`
- `Bilîze û xelatan bistîne.`
- `Di 15 çirkeyan de bersiva xwe hilbijêre.`
- Görsel soru tipi: `Wêneyî`
- Çevrimiçi: `Serhêl`
- Alt kategori: `Beşekî hilbijêre û dest bi lîstinê bike.`

- [ ] **Step 3: Quiz doğru/yanlış semantiğini tekleştir**

Kurmancî: `bersiva rast` / `bersiva şaş`; Türkçe: `doğru cevap` / `yanlış cevap`.

- [ ] **Step 4: Demo adlarını doğal örneklerle değiştir**

`Baweroooo`, `Ranakêêê` gibi adları `Bawer`, `Ronahî` gibi kısa örneklere çevir; kullanıcı verisine dokunma.

- [ ] **Step 5: Metin ve ilgili widget testlerini çalıştır**

Run: `dart test test/l10n_copy_consistency_test.dart`

Run: `flutter test test/kulturel_modern_home_test.dart test/leaderboard_result_profile_test.dart`

Expected: PASS.

---

### Task 5: Erişilebilirlik ve dokunma alanlarını tamamla

**Files:**
- Modify: `lib/src/screens/quiz_screen.dart:670`
- Modify: `lib/src/widgets/styled_input.dart:155`
- Modify: `lib/src/screens/categories_tab.dart:100`
- Modify: `test/accessibility_guideline_test.dart:35`
- Test: `test/accessibility_guideline_test.dart`

**Interfaces:**
- Mevcut `onPressed` callback'leri korunur.
- Suffix icon için mevcut `onSuffixIconPressed` imzası korunur.

- [ ] **Step 1: Quiz ikonlarının yerelleştirilmiş tooltip ve semantics taşımasını test et**

```dart
expect(find.byTooltip('Pirsê hilîne'), findsOneWidget);
expect(find.byTooltip('Pirsê ragihîne'), findsOneWidget);
```

Run: `flutter test test/accessibility_guideline_test.dart`

Expected: FAIL.

- [ ] **Step 2: Quiz ve geri ikonlarına yerelleştirilmiş tooltip ekle**

Favori: `Pirsê hilîne / Soruyu kaydet`; rapor: `Pirsê ragihîne / Soruyu bildir`; özel geri ikonlarında `Vegere / Geri`.

- [ ] **Step 3: `StyledInput` suffix alanını 44x44 `IconButton` yap**

```dart
IconButton(
  constraints: const BoxConstraints.tightFor(width: 44, height: 44),
  padding: EdgeInsets.zero,
  tooltip: widget.suffixTooltip,
  onPressed: widget.onSuffixIconPressed,
  icon: Icon(widget.suffixIcon, size: 18),
)
```

Yeni `suffixTooltip` yalnız bu mevcut widget'ın erişilebilir adı için nullable parametre olur; tek kullanımlık yeni widget eklenmez.

- [ ] **Step 4: Kontrast ve 200% metin ölçeği kapılarını aç**

`textContrastGuideline` yorumunu kaldır. Home, profil, quiz sonucu ve seviye ekranında `textScaler: const TextScaler.linear(2)` ile tap target/label/overflow denetimleri ekle.

- [ ] **Step 5: Erişilebilirlik testlerini çalıştır**

Run: `flutter test test/accessibility_guideline_test.dart`

Expected: PASS.

---

### Task 6: Kategori hata durumuna çözüm eylemi ekle

**Files:**
- Modify: `lib/src/screens/categories_tab.dart:33`
- Test: `test/kulturel_modern_home_test.dart`

**Interfaces:**
- Mevcut `AppErrorState`, `AppEmptyState` ve `BrandedLoader` kullanılır.

- [ ] **Step 1: Kategori yükleme hatasında yeniden deneme eylemi bekleyen testi yaz**

Repository `loadCategories` hata verdiğinde `Dîsa biceribîne / Tekrar dene` düğmesi görünmeli ve `_load` çağrısını yeniden başlatmalı.

- [ ] **Step 2: SnackBar-only kategori hatasını mevcut `AppErrorState` ile değiştir**

State içinde kısa bir hata bayrağı tut; başarılı yeniden yüklemede temizle. Yeni hata framework'ü ekleme.

- [ ] **Step 3: Hedef testi çalıştır**

Run: `flutter test test/kulturel_modern_home_test.dart`

Expected: PASS.

---

### Task 7: Tam doğrulama ve gerçek ekran denetimi

**Files:**
- Modify: yalnız doğrulamada bulunan gerçek regresyonların ilgili dosyaları
- Artifacts: `output/playwright/`

**Interfaces:**
- Üretim davranışında yeni kapsam yok; yalnız plan başarı ölçütleri doğrulanır.

- [ ] **Step 1: Format ve statik analiz**

Run: `dart format --output=none --set-exit-if-changed lib test tool/question_quality`

Run: `dart analyze`

Expected: exit 0, hata ve uyarı yok.

- [ ] **Step 2: Hedef testler**

Run: `flutter test test/question_quality/source_readers_and_discovery_test.dart test/profile_before_after_test.dart test/leaderboard_result_profile_test.dart test/result_before_after_test.dart test/quiz_result_visual_test.dart test/auth_onboarding_test.dart test/onboarding_hierarchy_test.dart test/accessibility_guideline_test.dart test/l10n_copy_consistency_test.dart`

Expected: tümü PASS.

- [ ] **Step 3: Tam test paketi**

Run: `flutter test`

Expected: sıfır başarısız test.

- [ ] **Step 4: Web build ve yerel sunucu**

Run: `flutter build web --release`

Run: `flutter run -d web-server --web-hostname 127.0.0.1 --web-port 53180`

Expected: build exit 0; yerel uygulama açılır.

- [ ] **Step 5: Playwright ile ekran matrisi**

Home, kategori, alt kategori, seviye, quiz, sonuç, liderlik, profil, profil adı ve ayarları 320, 360, 390, 430, 768, 1024, 1366 ve 1440 px'de kontrol et. Kritik ekranları light/dark ve 844x390 landscape'de tekrar kontrol et.

Expected: overflow şeridi, yatay kaydırma, kesik ana buton, iki satıra kırılmış puan veya erişilemeyen geri yolu yok.

- [ ] **Step 6: Gerekiyorsa yalnız bulunan kök regresyonu test-first düzelt ve doğrulamayı tekrarla**

Yeni özellik ekleme; bulunan sorunun tüm çağrılarını kontrol edip paylaşılan kökte en küçük düzeltmeyi yap.
