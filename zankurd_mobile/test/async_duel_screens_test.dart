// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
/// Sırayla düello (async 1v1) EKRANLARI.
///
/// ## Kusur
///
/// Veri katmanı (`ZanKurdRepository.startAsyncDuel`/`answerAsyncDuel`/
/// `loadMyAsyncDuels`/`claimAsyncDuelXp`) ve sözleşmesi
/// (`lib/src/models/async_duel.dart`) `test/async_duel_repository_test.dart`
/// ile baştan sona test edilmiş hâlde duruyordu, ama hiçbir ekran onu
/// ÇAĞIRMIYORDU: Play Hub'da "Sırayla düello" diye bir kart yoktu; oyuncu
/// düello açamıyor, cevaplayamıyor, sonucunu göremiyordu. Bir özellik
/// yalnız arka uçta var olduğunda oyuncu için hiç yok demektir.
///
/// ## Niçin sessiz kalırdı
///
/// `dart analyze` ve mevcut testlerin hiçbiri "Play Hub'da bu kart eksik"
/// diyemezdi — eksik olan çalışma zamanı hatası değil, hiç yazılmamış bir
/// arayüzdü. Bu dosya dört yeni ekranı (Play Hub kartı + kutu, oyun,
/// sonuç, tam liste) widget testleriyle sınar: kilit durumu, creator/
/// opponent akışı, süre dolumu, yarım bırakıp çıkma, "Too many open
/// duels" hatası ve okunmamış sonuç rozeti.
///
/// İnceleme bekçileri (ana ajan, 2026-09-27):
/// - Gönderimi ağ hatasıyla düşen cevap yerelde "cevaplandı" sayılıyordu;
///   oyuncu o anda çıkınca soru sunucuya hiç gitmiyor, düello 6/7'de
///   sonsuza dek yarım kalıyordu. Artık çıkış onu oyuncunun KENDİ
///   seçimiyle yeniden gönderir.
/// - Bilinmeyen sonuçta (son cevabın yanıtı ağda kayboldu) ekran "0/7"
///   uyduruyordu.
/// - Liste yeniden yüklenirken satırların yerini yükleme çarkı alıyordu;
///   kabuk her sekme dönüşünde tazeleyince sayfa zıplardı.
/// - Sunucu göçü uygulanmadan kart görünürse her dokunuş hatayla düşer;
///   kart `kAsyncDuelEnabled` bayrağına bağlı.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/feature_flags.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/providers/remote_availability.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_inbox.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_result_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

/// `startAsyncDuel`i her zaman "Too many open duels" ile reddeden sahte
/// depo — sunucunun beş açık düello tavanına çarpan gerçek durumu taklit
/// eder (bkz. `ZanKurdRepository.startAsyncDuel` belgesi).
class _TooManyOpenDuelsRepository extends MockZanKurdRepository {
  @override
  Future<AsyncDuelStart> startAsyncDuel({String? category}) async {
    throw StateError('Too many open duels');
  }
}

/// İkinci sorunun İLK gönderimini ağ hatasıyla düşüren sahte depo; her
/// cevap çağrısını (index, seçim) olarak kaydeder.
class _FailSecondAnswerOnceRepository extends MockZanKurdRepository {
  final calls = <(int, String)>[];
  bool _failed = false;

  @override
  Future<AsyncDuelAnswer> answerAsyncDuel({
    required String duelId,
    required int questionIndex,
    required String choice,
    required int responseMs,
  }) {
    calls.add((questionIndex, choice));
    if (questionIndex == 1 && !_failed) {
      _failed = true;
      throw StateError('network down');
    }
    return super.answerAsyncDuel(
      duelId: duelId,
      questionIndex: questionIndex,
      choice: choice,
      responseMs: responseMs,
    );
  }
}

