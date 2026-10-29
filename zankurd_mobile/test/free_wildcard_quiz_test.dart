import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/free_wildcard_store.dart';
import 'package:zankurd_mobile/src/data/joker_stock_store.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/wildcard.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_wildcard_bar.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

/// 2026-10-28 tur 5 W1: hak açıkken fiyat yuvasında "Bedava" (rozet/çip yok);
/// kısa etiketler (50/50, İpucu, Çift cevap, Değiştir) ≥ 12 sp.
///
/// 2026-10-29 vay 2A: W1 TERSİNE döndü — dört jokerde tekrarlanan "Bedava"
/// etiketleri joker çubuğunu kalabalıklaştırıyordu (Astra: "tekrarlanan
/// sarı 'Bedava' rozetleri kalite hissini düşürüyor"). Hak artık joker
/// satırının üstündeki TEK satırda yazar ("Bugün 1 joker bedava"); jokerde
/// fiyat yuvası çizilmez, ekran okuyucu jokerin adında "Bedava" duyar.
///
/// Solo turda günlük bedava joker: ilk kullanım jeton düşmez, ikincisi düşer.
///
/// ## Kusur
///
/// Yeni oyuncunun jetonu 8–19, jokerler 20–50: joker satırı her soruda
/// kilitliydi ("Joker için jeton yetmiyor") ve özellik denenemiyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Joker testleri bol jetonlu bakiyeyle koşar; "hiç jetonu olmayan oyuncu
/// bir jokere dokunabilir mi" durumu hiçbir testte kurulmuyordu.
///
/// ## Kural
///
/// Günün ilk joker kullanımı (solo) `spend_coins` çağırmaz ve yerel bakiyeyi
/// düşürmez; satırda "Bugün 1 joker bedava" ipucu durur. İkinci kullanım
/// normal ücretlidir. Yeni günde hak yenilenir.
const _question = QuizQuestion(
  id: 'free-wildcard-q',
  category: 'Ziman',
  prompt: 'Pirtûk çi ye?',
  answers: ['Kitêb', 'Mase', 'Av', 'Mal'],
  correctAnswer: 'Kitêb',
  explanation: 'Pirtûk kitêb e.',
);

class _CountingRepository extends MockZanKurdRepository {
  _CountingRepository(this.balance);

  final int balance;
  final spends = <int>[];

  @override
  Future<int> loadCoinBalance() async => balance;

  @override
  Future<bool> spendCoins(int amount, String reason) async {
    spends.add(amount);
    return true;
  }
}

