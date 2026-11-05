import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/material_locales.dart';

/// 1.2 (Pro denetimi 2026-11-05): Kurmancî seçilince Flutter'ın kendi
/// metinleri (saat seçici "Tamam / İptal", iOS "Kopyala / Yapıştır") Türkçe
/// kalıyordu, çünkü `locale` sabit `tr` ve desteklenen liste yalnız `tr`'ydi.
/// Sessiz kaldı: Türkçe metin de "bir dil"dir, hiçbir test/hata yoktu ve
/// Türkçe kullanıcı sorunu hiç görmez. Bu bekçi her iki yerelin de gerçek
/// temsilci zincirinden çözüldüğünü ve Türkçe'nin bozulmadığını sabitler.
Future<(MaterialLocalizations, CupertinoLocalizations)> _resolve(
  WidgetTester tester,
  Locale locale,
) async {
  late MaterialLocalizations material;
  late CupertinoLocalizations cupertino;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppMaterialLocales.supported,
      localizationsDelegates: AppMaterialLocales.delegates,
      home: Builder(
        builder: (context) {
          material = MaterialLocalizations.of(context);
          cupertino = CupertinoLocalizations.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (material, cupertino);
}

void main() {
  testWidgets('Kurmancî: Material düğme ve saat seçici metinleri Kurmancî', (
    tester,
  ) async {
    final (m, _) = await _resolve(tester, AppMaterialLocales.kurmanji);
    expect(m.okButtonLabel, 'Temam');
    expect(m.cancelButtonLabel, 'Betal bike');
    expect(m.copyButtonLabel, 'Kopî bike');
    expect(m.pasteButtonLabel, 'Pêve bike');
    expect(m.timePickerHourLabel, 'Demjimêr');
    expect(m.timePickerMinuteLabel, 'Deqe');
    // Dizgelerin hiçbiri Türkçe karşılığıyla aynı kalmamalı (sızıntı).
    final tr = (await _resolve(tester, AppMaterialLocales.turkish)).$1;
    expect(m.okButtonLabel, isNot(tr.okButtonLabel));
    expect(m.cancelButtonLabel, isNot(tr.cancelButtonLabel));
    expect(m.backButtonTooltip, isNot(tr.backButtonTooltip));
    expect(m.selectAllButtonLabel, isNot(tr.selectAllButtonLabel));
  });

  testWidgets('Kurmancî: iOS metin seçme çubuğu (Cupertino) Kurmancî', (
    tester,
  ) async {
    final (_, c) = await _resolve(tester, AppMaterialLocales.kurmanji);
    expect(c.copyButtonLabel, 'Kopî bike');
    expect(c.pasteButtonLabel, 'Pêve bike');
    expect(c.selectAllButtonLabel, 'Hemûyan hilbijêre');
  });

  testWidgets('Türkçe bozulmadı', (tester) async {
    final (m, c) = await _resolve(tester, AppMaterialLocales.turkish);
    expect(m.okButtonLabel, 'Tamam');
    expect(c.copyButtonLabel, 'Kopyala');
  });

  test('`localeFor` dil anahtarına göre yerel seçer', () {
    expect(AppMaterialLocales.localeFor(isKu: true).languageCode, 'ku');
    expect(AppMaterialLocales.localeFor(isKu: false).languageCode, 'tr');
  });

  test('bindirme tabloları boş dizge içermez', () {
    for (final table in [kKuMaterialStrings, kKuCupertinoStrings]) {
      for (final e in table.entries) {
        expect(e.value.trim(), isNotEmpty, reason: e.key);
      }
    }
  });
}
