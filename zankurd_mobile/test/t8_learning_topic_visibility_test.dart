import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/lesson.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/screens/matchmaking_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

class _Repository extends MockZanKurdRepository {
  static const topics = [
    'Ziman',
    'Teknolojî',
    'Siyaset',
    'Sînema',
    'Paradigma',
    'Muzîk',
    'Edebiyat',
    'Dîrok',
    'Çand',
    'Cografya',
  ];
  @override
  Future<List<String>> loadMatchmakingCategories() async => topics;
  @override
  Future<List<Lesson>> loadLessonsByCategory(String category) async => [
    for (var i = 0; i < 5; i++)
      Lesson(
        id: 'lesson-$i',
        slug: 'lesson-$i',
        titleTr: 'Ders ${i + 1}',
        titleKu: 'Ders ${i + 1}',
        category: category,
        order: i,
      ),
  ];
  @override
  Future<Set<String>> loadCompletedLessonIds() async => {
    'lesson-0',
    'lesson-1',
    'lesson-2',
  };
}

Widget _shell(Widget child, String lang, double scale) =>
    ChangeNotifierProvider(
      create: (_) => LanguageProvider()..setLang(lang),
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            padding: const EdgeInsets.only(top: 44, bottom: 34),
          ),
          child: child!,
        ),
        home: child,
      ),
    );

void main() {
  for (final width in [320.0, 375.0, 402.0, 800.0]) {
    for (final lang in ['tr', 'ku']) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
          'E12 seçili ders ve Başla tam görünür $width $lang x$scale',
          (tester) async {
            SharedPreferences.setMockInitialValues({});
            PlacementStore.resetInstance();
            addTearDown(PlacementStore.resetInstance);
            tester.view.physicalSize = Size(width, width == 320 ? 640 : 874);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              _shell(LearningScreen(repository: _Repository()), lang, scale),
            );
            await tester.pumpAndSettle();
            final card = tester.getRect(
              find.byKey(const ValueKey('learning-active-frame')),
            );
            final viewport = tester.getRect(
              find.byType(SingleChildScrollView).first,
            );
            expect(card.top, greaterThanOrEqualTo(viewport.top));
            expect(card.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));
            final button = find.descendant(
              of: find.byKey(const ValueKey('learning-active-frame')),
              matching: find.byType(SahneButton),
            );
            expect(button.hitTestable(), findsOneWidget);
            expect(
              tester.getRect(button).bottom,
              lessThanOrEqualTo(viewport.bottom),
            );
            expect(tester.takeException(), isNull);
          },
        );
        testWidgets(
          'E13 açılışta tam satırlar ve son satıra erişim $width $lang x$scale',
          (tester) async {
            SharedPreferences.setMockInitialValues({});
            tester.view.physicalSize = Size(width, width == 320 ? 640 : 874);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              _shell(MatchmakingScreen(repository: _Repository()), lang, scale),
            );
            await tester.pumpAndSettle();
            final clip = tester.renderObject<RenderClipRect>(
              find.byKey(const ValueKey('matchmaking-whole-rows')),
            );
            Rect visibleClip() => clip.clipper!
                .getClip(clip.size)
                .shift(clip.localToGlobal(Offset.zero));
            final paintRect = visibleClip();
            var visible = 0;
            for (final category in _Repository.topics) {
              final tile = tester.getRect(
                find.byKey(ValueKey('matchmaking-category-$category')),
              );
              if (tile.top >= 0 && tile.overlaps(paintRect)) {
                visible++;
                expect(
                  tile.bottom,
                  lessThanOrEqualTo(paintRect.bottom + 0.5),
                  reason: '$category yarım görünmemeli',
                );
              }
            }
            expect(visible, greaterThan(0));
            final scroll = tester.state<ScrollableState>(
              find.descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              ),
            );
            scroll.position.jumpTo(scroll.position.maxScrollExtent);
            await tester.pumpAndSettle();
            final last = find.byKey(
              const ValueKey('matchmaking-category-Cografya'),
            );
            final lastRect = tester.getRect(last);
            expect(
              lastRect.bottom,
              lessThanOrEqualTo(visibleClip().bottom + 0.5),
            );
            expect(last.hitTestable(), findsOneWidget);
            expect(
              lastRect.bottom,
              lessThan(tester.getRect(find.byType(SahneBottomDock)).top),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
