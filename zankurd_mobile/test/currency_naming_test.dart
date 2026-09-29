import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';

/// Para biriminin adı Kurmancî'de "zêr", Türkçede "jeton"dur — karışmaz.
///
/// ## Kusur
///
/// Defterde `K.coinWord` zaten vardı (`ku: Zêr`, `tr: jeton`) ama mağaza
/// ekranı iki yerde dizeyi sabit yazıyordu. Kurmancî mağazada başlık
/// "Zêrên xwe bi aqilmendî bixercîne" derken sayaç "0 coin" diyordu; aynı
/// ekranda para birimi iki ayrı adla anılıyordu.
///
/// Ayrıca bir Kurmancî dizesi Türkçe kelimeyi taşıyordu:
/// "Zincîra te ya rojane bixweber, bê coin tê parastin."
///
/// 2026-08-01'de canlı Kurmancî mağaza ekranında görüldü. Mevcut l10n
/// bekçisi bunu yakalamıyordu: o, `ku ? '…' : '…'` biçimindeki satır içi
/// çevirileri sayıyor; buradaki dize tek dilli ve koşulsuzdu.
void main() {
  test('defterdeki para birimi adları doğru', () {
    expect(Tr.of(K.coinWord, AppLanguage.ku), 'Zêr');
    expect(Tr.of(K.coinWord, AppLanguage.tr), 'jeton');
  });

  test('mağaza para birimini sabit yazmıyor', () {
    final source = File('lib/src/screens/shop_screen.dart').readAsStringSync();
    final code = source
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    expect(
      code,
      isNot(contains(r"'${item.cost} coin'")),
      reason: 'Ürün fiyatı defterden okumalı.',
    );
    expect(
      code,
      isNot(contains(r"'$_coinBalance coin'")),
      reason: 'Bakiye sayacı defterden okumalı.',
    );
    expect(code, contains('K.coinWord'));
  });

  test('para birimi kısaltması da defterden geliyor', () {
    // Dar rozetlerde fiyat "1000c" diye yazılıyordu; `c` Türkçe "coin"in
    // kısaltması ve Kurmancî ekranda anlamsız bir harf. Üç ekran aynı
    // sabiti taşıyordu: mağaza kartı, sonuç ekranı coin rozeti ve joker
    // çubuğu.
    // 2026-09-29 doğallık (G3): mağaza fiyatı artık kısaltma taşımaz —
    // sayı + jeton glifi ("720", "720j" değil; K10). Mağaza listeden
    // çıktı; mağazanın para birimini sabit yazmadığını üstteki test korur.
    expect(Tr.of(K.coinAbbrev, AppLanguage.ku), 'z');
    expect(Tr.of(K.coinAbbrev, AppLanguage.tr), 'j');

    const screens = [
      'lib/src/screens/quiz_result_screen.dart',
      'lib/src/screens/quiz/quiz_wildcard_bar.dart',
    ];
    for (final path in screens) {
      final code = File(path)
          .readAsStringSync()
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        code,
        contains('K.coinAbbrev'),
        reason: '\$path kısaltmayı defterden okumalı.',
      );
      expect(
        RegExp(r"\}c'").hasMatch(code),
        isFalse,
        reason: '\$path içinde sabit `c` son eki kalmış.',
      );
    }
  });

  test('hiçbir Kurmancî dizesi Türkçe para birimini taşımıyor', () {
    // Kural genelleşiyor: Kurmancî tarafta "coin" kelimesi hiç geçmemeli.
    final offenders = <String>[];
    for (final key in Tr.keys) {
      // `{coins}` bir yer tutucudur; kullanıcı onu görmez, gördüğü şey
      // yerine geçen sayıdır. Kural yalnız görünen metne bakar.
      final ku = Tr.of(
        key,
        AppLanguage.ku,
      ).replaceAll(RegExp(r'\{[^}]*\}'), '');
      if (RegExp(r'\bcoins?\b', caseSensitive: false).hasMatch(ku)) {
        offenders.add('$key: $ku');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Kurmancî metinde para birimi "zêr"dir:\n${offenders.join("\n")}',
    );
  });

  test('Türkçe tarafta "zêr" sızıntısı yok', () {
    // Ayna kural: Türkçe metinde Kurmancî para birimi geçmemeli.
    final offenders = <String>[];
    for (final key in Tr.keys) {
      final tr = Tr.of(
        key,
        AppLanguage.tr,
      ).replaceAll(RegExp(r'\{[^}]*\}'), '');
      if (RegExp(r'\bzêrs?\b', caseSensitive: false).hasMatch(tr)) {
        offenders.add('$key: $tr');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('Türkçe tarafta çıplak İngilizce "coin" yok', () {
    // `K.coinWord` Türkçede "jeton"; hesap silme alt metni de "jeton"
    // der. Hesap silme gövdesi ve misafir çıkış uyarısı hâlâ "coin"
    // diyordu — aynı para birimi iki adla. `{coins}` yer tutucudur.
    final offenders = <String>[];
    for (final key in Tr.keys) {
      final tr = Tr.of(
        key,
        AppLanguage.tr,
      ).replaceAll(RegExp(r'\{[^}]*\}'), '');
      if (RegExp(r'\bcoins?\b', caseSensitive: false).hasMatch(tr)) {
        offenders.add('$key: $tr');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Türkçe metinde para birimi "jeton"dur:\n${offenders.join("\n")}',
    );
  });
}
