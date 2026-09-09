import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

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

void main() {
  testWidgets('hareketi azalt açıkken doğru cevap zıplamaz', (tester) async {
    await tester.pumpWidget(_shell(reducedMotion: true));

    final bounce = tester.widget<TweenAnimationBuilder<double>>(
      find.byKey(const ValueKey('bounce_true')),
    );
    expect(bounce.tween.begin, 1.0);
    expect(bounce.tween.end, 1.0);

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

  testWidgets('normal modda doğru cevap geri bildirimi korunur', (
    tester,
  ) async {
    await tester.pumpWidget(_shell(reducedMotion: false));

    final bounce = tester.widget<TweenAnimationBuilder<double>>(
      find.byKey(const ValueKey('bounce_true')),
    );
    expect(bounce.tween.begin, 0.95);
    expect(bounce.tween.end, 1.0);

    final switcher = tester.widget<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    );
    expect(switcher.duration, const Duration(milliseconds: 250));
  });
}
