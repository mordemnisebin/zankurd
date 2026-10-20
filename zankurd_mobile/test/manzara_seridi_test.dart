/// Ana sayfa manzara şeridinin bekçisi (2026-10-20 kimlik, "Çiya").
///
/// ## Karar
///
/// Kullanıcının açık tercihi: "Günün dersi" kartının tepesinde logodaki dağ
/// sırtından türeyen bir manzara (gündüz şafak, gece yıldızlı gök + zirvede
/// tek turuncu ışık). Kimlik kurulunun tek itirazı manzaranın kartı büyütüp
/// konuları ~170 pt aşağı itmesiydi.
///
/// ## Neyi korur, niçin sessiz kalırdı
///
/// * Şerit ALÇAKTIR (≤ 100). Birisi "daha güzel dursun" diye yüksekliği
///   artırırsa hiçbir test kırılmaz; konular ekranın altına kayar ve ana
///   sayfanın "neyi öğrenebilirim?" sorusu ilk bakışta cevapsız kalır.
/// * 390×844'te (en yaygın telefon) konu ızgarasının İLK satırı alt gezinme
///   çubuğunun üstünde, ilk ekranda görünür — iki dilli etiketler açıkken
///   de (en kalabalık hâl), iki dilde ve iki temada.
/// * Şerit ana sayfada TEK kezdir ve kilim yoktur (kilim imzası yalnız yarış
///   merkezindedir).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

void main() {
  for (final isKu in [false, true]) {
    for (final dark in [false, true]) {
      final label = '${isKu ? 'KU' : 'TR'} ${dark ? 'gece' : 'gündüz'}';
      testWidgets('$label: tek alçak şerit, ilk konu satırı ilk ekranda', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repo = freshMockRepository();
        await tester.pumpWidget(
          testShell(
            languageProvider: isKu ? kurmanciLang() : turkishLang(),
            themeProvider: ThemeProvider(
              initialMode: dark ? ThemeMode.dark : ThemeMode.light,
            ),
            child: AppShell(repository: repo),
          ),
        );
        // Kabukta sürekli dönen bir yükleyici var; sayılı pump.
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }

        final strip = find.byKey(const ValueKey('sahne-vista-strip'));
        expect(strip, findsOneWidget);
        expect(tester.getSize(strip).height, lessThanOrEqualTo(100));
        // Şerit Günün dersi kartının içindedir.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('home-daily-task')),
            matching: strip,
          ),
          findsOneWidget,
        );
        expect(find.byType(SahneKilimStrip), findsNothing);

        final firstTile = find.byKey(
          ValueKey('home-topic-${repo.categories.first}'),
        );
        expect(firstTile, findsOneWidget);
        final navTop = tester.getRect(find.byType(NavigationBar)).top;
        expect(
          tester.getRect(firstTile).bottom,
          lessThanOrEqualTo(navTop),
          reason: 'ilk konu satırı alt çubuğun altında kaldı',
        );
      });
    }
  }
}
