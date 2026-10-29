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
/// * 390×844'te (en yaygın telefon) öğren kapısı alt gezinme çubuğunun
///   üstünde, ilk ekranda görünür ve konu ızgarasının İLK satırı en çok bir
///   kaydırma ötededir (2026-10-21'den önce ilk satırın kendisi ilk
///   ekrandaydı; kapılar ızgaranın üstüne taşınınca bu şart gevşedi) — iki
///   dilli etiketler açıkken de, iki dilde ve iki temada.
/// * Şerit ana sayfada TEK kezdir ve kilim yoktur (kilim imzası yalnız yarış
///   merkezindedir).
///
/// 2026-10-29 vay katmanı B1: kahraman şeridi maskotlu 120'ye çıktı (üst sınır
/// [SahneVistaStrip.maxHeight] = 128) ve alt kenarında TEK 6 px kilim
/// şeridi vardır (ekran başına ≤ 2 kilim bölgesi); ilk konu satırı ve öğren
/// kapısı yine ilk ekranda kalır.
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
        expect(
          tester.getSize(strip).height,
          lessThanOrEqualTo(SahneVistaStrip.maxHeight),
        );
        // Şerit Günün dersi kartının içindedir.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('home-daily-task')),
            matching: strip,
          ),
          findsOneWidget,
        );
        expect(find.byType(SahneKilimStrip), findsNothing);
        expect(
          find.byKey(const ValueKey('sahne-kilim-border')),
          findsOneWidget,
        );

        final firstTile = find.byKey(
          ValueKey('home-topic-${repo.categories.first}'),
        );
        expect(firstTile, findsOneWidget);
        final navTop = tester.getRect(find.byType(NavigationBar)).top;
        // Erişim haritası (2026-10-21): öğren/oyna kapıları konu ızgarasının
        // ÜSTÜNE taşındı ve günlük görevler Günün dersinin altına indi; ilk
        // konu satırı artık ilk ekranın hemen altında başlar. "Neyi
        // öğrenebilirim?" sorusunun cevabı ilk ekranda KAPI olarak durur,
        // ızgara bir kaydırma ötededir.
        expect(
          tester.getRect(find.byKey(const ValueKey('home-door-learn'))).bottom,
          lessThanOrEqualTo(navTop),
          reason: 'öğren kapısı alt çubuğun altında kaldı',
        );
        expect(
          tester.getRect(firstTile).bottom,
          lessThanOrEqualTo(navTop + 844 - 100),
          reason: 'ilk konu satırı ilk iki ekrandan da uzağa düştü',
        );
      });
    }
  }
}
