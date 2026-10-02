// 2026-10-02 uçtan uca QA: Ayarlar'ın sonu kimi zaman erişilemiyordu.
//
// ## Kusur
//
// Ayarlar tembel bir `ListView` idi. Tembel liste, ekran dışındaki çocukların
// boyunu kestirir; boyları çok farklı satırlarda (başlık, kart, anahtar,
// açılır satır) kestirim kayma sırasında oynar. iOS'ta tema ve dil değiştirip
// alta kaydıran kullanıcı "Hakkında" kartının yarısında kalıyor, altındaki
// "Hesap işlemleri → Hesabımı sil" görünmüyordu (App Store 5.1.1(v): hesap
// silme her zaman erişilebilir olmalı). "Gizlilik" satırını açmak (boy
// değişip yeniden ölçüldüğü için) sonu erişilir kılıyordu.
//
// ## Niçin sessiz kalırdı
//
// Taze açılışta ve düz kaydırmada son satıra varılıyordu; kestirim yalnız
// bazı boy/kayma bileşimlerinde eksik kalıyor. Testler `scrollUntilVisible`
// ile ARAYA ARAYA kaydırdığından, her adımda yeniden ölçülen liste hep
// sonunda bulunuyordu: bekçi yoktu.
//
// ## Bekçi
//
// Ölçü kesin olmalı: sayfa tembel değil, kaydırma uzunluğu en üstte de en
// altta da AYNI olmalı. Tembel liste en üstteyken kestirimle farklı bir sayı
// verir (deneyde 2482 ↔ 2368). Üstüne, tema+dil değişiminden sonra (TR ve KU)
// hesap silme satırı kaydırılıp dokunulabilir olmalı.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/app_config.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';

import 'support/widget_test_helpers.dart';

void main() {
  for (final startKu in [false, true]) {
    final label = startKu ? 'KU' : 'TR';
    testWidgets('ayarlar: tema ve dil değişince $label sonunda hesap silme '
        'erişilebilir', (tester) async {
      AppConfig.debugHasRevenuecatConfig = true;
      addTearDown(() => AppConfig.debugHasRevenuecatConfig = null);
      // iPhone 17 Pro: 402x874, alt güvenli alan 34.
      tester.view.physicalSize = const Size(402 * 3, 874 * 3);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 62 * 3, bottom: 34 * 3);
      tester.view.viewPadding = const FakeViewPadding(
        top: 62 * 3,
        bottom: 34 * 3,
      );
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        testShell(
          child: SettingsScreen(repository: freshMockRepository()),
          languageProvider: startKu ? turkishLang() : kurmanciLang(),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      ScrollPosition position() =>
          tester.state<ScrollableState>(scrollable).position;

      // Dili ve temayı değiştir (başlangıcın tersine).
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-language-ku')),
        300,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          ValueKey(startKu ? 'settings-language-ku' : 'settings-language-tr'),
        ),
      );
      await tester.pumpAndSettle();
      // Sıra: gizlilik izni, karanlık/aydınlık, hareketi azalt...
      await tester.ensureVisible(find.byType(Switch).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).at(1));
      await tester.pumpAndSettle();

      // Kesin ölçü: değişimden sonra en üstteki uzunluk = en alttaki uzunluk.
      position().jumpTo(0);
      await tester.pumpAndSettle();
      final topExtent = position().maxScrollExtent;

      // Gerçek parmak: art arda hızlı sürüklemeler.
      for (var i = 0; i < 8; i++) {
        await tester.fling(scrollable, const Offset(0, -400), 2000);
        await tester.pumpAndSettle();
      }

      expect(
        position().pixels,
        position().maxScrollExtent,
        reason: 'sona varılmalı',
      );
      expect(
        position().maxScrollExtent,
        closeTo(topExtent, 1.0),
        reason: 'kaydırma uzunluğu kestirim değil kesin olmalı',
      );

      final del = find.byKey(const ValueKey('delete-account-action'));
      expect(del, findsOneWidget);
      final rect = tester.getRect(del);
      const viewportBottom = 874.0 - 34.0;
      expect(
        rect.bottom,
        lessThanOrEqualTo(viewportBottom),
        reason: 'hesap silme satırı güvenli alanın içinde görünmeli',
      );
      await tester.tap(del);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }
}
