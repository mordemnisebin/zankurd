import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

Widget _shell({required bool reducedMotion}) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
    ChangeNotifierProvider(
      create: (_) => ReducedMotionProvider(initialUserReduce: reducedMotion),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: QuizOptionTile(
        index: 0,
        answer: 'Bersiv',
        selected: true,
        correct: true,
        disabled: true,
        onTap: () {},
      ),
    ),
  ),
);

/// "Hareketi azalt" şık çubuğunda da uygulanır.
///
/// 2026-09-29 Şahnê: doğru cevabın hareketi artık zıplama (0.95 → 1) değil
/// Rast dolgusunun soldan sağa TARAMASIDIR (240 ms). Bekçi yeni hareketi
/// ölçer: hareketi azalt açıkken tarama hiç oynamaz (dolgu ilk karede tam)
/// ve ✓ ikonu ölçek/solma oynatmaz; kapalıyken tarama baştan (0) başlar.
TweenAnimationBuilder<double> _sweep(WidgetTester tester) =>
    tester.widget<TweenAnimationBuilder<double>>(
      find.byKey(const ValueKey('option-sweep-correct')),
    );

void main() {
  testWidgets('hareketi azalt açıkken doğru cevap taranmaz, hemen dolar', (
    tester,
  ) async {
    await tester.pumpWidget(_shell(reducedMotion: true));

    final sweep = _sweep(tester);
    expect(sweep.tween.begin, 1.0);
    expect(sweep.duration, Duration.zero);

    final switcher = tester.widget<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    );
    expect(
      switcher.duration,
      Duration.zero,
      reason:
          'Doğru/yanlış ikonu reduced-motion modunda scale/fade oynamamalı.',
    );
  });

  testWidgets('normal modda doğru cevap soldan sağa taranır', (tester) async {
    await tester.pumpWidget(_shell(reducedMotion: false));

    final sweep = _sweep(tester);
    expect(sweep.tween.begin, 0.0);
    expect(sweep.tween.end, 1.0);
    expect(sweep.duration, SahneMotion.answerReveal);

    final switcher = tester.widget<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    );
    expect(switcher.duration, SahneMotion.answerReveal);
    await tester.pumpAndSettle();
  });
}