/// `startAsyncDuel`i hiç yanıtlamayan (yavaş bağlantı) sahte depo.
class _NeverStartsRepository extends MockZanKurdRepository {
  @override
  Future<AsyncDuelStart> startAsyncDuel({String? category}) =>
      Completer<AsyncDuelStart>().future;
}

/// Play Hub kartından düello ekranını açar; oyun ekranındaki 20 sn'lik
/// geri sayım aktif bir `Ticker` olduğu için burada KASITLI olarak
/// `pumpAndSettle` KULLANILMAZ — o, sayaç sıfıra inene kadar (20 sn'lik
/// sahte zaman) pompalamaya devam eder ve istemeden bir TIMEOUT tetikler.
Future<void> _openAsyncDuelFromHub(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('play-hub-async-duel')));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Ekrandaki ilk soruyu [optionIndex] şıkkına dokunarak cevaplar ve
/// açıklama duraklamasını (1200 ms) geçip bir sonraki soruya ilerler.
///
/// Üç adımlı pompa dizisi bu depodaki yerleşik desendir (bkz.
/// `test/gamification_custom_room_test.dart`): ilk `pump()` sunucu
/// cevabının (sahte depoda gerçek gecikmesiz bir mikro görev) işlenmesini,
/// süreli `pump()` açıklama duraklamasının geçmesini, son `pump()` da
/// sonucun (sıradaki soru ya da sonuç ekranı) yerleşmesini sağlar.
Future<void> _answerCurrentQuestion(
  WidgetTester tester, {
  int optionIndex = 0,
}) async {
  await tester.tap(find.byKey(ValueKey('async-duel-option-$optionIndex')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1300));
  await tester.pump();
}

Text _progressText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('async-duel-progress')));

