import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/learning_goal_store.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

class _Repository extends MockZanKurdRepository {
  _Repository({this.canSpin = false, this.completedLessons = 0});
  final bool canSpin;
  final int completedLessons;

  @override
  Future<bool> canSpinToday() async => canSpin;

  @override
  Future<int> unusedExtraSpins() async => 0;

  @override
  Future<Set<String>> loadCompletedLessonIds() async => {
    for (var i = 0; i < completedLessons; i++) 'lesson-$i',
  };
}

Widget _shell(Widget child, {String lang = 'tr', double scale = 1}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LanguageProvider(initialLang: lang),
        ),
        ChangeNotifierProvider(create: (_) => AuthProvider.test()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SoundProvider()),
        ChangeNotifierProvider(create: (_) => ReducedMotionProvider()),
        ChangeNotifierProvider(create: (_) => PremiumService.fallback()),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: child,
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LearningGoalStore.resetInstance();
    MasteryStore.resetInstance();
  });

  for (final lang in ['tr', 'ku']) {
    testWidgets(
      'R22 $lang: öğren kapısı sayıyı tamamlanan ders olarak açıklar',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _shell(
            HomeScreen(
              repository: _Repository(completedLessons: 3),
              onOpenLearning: () async {},
            ),
            lang: lang,
          ),
        );
        await tester.pumpAndSettle();
        final door = find.byKey(const ValueKey('home-door-learn'));
        await tester.ensureVisible(door);
        await tester.pumpAndSettle();
        final tile = tester.widget<SahneModeTile>(door);
        expect(tile.badge, isNull, reason: 'açıklamasız sayı rozeti dönmemeli');
        final expected = tester.element(door).t(K.t12CompletedLessons, {
          'n': '3',
        });
        expect(tile.subtitle, expected);
        final caption = tester.widget<Text>(find.text(expected));
        expect(caption.style?.fontSize, greaterThanOrEqualTo(14));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('R19/R39/R54 $lang: kullanılan hak ve takvim saati açıklanır', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _shell(SpinWheelScreen(repository: _Repository()), lang: lang),
      );
      await tester.pumpAndSettle();
      final used = find.byKey(const ValueKey('spin-used-today'));
      final reset = find.byKey(const ValueKey('spin-reset-time'));
      expect(used, findsOneWidget);
      expect(reset, findsOneWidget);
      for (final finder in [used, reset]) {
        expect(
          tester.widget<Text>(finder).style?.fontSize,
          greaterThanOrEqualTo(14),
        );
      }
      expect(tester.widget<Text>(reset).data, contains('00.00'));
      await tester.ensureVisible(reset);
      await tester.pumpAndSettle();
      expect(tester.getRect(reset).bottom, lessThan(844));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('R19: kullanılabilir hak yanlışlıkla kullanılmış gösterilmez', (
    tester,
  ) async {
    await tester.pumpWidget(
      _shell(SpinWheelScreen(repository: _Repository(canSpin: true))),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('spin-used-today')), findsNothing);
    expect(find.byKey(const ValueKey('spin-reset-time')), findsNothing);
    expect(find.text('Çevir'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('R54: dar ekran büyük yazıda reset açıklaması erişilebilir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _shell(SpinWheelScreen(repository: _Repository()), scale: 1.4),
    );
    await tester.pumpAndSettle();
    final reset = find.byKey(const ValueKey('spin-reset-time'));
    await tester.ensureVisible(reset);
    await tester.pumpAndSettle();
    expect(tester.getRect(reset).bottom, lessThan(640));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
