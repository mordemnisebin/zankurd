// Tasarım kurulu 4. tur 2026-10-20 (40 ekran): ortak bulgular.
//
// 1. Konu akışı başlığı (37/38): alt satırlı çubukta dikey pay 24; ad üst
//    kenara, alt satır altındaki çizgiye yapışmasın. 38'de dört tam boy
//    kilitli seviye yerine ilk kilitli kart + "+N seviye daha" satırı.
// 2. Sonuç (68/200): alt solma bandı kalktı; yanlış konu satırı pasif
//    gibi sönmez, yanlış yalnız kırmızı ✗ karesiyle söylenir.
// 3. 49 turu 17 ile aynı gerçek lobi verisini basar (ev sahibi rozeti,
//    sohbet düğmesi); iki tema karşılaştırılabilir.
// 4. 13: "Odaya çağır" artık "Meydan oku" ile aynı kenarlı ikincil düğme.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/widgets/zk_back_button.dart';

import 'support/widget_test_helpers.dart';

void main() {
  testWidgets('alt satırlı başlık çubuğu 24 dikey pay taşır', (t) async {
    late PreferredSizeWidget bar;
    late PreferredSizeWidget plain;
    await t.pumpWidget(
      testShell(
        child: Builder(
          builder: (context) {
            bar = zkAppBar(
              context,
              title: const Text('Dil'),
              subtitle: const Text('Kolaydan zora doğru ilerle'),
            );
            plain = zkAppBar(context, title: const Text('Dil'));
            return const SizedBox();
          },
        ),
      ),
    );
    // Başlık (~28) + alt satır (~18) + 24 ≥ 64; düz başlık 64'te kalır.
    expect(bar.preferredSize.height, greaterThan(plain.preferredSize.height));
    expect(plain.preferredSize.height, 64);
  });

  test('"+N seviye daha" her iki dilde tanımlı', () {
    expect(Tr.forKu(K.levelsMoreCount, false, {'n': '3'}), '+3 seviye daha');
    expect(Tr.forKu(K.levelsMoreCount, true, {'n': '3'}), '+3 astên din');
  });

  test('sonuç gövdesinde alt solma bandı yok', () {
    final src = File(
      'lib/src/widgets/sahne/sahne_result.dart',
    ).readAsStringSync();
    expect(src.contains('SahneBottomFade('), isFalse);
  });

  test('49 turu 17 ile aynı lobi verisini basar', () {
    final src = File(
      'tool/screenshots/screen_tour_test.dart',
    ).readAsStringSync();
    final start = src.indexOf("testWidgets('49 oda (karanlık)'");
    final end = src.indexOf("testWidgets('50 ", start);
    final block = src.substring(start, end);
    expect(block, contains('_LobbyView.hostGuestReady'));
    expect(block, isNot(contains('repository.createRoom()')));
  });
}
