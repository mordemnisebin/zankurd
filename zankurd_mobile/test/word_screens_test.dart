// ignore_for_file: prefer_const_constructors
// (kapsam testi: aynı widget örneği yeniden çizilmesin diye const değil)
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/data/local_data_storage.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/word_list_store.dart';
import 'package:zankurd_mobile/src/screens/learner_lexicon_screen.dart';
import 'package:zankurd_mobile/src/screens/my_words_screen.dart';
import 'package:zankurd_mobile/src/screens/word_drill_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/widgets/lexicon_speak_button.dart';
import 'package:zankurd_mobile/src/widgets/pronunciation_sheet.dart';
import 'package:zankurd_mobile/src/widgets/word_save_button.dart';

import 'support/widget_test_helpers.dart';

class _FailOnceRandom implements math.Random {
  final math.Random _delegate = math.Random(3);
  bool fail = true;

  @override
  int nextInt(int max) {
    if (fail) {
      fail = false;
      throw StateError('question generation failed');
    }
    return _delegate.nextInt(max);
  }

  @override
  bool nextBool() => _delegate.nextBool();

  @override
  double nextDouble() => _delegate.nextDouble();
}

/// "Kelimelerim", kelime tekrarı ve çift yönlü sözlük ekranları (2026-10-24).
///
/// ## Kusur
///
/// Yeni ekranlar Kurmancî dizeler (%30 daha uzun) ve büyük yazıyla en dar
/// telefonda (320 dp, %200 yazı) sınanmadan gönderilirse düğme satırları ve
/// kart başlıkları sessizce taşar.
///
/// ## Niçin sessiz kalırdı
///
/// Taşma yalnız dar ekran + büyük yazı + uzun dizenin üçü birleşince oluşur;
/// geliştirme cihazında ve varsayılan testte hiçbiri yoktur.
///
/// ## Kural
///
/// Her yeni ekran 320 dp genişlikte, %200 yazıyla, hem Türkçe hem Kurmancî
/// açılır ve `takeException` boş kalır; ek olarak akışlar (kaydet, ara,
/// tekrar et) çalışır.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WordListStore.resetInstance();
    LocalProgressScope.debugReset();
  });

  tearDown(() {
    WordListStore.resetInstance();
    LocalProgressScope.debugReset();
  });

  Future<void> pumpAt(
    WidgetTester tester,
    Widget screen, {
    double width = 390,
    double scale = 1,
    LanguageProviderKind lang = LanguageProviderKind.tr,
  }) async {
    tester.view.devicePixelRatio = 3.0;
    // 2026-10-29 vay 2B: üstteki tekrar kahramanı (maskot + ustalık çubuğu
    // + tek turuncu düğme) ve iki pratik karosu listeyi aşağı itti; satır
    // bekçileri tembel listenin ilk kelimelerini görebilsin diye yüzey 1400.
    // Taşma bekçisi için belirleyici olan genişliktir (320).
    tester.view.physicalSize = Size(width, 1400) * 3;
    addTearDown(tester.view.reset);
    // Önceki dilin durumu (State) yeni dil turuna sızmasın.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      testShell(
        languageProvider: lang == LanguageProviderKind.ku
            ? kurmanciLang()
            : turkishLang(),
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: screen,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<WordListStore> seededStore(List<String> ids, {DateTime? at}) async {
    final store = await WordListStore.load(storage: InMemoryDataStorage());
    final base = at ?? DateTime.now().subtract(const Duration(days: 1));
    for (var i = 0; i < ids.length; i++) {
      await store.add(ids[i], now: base.add(Duration(minutes: i)));
    }
    return store;
  }

  testWidgets(
    'kelime tekrarında yükleme hatası tamamlandı sayılmaz; yeniden denenir',
    (tester) async {
      final store = await seededStore(['rojbas']);
      final random = _FailOnceRandom();
      await pumpAt(tester, WordDrillScreen(store: store, random: random));

      expect(
        find.byKey(const ValueKey('word-review-load-error')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('word-review-empty')), findsNothing);
      expect(find.byKey(const ValueKey('word-review-done')), findsNothing);

      await tester.tap(find.text('Tekrar dene'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey('word-review-load-error')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('word-review-prompt')), findsOneWidget);
    },
  );

  group('sözlük yön seçimi', () {
    testWidgets('Türkçe -> Kurmancî: kapı yazınca Derî ilk sırada', (
      tester,
    ) async {
      await pumpAt(tester, const LearnerLexiconScreen());
      await tester.tap(find.byKey(const ValueKey('lexicon-dir-tr-ku')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('lexicon-search-field')),
        'KAPI',
      );
      await tester.pump();

      final first = LearnerLexicon.searchByMeaning('kapı').first;
      expect(first.termKu, 'Derî');
      final list = tester.widget<ListView>(
        find.byKey(const ValueKey('lexicon-results-list')),
      );
      expect(list.semanticChildCount ?? 1, greaterThan(0));
      expect(find.byKey(ValueKey('lexicon-entry-${first.id}')), findsOneWidget);
      // İlk kart en üsttedir.
      final firstTop = tester
          .getTopLeft(find.byKey(ValueKey('lexicon-entry-${first.id}')))
          .dy;
      final other = LearnerLexicon.searchByMeaning('kapı')[1];
      final otherFinder = find.byKey(ValueKey('lexicon-entry-${other.id}'));
      if (otherFinder.evaluate().isNotEmpty) {
        expect(tester.getTopLeft(otherFinder).dy, greaterThan(firstTop));
      }
    });

    testWidgets('Kurmancî -> Türkçe varsayılandır ve Kurmancî terimle bulur', (
      tester,
    ) async {
      await pumpAt(tester, const LearnerLexiconScreen());
      await tester.enterText(
        find.byKey(const ValueKey('lexicon-search-field')),
        'derî',
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('lexicon-entry-q-deri')), findsWidgets);
    });

    testWidgets('320 dp + %200 yazıda iki dilde taşmaz', (tester) async {
      for (final lang in LanguageProviderKind.values) {
        await pumpAt(
          tester,
          const LearnerLexiconScreen(initialQuery: 'Rojbaş'),
          width: 320,
          scale: 2,
          lang: lang,
        );
        await tester.tap(find.byKey(const ValueKey('lexicon-dir-tr-ku')));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$lang');
      }
    });
  });

  group('kelime listesine ekle', () {
    testWidgets('sözlük kartındaki yer işareti kelimeyi kaydeder/çıkarır', (
      tester,
    ) async {
      await pumpAt(tester, const LearnerLexiconScreen(initialQuery: 'Rojbaş'));
      await tester.pump(const Duration(milliseconds: 100));
      final button = find.byKey(const ValueKey('word-save-rojbas'));
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pump();
      final store = await WordListStore.load();
      expect(store.contains('rojbas'), isTrue);
      expect(find.bySemanticsLabel('Listemden çıkar'), findsOneWidget);

      await tester.tap(button);
      await tester.pump();
      expect(store.contains('rojbas'), isFalse);
      expect(find.bySemanticsLabel('Listeme ekle'), findsOneWidget);
    });
  });

  group('kelime listesine ekle: kullanıcı değişimi', () {
    testWidgets('kapsam değişince düğme yeni kullanıcının listesini gösterir', (
      tester,
    ) async {
      LocalProgressScope.bind('kullanici-1');
      final first = await WordListStore.load();
      await first.add('rojbas');
      await pumpAt(tester, WordSaveButton(entryId: 'rojbas'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.bySemanticsLabel('Listemden çıkar'), findsOneWidget);

      LocalProgressScope.bind('kullanici-2');
      await tester.pumpWidget(
        testShell(child: WordSaveButton(entryId: 'rojbas')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.bySemanticsLabel('Listeme ekle'), findsOneWidget);
    });
  });

  group('Kelimelerim', () {
    testWidgets('boş liste boş durum gösterir', (tester) async {
      final store = await WordListStore.load(storage: InMemoryDataStorage());
      await pumpAt(
        tester,
        MyWordsScreen(repository: MockZanKurdRepository(), store: store),
      );
      expect(find.byKey(const ValueKey('my-words-empty')), findsOneWidget);
      expect(find.text('Henüz kelime yok'), findsOneWidget);
    });

    // 2026-10-25: CSV paylaş düğmesi yalnız kelime varken görünür; boş
    // listede düğme yoktur (paylaşılacak bir şey yok).
    testWidgets('paylaş düğmesi yalnız kelime varken çıkar', (tester) async {
      final empty = await WordListStore.load(storage: InMemoryDataStorage());
      await pumpAt(
        tester,
        MyWordsScreen(repository: MockZanKurdRepository(), store: empty),
      );
      expect(find.byKey(const ValueKey('my-words-share')), findsNothing);

      final store = await seededStore(['rojbas']);
      await pumpAt(
        tester,
        MyWordsScreen(repository: MockZanKurdRepository(), store: store),
      );
      expect(find.byKey(const ValueKey('my-words-share')), findsOneWidget);
    });

    testWidgets('sayılar, tek Tekrar kartı ve kutu görünür', (tester) async {
      final store = await seededStore(['rojbas', 'evarbas', 'sevbas']);
      await store.recordReview('sevbas', correct: true);
      await pumpAt(
        tester,
        MyWordsScreen(repository: MockZanKurdRepository(), store: store),
      );

      expect(find.text('3 kelime'), findsOneWidget);
      // Tek giriş: eski kelime-yalnız kartı ("Bugünkü tekrar" + Başla)
      // gitti; yerinde birleşik "Tekrar · bugün N" kartı durur.
      expect(find.text('Tekrar · bugün 2'), findsOneWidget);
      expect(find.byKey(const ValueKey('todays-review-card')), findsOneWidget);
      expect(find.text('Bugünkü tekrar'), findsNothing);
      expect(find.byKey(const ValueKey('my-words-review-start')), findsNothing);
      // 2026-10-28 K13 (eski karar geçersiz): "Kutu n/5" yazısı kalktı; kutu
      // 5 küçük noktayla gösterilir (dolu nokta sayısı = kutu), sayı yalnız
      // ekran okuyucu etiketinde yaşar.
      expect(find.textContaining(RegExp(r'Kutu \d/5')), findsNothing);
      int filled(String id) => find
          .descendant(
            of: find.byKey(ValueKey('my-word-mastery-$id')),
            matching: find.byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.endsWith('-on'),
            ),
          )
          .evaluate()
          .length;
      expect(filled('sevbas'), 2);
      expect(filled('rojbas'), 1);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('my-word-mastery-rojbas')),
          matching: find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('mastery-dot-'),
          ),
        ),
        findsNWidgets(5),
      );
    });

    // 2026-10-28 K13: satırda yalnız ses + kaydet; mikrofon kelime ayrıntısında
    // (balon) ve çalışmada. Vadesi gelen kelime küçük yeşil "Tekrar zamanı"
    // çipi taşır ("Hazır" kalktı).
    testWidgets('satırda mikrofon yok; vade çipi "Tekrar zamanı"', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final store = await seededStore(['rojbas', 'evarbas']);
      await pumpAt(
        tester,
        MyWordsScreen(repository: MockZanKurdRepository(), store: store),
      );
      final row = find.byKey(const ValueKey('my-word-rojbas'));
      expect(
        find.descendant(of: row, matching: find.byType(PronunciationButton)),
        findsNothing,
      );
      expect(
        find.descendant(of: row, matching: find.byIcon(AppIcons.microphone)),
        findsNothing,
      );
      expect(
        find.descendant(of: row, matching: find.byType(LexiconSpeakButton)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.byType(WordSaveButton)),
        findsOneWidget,
      );
      expect(find.text('Hazır'), findsNothing);
      expect(
        find.descendant(of: row, matching: find.text('Tekrar zamanı')),
        findsOneWidget,
      );
      // Kutu bilgisi kaybolmadı: kartın ekran okuyucu etiketinde.
      expect(find.bySemanticsLabel(RegExp(r'Kutu 1/5')), findsWidgets);

      // Mikrofon artık ayrıntı balonunda.
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('lexicon-entry-sheet')),
          matching: find.byType(PronunciationButton),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('kelime çıkarılınca satır kaybolur ve sayı düşer', (
      tester,
    ) async {
      final store = await seededStore(['rojbas', 'evarbas']);
      await pumpAt(
        tester,
        MyWordsScreen(repository: MockZanKurdRepository(), store: store),
      );
      await tester.tap(find.byKey(const ValueKey('word-save-rojbas')));
      await tester.pump();
      expect(find.byKey(const ValueKey('my-word-rojbas')), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('my-words-count'))).data,
        '1 kelime',
      );
    });

    testWidgets('vadesi gelen yoksa "Bugün tekrar yok" durumu', (tester) async {
      final store = await seededStore(['rojbas'], at: DateTime.now());
      await store.recordReview('rojbas', correct: true);
      await pumpAt(
        tester,
        MyWordsScreen(repository: MockZanKurdRepository(), store: store),
      );
      expect(find.text('Bugün tekrar yok'), findsOneWidget);
      expect(find.byKey(const ValueKey('todays-review-card')), findsNothing);
    });

    testWidgets('320 dp + %200 yazıda iki dilde taşmaz', (tester) async {
      final store = await seededStore([
        for (final e in LearnerLexicon.entries.take(6)) e.id,
      ]);
      for (final lang in LanguageProviderKind.values) {
        await pumpAt(
          tester,
          MyWordsScreen(repository: MockZanKurdRepository(), store: store),
          width: 320,
          scale: 2,
          lang: lang,
        );
        expect(tester.takeException(), isNull, reason: '$lang');
      }
    });

    testWidgets('Tekrar kartı tek oturumu açar', (tester) async {
      final store = await seededStore(['rojbas', 'evarbas']);
      await pumpAt(
        tester,
        MyWordsScreen(repository: MockZanKurdRepository(), store: store),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('todays-review-card')),
      );
      await tester.tap(find.byKey(const ValueKey('todays-review-card')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('word-review-term')), findsOneWidget);
    });
  });

  group('kelime tekrarı oturumu', () {
    String optionText(WidgetTester tester, int index) {
      final finder = find.descendant(
        of: find.byKey(ValueKey('word-review-option-$index')),
        matching: find.byType(Text),
      );
      // Şık çubuğunda ilk Text harf karosudur (A/B/C/D); anlam ikincidir.
      return tester.widget<Text>(finder.at(1)).data!;
    }

    testWidgets('doğru cevap kutuyu artırır, yanlış 1e düşürür, skor yazılır', (
      tester,
    ) async {
      final store = await seededStore(['rojbas', 'evarbas']);
      await pumpAt(
        tester,
        WordDrillScreen(store: store, random: math.Random(3)),
      );

      // 1. soru: Rojbaş -> doğru şıkkı seç.
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('word-review-term')))
            .data,
        'Rojbaş',
      );
      await tester.tap(
        find.text(LearnerLexicon.byId('rojbas')!.meaningTr).first,
      );
      await tester.pump();
      expect(find.text('Doğru'), findsOneWidget);
      expect(store.wordFor('rojbas')!.box, 2);
      await tester.tap(find.byKey(const ValueKey('word-review-next')));
      await tester.pump();

      // 2. soru: Êvarbaş -> doğru olmayan bir şık.
      final right = LearnerLexicon.byId('evarbas')!.meaningTr;
      final wrongIndex = [
        for (var i = 0; i < 4; i++) i,
      ].firstWhere((i) => optionText(tester, i) != right);
      await tester.tap(find.byKey(ValueKey('word-review-option-$wrongIndex')));
      await tester.pump();
      expect(find.text('Yanlış'), findsOneWidget);
      expect(store.wordFor('evarbas')!.box, 1);
      // Yanlış kelime oturum sonunda bir kez daha sorulur (2026-10-25):
      // bu yüzden 2. soru son değil, düğme hâlâ "Sonraki".
      expect(find.text('Tamamla'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('word-review-next')));
      await tester.pump();

      // Tekrar sorusu: cevap verilir, kutu YAZILMAZ, skor değişmez.
      await tester.tap(find.byKey(const ValueKey('word-review-option-0')));
      await tester.pump();
      expect(store.wordFor('evarbas')!.box, 1);
      expect(find.text('Tamamla'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('word-review-next')));
      await tester.pump();

      expect(find.byKey(const ValueKey('word-review-done')), findsOneWidget);
      expect(find.text('Doğru: 1/2'), findsOneWidget);
      // İki kelime de tekrar edildi: bugün vadesi gelen kalmadı.
      expect(store.dueCount(), 0);
    });

    testWidgets(
      'kayıt yazılamazsa ilerleme durur, yeniden dene devam ettirir',
      (tester) async {
        final flaky = _FlakyStorage();
        final store = await WordListStore.load(storage: flaky);
        await store.add(
          'rojbas',
          now: DateTime.now().subtract(const Duration(days: 1)),
        );
        flaky.fail = true;
        await pumpAt(
          tester,
          WordDrillScreen(store: store, random: math.Random(3)),
        );
        await tester.tap(
          find.text(LearnerLexicon.byId('rojbas')!.meaningTr).first,
        );
        await tester.pump();
        await tester.pump();
        expect(
          find.byKey(const ValueKey('word-review-save-failed')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('word-review-next')), findsNothing);

        flaky.fail = false;
        await tester.tap(find.byKey(const ValueKey('word-review-retry')));
        await tester.pump();
        await tester.pump();
        expect(
          find.byKey(const ValueKey('word-review-save-failed')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('word-review-next')), findsOneWidget);
        WordListStore.resetInstance();
        final restored = await WordListStore.load(storage: flaky);
        expect(restored.wordFor('rojbas')!.box, 2);
      },
    );

    testWidgets('cevaptan sonra şıklar kilitlenir', (tester) async {
      final store = await seededStore(['rojbas']);
      await pumpAt(
        tester,
        WordDrillScreen(store: store, random: math.Random(3)),
      );
      await tester.tap(
        find.text(LearnerLexicon.byId('rojbas')!.meaningTr).first,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('word-review-option-0')));
      await tester.pump();
      expect(store.wordFor('rojbas')!.reviews, 1);
    });

    testWidgets('vadesi gelen kelime yoksa boş durum', (tester) async {
      final store = await seededStore(['rojbas'], at: DateTime.now());
      await store.recordReview('rojbas', correct: true);
      await pumpAt(tester, WordDrillScreen(store: store));
      expect(find.byKey(const ValueKey('word-review-empty')), findsOneWidget);
    });

    testWidgets('oturum en çok 10 soru', (tester) async {
      final store = await seededStore([
        for (final e in LearnerLexicon.entries.take(14)) e.id,
      ]);
      await pumpAt(
        tester,
        WordDrillScreen(store: store, random: math.Random(1)),
      );
      expect(find.text('1/10'), findsOneWidget);
    });

    testWidgets('320 dp + %200 yazıda iki dilde taşmaz (soru, sonuç)', (
      tester,
    ) async {
      for (final lang in LanguageProviderKind.values) {
        WordListStore.resetInstance();
        final store = await seededStore(['rojbas']);
        await pumpAt(
          tester,
          WordDrillScreen(store: store, random: math.Random(2)),
          width: 320,
          scale: 2,
          lang: lang,
        );
        expect(tester.takeException(), isNull, reason: 'soru $lang');
        await tester.ensureVisible(
          find.byKey(const ValueKey('word-review-option-0')),
        );
        await tester.tap(find.byKey(const ValueKey('word-review-option-0')));
        await tester.pump();
        await tester.ensureVisible(
          find.byKey(const ValueKey('word-review-next')),
        );
        await tester.tap(find.byKey(const ValueKey('word-review-next')));
        await tester.pump();
        // Yanlış cevapta kelime oturum sonunda bir kez daha sorulur.
        if (find.byKey(const ValueKey('word-review-done')).evaluate().isEmpty) {
          await tester.ensureVisible(
            find.byKey(const ValueKey('word-review-option-0')),
          );
          await tester.tap(find.byKey(const ValueKey('word-review-option-0')));
          await tester.pump();
          await tester.ensureVisible(
            find.byKey(const ValueKey('word-review-next')),
          );
          await tester.tap(find.byKey(const ValueKey('word-review-next')));
          await tester.pump();
        }
        expect(find.byKey(const ValueKey('word-review-done')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'sonuç $lang');
      }
    });
  });
}

/// Test içi dil seçici (iki arayüz dili).
enum LanguageProviderKind { tr, ku }

class _FlakyStorage extends InMemoryDataStorage {
  bool fail = false;

  @override
  Future<bool> setString(String key, String value) async {
    if (fail) return false;
    return super.setString(key, value);
  }
}
