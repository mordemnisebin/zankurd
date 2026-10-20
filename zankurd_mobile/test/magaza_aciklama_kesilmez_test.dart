// Koordinatör (2026-10-20, 29_shop_ku): mağaza açıklamaları "…" ile kesiliyor
// ("Profîla te de rozeteke taybet …"); oyuncu ne aldığını okuyamıyordu.
//
// ## Niçin sessiz kalırdı
//
// İlk düzeltme (2 satır sınırı) kartın şişmemesi içindi ve test ediliyordu;
// ama sınır, Kurmancî gibi uzun metinde bilgiyi yok ediyordu. Hiçbir test
// "açıklama tam okunur" demiyordu.
//
// Bekçi: tr ve ku'da, 320 ve 390 genişlikte hiçbir ürün açıklaması
// kesilmez (didExceedMaxLines yok, "…" yok), taşma yok.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';

import 'support/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final lang in ['tr', 'ku']) {
    for (final width in [320.0, 390.0]) {
      testWidgets('mağaza açıklamaları kesilmez ($lang, ${width.toInt()})', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1800);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          testShell(
            languageProvider: LanguageProvider()..setLang(lang),
            child: ShopScreen(repository: MockZanKurdRepository()),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        var checked = 0;
        for (final e
            in find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(RichText),
                )
                .evaluate()) {
          final p = e.renderObject! as RenderParagraph;
          expect(
            p.didExceedMaxLines,
            isFalse,
            reason: '"${p.text.toPlainText()}" kesildi',
          );
          expect(p.text.toPlainText().endsWith('…'), isFalse);
          checked++;
        }
        expect(checked, greaterThan(4));
      });
    }
  }
}
