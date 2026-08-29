import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/quiz_level.dart';
import 'package:zankurd_mobile/src/screens/home/home_level_path.dart';
import 'package:zankurd_mobile/src/screens/home/home_rows.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Ana sayfa "ders yolu" kartı seviye haritasını gizliyordu: merdiven
/// LevelScreen'de vardı, günlük açılışta yoktu. Odak kategori ve kilit
/// kuralı ekrandan bağımsız iddia edilmeli.
void main() {
  test('odak, başlanmış ilk kategoridir; yoksa yedek', () {
    expect(
      homePathFocusCategory(
        started: const [
          CategoryProgress(category: 'Dîrok', correct: 3, threshold: 20),
          CategoryProgress(category: 'Ziman', correct: 1, threshold: 20),
        ],
        categories: const ['Ziman', 'Dîrok'],
      ),
      'Dîrok',
    );
    expect(
      homePathFocusCategory(started: const [], categories: const ['Ziman']),
      'Ziman',
    );
  });

  test('ilk basamak açık, sonrakiler önceki oynanınca açılır', () {
    expect(isHomePathLevelUnlocked(1, const {}), isTrue);
    expect(isHomePathLevelUnlocked(2, const {}), isFalse);
    expect(isHomePathLevelUnlocked(2, const {1}), isTrue);
    expect(homePathNextLevel(const [1, 2, 3], const {1}), 2);
    expect(homePathNextLevel(const [1, 2, 3], const {1, 2, 3}), isNull);
  });

  testWidgets('sıradaki basamağı ve kategori yolunu gösterir', (tester) async {
    const levels = [
      QuizLevel(
        number: 1,
        title: 'Destpêk',
        category: 'Ziman',
        difficultyMin: 1,
        difficultyMax: 2,
        questionCount: 10,
      ),
      QuizLevel(
        number: 2,
        title: 'Bingeh',
        category: 'Ziman',
        difficultyMin: 1,
        difficultyMax: 2,
        questionCount: 10,
      ),
      QuizLevel(
        number: 3,
        title: 'Navîn',
        category: 'Ziman',
        difficultyMin: 2,
        difficultyMax: 3,
        questionCount: 12,
      ),
      QuizLevel(
        number: 4,
        title: 'Pêşketî',
        category: 'Ziman',
        difficultyMin: 3,
        difficultyMax: 4,
        questionCount: 12,
      ),
      QuizLevel(
        number: 5,
        title: 'Mamoste',
        category: 'Ziman',
        difficultyMin: 4,
        difficultyMax: 5,
        questionCount: 15,
      ),
    ];

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider()..setLang('tr'),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: HomeLevelPath(
              category: 'Ziman',
              levels: levels,
              played: const {1},
              isKu: false,
              onOpen: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Dil yolu'), findsOneWidget);
    expect(find.text('Sıradaki: Temel'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('home-lessons-row')))
          .getSemanticsData()
          .label,
      'Sıradaki: Temel',
    );
    expect(find.byKey(const ValueKey('home-path-node-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-path-node-5')), findsOneWidget);
    expect(find.byIcon(Icons.circle), findsNothing);
    expect(find.byIcon(AppIcons.play), findsOneWidget);
  });
}