void main() {
  setUp(LocalProgressScope.debugReset);
  tearDown(LocalProgressScope.debugReset);

  Future<void> pumpQuiz(
    WidgetTester tester,
    MockZanKurdRepository repository, {
    String? freeDay,
    int? jokerStock,
  }) async {
    freshMockRepository();
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.quiz_tutorial.seen': true,
      'zankurd.wildcard_hint.fiftyFifty': true,
      'zankurd.wildcard_hint.audience': true,
      'zankurd.missions.freeWildcardDay': ?freeDay,
      'zankurd.missions.jokerStock': ?jokerStock,
    });
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: const [_question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> tap(WidgetTester tester, WildcardType type) async {
    final button = find.byWidgetPredicate(
      (w) => w is WildcardButton && w.type == type,
    );
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  WildcardButton button(WidgetTester tester, WildcardType type) => tester
      .widgetList<WildcardButton>(find.byType(WildcardButton))
      .firstWhere((b) => b.type == type);

  // 2026-10-27: turnuva maçında iki oyuncu aynı dört soruyu oynar; "Soru
  // değiştir" bunu bozuyor, jetonla 50/50 maçı parayla kazandırıyordu.
  testWidgets('turnuva maçında (versus bandı) joker satırı yok', (
    tester,
  ) async {
    final repository = _CountingRepository(500);
    freshMockRepository();
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.quiz_tutorial.seen': true,
    });
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: const [_question],
          enableTimer: false,
          versusBannerText: 'Yarı Final · Rakip: Rojda',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(WildcardButton), findsNothing);
    expect(
      find.byKey(const ValueKey('quiz-collapsed-wildcard-pill')),
      findsNothing,
    );
  });

  testWidgets('jetonsuz yeni oyuncu: joker açık, ipucu yazar, kullanımda '
      'spend_coins çağrılmaz ve bakiye düşmez', (tester) async {
    final repository = _CountingRepository(8);
    await pumpQuiz(tester, repository);

    // Vay 2A: hak TEK satırda yazar; jokerlerde "Bedava" tekrarı yok.
    expect(find.byKey(const ValueKey('quiz-free-wildcard-chip')), findsNothing);
    expect(
      find.byKey(const ValueKey('quiz-free-wildcard-hint')),
      findsOneWidget,
    );
    expect(find.textContaining('Bugün 1 joker bedava'), findsOneWidget);
    expect(find.byKey(const ValueKey('joker-free-label')), findsNothing);
    expect(find.text('Bedava'), findsNothing);
    expect(find.byKey(const ValueKey('joker-free-badge')), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp('50/50 • Bedava')),
      findsOneWidget,
      reason: 'ekran okuyucu hakkı jokerde duyar',
    );
    expect(
      find.byKey(const ValueKey('quiz-collapsed-wildcard-pill')),
      findsNothing,
      reason: 'kilitli çubuk yerine joker satırı',
    );
    expect(button(tester, WildcardType.fiftyFifty).isEnabled, isTrue);

    await tap(tester, WildcardType.fiftyFifty);

    expect(repository.spends, isEmpty, reason: 'bedava: sunucuya gitmez');
    expect(find.text('8'), findsOneWidget, reason: 'bakiye 8 kalır');
    expect(find.byKey(const ValueKey('quiz-free-wildcard-hint')), findsNothing);
    // Hak yazıldı: aynı gün ikinci kez verilmez.
    expect(await FreeWildcardStore.isAvailable(), isFalse);
  });

  testWidgets('ikinci joker ücretli: normal jeton düşer', (tester) async {
    final repository = _CountingRepository(500);
    await pumpQuiz(tester, repository);

    await tap(tester, WildcardType.fiftyFifty);
    expect(repository.spends, isEmpty);

    await tap(tester, WildcardType.audience);
    expect(repository.spends, [WildcardType.audience.coinCost]);
    expect(
      find.text('${500 - WildcardType.audience.coinCost}'),
      findsOneWidget,
    );
  });

  testWidgets('hak bugün tükenmişse ipucu yok, joker ücretli', (tester) async {
    final repository = _CountingRepository(500);
    await pumpQuiz(
      tester,
      repository,
      freeDay: FreeWildcardStore.dayKey(DateTime.now()),
    );

    expect(find.byKey(const ValueKey('quiz-free-wildcard-hint')), findsNothing);
    // Hak bittiyse normal fiyatlar: "Bedava" yazmaz.
    expect(find.text('Bedava'), findsNothing);
    expect(find.text('${WildcardType.fiftyFifty.coinCost}'), findsOneWidget);
    await tap(tester, WildcardType.fiftyFifty);
    expect(repository.spends, [WildcardType.fiftyFifty.coinCost]);
  });

  testWidgets('dünden kalan kayıt hakkı yeniler (yeni gün)', (tester) async {
    final repository = _CountingRepository(8);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await pumpQuiz(
      tester,
      repository,
      freeDay: FreeWildcardStore.dayKey(yesterday),
    );

    // Vay 2A: hak TEK satırda yazar; jokerlerde "Bedava" tekrarı yok.
    expect(find.byKey(const ValueKey('quiz-free-wildcard-chip')), findsNothing);
    expect(
      find.byKey(const ValueKey('quiz-free-wildcard-hint')),
      findsOneWidget,
    );
    expect(find.textContaining('Bugün 1 joker bedava'), findsOneWidget);
    expect(find.byKey(const ValueKey('joker-free-label')), findsNothing);
    expect(find.text('Bedava'), findsNothing);
    expect(find.byKey(const ValueKey('joker-free-badge')), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp('50/50 • Bedava')),
      findsOneWidget,
      reason: 'ekran okuyucu hakkı jokerde duyar',
    );
    await tap(tester, WildcardType.fiftyFifty);
    expect(repository.spends, isEmpty);
  });

  // Mağaza joker paketi (2026-10-27): bedava hak bittiyse joker önce
  // stoktan ödenir; jeton düşmez, sunucuya gitmez, stok bir azalır.
  testWidgets('joker stoğu: jetonsuzken joker açık, stoktan düşer', (
    tester,
  ) async {
    final repository = _CountingRepository(8);
    await pumpQuiz(
      tester,
      repository,
      freeDay: FreeWildcardStore.dayKey(DateTime.now()),
      jokerStock: 2,
    );

    expect(find.textContaining('Stokta 2 joker'), findsWidgets);
    expect(button(tester, WildcardType.fiftyFifty).isEnabled, isTrue);

    await tap(tester, WildcardType.fiftyFifty);

    expect(repository.spends, isEmpty, reason: 'paket parası zaten alındı');
    expect(find.text('8'), findsOneWidget, reason: 'bakiye 8 kalır');
    expect(await JokerStockStore.count(), 1);
  });

  testWidgets('W1: kısa joker etiketleri ≥ 12 sp, bedava hak tek satırda', (
    tester,
  ) async {
    await pumpQuiz(tester, _CountingRepository(8));
    final names = [
      for (final e in find.byKey(const ValueKey('joker-name')).evaluate())
        e.widget as Text,
    ];
    expect(names.map((n) => n.data), [
      '50/50',
      'İpucu',
      'Çift cevap',
      'Değiştir',
    ]);
    for (final n in names) {
      expect(n.style!.fontSize, greaterThanOrEqualTo(12));
    }
    // Vay 2A: bedava hakta jokerde fiyat hapı yok; tek satır ipucu ≥ 12 sp.
    expect(find.byKey(const ValueKey('joker-free-label')), findsNothing);
    final hint = tester.widget<Text>(
      find.byKey(const ValueKey('quiz-free-wildcard-hint')),
    );
    expect(hint.style!.fontSize, greaterThanOrEqualTo(12));
  });
}
