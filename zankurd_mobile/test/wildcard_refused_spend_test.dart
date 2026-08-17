import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/wildcard.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_wildcard_bar.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

/// Sunucu jeton harcamasını reddederse ekrandaki bakiye yalan söylememeli.
///
/// ## Kusur
///
/// Dört jokerin dördü de ücreti şöyle yazıyordu:
///
/// ```dart
/// setState(() => _coinBalance -= cost);   // iyimser düşüş
/// widget.repository.spendCoins(cost, ...).catchError((e, s) {
///   ErrorReporter.record(e, s, ...);
///   return false;                          // dönen değer HİÇ okunmuyor
/// });
/// ```
///
/// `spendCoins` sunucu reddettiğinde İSTİSNA FIRLATMAZ, yalnız `false`
/// döner — fiyat ayrışması, yetersiz sunucu bakiyesi, düşmüş oturum. O dönüş
/// hiç okunmadığı için ekran jetonların gittiğini gösteriyor, sunucuda ise
/// hiç gitmiş olmuyordu. Kullanıcı olmayan bir borcu görüyor ve bir sonraki
/// tazelemeye kadar aslında alabileceği jokeri/ürünü alamıyordu: joker
/// düğmeleri `_coinBalance < cost` ile kilitlenir (2026-08-17).
///
/// ## Niçin sessiz kaldı
///
/// Ateşle-unut çağrının hiçbir görünür sonucu yok; ne hata mesajı ne de
/// bakiye düzeltmesi. Ayrışma ancak ekonomi bozulunca fark edilirdi. Joker
/// testleri (`quiz_wildcard_availability_test`, `wildcard_test`) jokerin
/// ETKİSİNİ ölçüyor, ücretin gerçekten yazıldığını değil.
///
/// ## Ölçülen sözleşme
///
/// Reddedilirse gösterilen bakiye sunucudan yeniden okunur — tahmin
/// edilmez. Jokerin etkisi geri ALINMAZ (şıklar gizlenmiştir; geri getirmek
/// verilmiş bir şeyi elden almak, jokeri yeniden açmak ise bedava tekrar
/// olurdu) ve taşıma hatasında son bilinen bakiye korunur.
const _question = QuizQuestion(
  id: 'wildcard-refused-spend',
  category: 'Ziman',
  prompt: 'Pirtûk çi ye?',
  answers: ['Kitêb', 'Mase', 'Av', 'Mal'],
  correctAnswer: 'Kitêb',
  explanation: 'Pirtûk kitêb e.',
);

/// Sunucusu her harcamayı reddeden depo. Gerçek bakiye hiç düşmez.
class _RefusingRepository extends MockZanKurdRepository {
  _RefusingRepository({required this.serverBalance});

  final int serverBalance;
  int spendAttempts = 0;
  int balanceReads = 0;

  @override
  Future<int> loadCoinBalance() async {
    balanceReads++;
    return serverBalance;
  }

  @override
  Future<bool> spendCoins(int amount, String reason) async {
    spendAttempts++;
    return false;
  }
}

/// Bakiye ilk açılışta okunur, sonra ağ düşer.
///
/// İlk okumanın BAŞARILI olması şart: ekran açılışta bakiyeyi okuyamazsa
/// `_coinBalance` 0 kalır ve joker `_coinBalance < cost` ile kilitlenir —
/// yani harcama hiç denenmez ve test ölçmek istediği yola hiç girmez. Bu
/// tuzağa bir kez düşüldü (`spendAttempts` 0 geldi), buraya yazıldı.
class _RefusingOfflineRepository extends _RefusingRepository {
  _RefusingOfflineRepository({required super.serverBalance});

  @override
  Future<int> loadCoinBalance() async {
    final first = balanceReads == 0;
    balanceReads++;
    if (first) return serverBalance;
    throw Exception('injected: taşıma hatası');
  }
}

void main() {
  Future<void> pumpQuiz(
    WidgetTester tester,
    MockZanKurdRepository repository,
  ) async {
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

  /// Joker barındaki 50/50 düğmesine dokunur.
  Future<void> tapFiftyFifty(WidgetTester tester) async {
    final button = find.byWidgetPredicate(
      (w) => w is WildcardButton && w.type == WildcardType.fiftyFifty,
    );
    expect(button, findsOneWidget, reason: '50/50 jokeri barda bulunamadı.');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('reddedilen harcamada bakiye sunucudan yeniden okunur', (
    tester,
  ) async {
    freshMockRepository();
    // Sunucu 500 diyor ve harcamayı reddediyor: doğru sonuç, ekranın
    // 500 - 20 = 480 değil yine 500 göstermesi.
    final repository = _RefusingRepository(serverBalance: 500);
    await pumpQuiz(tester, repository);
    await tapFiftyFifty(tester);

    expect(repository.spendAttempts, 1);
    expect(
      repository.balanceReads,
      greaterThanOrEqualTo(1),
      reason:
          'Harcama reddedildi ama bakiye sunucudan yeniden okunmadı; ekran '
          'iyimser düşüşü doğruymuş gibi göstermeye devam ediyor.',
    );
    expect(
      find.text('${500 - WildcardType.fiftyFifty.coinCost}'),
      findsNothing,
      reason:
          'Ekran düşülmüş bakiyeyi gösteriyor. Sunucuda hiç düşmedi: '
          'kullanıcı olmayan bir borcu görür ve joker düğmeleri gereksiz '
          'yere kilitlenir.',
    );
  });

  testWidgets('taşıma hatasında son bilinen bakiye korunur', (tester) async {
    freshMockRepository();
    // `loadCoinBalance` çevrimdışı hatayı yukarı taşır. O anda bakiyeyi
    // sıfırlamak ya da tahmin etmek, uçak modunda "bakiyen bitti" demek
    // olurdu — düzeltme yalnız okunabildiğinde uygulanır.
    final repository = _RefusingOfflineRepository(serverBalance: 500);
    await pumpQuiz(tester, repository);
    await tapFiftyFifty(tester);

    expect(repository.spendAttempts, 1);
    expect(
      repository.balanceReads,
      greaterThanOrEqualTo(2),
      reason: 'Reddedilen harcamadan sonra bakiye yeniden okunmaya çalışılmadı.',
    );
    expect(
      tester.takeException(),
      isNull,
      reason: 'Bakiye okuması fırladı ve hata ekrana kaçtı.',
    );
  });

  testWidgets('jokerin etkisi geri alınmaz', (tester) async {
    freshMockRepository();
    final repository = _RefusingRepository(serverBalance: 500);
    await pumpQuiz(tester, repository);
    await tapFiftyFifty(tester);

    // Reddedilse bile şıklar gizli kalır ve joker yeniden açılmaz: ikisi de
    // kullanıcıya verilmiş bir şeyi geri almak ya da bedava tekrar sunmak
    // olurdu.
    final fiftyFifty = tester
        .widgetList<WildcardButton>(find.byType(WildcardButton))
        .where((b) => b.type == WildcardType.fiftyFifty)
        .toList();
    expect(fiftyFifty, hasLength(1));
    expect(
      fiftyFifty.single.isUsed,
      isTrue,
      reason:
          'Joker yeniden kullanılabilir hâle geldi; aynı soruda bedava '
          'ikinci kez çalıştırılabilir.',
    );
  });
}
