# Sprint 1: Ses, Haptic, Shimmer & Kişiselleştirme — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SoundProvider (5 ses efekti + SharedPreferences persist), haptic feedback, shimmer skeleton loading ve kişiselleştirilmiş home karşılaması ekle.

**Architecture:** Yeni `SoundProvider` ChangeNotifier oluşturulur, `main.dart`'taki `MultiProvider`'a dahil edilir. `audioplayers` ile ses çalma, `shimmer` paketiyle `SkeletonLoader` yenilenir. `HomeScreen`, profil adını `AppShell`'den `displayName` parametresiyle alır. Hiçbir mevcut API değişmez.

**Tech Stack:** `audioplayers ^6.1.0`, `shimmer ^3.0.0`, Flutter `HapticFeedback` (built-in, `flutter/services.dart`), Provider 6.1.0

---

## Dosya Haritası

**Oluşturulacak:**
- `lib/src/providers/sound_provider.dart` — SoundProvider ChangeNotifier
- `test/sound_provider_test.dart` — 5 birim testi
- `assets/sounds/correct.mp3` — manuel indirme (aşağıya bak)
- `assets/sounds/wrong.mp3` — manuel indirme
- `assets/sounds/win.mp3` — manuel indirme
- `assets/sounds/coin.mp3` — manuel indirme
- `assets/sounds/wildcard.mp3` — manuel indirme

