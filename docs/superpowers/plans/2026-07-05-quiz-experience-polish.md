# Quiz Deneyimi Cilası ("TV Şovu Hissi") Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Quiz ekranına gerilim–patlama–ödül ritmi katmak: kritik-süre vinyeti, cevap öncesi gerilim tutuşu, yanlışta sarsıntı+flaş, her doğruda mini konfeti, ×N combo rozeti ve puan uçuşu — oyun kurallarına dokunmadan.

**Architecture:** Tüm yeni efektler `lib/src/screens/quiz/quiz_effects.dart` içinde bağımsız widget/saf-fonksiyon olarak yaşar; `quiz_screen.dart` ve `quiz_widgets.dart` bunları ince entegrasyon noktalarından çağırır. Mevcut `ConfettiOverlay` parametrikleştirilerek (parçacık sayısı/süre) hem mini hem büyük patlama için yeniden kullanılır. Animasyonlar `isFlutterTestEnvironment` korumasıyla testte anında biter.

**Tech Stack:** Flutter (yeni paket YOK), CustomPainter, AnimationController, mevcut SoundProvider/HapticFeedback desenleri.

**Mevcut durum notu (spec'ten farkı):** `_CircularTimer` renk geçişi (yeşil→amber→kırmızı) ve son-5-sn nabzı ZATEN VAR (quiz_widgets.dart:918-983); tam ekran konfeti streak %5==0'da ZATEN VAR (quiz_screen.dart:1048-1050, 464-471). Bu plan yalnızca gerçekten eksik parçaları ekler.

---

### Task 1: Saf efekt mantığı — `comboTierFor` + `vignetteStrengthFor`

**Files:**
- Create: `zankurd_mobile/lib/src/screens/quiz/quiz_effects.dart`
- Create: `zankurd_mobile/test/quiz_effects_test.dart`

- [ ] **Step 1: Başarısız testi yaz**

`zankurd_mobile/test/quiz_effects_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_effects.dart';

void main() {
  group('comboTierFor', () {
    test('2 ve altı seri rozet üretmez', () {
      expect(comboTierFor(0), isNull);
      expect(comboTierFor(1), isNull);
      expect(comboTierFor(2), isNull);
    });

    test('3-4 seri turuncu (bronze) kademe', () {
      expect(comboTierFor(3), ComboTier.bronze);
      expect(comboTierFor(4), ComboTier.bronze);
    });

    test('5-9 seri mor (silver) kademe', () {
      expect(comboTierFor(5), ComboTier.silver);
      expect(comboTierFor(9), ComboTier.silver);
    });

    test('10+ seri altın (gold) kademe', () {
      expect(comboTierFor(10), ComboTier.gold);
      expect(comboTierFor(25), ComboTier.gold);
    });
  });

  group('vignetteStrengthFor', () {
    test('kalan süre üçte birden fazlayken vinyet yok', () {
      expect(vignetteStrengthFor(1.0), 0.0);
      expect(vignetteStrengthFor(0.5), 0.0);
      expect(vignetteStrengthFor(0.34), 0.0);
    });

    test('son üçte birde doğrusal olarak güçlenir', () {
      expect(vignetteStrengthFor(1 / 3), closeTo(0.0, 0.001));
      expect(vignetteStrengthFor(1 / 6), closeTo(0.5, 0.01));
      expect(vignetteStrengthFor(0.0), closeTo(1.0, 0.001));
    });

    test('aralık dışı girdiler kırpılır', () {
      expect(vignetteStrengthFor(-0.2), 1.0);
      expect(vignetteStrengthFor(1.7), 0.0);
    });
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Çalıştır: `cd zankurd_mobile && flutter test test/quiz_effects_test.dart`
Beklenen: DERLEME HATASI ("quiz_effects.dart" yok / `comboTierFor` tanımsız)

- [ ] **Step 3: Minimal implementasyonu yaz**

`zankurd_mobile/lib/src/screens/quiz/quiz_effects.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/test_environment.dart';

/// Üst üste doğru cevap serisinin görsel kademesi.
/// Eşikler spec'ten: ×3 bronz(turuncu), ×5 gümüş(mor), ×10 altın.
enum ComboTier { bronze, silver, gold }

ComboTier? comboTierFor(int streak) {
  if (streak >= 10) return ComboTier.gold;
  if (streak >= 5) return ComboTier.silver;
  if (streak >= 3) return ComboTier.bronze;
  return null;
}

/// Kalan süre oranından (1.0=dolu, 0.0=bitti) kırmızı kenar vinyetinin
/// gücünü üretir. Son üçte birde 0→1 doğrusal tırmanır; öncesinde 0.
double vignetteStrengthFor(double remainingFraction) {
  final clamped = remainingFraction.clamp(0.0, 1.0);
  const threshold = 1 / 3;
  if (clamped >= threshold) return 0.0;
  return (threshold - clamped) / threshold;
}
```

- [ ] **Step 4: Testin geçtiğini doğrula**

Çalıştır: `cd zankurd_mobile && flutter test test/quiz_effects_test.dart`
Beklenen: PASS (tüm testler)

- [ ] **Step 5: Commit**

```bash
git add zankurd_mobile/lib/src/screens/quiz/quiz_effects.dart zankurd_mobile/test/quiz_effects_test.dart
git commit -m "feat(quiz): combo kademe ve vinyet gücü saf mantığı"
```

---

### Task 2: `ConfettiOverlay`'i parametrikleştir (mini patlama için)

**Files:**
- Modify: `zankurd_mobile/lib/src/widgets/confetti_overlay.dart` (satır 4-35 civarı: constructor + initState)
- Test: `zankurd_mobile/test/quiz_effects_test.dart` (ekleme)

- [ ] **Step 1: Başarısız testi yaz** — `quiz_effects_test.dart` sonuna ekle:

```dart
  group('ConfettiOverlay parametreleri', () {
    testWidgets('özel parçacık sayısı ve süre ile kurulabilir', (tester) async {
      var finished = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ConfettiOverlay(
            particleCount: 24,
            duration: const Duration(milliseconds: 300),
            onFinished: () => finished = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(finished, isTrue);
    });
  });
```

Import ekle (dosyanın başına): `import 'package:zankurd_mobile/src/widgets/confetti_overlay.dart';`

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Çalıştır: `cd zankurd_mobile && flutter test test/quiz_effects_test.dart`
Beklenen: DERLEME HATASI (`particleCount` diye parametre yok)

- [ ] **Step 3: ConfettiOverlay'e parametreleri ekle**

`confetti_overlay.dart` — constructor'ı şöyle genişlet (mevcut alan/initState'e dokunan minimal değişiklik):

```dart
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({
    required this.onFinished,
    this.particleCount = 80,
    this.duration = const Duration(milliseconds: 2500),
    super.key,
  });

  final VoidCallback onFinished;
  final int particleCount;
  final Duration duration;
  ...
}
```

`_ConfettiOverlayState.initState` içinde:
- `_particles = List.generate(80, ...)` → `List.generate(widget.particleCount, ...)`
- Controller süresi sabitse → `duration: widget.duration`

(Not: mevcut süre 2500ms değilse dosyadaki gerçek sabiti default olarak kullan — mevcut çağıranların davranışı DEĞİŞMEMELİ.)

- [ ] **Step 4: Testlerin geçtiğini doğrula**

Çalıştır: `cd zankurd_mobile && flutter test test/quiz_effects_test.dart test/widget_test.dart`
Beklenen: PASS (regresyon dahil)

- [ ] **Step 5: Commit**

```bash
git add zankurd_mobile/lib/src/widgets/confetti_overlay.dart zankurd_mobile/test/quiz_effects_test.dart
git commit -m "feat(ui): ConfettiOverlay'e parçacık sayısı ve süre parametresi"
```

---

### Task 3: Efekt widget'ları — `ShakeWrapper`, `ComboBadge`, `CriticalVignette`, `ScoreFlyup`

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/quiz/quiz_effects.dart` (Task 1 dosyasına ekle)
- Test: `zankurd_mobile/test/quiz_effects_test.dart` (ekleme)

- [ ] **Step 1: Başarısız widget testlerini yaz** — `quiz_effects_test.dart` sonuna:

```dart
  group('ComboBadge', () {
    testWidgets('streak 2 iken görünmez, 3 olunca ×3 rozeti çıkar',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ComboBadge(streak: 2, isKu: false)),
      );
      expect(find.textContaining('×'), findsNothing);

      await tester.pumpWidget(
        const MaterialApp(home: ComboBadge(streak: 3, isKu: false)),
      );
      await tester.pumpAndSettle();
      expect(find.text('×3 Seri!'), findsOneWidget);
    });

    testWidgets('KU modunda Rêz metni kullanılır', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ComboBadge(streak: 5, isKu: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('×5 Rêz!'), findsOneWidget);
    });
  });

  group('ShakeWrapper', () {
    testWidgets('trigger değişince çocuğu sarsar ve durulur', (tester) async {
      Widget build(int trigger) => MaterialApp(
            home: ShakeWrapper(
              trigger: trigger,
              child: const Text('hedef'),
            ),
          );
      await tester.pumpWidget(build(0));
      await tester.pumpWidget(build(1));
      await tester.pump(const Duration(milliseconds: 50));
      // Animasyon ortasında Transform.translate ofseti sıfırdan farklı olmalı
      final transform = tester.widget<Transform>(
        find.ancestor(of: find.text('hedef'), matching: find.byType(Transform)).first,
      );
      expect(transform.transform.getTranslation().x, isNot(0.0));
      await tester.pumpAndSettle();
    });
  });

  group('CriticalVignette', () {
    testWidgets('animasyon değeri yüksekken boyamaz, düşükken boyar',
        (tester) async {
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(seconds: 15),
        value: 1.0,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(children: [CriticalVignette(animation: controller)]),
        ),
      );
      expect(find.byType(CustomPaint), findsNothing);
      controller.value = 0.1; // son ~1.5 saniye
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(CriticalVignette),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });
  });
```

- [ ] **Step 2: Başarısızlığı doğrula**

Çalıştır: `cd zankurd_mobile && flutter test test/quiz_effects_test.dart`
Beklenen: DERLEME HATASI (widget'lar tanımsız)

- [ ] **Step 3: Widget'ları `quiz_effects.dart`'a ekle**

```dart
/// Yanlış cevapta şıkkı yatay sarsar. [trigger] her arttığında bir kez oynar.
class ShakeWrapper extends StatefulWidget {
  const ShakeWrapper({required this.trigger, required this.child, super.key});

  final int trigger;
  final Widget child;

  @override
  State<ShakeWrapper> createState() => _ShakeWrapperState();
}

class _ShakeWrapperState extends State<ShakeWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void didUpdateWidget(covariant ShakeWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Sönümlenen sinüs: 3 tam salınım, gittikçe küçülen genlik.
        final t = _controller.value;
        final offset = math.sin(t * math.pi * 6) * (1 - t) * 8;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: widget.child,
    );
  }
}

/// "×N Seri!" rozeti. comboTierFor null dönerse hiçbir şey çizmez.
class ComboBadge extends StatelessWidget {
  const ComboBadge({required this.streak, required this.isKu, super.key});

  final int streak;
  final bool isKu;

  static const _tierColors = {
    ComboTier.bronze: Color(0xFFFF8F00),
    ComboTier.silver: Color(0xFF7C3AED),
    ComboTier.gold: Color(0xFFFFC107),
  };

  @override
  Widget build(BuildContext context) {
    final tier = comboTierFor(streak);
    return AnimatedSwitcher(
      duration: isFlutterTestEnvironment
          ? Duration.zero
          : const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: tier == null
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey('combo-$streak'),
              margin: const EdgeInsets.only(top: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _tierColors[tier]!,
                    _tierColors[tier]!.withValues(alpha: 0.75),
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: _tierColors[tier]!.withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '×$streak ${isKu ? 'Rêz!' : 'Seri!'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Son saniyelerde ekran kenarlarında beliren kırmızı vinyet.
/// [animation]: quiz'in geri sayan timer controller'ı (1.0→0.0).
class CriticalVignette extends StatelessWidget {
  const CriticalVignette({required this.animation, super.key});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final strength = vignetteStrengthFor(animation.value);
        if (strength <= 0) return const SizedBox.shrink();
        return Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _VignettePainter(strength: strength),
            ),
          ),
        );
      },
    );
  }
}

class _VignettePainter extends CustomPainter {
  _VignettePainter({required this.strength});

  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = RadialGradient(
        radius: 1.1,
        colors: [
          Colors.transparent,
          AppTheme.wrong.withValues(alpha: 0.22 * strength),
        ],
        stops: const [0.72, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _VignettePainter oldDelegate) =>
      oldDelegate.strength != strength;
}

/// Yanlış cevapta tam ekran çok kısa kırmızı flaş (0→0.15→0 opaklık).
/// [trigger] her arttığında bir kez oynar.
class WrongFlash extends StatefulWidget {
  const WrongFlash({required this.trigger, super.key});

  final int trigger;

  @override
  State<WrongFlash> createState() => _WrongFlashState();
}

class _WrongFlashState extends State<WrongFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: isFlutterTestEnvironment
        ? Duration.zero
        : const Duration(milliseconds: 260),
  );

  @override
  void didUpdateWidget(covariant WrongFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (!_controller.isAnimating) return const SizedBox.shrink();
        // 0→0.15→0 üçgen eğri
        final t = _controller.value;
        final opacity = (t < 0.5 ? t : 1 - t) * 0.30;
        return Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: AppTheme.wrong.withValues(alpha: opacity),
            ),
          ),
        );
      },
    );
  }
}

/// Doğru cevapta kazanılan puanın yukarı süzülen "+N" göstergesi.
/// [trigger] her arttığında [points] değeriyle bir kez oynar.
class ScoreFlyup extends StatefulWidget {
  const ScoreFlyup({required this.trigger, required this.points, super.key});

  final int trigger;
  final int points;

  @override
  State<ScoreFlyup> createState() => _ScoreFlyupState();
}

class _ScoreFlyupState extends State<ScoreFlyup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: isFlutterTestEnvironment
        ? Duration.zero
        : const Duration(milliseconds: 900),
  );

  @override
  void didUpdateWidget(covariant ScoreFlyup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (!_controller.isAnimating) return const SizedBox.shrink();
        final t = Curves.easeOut.transform(_controller.value);
        return IgnorePointer(
          child: Opacity(
            opacity: (1 - t).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -40 * t),
              child: Text(
                '+${widget.points}',
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black38)],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
```

(`AppTheme.gold` / `AppTheme.wrong` mevcut sabitlerdir; `import '../../theme/app_theme.dart';` Task 1'de eklendi.)

- [ ] **Step 4: Testlerin geçtiğini doğrula**

Çalıştır: `cd zankurd_mobile && flutter test test/quiz_effects_test.dart`
Beklenen: PASS

- [ ] **Step 5: Commit**

```bash
git add zankurd_mobile/lib/src/screens/quiz/quiz_effects.dart zankurd_mobile/test/quiz_effects_test.dart
git commit -m "feat(quiz): sarsıntı, combo rozeti, vinyet ve puan uçuşu widget'ları"
```

---

### Task 4: Quiz ekranına entegrasyon (gerilim tutuşu + tüm efektler)

**Files:**
- Modify: `zankurd_mobile/lib/src/screens/quiz_screen.dart`
  - state alanları (~satır 93-99), `_answer` (~satır 985-1086), build Stack (~satır 408-473), portrait/landscape listeler (~satır 415-459)
- Modify: `zankurd_mobile/lib/src/screens/quiz/quiz_widgets.dart`
  - `_QuestionTextAndAnswers` (~satır 156-230): yanlış şıkkı `ShakeWrapper` ile sar
- Test: `zankurd_mobile/test/quiz_effects_test.dart` (entegrasyon testi ekle)

- [ ] **Step 1: Başarısız entegrasyon testini yaz** — `quiz_effects_test.dart` sonuna. Mevcut `widget_test.dart`'taki quiz kurulum desenini kullan (MockZanKurdRepository + createRoom + QuizScreen pump; oradaki 'quiz answer feedback labels the correct answer' testinin kurulumunu birebir örnek al):

```dart
  group('Quiz efekt entegrasyonu', () {
    testWidgets('yanlış cevapta ShakeWrapper tetiklenir, doğruda mini konfeti',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      SeenQuestionStore.resetInstance();
      final repo = MockZanKurdRepository();
      final room = repo.createRoom();
      final questions = repo.questions.take(2).toList();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
            ChangeNotifierProvider(create: (_) => SoundProvider()),
          ],
          child: MaterialApp(
            home: QuizScreen(
              repository: repo,
              room: room,
              questions: questions,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Yanlış şıkkı bul ve bas
      final q = questions.first;
      final wrongAnswer = q.displayAnswers
          .firstWhere((a) => a != q.correctAnswer);
      await tester.tap(find.text(wrongAnswer).first);
      await tester.pumpAndSettle();

      // Yanlış seçilen şık ShakeWrapper içinde olmalı
      expect(
        find.ancestor(
          of: find.text(wrongAnswer).first,
          matching: find.byType(ShakeWrapper),
        ),
        findsWidgets,
      );
    });
  });
```

Gerekli import'lar: `shared_preferences`, `provider`, `MockZanKurdRepository`, `SeenQuestionStore`, `QuizScreen`, `LanguageProvider`, `SoundProvider` (yolları widget_test.dart'ın başından kopyala).

- [ ] **Step 2: Başarısızlığı doğrula**

Çalıştır: `cd zankurd_mobile && flutter test test/quiz_effects_test.dart`
Beklenen: FAIL (ShakeWrapper ağaçta yok)

- [ ] **Step 3: Entegrasyonu yaz**

**(a) `quiz_screen.dart` state alanlarına ekle** (satır ~98 `_showConfetti` yanına):

```dart
  bool _showAnswerBurst = false; // her doğruda mini konfeti
  bool _suspense = false; // cevap sonrası kısa gerilim tutuşu
  int _shakeTrigger = 0; // yanlış cevapta artar → ShakeWrapper oynar
  int _flyupTrigger = 0; // doğru cevapta artar → ScoreFlyup oynar
  int _lastPointsEarned = 0;
```

**(b) `_answer` içinde gerilim tutuşu** — optimistic setState'i (satır ~1005-1008) şöyle değiştir:

```dart
    final isTimeout = answer == 'TIMEOUT';
    setState(() {
      selectedAnswer = answer;
      _suspense = !isTimeout;
    });
    if (!isTimeout && !isFlutterTestEnvironment) {
      await Future.delayed(const Duration(milliseconds: 400));
    }
    if (!mounted) return;
```

(`import '../utils/test_environment.dart';` zaten quiz_screen'de yoksa ekle.)

**(c) Başarı yolunda** (try bloğundaki setState, satır ~1033-1054) — mevcut satırları koruyarak ekle:

```dart
      final oldScore = score;
      setState(() {
        _suspense = false;
        ... // mevcut atamalar aynen
        if (correct) {
          _showAnswerBurst = true;
          _lastPointsEarned = score - oldScore;
          _flyupTrigger += 1;
        } else {
          _shakeTrigger += 1;
        }
      });
```

`oldScore`'u setState'ten ÖNCE al; `score` ataması mevcut satırıyla kalır. Catch (offline) yolundaki setState'e de (satır ~1068-1084) aynı beş satırı ekle (`_suspense = false;` + correct/else blokları; offline yolda `_lastPointsEarned = 100 + (streak * 10).clamp(0, 50);`).

Her iki yolda da setState'ten SONRA ×10 anı sesi (spec: altın kademede özel ses; yeni ses dosyası yok, mevcut win.mp3):

```dart
      if (isCorrect && streak == 10 && mounted) {
        context.read<SoundProvider>().playWin();
      }
```

(offline yolda koşul `correct && streak == 10`.)

**(d) Suspense'i şıklara ilet** — `_buildQuestionPanel` içindeki her iki `_QuestionTextAndAnswers` çağrısına `suspense: _suspense,` parametresi ekle. `quiz_widgets.dart`'ta `_QuestionTextAndAnswers`'a `final bool suspense;` alanı ekle (default parametre değil, required; quiz_screen tek çağıran). Şık üretiminde (satır ~200-220 civarı, `_AnswerButton` kurulan yer):
- `correct:` hesabına `&& !suspense` ekle (reveal gecikir),
- yanlış-sarsıntı için `_AnswerButton`'ı şöyle sar:

```dart
        final isWrongSelected =
            answered && !suspense && a == selectedAnswer &&
                a != question.correctAnswer;
        Widget button = _AnswerButton(...mevcut parametreler...);
        if (isWrongSelected) {
          button = ShakeWrapper(
            trigger: 1, // görünür olduğu anda bir kez oynar
            child: button,
          );
        }
```

ShakeWrapper `trigger: 1` ile ilk build'de oynamaz (didUpdateWidget bekler) — bu yüzden ShakeWrapper'a şu davranışı ekle: `initState`'te `if (widget.trigger > 0) _controller.forward(from: 0);` (Task 3 koduna bu satırı dahil et). `import 'quiz_effects.dart';` quiz_widgets.dart'a eklenir.

**(e) Build Stack katmanları** — satır ~464 `if (_showConfetti)` bloğunun yanına:

```dart
              if (widget.enableTimer)
                CriticalVignette(animation: _timerController),
              WrongFlash(trigger: _shakeTrigger),
              if (_showAnswerBurst)
                ConfettiOverlay(
                  particleCount: 24,
                  duration: const Duration(milliseconds: 900),
                  onFinished: () =>
                      setState(() => _showAnswerBurst = false),
                ),
```

**(f) Combo rozeti + puan uçuşu** — portrait listede (satır ~420-421) `_buildProgressBar` ile question switcher arasına; landscape listede (satır ~442-444) aynı şekilde:

```dart
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ComboBadge(streak: streak, isKu: _isKu),
                              const SizedBox(width: 10),
                              ScoreFlyup(
                                trigger: _flyupTrigger,
                                points: _lastPointsEarned,
                              ),
                            ],
                          ),
```

`import 'quiz/quiz_effects.dart';` quiz_screen.dart'a eklenir.

- [ ] **Step 4: Tüm testleri çalıştır**

Çalıştır: `cd zankurd_mobile && flutter test`
Beklenen: PASS (244 + yeniler). Özellikle mevcut 'quiz answer feedback labels the correct answer' ve 'explanation box is displayed after 800ms delay' testleri KIRILMAMALI (test ortamında suspense delay atlandığı için davranış aynı kalmalı).

Çalıştır: `cd zankurd_mobile && dart analyze`
Beklenen: No issues found!

- [ ] **Step 5: Commit**

```bash
git add zankurd_mobile/lib/src/screens/quiz_screen.dart zankurd_mobile/lib/src/screens/quiz/quiz_widgets.dart zankurd_mobile/lib/src/screens/quiz/quiz_effects.dart zankurd_mobile/test/quiz_effects_test.dart
git commit -m "feat(quiz): gerilim tutuşu, sarsıntı, mini konfeti, combo rozeti ve puan uçuşu entegrasyonu"
```

---

### Task 5: Görsel QA (web) + dağıtım

**Files:** yok (doğrulama + dağıtım)

- [ ] **Step 1: Web sunucusuyla görsel kontrol**

`flutter run -d web-server --web-port 8787` başlat; Playwright ile 390×844 viewport'ta bir quiz oyna:
- Yanlış cevapta sarsıntı + kırmızı vinyet YOK (vinyet yalnız süre azalınca), doğruda mini konfeti görünür,
- 3 doğru üst üste → "×3 Seri!" rozeti,
- son 5 saniyede ekran kenarlarında kırmızı vinyet,
- ekran görüntüleriyle belgelenir. Kırpılma/overflow konsol hatası olmamalı.

- [ ] **Step 2: Sürüm + dağıtım**

`flutter build web --release` (C:\src\zk üzerinden, TMP/TEMP ayarıyla) → FTP ile Hostinger `public_html`'e yükle (oturumda kurulmuş ftp_deploy.py akışı) → https://zankurd.com/ üzerinde smoke test.

- [ ] **Step 3: Commit yoksa işaretle**

Görsel QA'de düzeltme çıktıysa ayrı `fix(quiz):` commit'i; çıkmadıysa bu task commit üretmez.
