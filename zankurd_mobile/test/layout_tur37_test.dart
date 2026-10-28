/// Tur 37 simülatör bulguları: iki yerleşim kusuru.
///
/// ## Kusur 1: Yarış kapısı alt yazısı "…" ile kesiliyordu
///
/// Kurmancî "Ode ava bike, hevrikekî bibîne an bi dorê bilîze" yarım
/// genişlikteki mod kartında iki satıra sığmayıp üç noktayla bitiyordu.
/// Sessizdi: taşma değil, `maxLines` kırpmasıydı; hiçbir test "alt yazı
/// kesilmedi" diye sormuyordu.
///
/// ## Kusur 2: "Soru çöz" / "Kartlarla çalış" çifti
///
/// Kurmancî "Bi kartan bixwîne" yarım genişlikte iki satıra inip yanındaki
/// tek satırlık düğmeden farklı duruyordu. 2026-10-28 tur 3 (T13): çift
/// düğme kalktı, iki eylem Pratik ızgarasının karosu oldu; bekçi eşit boyu
/// ve ≥ 48 dokunma hedefini korur. T15: mod kartı alt satırı tek satır.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

import 'support/realistic_device.dart';

Widget _shell({
  required bool isKu,
  required double scale,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(initialLang: isKu ? 'ku' : 'tr'),
      ),
      ChangeNotifierProvider(create: (_) => AuthProvider.test()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<PremiumService>(
        create: (_) => PremiumService.fallback(),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: c!,
      ),
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Gerçek yazı tipi: ölçü fontunda (her harf kare) kırpma testi anlamsızdır.
  setUpAll(loadAppFonts);

  setUp(() {
    AchievementStore.resetInstance();
    SharedPreferences.setMockInitialValues({
      'zankurd.achievements.unlocked': ['first_game'],
    });
    MasteryStore.resetInstance();
    LevelProgressStore.resetInstance();
  });

  for (final isKu in [true, false]) {
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Yarış kapısı alt yazısı kesilmez (${isKu ? 'KU' : 'TR'}, '
            '$width, ×$scale)', (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            _shell(
              isKu: isKu,
              scale: scale,
              child: HomeScreen(
                repository: MockZanKurdRepository(),
                onOpenLearning: () async {},
                onOpenPlay: () {},
              ),
            ),
          );
          await tester.pump(const Duration(seconds: 1));
          final sub = Tr.of(
            K.homeDoorPlaySub,
            isKu ? AppLanguage.ku : AppLanguage.tr,
          );
          final finder = find.text(sub);
          await tester.ensureVisible(finder);
          final paragraph = tester.renderObject<RenderParagraph>(finder);
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: 'alt yazı "…" ile kesildi',
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  // 2026-10-28 tur 3 T15: mod kartı alt satırı TEK satır (TASARIM_DILI kuralı).
  for (final isKu in [true, false]) {
    testWidgets(
      'mod kartı alt satırları tek satır (${isKu ? 'KU' : 'TR'}, 390)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _shell(
            isKu: isKu,
            scale: 1.0,
            child: HomeScreen(
              repository: MockZanKurdRepository(),
              onOpenLearning: () async {},
              onOpenPlay: () {},
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        for (final key in [K.homeDoorLearnSub, K.homeDoorPlaySub]) {
          final finder = find.text(
            Tr.of(key, isKu ? AppLanguage.ku : AppLanguage.tr),
          );
          await tester.ensureVisible(finder);
          final p = tester.renderObject<RenderParagraph>(finder);
          expect(
            p.size.height,
            lessThan((p.text.style?.fontSize ?? 14) * 1.6),
            reason: '$key iki satıra indi',
          );
        }
      },
    );
  }

  // T13 (tur 3): "Soru çöz" / "Kartlarla çalış" ikili düğmesi kalktı; Pratik
  // ızgarasının karoları oldu. Aynı satırdaki iki karo eşit boydadır.
  for (final isKu in [true, false]) {
    for (final width in [320.0, 360.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('konu karoları (soru çöz / kartlar) eşit boy, taşmaz '
            '(${isKu ? 'KU' : 'TR'}, $width, ×$scale)', (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            _shell(
              isKu: isKu,
              scale: scale,
              child: LearningScreen(repository: MockZanKurdRepository()),
            ),
          );
          await tester.pumpAndSettle();
          final a = find.byKey(const ValueKey('learning-topic-practice'));
          final b = find.byKey(const ValueKey('learning-topic-flashcards'));
          await tester.ensureVisible(b);
          await tester.pumpAndSettle();
          final ra = tester.getRect(a);
          final rb = tester.getRect(b);
          if ((ra.top - rb.top).abs() < 1) {
            expect(ra.height, closeTo(rb.height, 0.5), reason: 'eşit boy');
          }
          expect(ra.height, greaterThanOrEqualTo(48));
          expect(rb.height, greaterThanOrEqualTo(48));
          expect(
            find.byKey(const ValueKey('learning-topic-actions')),
            findsNothing,
            reason: 'eski ikili düğme çifti geri gelmemeli',
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