**Değiştirilecek:**
- `pubspec.yaml` — 6 yeni paket + `assets/sounds/` + `assets/animations/`
- `lib/main.dart` — `SoundProvider.load()` + `MultiProvider`'a ekleme + `ZanKurdApp` parametresi
- `lib/src/providers/sound_provider.dart` — sync default ctor (Task 3'te güncelleme)
- `lib/src/screens/quiz_screen.dart` — haptic + ses çağrıları
- `lib/src/widgets/skeleton_loader.dart` — shimmer paketi ile yeniden yaz + `SkeletonLine` ekle
- `lib/src/screens/settings_screen.dart` — ses toggle `AppPanel`
- `lib/src/screens/app_shell.dart` — `_profileName` → `HomeScreen.displayName`
- `lib/src/screens/home_screen.dart` — `displayName` parametresi + karşılama metni

---

## Task 1: Paketleri ve Ses Asset'lerini Ekle

**Dosyalar:**
- Değiştir: `zankurd_mobile/pubspec.yaml`

- [ ] **Adım 1: pubspec.yaml'a paket bağımlılıklarını ekle**

`zankurd_mobile/pubspec.yaml` dosyasını aç. `provider: ^6.1.0` satırından sonraya şunları ekle:

```yaml
  # Ses efektleri
  audioplayers: ^6.1.0

  # Shimmer skeleton loading
  shimmer: ^3.0.0

  # Lottie animasyonları (Sprint 4'te kullanılacak)
  lottie: ^3.1.2

  # Paylaşım (Sprint 5'te kullanılacak)
  share_plus: ^10.0.3

  # Mağaza değerlendirmesi (Sprint 5'te kullanılacak)
  in_app_review: ^2.0.9

  # Bağlantı durumu (Sprint 6'da kullanılacak)
  connectivity_plus: ^6.1.0
```

- [ ] **Adım 2: pubspec.yaml'a ses ve animasyon asset klasörlerini ekle**

`flutter:` → `assets:` listesinin sonuna ekle:

```yaml
    - assets/sounds/
    - assets/animations/
```

Tam `assets:` bloğu şöyle görünmeli:

```yaml
  assets:
    - assets/question_images/
    - assets/zankurd.png
    - assets/sounds/
    - assets/animations/
```

- [ ] **Adım 3: Asset klasörlerini oluştur**

`zankurd_mobile/` klasöründen PowerShell'de:

```powershell
New-Item -ItemType Directory -Force -Path assets/sounds, assets/animations
```

- [ ] **Adım 4: Ses dosyalarını indir**

`https://mixkit.co/free-sound-effects/` adresine git, ücretsiz (CC0) kısa MP3 dosyaları indir ve `zankurd_mobile/assets/sounds/` klasörüne şu isimlerle kaydet:

| Dosya adı | Arama terimi | Hedef süre |
|---|---|---|
| `correct.mp3` | "correct answer tone" | ~0.5 saniye |
| `wrong.mp3` | "wrong buzzer" | ~0.5 saniye |
| `win.mp3` | "success fanfare" | ~1.5 saniye |
| `coin.mp3` | "coin pickup" | ~0.4 saniye |
| `wildcard.mp3` | "magic sparkle" | ~0.6 saniye |

**Alternatif:** `https://freesound.org/` (CC0 lisans filtresi uygula).

- [ ] **Adım 5: Paketleri yükle**

```powershell
cd zankurd_mobile
flutter pub get
```

Beklenen çıktı:
```
Resolving dependencies...
Got dependencies!
```

- [ ] **Adım 6: Statik analiz**

```powershell
dart analyze
```

Beklenen: `No issues found!`

- [ ] **Adım 7: Commit**

```powershell
git add pubspec.yaml pubspec.lock assets/sounds/ assets/animations/
git commit -m "chore(deps): audioplayers, shimmer, lottie, share_plus, in_app_review, connectivity_plus"
```

---

## Task 2: SoundProvider — Test ve Implementasyon

**Dosyalar:**
- Oluştur: `zankurd_mobile/lib/src/providers/sound_provider.dart`
- Oluştur: `zankurd_mobile/test/sound_provider_test.dart`

- [ ] **Adım 1: Başarısız testleri yaz**

`zankurd_mobile/test/sound_provider_test.dart` dosyasını oluştur:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SoundProvider', () {
    test('varsayılan olarak ses açık', () async {
      final provider = await SoundProvider.load();
      expect(provider.enabled, isTrue);
    });

    test('toggle() sesi kapatır', () async {
      final provider = await SoundProvider.load();
      provider.toggle();
      expect(provider.enabled, isFalse);
    });

    test('iki kez toggle() sonra ses açık', () async {
      final provider = await SoundProvider.load();
      provider.toggle();
      provider.toggle();
      expect(provider.enabled, isTrue);
    });

    test('toggle() SharedPreferences\'e false yazar', () async {
      final provider = await SoundProvider.load();
      provider.toggle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('zankurd.sound.enabled'), isFalse);
    });

    test('load() SharedPreferences\'ten false okur', () async {
      SharedPreferences.setMockInitialValues({'zankurd.sound.enabled': false});
      final provider = await SoundProvider.load();
      expect(provider.enabled, isFalse);
    });
  });
}
```

- [ ] **Adım 2: Testin başarısız olduğunu doğrula**

```powershell
flutter test test/sound_provider_test.dart
```

Beklenen: Import hatası (dosya henüz yok).

- [ ] **Adım 3: SoundProvider implementasyonunu yaz**

`zankurd_mobile/lib/src/providers/sound_provider.dart` dosyasını oluştur:

```dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundProvider extends ChangeNotifier {
  // Sync default constructor — MultiProvider fallback ve testler için.
  SoundProvider() : _enabled = true, _player = AudioPlayer();

  SoundProvider._({required bool enabled, AudioPlayer? player})
    : _enabled = enabled,
      _player = player ?? AudioPlayer();

  static const _enabledKey = 'zankurd.sound.enabled';

  final AudioPlayer _player;
  bool _enabled;

  bool get enabled => _enabled;

  /// SharedPreferences'ten önceki ayarı okuyarak başlatır.
  static Future<SoundProvider> load({AudioPlayer? player}) async {
    final prefs = await SharedPreferences.getInstance();
    return SoundProvider._(
      enabled: prefs.getBool(_enabledKey) ?? true,
      player: player,
    );
  }

  /// Ses ayarını tersine çevirir ve kalıcı olarak kaydeder.
  void toggle() {
    _enabled = !_enabled;
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool(_enabledKey, _enabled),
    );
    notifyListeners();
  }

  Future<void> playCorrect() => _play('sounds/correct.mp3');
  Future<void> playWrong() => _play('sounds/wrong.mp3');
  Future<void> playWin() => _play('sounds/win.mp3');
  Future<void> playCoin() => _play('sounds/coin.mp3');
  Future<void> playWildcard() => _play('sounds/wildcard.mp3');

  Future<void> _play(String asset) async {
    if (!_enabled) return;
    try {
      await _player.play(AssetSource(asset));
    } catch (_) {
      // Platform ses desteği yoksa veya dosya eksikse sessizce geç.
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
```

- [ ] **Adım 4: Testlerin geçtiğini doğrula**

```powershell
flutter test test/sound_provider_test.dart
```

Beklenen:
```
00:00 +5: All tests passed!
```

- [ ] **Adım 5: Tüm testleri çalıştır**

```powershell
flutter test
```

Beklenen: Önceki tüm testler + 5 yeni SoundProvider testi, hepsi yeşil.

- [ ] **Adım 6: Commit**

```powershell
git add lib/src/providers/sound_provider.dart test/sound_provider_test.dart
git commit -m "feat(sound): SoundProvider — toggle, SharedPreferences persist, 5 ses metodu"
```

---

## Task 3: SoundProvider'ı main.dart'a Bağla

**Dosyalar:**
- Değiştir: `zankurd_mobile/lib/main.dart`

- [ ] **Adım 1: Import ekle**

`lib/main.dart` import listesine (diğer provider importlarının yanına):

```dart
import 'src/providers/sound_provider.dart';
```

- [ ] **Adım 2: main() içinde SoundProvider'ı yükle**

`lib/main.dart`'ta şu satırın hemen ardına:
```dart
  final themeProvider = await ThemeProvider.load();
```

Şunu ekle:
```dart
  final soundProvider = await SoundProvider.load();
```

- [ ] **Adım 3: ZanKurdApp'a soundProvider parametresi ekle**

`ZanKurdApp` class tanımını güncelle:

```dart
class ZanKurdApp extends StatelessWidget {
  const ZanKurdApp({
    required this.repository,
    this.authProvider,
    this.languageProvider,
    this.themeProvider,
    this.soundProvider,
    super.key,
  });

  final ZanKurdRepository repository;
  final AuthProvider? authProvider;
  final LanguageProvider? languageProvider;
  final ThemeProvider? themeProvider;
  final SoundProvider? soundProvider;
```

- [ ] **Adım 4: runApp çağrısını güncelle**

`main()` içindeki `runApp(ZanKurdApp(...))` çağrısına `soundProvider:` ekle:

```dart
  runApp(
    ZanKurdApp(
      repository: repository,
      authProvider: authProvider,
      languageProvider: languageProvider,
      themeProvider: themeProvider,
      soundProvider: soundProvider,
    ),
  );
```

- [ ] **Adım 5: MultiProvider'a SoundProvider ekle**

`ZanKurdApp.build()` içindeki `MultiProvider` providers listesine en sona ekle:

```dart
        ChangeNotifierProvider(
          create: (_) => soundProvider ?? SoundProvider(),
        ),
```

- [ ] **Adım 6: Analiz ve testler**

```powershell
dart analyze
flutter test
```

Beklenen: sıfır hata, tüm testler yeşil.

- [ ] **Adım 7: Commit**

```powershell
git add lib/main.dart
git commit -m "feat(sound): SoundProvider MultiProvider'a eklendi"
```

---

## Task 4: Quiz Ekranına Haptic Feedback Ekle

**Dosyalar:**
- Değiştir: `zankurd_mobile/lib/src/screens/quiz_screen.dart`

`flutter/services.dart` zaten import edilmiş — ek import gerekmez.

- [ ] **Adım 1: Cevap seçim noktasını bul**

```powershell
Select-String -Path "lib/src/screens/quiz_screen.dart" -Pattern "selectedAnswer\s*=" -n
```

Bu, `selectedAnswer`'ın atandığı `setState` satırını gösterir. Genellikle şu şekilde görünür:

```dart
setState(() => selectedAnswer = answer);
// veya
setState(() {
  selectedAnswer = answer;
  ...
});
```

- [ ] **Adım 2: Doğruluk kontrolünü bul**

```powershell
Select-String -Path "lib/src/screens/quiz_screen.dart" -Pattern "correctAnswer|correct_answer|isCorrect" -n
```

Doğru/yanlış dallarını içeren `if` bloğunu bul.

- [ ] **Adım 3: Haptic ekle**

Doğru cevap dalına (örn. `if (answer == question.correctAnswer)` içine):

```dart
HapticFeedback.lightImpact();
```

Yanlış cevap dalına:

```dart
HapticFeedback.heavyImpact();
```

- [ ] **Adım 4: Analiz**

```powershell
dart analyze
```

Beklenen: `No issues found!`

- [ ] **Adım 5: Commit**

```powershell
git add lib/src/screens/quiz_screen.dart
git commit -m "feat(quiz): haptic feedback — light=doğru, heavy=yanlış"
```

---

## Task 5: Quiz Ekranına Ses Efektleri Ekle

**Dosyalar:**
- Değiştir: `zankurd_mobile/lib/src/screens/quiz_screen.dart`

- [ ] **Adım 1: Import ekle**

`quiz_screen.dart` import listesine:

```dart
import 'package:provider/provider.dart';
import '../providers/sound_provider.dart';
```

- [ ] **Adım 2: Doğru cevap sesini ekle**

Haptic `lightImpact()` satırının hemen ardına:

```dart
context.read<SoundProvider>().playCorrect();
```

- [ ] **Adım 3: Yanlış cevap sesini ekle**

Haptic `heavyImpact()` satırının hemen ardına:

```dart
context.read<SoundProvider>().playWrong();
```

- [ ] **Adım 4: Joker sesi için aktivasyon noktasını bul**

```powershell
Select-String -Path "lib/src/screens/quiz_screen.dart" -Pattern "_wildcard\s*=" -n
```

`_wildcard = _wildcard.with...` veya benzeri joker state değişiminin yapıldığı `setState` bloğunda:

```dart
context.read<SoundProvider>().playWildcard();
```

- [ ] **Adım 5: Quiz bitiş sesini ekle**

```powershell
Select-String -Path "lib/src/screens/quiz_screen.dart" -Pattern "QuizResultScreen|push.*Result|_finish|_complete" -n
```

`Navigator.push` ile `QuizResultScreen`'e geçişten önce:

```dart
context.read<SoundProvider>().playWin();
```

- [ ] **Adım 6: Analiz**

```powershell
dart analyze
```

Beklenen: `No issues found!`

- [ ] **Adım 7: Commit**

```powershell
git add lib/src/screens/quiz_screen.dart
git commit -m "feat(quiz): ses efektleri — doğru/yanlış/joker/bitiş"
```

---

## Task 6: Ayarlar Ekranına Ses Toggle Ekle

**Dosyalar:**
- Değiştir: `zankurd_mobile/lib/src/screens/settings_screen.dart`

- [ ] **Adım 1: Import ekle**

`settings_screen.dart` import listesine:

```dart
import '../providers/sound_provider.dart';
```

- [ ] **Adım 2: Dil AppPanel'ini bul**

`_SettingsScreenState.build()` içinde dil paneli (`Icons.language`) ile başlayan `AppPanel` bloğunu bul. Kapanış parantezinden sonra `const SizedBox(height: 14),` satırı gelir.

- [ ] **Adım 3: Ses toggle panelini ekle**

Dil panelinin `const SizedBox(height: 14),` satırından SONRA şunu ekle:

```dart
              Consumer<SoundProvider>(
                builder: (context, sound, _) => AppPanel(
                  child: Row(
                    children: [
                      Icon(
                        sound.enabled
                            ? Icons.volume_up_outlined
                            : Icons.volume_off_outlined,
                        color: AppTheme.accent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          ku ? 'Deng û mûzîk' : 'Ses efektleri',
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Switch(
                        value: sound.enabled,
                        onChanged: (_) => sound.toggle(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
```

- [ ] **Adım 4: Analiz**

```powershell
dart analyze
```

Beklenen: `No issues found!`

- [ ] **Adım 5: Commit**

```powershell
git add lib/src/screens/settings_screen.dart
git commit -m "feat(settings): ses efektleri aç/kapat toggle"
```

---

## Task 7: SkeletonLoader'ı shimmer Paketiyle Güncelle

**Dosyalar:**
- Değiştir: `zankurd_mobile/lib/src/widgets/skeleton_loader.dart`

- [ ] **Adım 1: skeleton_loader.dart'ı tamamen değiştir**

`lib/src/widgets/skeleton_loader.dart` dosyasının tüm içeriğini şununla değiştir:

```dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

/// Tam genişlikte yükleniyor kartları için shimmer liste.
class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    this.count = 3,
    this.height = 80,
    this.borderRadius = 12,
    super.key,
  });

  final int count;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? AppTheme.surfaceHi : const Color(0xFFE0E0E0);
    final highlightColor =
        isDark ? const Color(0xFF3A3A50) : const Color(0xFFF5F5F5);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tek satır metin için shimmer placeholder.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
    super.key,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? AppTheme.surfaceHi : const Color(0xFFE0E0E0);
    final highlightColor =
        isDark ? const Color(0xFF3A3A50) : const Color(0xFFF5F5F5);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
```

- [ ] **Adım 2: Analiz ve testler**

```powershell
dart analyze
flutter test
```

Beklenen: `No issues found!`, tüm testler yeşil.

- [ ] **Adım 3: Commit**

```powershell
git add lib/src/widgets/skeleton_loader.dart
git commit -m "feat(ui): SkeletonLoader shimmer paketiyle yenilendi, SkeletonLine eklendi"
```

---

## Task 8: HomeScreen Kişiselleştirilmiş Karşılama

**Dosyalar:**
- Değiştir: `zankurd_mobile/lib/src/screens/home_screen.dart`
- Değiştir: `zankurd_mobile/lib/src/screens/app_shell.dart`

- [ ] **Adım 1: HomeScreen'e displayName parametresi ekle**

`lib/src/screens/home_screen.dart`'ta `HomeScreen` StatefulWidget'ı güncelle:

```dart
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.repository,
    this.displayName,
    super.key,
  });

  final ZanKurdRepository repository;
  final String? displayName;
```

- [ ] **Adım 2: _buildGeometricHeader'da karşılama metnini güncelle**

`home_screen.dart`'ta `_buildGeometricHeader` metodunu bul. İçindeki şu metni:

```dart
ku ? 'Salam, Lîstikvan!' : 'Hoş geldin, Oyuncu!'
```

Şununla değiştir:

```dart
ku
    ? 'Salam, ${widget.displayName ?? 'Lîstikvan'}!'
    : 'Hoş geldin, ${widget.displayName ?? 'Oyuncu'}!'
```

- [ ] **Adım 3: AppShell'de HomeScreen'e displayName geçir**

`lib/src/screens/app_shell.dart`'ta `IndexedStack` children'ındaki `HomeScreen` satırını güncelle:

```dart
          HomeScreen(
            repository: widget.repository,
            displayName: _profileName,
          ),
```

`_profileName` zaten `_AppShellState`'de `String? _profileName` olarak tanımlı.

- [ ] **Adım 4: Analiz ve testler**

```powershell
dart analyze
flutter test
```

Beklenen: `No issues found!`, tüm testler yeşil.

- [ ] **Adım 5: Commit**

```powershell
git add lib/src/screens/home_screen.dart lib/src/screens/app_shell.dart
git commit -m "feat(home): kişiselleştirilmiş karşılama — profil adı göster"
```

---

## Task 9: Sprint 1 Son Doğrulama

- [ ] **Adım 1: Tüm testleri çalıştır**

```powershell
flutter test
```

Beklenen: Önceki 135+ test + 5 yeni SoundProvider testi = hepsi yeşil.

- [ ] **Adım 2: Statik analiz**

```powershell
dart analyze
```

Beklenen: `No issues found!`

- [ ] **Adım 3: Manuel test kontrol listesi**

Emülatörde (`flutter run -d emulator-5554`) veya fiziksel cihazda:

```
Ses:
- [ ] Quiz'de doğru cevap → kısa tını çalıyor
- [ ] Quiz'de yanlış cevap → farklı ses çalıyor
- [ ] Joker kullanınca ses çalıyor
- [ ] Quiz bitince kazanma sesi çalıyor
- [ ] Ayarlar → "Ses efektleri" switch'i görünüyor
- [ ] Switch'i kapat → quiz'de hiç ses çıkmıyor
- [ ] Uygulamayı kapat-aç → ses ayarı hatırlanıyor

Haptic:
- [ ] Doğru cevap → hafif vibrasyon hissediliyor
- [ ] Yanlış cevap → daha güçlü vibrasyon hissediliyor

Shimmer:
- [ ] Leaderboard yüklenirken shimmer animasyonu akıyor
- [ ] Dark modda shimmer koyu renk, light modda açık renk

Kişiselleştirme:
- [ ] Home ekranı başlığında "Salam, [kullanıcı adın]!" görünüyor
- [ ] Profil adı yokken "Salam, Lîstikvan!" görünüyor
```

- [ ] **Adım 4: Sprint tag'i**

```powershell
git tag sprint-1-complete
```

---

## Öz İnceleme — Spec Karşılaştırması

| Spec Maddesi | Plan'daki Kapsam |
|---|---|
| `audioplayers` paketi ekleme | Task 1 |
| `shimmer` paketi ekleme | Task 1 |
| `lottie`, `share_plus`, `in_app_review`, `connectivity_plus` pubspec'e ekleme | Task 1 (impl sonraki sprintler) |
| `SoundProvider` ChangeNotifier | Task 2 |
| Ses dosyaları + asset tanımı | Task 1 (indirme talimatı) |
| `main.dart` MultiProvider entegrasyonu | Task 3 |
| Quiz haptic feedback | Task 4 |
| Quiz ses efektleri (5 nokta) | Task 5 |
| Settings ses toggle | Task 6 |
| `shimmer` paketiyle SkeletonLoader yenileme + `SkeletonLine` | Task 7 |
| Kişiselleştirilmiş karşılama | Task 8 |

**Placeholder taraması:** TBD/TODO/implement yok. Her adımda gerçek kod mevcut.

**Tip tutarlılığı:**
- `SoundProvider.load()` → `Future<SoundProvider>` (Task 2 → Task 3 tutarlı)
- `SoundProvider()` sync ctor Task 2'de tanımlandı, Task 3'te `create: (_) => soundProvider ?? SoundProvider()` kullanıldı
- `displayName: String?` Task 8'de HomeScreen'e eklendi, AppShell'de `_profileName` (aynı tip) geçildi

---

## Sonraki Sprint

**Sprint 2:** Günlük Görev Sistemi — `DailyMissionStore`, `DailyMission` modeli, `DailyMissionsCard` widget, görev ilerleme takibi, coin ödülü.

Plan: `docs/superpowers/plans/2026-XX-XX-sprint-2-gunluk-gorevler.md` (Sprint 2 başında yazılacak)
