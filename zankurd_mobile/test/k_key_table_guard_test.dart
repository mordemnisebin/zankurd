import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';

/// Her `K` sabitinin tabloda olması ve bilinmeyen anahtarın gizlenmemesi.
///
/// ## Kusur
///
/// `Tr.of` bilinmeyen anahtarı debug'da assert, release'te ham key olarak
/// yutuyordu. Ekran `quiz.report.title` gibi bir teknik dize gösterirdi;
/// testler yalnız tablodaki bilinen anahtarları okuduğu için sızıntı
/// sessizdi. `K` sınıfına eklenip tabloya yazılmayan sabit de aynı yoldan
/// kaçar.
void main() {
  test('her K sabitinin strings tablosunda karşılığı var', () {
    final source = File('lib/src/l10n/strings.dart').readAsStringSync();
    final classBody = source.substring(source.indexOf('class K {'));
    final keys = RegExp(
      r"static const \w+ = '([^']+)';",
    ).allMatches(classBody).map((m) => m.group(1)!).toList();

    expect(keys, isNotEmpty);
    final missing = [
      for (final key in keys)
        if (!Tr.keys.contains(key)) key,
    ];
    expect(
      missing,
      isEmpty,
      reason: 'Tablosuz K sabitleri: ${missing.join(", ")}',
    );
  });

  test('bilinmeyen anahtar ham key olarak yutulmaz', () {
    expect(
      () => Tr.of('no.such.key.for.guard', AppLanguage.tr),
      throwsA(anything),
    );
  });

  test('başlık metinleri tavanı aşmaz', () {
    // Kart ve AppBar başlıkları taşmasın diye kısa tutulur. Yeni uzun
    // başlık ya kırpılır ya da cümle gövdeye iner.
    const ceiling = 48;
    final long = <String>[];
    for (final key in Tr.keys) {
      if (!key.contains('.title')) continue;
      for (final language in AppLanguage.values) {
        final text = Tr.of(key, language);
        if (text.length > ceiling) {
          long.add('$key ${language.code} (${text.length}): $text');
        }
      }
    }
    expect(long, isEmpty, reason: long.join('\n'));
  });
}
