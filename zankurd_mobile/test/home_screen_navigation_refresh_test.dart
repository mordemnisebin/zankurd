import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/level_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// 2026-08-14 denetimi: Ana ekranın (`home_screen.dart`) dört bulgusu.
///
/// 1. `onOpenLearning`/`onOpenCategories` eskiden `VoidCallback` idi ve
///    push'un dönüşü hiç izlenmiyordu — Fêr Bibe sekmesi içinde push/pop
///    ile kalan bir oyuncu ders bitirip döndüğünde ekran YALNIZ sekmeye
///    tekrar basılırsa (bir sekme değişimi tetiklenirse) tazeleniyordu.
/// 2. "Tekrar zamanı" satırı `MistakeStore.readyCount`u ham gösteriyordu;
///    o sayı artık bankada bulunmayan (karantina/sunucu UUID'li) kimlikleri
///    de sayıyordu.
/// 3. `_refreshProgress()` `initState`te hiç çağrılmıyordu — "Kaldığın
///    yer" yalnız `_handleRefreshSignal` (sekme değişimi) ile doluyordu;
///    Öğren açılış sekmesi olduğu için ilk açılışta asla tetiklenmiyordu.
/// 4. `ContinueSection` dıştan `_categoryProgress.any(ratio > 0)` ile
///    kapatılıyordu — widget'ın kendi "keşif" dalı bu yüzden hiç
///    çağrılamıyordu (ilerleme boşken bölüm tamamen kayboluyordu, keşif
///    daveti değil).
/// 5. "Kaldığın yer" satırındaki kategori argümanı yok sayılıp her zaman
///    genel kategori listesi açılıyordu.
Widget _wrap(Widget child, {bool isKu = true}) => MultiProvider(
  providers: [
    ChangeNotifierProvider(
      create: (_) => LanguageProvider()..setLang(isKu ? 'ku' : 'tr'),
    ),
    ChangeNotifierProvider(create: (_) => AuthProvider.test()),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    // Ana ekran abonelik satırını `Consumer<PremiumService>` ile çiziyor;
    // uygulamada bu sağlayıcı her zaman var (bkz. `main.dart`), testin
    // kendi kapsamında da olmalı.
    ChangeNotifierProvider<PremiumService>(
      create: (_) => PremiumService.fallback(),
    ),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

class _ControllableCoinRepository extends MockZanKurdRepository {
  int coinBalance = 0;

  @override
  Future<int> loadCoinBalance() async => coinBalance;
}

QuizQuestion _q(String id) => QuizQuestion(
  id: id,
  category: 'Ziman',
  prompt: 'p',
  answers: const ['a', 'b'],
  correctAnswer: 'a',
  explanation: 'e',
);

void main() {
  setUp(() {
    MasteryStore.resetInstance();
    LevelProgressStore.resetInstance();
    SharedPreferences.setMockInitialValues({});
  });

  group('launchableReviewCount', () {
    test('yalnız playableQuestions içinde bulunan hazır kimlikleri sayar', () {
      final playable = [_q('offline_0001'), _q('offline_0002')];
      final readyIds = {
        'offline_0001',
        // Sunucu UUID'si / karantinaya alınmış — artık bankada yok.
        '9f1b6d2e-4c77-4a51-9a2f-1d0e3b8c5a44',
      };

      expect(launchableReviewCount(readyIds, playable), 1);
    });

    test('hiçbiri açılamıyorsa 0 döner, ham kimlik sayısı değil', () {
      final playable = [_q('offline_0001')];
      final readyIds = {
        '9f1b6d2e-4c77-4a51-9a2f-1d0e3b8c5a44',
        'c3a0f5b1-2d64-4e89-b7f3-6a8e2c9d1077',
      };

      expect(launchableReviewCount(readyIds, playable), 0);
    });
  });

  testWidgets('ilk açılışta sekmeye basmadan "Kaldığın yer" görünür', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'zankurd.mastery.Ziman': 5});
    await tester.pumpWidget(
      _wrap(
        HomeScreen(
          repository: MockZanKurdRepository(),
          onOpenCategories: () async {},
        ),
      ),
    );
    // `refreshSignal` hiç tetiklenmedi (widget'a hiç verilmedi) — bölüm
    // yalnız initState'teki ilk yükten gelebilir.
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const ValueKey('home-continue-section')), findsOneWidget);
    expect(find.text('Ziman'), findsOneWidget);
  });

  testWidgets(
    'ilerleme yokken ilk açılışta keşif daveti görünür (bölüm boş kalmaz)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          HomeScreen(
            repository: MockZanKurdRepository(),
            onOpenCategories: () async {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(const ValueKey('home-discover-section')), findsNothing);
      expect(
        find.byKey(const ValueKey('home-browse-categories-row')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('home-continue-section')), findsNothing);
    },
  );

  testWidgets(
    '"Kaldığın yer" satırı dokunulan kategoriyi açar, genel listeyi değil',
    (tester) async {
      SharedPreferences.setMockInitialValues({'zankurd.mastery.Ziman': 5});
      String? openedCategory;
      var genericOpened = false;
      await tester.pumpWidget(
        _wrap(
          HomeScreen(
            repository: MockZanKurdRepository(),
            onOpenCategories: () async {
              genericOpened = true;
            },
            onOpenCategory: (category) async {
              openedCategory = category;
            },
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Ziman'));
      await tester.pump();

      expect(openedCategory, 'Ziman');
      expect(
        genericOpened,
        isFalse,
        reason: 'kategoriye özel geri çağırma varken genel listeye düşülmemeli',
      );
    },
  );

  testWidgets('öğrenmeden dönünce ana ekran sekmeye basmadan tazelenir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _ControllableCoinRepository()..coinBalance = 10;
    await tester.pumpWidget(
      _wrap(HomeScreen(repository: repo, onOpenCategories: () async {})),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('10'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-lessons-row')));
    await tester.pumpAndSettle();
    expect(find.byType(LevelScreen), findsOneWidget);

    repo.coinBalance = 55;
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(
      find.text('55'),
      findsOneWidget,
      reason:
          'push tab-içi kaldığı için tek tazeleme fırsatı dönüş anıdır — '
          'sekmeye tekrar basılmasını beklememeli',
    );
  });
}
