import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kurmancî'de özel ad izafeden sonra oblik hâl alır.
///
/// 2026-07-27 Kurmancî taraması: kayıt defteri aynı adı iki ayrı biçimde
/// yazıyordu — "Bi xêr hatî ZanKurd**ê**" ve "Ji ZanKurd**ê** re" doğruydu,
/// ama "Kûpaya ZanKurd" ve "Xweş hatî ZanKurd" oblik hâli almıyordu.
/// Aynı ekranda iki farklı çekim, dili bilen bir okuyucu için özensizliktir.
///
/// Kural dar tutuldu: yalnız izafe (`-a/-ê/-ên` ile biten sözcükten sonra)
/// ve "hatî" kalıbı denetlenir. Bileşik marka adı ("ZanKurd Premium") ve
/// yalın kullanım kapsam dışıdır — orada oblik gerekmez.
void main() {
  test('izafe ve "hatî" sonrası ZanKurd oblik hâlde yazılır', () {
    final source = File('lib/src/l10n/strings.dart').readAsStringSync();
    final kurmanciValues = RegExp(
      r"'ku': '([^']*)'",
    ).allMatches(source).map((m) => m.group(1)!).toList();

    final offenders = <String>[];
    final needsOblique = RegExp(r"(\w+[aêên]|hatî)\s+ZanKurd(?![êa-zA-Z])");
    for (final value in kurmanciValues) {
      if (needsOblique.hasMatch(value)) offenders.add(value);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'İzafe/"hatî" sonrası oblik hâl eksik (ZanKurdê olmalı): '
          '${offenders.join(" | ")}',
    );
  });
}