void main() {
  testWidgets('Play Hub kilit açıkken kart ve düellolarım kutusu görünür', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: PlayHubScreen(
          repository: freshMockRepository(),
          asyncDuelEnabled: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('play-hub-async-duel')), findsOneWidget);
    expect(find.text('Sırayla düello'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('play-hub-async-duel-inbox')),
      findsOneWidget,
    );
    expect(find.text('Düellolarım'), findsOneWidget);
  });

  testWidgets(
    'Play Hub kilitliyken (sunucuya ulaşılamaz) kart pasiftir ve kutu hiç çizilmez',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        testShell(
          child: PlayHubScreen(
            repository: freshMockRepository(),
            asyncDuelEnabled: true,
          ),
          remoteAvailability: RemoteAvailability(reachable: false),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const ValueKey('play-hub-async-duel'));
      expect(cardFinder, findsOneWidget);
      // 2026-09-29 Şahnê: kart artık liste satırıdır (`SahneListRow`);
      // kural aynı: kilitliyken dokunulamaz ve nedenini söyler.
      final card = tester.widget<SahneListRow>(cardFinder);
      expect(card.onTap, isNull, reason: 'kilitliyken kart dokunulamaz olmalı');
      // 2026-09-30 simülatör: neden üstteki şeritte söylenir; satır kendi
      // açıklamasını korur.
      expect(card.subtitle, isNot('Sunucuya ulaşılamadı'));
      expect(
        find.byKey(const ValueKey('play-hub-async-duel-inbox')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'creator akışı: 7 soruyu ilk şıkka dokunarak cevaplar, sonuç ekranı '
    '"turun bitti" der',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = freshMockRepository();

      await tester.pumpWidget(
        testShell(
          child: PlayHubScreen(repository: repository, asyncDuelEnabled: true),
        ),
      );
      await tester.pumpAndSettle();

      await _openAsyncDuelFromHub(tester);
      expect(find.byKey(const ValueKey('async-duel-play')), findsOneWidget);
      expect(_progressText(tester).data, '1/7');

      for (var i = 0; i < 7; i++) {
        await _answerCurrentQuestion(tester);
      }
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('async-duel-result')), findsOneWidget);
      expect(find.text('Senin turun bitti.'), findsOneWidget);
    },
  );

  testWidgets(
    'opponent akışı: bekleyen düello varken 7 cevaptan sonra sonuç hemen '
    'kesinleşir',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = freshMockRepository();
      repository.addPendingAsyncDuelForTesting(
        opponentCorrect: 0,
        opponentMs: 1,
      );

      await tester.pumpWidget(
        testShell(
          child: PlayHubScreen(repository: repository, asyncDuelEnabled: true),
        ),
      );
      await tester.pumpAndSettle();
      await _openAsyncDuelFromHub(tester);

      for (var i = 0; i < 7; i++) {
        await _answerCurrentQuestion(tester);
      }
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('async-duel-result')), findsOneWidget);
      const outcomeTexts = ['Kazandın!', 'Kaybettin…', 'Berabere!'];
      final visibleOutcomes = outcomeTexts.where(
        (text) => find.text(text).evaluate().isNotEmpty,
      );
      expect(
        visibleOutcomes,
        hasLength(1),
        reason: 'tam olarak bir sonuç başlığı görünmeli: $outcomeTexts',
      );
      expect(find.textContaining('Sen '), findsWidgets);
    },
  );

  testWidgets(
    'süre dolumu: hiçbir şıkka dokunulmazsa TIMEOUT gönderilir ve ilerleme '
    '2/7\'ye geçer',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = freshMockRepository();

      await tester.pumpWidget(
        testShell(
          child: PlayHubScreen(repository: repository, asyncDuelEnabled: true),
        ),
      );
      await tester.pumpAndSettle();
      await _openAsyncDuelFromHub(tester);
      expect(_progressText(tester).data, '1/7');

      // 20 sn'lik geri sayım + 1200 ms açıklama duraklaması: tek pompa
      // yerine ikisi ayrı ayrı ilerletilir (bkz. `_answerCurrentQuestion`
      // üstündeki not).
      await tester.pump(const Duration(seconds: 21));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump();

      expect(_progressText(tester).data, '2/7');
    },
  );

  testWidgets(
    'çıkış: 2 soru cevaplayıp kapatınca kalan sorular TIMEOUT ile tamamlanır',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = freshMockRepository();

      await tester.pumpWidget(
        testShell(
          child: PlayHubScreen(repository: repository, asyncDuelEnabled: true),
        ),
      );
      await tester.pumpAndSettle();
      await _openAsyncDuelFromHub(tester);

      await _answerCurrentQuestion(tester);
      await _answerCurrentQuestion(tester);
      expect(_progressText(tester).data, '3/7');

      await tester.tap(find.byKey(const ValueKey('async-duel-quit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Düellodan çıkılsın mı?'), findsOneWidget);

      await tester.tap(find.text('Çık'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('play-hub-async-duel')), findsOneWidget);

      final duels = await repository.loadMyAsyncDuels();
      expect(duels, isNotEmpty);
      expect(
        duels.first.myCorrect,
        isNotNull,
        reason: 'kalan 5 soru TIMEOUT ile bitmiş olmalı',
      );
    },
  );

  testWidgets(
    '"Too many open duels" hatasında K.asyncDuelTooMany metni ve tekrar/'
    'kapat düğmeleri görünür',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        testShell(
          child: PlayHubScreen(
            repository: _TooManyOpenDuelsRepository(),
            asyncDuelEnabled: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('play-hub-async-duel')));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.text('Açık 5 düellon var. Önce sonuçlarını bekle.'),
        findsOneWidget,
      );
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(find.text('Kapat'), findsOneWidget);
    },
  );

  testWidgets(
    'inbox: bekleyen creator satırı "Rakip bekleniyor" der; tamamlanmış '
    'opponent satırı okunmamış rozet gösterir ve dokununca kalkar',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = freshMockRepository();

      // Bir CREATOR düellosu — kendi 7 sorusunu bitirir, rakip henüz
      // katılmadı: satır "Rakip bekleniyor" der.
      final creatorStart = await repository.startAsyncDuel();
      for (var i = 0; i < creatorStart.questions.length; i++) {
        await repository.answerAsyncDuel(
          duelId: creatorStart.duelId,
          questionIndex: i,
          choice: 'A',
          responseMs: 1000,
        );
      }

      // Bir OPPONENT düellosu — rakip (test) önceden "bitirilmiş"; ben
      // bitirince karşılaştırma hemen kesinleşir. Doğrudan depo üzerinden
      // kuruluyor ki bu test Play Hub'ın kendi oynanış akışını değil,
      // SADECE kutunun okunmamış rozetini ve tıklamayla temizlenmesini
      // sınasın (oynanış zaten yukarıdaki creator/opponent testlerinde).
      repository.addPendingAsyncDuelForTesting(
        opponentCorrect: 0,
        opponentMs: 1,
      );
      final opponentStart = await repository.startAsyncDuel();
      for (var i = 0; i < opponentStart.questions.length; i++) {
        await repository.answerAsyncDuel(
          duelId: opponentStart.duelId,
          questionIndex: i,
          choice: 'A',
          responseMs: 1000,
        );
      }

      await tester.pumpWidget(
        testShell(
          child: PlayHubScreen(repository: repository, asyncDuelEnabled: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rakip bekleniyor'), findsOneWidget);
      final badge = find.byKey(const ValueKey('async-duel-ready-badge'));
      expect(badge, findsOneWidget);

      await tester.tap(badge);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('async-duel-result')), findsOneWidget);

      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('async-duel-ready-badge')),
        findsNothing,
        reason: 'sonuç ekranı görülünce rozet kalkmalı',
      );
    },
  );

  testWidgets('kart varsayılanda kAsyncDuelEnabled bayrağını izler', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(child: PlayHubScreen(repository: freshMockRepository())),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('play-hub-async-duel')),
      kAsyncDuelEnabled ? findsOneWidget : findsNothing,
    );
    expect(
      find.byKey(const ValueKey('play-hub-async-duel-inbox')),
      kAsyncDuelEnabled ? findsOneWidget : findsNothing,
    );
  });

  testWidgets(
    'çıkış: gönderimi düşen cevap oyuncunun kendi seçimiyle yeniden gider',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      freshMockRepository();
      final repository = _FailSecondAnswerOnceRepository();

      await tester.pumpWidget(
        testShell(
          child: PlayHubScreen(repository: repository, asyncDuelEnabled: true),
        ),
      );
      await tester.pumpAndSettle();
      await _openAsyncDuelFromHub(tester);

      await _answerCurrentQuestion(tester);
      await tester.tap(find.byKey(const ValueKey('async-duel-option-1')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Cevap gönderilemedi.'), findsOneWidget);
      final (failedIndex, failedChoice) = repository.calls.last;
      expect(failedIndex, 1);
      expect(failedChoice, isNot('TIMEOUT'));

      await tester.tap(find.byKey(const ValueKey('async-duel-quit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Çık'));
      await tester.pump();
      await tester.pumpAndSettle();

      final resent = repository.calls
          .skip(2)
          .where((call) => call.$1 == 1)
          .toList();
      expect(resent, [(1, failedChoice)]);
      final duels = await repository.loadMyAsyncDuels();
      expect(duels.single.myCorrect, isNotNull);
    },
  );

  testWidgets('yükleme ekranı kapatılabilir (yavaş bağlantıda mahsur kalmaz)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    freshMockRepository();

    await tester.pumpWidget(
      testShell(
        child: PlayHubScreen(
          repository: _NeverStartsRepository(),
          asyncDuelEnabled: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openAsyncDuelFromHub(tester);

    await tester.tap(find.byKey(const ValueKey('async-duel-loading-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('play-hub-async-duel')), findsOneWidget);
  });

  testWidgets('bilinmeyen sonuçta skor uydurulmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: AsyncDuelResultScreen(
          repository: freshMockRepository(),
          view: AsyncDuelResultView.unknownAfterFinish('duel-x'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Senin turun bitti.'), findsOneWidget);
    expect(find.byKey(const ValueKey('async-duel-result-score')), findsNothing);
    expect(find.textContaining('/7'), findsNothing);
  });

  testWidgets('kutu tazelenirken eski satırlar kalır, yeni düello görünür', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = freshMockRepository();
    final refresh = ValueNotifier<int>(0);
    addTearDown(refresh.dispose);

    Future<void> finishCreatorDuel() async {
      final start = await repository.startAsyncDuel();
      for (var i = 0; i < start.questions.length; i++) {
        await repository.answerAsyncDuel(
          duelId: start.duelId,
          questionIndex: i,
          choice: 'A',
          responseMs: 1000,
        );
      }
    }

    await finishCreatorDuel();
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: AsyncDuelInboxSection(
            repository: repository,
            refreshSignal: refresh,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rakip bekleniyor'), findsOneWidget);

    await finishCreatorDuel();
    refresh.value++;
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Rakip bekleniyor'), findsWidgets);

    await tester.pumpAndSettle();
    expect(find.text('Rakip bekleniyor'), findsNWidgets(2));
  });

  testWidgets('eşit doğruda süreyle kazanılan sonuç nedenini söyler', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    AsyncDuelSummary summary({required int theirs}) => AsyncDuelSummary(
      duelId: 'd-$theirs',
      status: AsyncDuelStatus.completed,
      role: AsyncDuelRole.opponent,
      opponentName: 'Rojda',
      myCorrect: 3,
      opponentCorrect: theirs,
      outcome: AsyncDuelOutcome.win,
      createdAt: DateTime.utc(2026, 9, 27),
      seen: true,
    );

    for (final (theirs, expected) in [(3, findsOneWidget), (1, findsNothing)]) {
      await tester.pumpWidget(
        testShell(
          child: AsyncDuelResultScreen(
            key: ValueKey(theirs),
            repository: freshMockRepository(),
            view: AsyncDuelResultView.fromSummary(summary(theirs: theirs)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('async-duel-result-tiebreak')),
        expected,
        reason: 'rakip $theirs doğru',
      );
    }
  });

  // 2026-09-29 doğallık: tamamlanan düellonun sonucunda iki amblem üst
  // üsteydi — taç/bayrak/terazi ve altında iki avatarlı VS amblemi. Kare
  // avatarlarda "VS" iki karonun arasına sıkışıp üstlerine biniyordu;
  // avatarların taşıdığı bilgi (sen ve rakibin baş harfi) zaten skor
  // satırında yazılı. Tek amblem kalır: sonucun kendisi.
  testWidgets('düello sonucunda tek amblem: sonuç, VS yok', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final outcome in AsyncDuelOutcome.values) {
      await tester.pumpWidget(
        testShell(
          child: AsyncDuelResultScreen(
            key: ValueKey(outcome),
            repository: freshMockRepository(),
            view: AsyncDuelResultView.fromSummary(
              AsyncDuelSummary(
                duelId: 'd-${outcome.name}',
                status: AsyncDuelStatus.completed,
                role: AsyncDuelRole.opponent,
                opponentName: 'Rojda',
                myCorrect: 2,
                opponentCorrect: 0,
                outcome: outcome,
                createdAt: DateTime.utc(2026, 9, 27),
                seen: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SahneVsEmblem), findsNothing, reason: '$outcome');
      final crowns = tester
          .widgetList<SahneGlyph>(find.byType(SahneGlyph))
          .where((g) => g.kind == SahneGlyphKind.crown);
      expect(
        crowns.length,
        outcome == AsyncDuelOutcome.win ? 1 : 0,
        reason: '$outcome',
      );
      expect(find.textContaining('Rojda'), findsWidgets, reason: '$outcome');
    }
  });
}
