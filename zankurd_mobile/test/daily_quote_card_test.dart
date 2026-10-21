// "Gotina rojê / Günün sözü" bekçisi.
//
// ## Kusur
//
// Ana ekrana her gün değişen bir söz kartı eklendi. Sessiz bozulma yolları:
// seçimin cihaz saat dilimine ya da dosya sırasına bağlanması (iki kullanıcı
// aynı gün farklı söz görür, derlem genişleyince herkesin sözü kayar),
// gün değişince eski sözün kalması, Kurmancî arayüzde Türkçe karşılığın
// düşmesi ya da paylaşım metninin biçiminin bozulması, dar telefonda +
// büyük yazıda taşma. Hiçbiri derleme hatası vermez.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/daily_quote_store.dart';
import 'package:zankurd_mobile/src/screens/home/daily_quote_card.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

import 'support/widget_test_helpers.dart';

DailyQuote _q(String id) => DailyQuote(
  id: id,
  ku: 'ku $id',
  tr: 'tr $id',
  source: 'kaynak $id',
  theme: 'x',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => SahneClock.now = DateTime.now);

  group('seçim', () {
    final quotes = [_q('g003'), _q('g001'), _q('g002')];

    test('aynı tarih aynı söz (saatten bağımsız)', () {
      final a = DailyQuoteStore.pick(quotes, DateTime(2026, 10, 21, 0, 5));
      final b = DailyQuoteStore.pick(quotes, DateTime(2026, 10, 21, 23, 59));
      expect(a!.id, b!.id);
    });

    test('ertesi gün farklı söz, üç gün sonra döngü', () {
      final d0 = DailyQuoteStore.pick(quotes, DateTime(2026, 10, 21))!.id;
      final d1 = DailyQuoteStore.pick(quotes, DateTime(2026, 10, 22))!.id;
      final d3 = DailyQuoteStore.pick(quotes, DateTime(2026, 10, 24))!.id;
      expect(d1, isNot(d0));
      expect(d3, d0);
    });

    test('derlemin dosya sırası seçimi değiştirmez (id sıralaması)', () {
      final day = DateTime(2026, 10, 21);
      final a = DailyQuoteStore.pick(quotes, day)!.id;
      final b = DailyQuoteStore.pick(quotes.reversed.toList(), day)!.id;
      expect(a, b);
    });

    test('boş derlem null', () {
      expect(DailyQuoteStore.pick(const []), isNull);
    });

    test('gün numarası yerel tarihten türer, DST günleri atlamaz', () {
      expect(
        DailyQuoteStore.dayNumber(DateTime(2026, 3, 30)) -
            DailyQuoteStore.dayNumber(DateTime(2026, 3, 29)),
        1,
      );
      expect(
        DailyQuoteStore.dayNumber(DateTime(2026, 10, 25, 23, 59)),
        DailyQuoteStore.dayNumber(DateTime(2026, 10, 25, 0, 1)),
      );
    });
  });

  test('gerçek derlem yüklenir, id benzersiz ve alanlar dolu', () async {
    DailyQuoteStore.resetForTest();
    final list = await DailyQuoteStore.load();
    expect(list, isNotEmpty);
    expect({for (final q in list) q.id}.length, list.length);
    for (final q in list) {
      expect(q.ku.trim(), isNotEmpty);
      expect(q.tr.trim(), isNotEmpty);
    }
    // İkinci çağrı önbellekten gelir.
    expect(identical(await DailyQuoteStore.load(), list), isTrue);
  });

  Future<void> pumpCard(
    WidgetTester t, {
    required bool ku,
    required List<DailyQuote> quotes,
    void Function(String)? onShare,
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(
      testShell(
        languageProvider: ku ? kurmanciLang() : turkishLang(),
        child: MediaQuery(
          data: MediaQueryData(
            size: t.view.physicalSize / t.view.devicePixelRatio,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: DailyQuoteCard(isKu: ku, quotes: quotes, onShare: onShare),
            ),
          ),
        ),
      ),
    );
    await t.pump();
  }

  testWidgets('Türkçe arayüz: etiket TR, söz KU tırnaklı, karşılık TR', (
    t,
  ) async {
    SahneClock.now = () => DateTime(2026, 10, 21);
    final quotes = [_q('g001'), _q('g002')];
    await pumpCard(t, ku: false, quotes: quotes);
    final expected = DailyQuoteStore.pick(quotes)!;
    expect(find.text('Günün sözü'), findsOneWidget);
    expect(find.text('„${expected.ku}“'), findsOneWidget);
    expect(find.text(expected.tr), findsOneWidget);
    expect(find.text(expected.source), findsOneWidget);
  });

  testWidgets('Kurmancî arayüz: etiket KU, Türkçe karşılık yine görünür', (
    t,
  ) async {
    SahneClock.now = () => DateTime(2026, 10, 21);
    final quotes = [_q('g001'), _q('g002')];
    await pumpCard(t, ku: true, quotes: quotes);
    final expected = DailyQuoteStore.pick(quotes)!;
    expect(find.text('Gotina rojê'), findsOneWidget);
    expect(find.text('„${expected.ku}“'), findsOneWidget);
    expect(find.text(expected.tr), findsOneWidget);
  });

  testWidgets('gün değişince bir sonraki çizimde söz değişir', (t) async {
    final quotes = [_q('g001'), _q('g002')];
    SahneClock.now = () => DateTime(2026, 10, 21, 23, 59);
    await pumpCard(t, ku: false, quotes: quotes);
    final before = DailyQuoteStore.pick(quotes)!;
    expect(find.text('„${before.ku}“'), findsOneWidget);
    SahneClock.now = () => DateTime(2026, 10, 22, 0, 1);
    await pumpCard(t, ku: false, quotes: quotes, textScale: 1.001);
    final after = DailyQuoteStore.pick(quotes)!;
    expect(after.id, isNot(before.id));
    expect(find.text('„${after.ku}“'), findsOneWidget);
  });

  testWidgets('paylaş düğmesi biçimli metni gönderir', (t) async {
    SahneClock.now = () => DateTime(2026, 10, 21);
    final shared = <String>[];
    final quotes = [_q('g001'), _q('g002')];
    await pumpCard(t, ku: false, quotes: quotes, onShare: shared.add);
    await t.tap(find.byKey(const ValueKey('home-daily-quote-share')));
    final q = DailyQuoteStore.pick(quotes)!;
    expect(shared, ['„${q.ku}“ — ${q.tr}\n${q.source}\nZanKurd · zankurd.com']);
  });

  for (final ku in [false, true]) {
    testWidgets('320 px + 2x yazıda taşma yok (ku=$ku)', (t) async {
      SahneClock.now = () => DateTime(2026, 10, 21);
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      const long = DailyQuote(
        id: 'g999',
        ku: 'Heta zimanê me hebe, em jî hene; ziman şikestî nabe û nemir e.',
        tr: 'Dilimiz var oldukça biz de varız; dil kırılmaz ve ölümsüzdür.',
        source: 'Gotina pêşiyan',
        theme: 'ziman',
      );
      await pumpCard(t, ku: ku, quotes: [long], textScale: 2);
      expect(t.takeException(), isNull);
    });
  }
}
