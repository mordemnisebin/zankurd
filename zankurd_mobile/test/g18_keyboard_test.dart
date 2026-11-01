import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/learn_path.dart';
import 'package:zankurd_mobile/src/widgets/keyboard_action.dart';

Widget _wrap(Widget child) => ChangeNotifierProvider(
  create: (_) => LanguageProvider()..setLang('tr'),
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

Future<void> _tabTo(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 40; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || focus is FocusScopeNode || focus.context == null) {
      continue;
    }
    if (find
        .descendant(of: find.byWidget(focus.context!.widget), matching: target)
        .evaluate()
        .isNotEmpty) {
      final action = find
          .ancestor(of: target, matching: find.byType(KeyboardAction))
          .first;
      final visibleRing = find.descendant(
        of: action,
        matching: find.byWidgetPredicate((widget) {
          if (widget is! DecoratedBox ||
              widget.position != DecorationPosition.foreground) {
            return false;
          }
          final decoration = widget.decoration;
          return decoration is BoxDecoration &&
              decoration.border is Border &&
              (decoration.border! as Border).top.width > 0 &&
              (decoration.border! as Border).top.color.a > 0;
        }),
      );
      expect(
        visibleRing,
        findsOneWidget,
        reason: 'Klavye odağı görünür çerçeveyle gösterilmeli',
      );
      return;
    }
  }
  fail('Tab ile hedef eyleme ulaşılmalı: $target');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlacementStore.resetInstance();
  });
  tearDown(PlacementStore.resetInstance);

  testWidgets(
    'G18 açık/tamamlanmış ders Tab Enter Space ile açılır; semantik dokunma testleri klavye eksikliğinde sessiz kaldı',
    (tester) async {
      final activated = <LearnNodeState>[];
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: LearnPath(
              stops: [
                for (final state in [
                  LearnNodeState.done,
                  LearnNodeState.locked,
                  LearnNodeState.open,
                ])
                  LearnPathStop(
                    state: state,
                    step: 1,
                    icon: Icons.school,
                    semanticLabel: state.name,
                    title: state.name,
                    onTap: state == LearnNodeState.locked
                        ? null
                        : () => activated.add(state),
                  ),
              ],
            ),
          ),
        ),
      );
      for (final state in [LearnNodeState.done, LearnNodeState.open]) {
        await _tabTo(tester, find.text(state.name));
        for (final key in [
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.space,
        ]) {
          await tester.sendKeyEvent(key);
          await tester.pump();
        }
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(activated, [
        LearnNodeState.done,
        LearnNodeState.done,
        LearnNodeState.open,
        LearnNodeState.open,
        LearnNodeState.done,
        LearnNodeState.open,
      ]);
    },
  );

  for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
    testWidgets(
      'G18 güncel ders sarmalayıcısı Tab ${key == LogicalKeyboardKey.space ? 'Space' : 'Enter'} ile açılır; başlangıç düğmesi dokunma testi sarmalayıcı kusurunda sessiz kaldı',
      (tester) async {
        await tester.pumpWidget(
          _wrap(LearningScreen(repository: MockZanKurdRepository())),
        );
        await tester.pumpAndSettle();
        await _tabTo(tester, find.byKey(const ValueKey('learning-next-step')));
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        expect(find.byType(LessonDetailScreen), findsOneWidget);
      },
    );
  }

  testWidgets(
    'G18 flaş kart Tab Enter Space ile iki yönde çevrilir; yalnız dokunma sınandığından klavye kusuru sessiz kaldı',
    (tester) async {
      final repository = MockZanKurdRepository();
      final lessons = await repository.loadLessonsByCategory('everyday');
      await tester.pumpWidget(
        _wrap(
          LessonDetailScreen(
            lesson: lessons.first,
            repository: repository,
            initialFlashcardMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tabTo(tester, find.text('Çeviri için dokun'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Çeviri'), findsOneWidget);
      expect(find.text('Çeviri için dokun'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text('Çeviri için dokun'), findsOneWidget);
      expect(find.text('Çeviri'), findsNothing);
    },
  );
}
