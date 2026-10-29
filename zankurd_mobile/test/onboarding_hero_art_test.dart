/// Karşılama görselinin ve sadeliğinin bekçisi (2026-10-28 kurul K10).
///
/// ## Geçersiz kılınan eski kararlar
///
/// * 2026-10-01/09-29 "kahraman yuvası": her slayt koyu, kilim şeritli bir
///   sahne kartıydı (`SahneEntryHero`). K10: "siyah kutu kalkar"; görsel artık
///   düz zeminde, rolün ton zeminli yuvarlak rozetidir.
/// * 2026-09-29 "üst/alt eşit boşluk (`spaceEvenly`)" ve 2026-10-24 "dil
///   seçici ilk sayfanın tepesinde": ilk görünümde sayfa yarısı boştu. Dil
///   seçimi kendi (1.) adımıdır ve iki büyük karttır; adım sayısı 2 → 3.
/// * 2026-10-24 "Sonraki": alt düğme artık "Devam" (son adımda "Başla").
///
/// ## Korunan kural
///
/// Görsel soru DEĞİLDİR: soru cümlesi, şık, harf karosu yok, dokunulmaz,
/// ekran okuyucuya duyurulmaz (kullanıcılar sahte soru kartındaki şıklara
/// dokunuyordu, 2026-10-24).
///
/// ## Yeni kural
///
/// Her adım = 1 görsel + 1 başlık + EN ÇOK 2 kısa satır + alt "Devam".
/// Görsel + başlık + satırlar tek grup; ortada delik yok. 2026-10-29 son
/// kurul tur 2 (F): grup tam ortada değil üst-ortadadır (boşluğun ≈ %30'u
/// üstte); tam ortalama dil seçimini ekranın altına itiyordu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/widgets/roj_mascot.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

Future<void> _pumpOnboarding(
  WidgetTester tester, {
  String lang = 'tr',
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => LanguageProvider()..setLang(lang),
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: tester.view.physicalSize / tester.view.devicePixelRatio,
            textScaler: TextScaler.linear(textScale),
          ),
          child: OnboardingScreen(onComplete: () {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _next(WidgetTester tester, {String label = 'Devam'}) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  final art = find.byKey(const ValueKey('onboarding-scene-art'));

  void phone(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  group('1) Görsel dokunulmaz bir çizimdir, soru değil', () {
    testWidgets('öğren adımı: soru, şık, harf karosu, dokunma yok', (
      tester,
    ) async {
      phone(tester, const Size(390, 844));
      await _pumpOnboarding(tester);
      await _next(tester);

      expect(art, findsOneWidget);
      expect(
        find.descendant(of: art, matching: find.byIcon(AppIcons.graduationCap)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: art, matching: find.textContaining('?')),
        findsNothing,
      );
      for (final letter in ['A', 'B', 'C', 'D']) {
        expect(
          find.descendant(of: art, matching: find.text(letter)),
          findsNothing,
        );
      }
      expect(
        find.descendant(of: art, matching: find.byType(InkWell)),
        findsNothing,
      );
      expect(
        find.descendant(of: art, matching: find.byType(GestureDetector)),
        findsNothing,
      );
      expect(
        find.ancestor(of: art, matching: find.byType(ExcludeSemantics)),
        findsWidgets,
        reason: 'görsel ekran okuyucuya duyurulmaz',
      );
    });

    testWidgets('siyah kutu yok: kahraman kartı (SahneStageCard) çizilmez', (
      tester,
    ) async {
      phone(tester, const Size(390, 844));
      await _pumpOnboarding(tester);
      for (var i = 0; i < 3; i++) {
        expect(
          find.byType(SahneStageCard),
          findsNothing,
          reason: 'adım ${i + 1}',
        );
        expect(find.byType(SahneEntryHero), findsNothing);
        if (i < 2) await _next(tester);
      }
    });

    testWidgets('yarış adımı: kılıçlar + kupa, maskot yok', (tester) async {
      phone(tester, const Size(390, 844));
      await _pumpOnboarding(tester);
      await _next(tester);
      await _next(tester);
      expect(
        find.descendant(of: art, matching: find.byIcon(AppIcons.swords)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: art, matching: find.byIcon(AppIcons.trophy)),
        findsOneWidget,
      );
      expect(find.byType(RojMascot), findsNothing);
      expect(find.text('Başla'), findsOneWidget, reason: 'son adımda "Başla"');
    });
  });

  group('2) Her adım: 1 başlık + en çok 2 kısa satır', () {
    for (final lang in ['tr', 'ku']) {
      testWidgets('$lang: yazılar sınırı aşmaz, madde/nokta listesi yok', (
        tester,
      ) async {
        phone(tester, const Size(390, 844));
        await _pumpOnboarding(tester, lang: lang);
        for (var i = 0; i < 3; i++) {
          final scroller = find.byKey(
            const ValueKey('onboarding-text-scrollbar'),
          );
          // Sayfadaki Text'ler: 1 başlık (+ dil adımında kart adları) + ≤ 2 satır.
          final texts = find
              .descendant(of: scroller, matching: find.byType(Text))
              .evaluate()
              .map((e) => (e.widget as Text).data ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
          final cardLabels = {'Kurmancî', 'Türkçe'};
          final body = texts.where((s) => !cardLabels.contains(s)).toList();
          expect(
            body.length,
            lessThanOrEqualTo(3),
            reason: 'adım ${i + 1}: başlık + ≤ 2 satır, bulunan: $body',
          );
          if (i < 2) {
            await _next(tester, label: lang == 'ku' ? 'Bidomîne' : 'Devam');
          }
        }
      });
    }

    testWidgets('1. adım iki büyük dil kartıdır (≥ 96 yüksek, yan yana)', (
      tester,
    ) async {
      phone(tester, const Size(390, 844));
      await _pumpOnboarding(tester);
      final ku = tester.getRect(
        find.byKey(const ValueKey('onboarding-language-ku')),
      );
      final tr = tester.getRect(
        find.byKey(const ValueKey('onboarding-language-tr')),
      );
      expect(ku.height, greaterThanOrEqualTo(96));
      expect(tr.height, greaterThanOrEqualTo(96));
      expect(ku.right, lessThan(tr.left), reason: 'Kurmancî ÖNCE, yan yana');
      expect(ku.width, greaterThanOrEqualTo(120));
    });
  });

  testWidgets('büyük yazıda dil kartları alt alta (kelime kırılmaz)', (
    tester,
  ) async {
    phone(tester, const Size(320, 568));
    await _pumpOnboarding(tester, textScale: 2);
    final ku = tester.getRect(
      find.byKey(const ValueKey('onboarding-language-ku')),
    );
    final tr = tester.getRect(
      find.byKey(const ValueKey('onboarding-language-tr')),
    );
    expect(tr.top, greaterThanOrEqualTo(ku.bottom), reason: 'alt alta');
    expect(ku.width, greaterThan(250));
    expect(tester.takeException(), isNull);
  });

  group('3) Boşluk', () {
    testWidgets('390×844: görsel+metin grubu üst-ortada (üst pay %20–45)', (
      tester,
    ) async {
      phone(tester, const Size(390, 844));
      await _pumpOnboarding(tester);
      await _next(tester);
      final area = tester.getRect(
        find.byKey(const ValueKey('onboarding-text-scrollbar')),
      );
      final top = tester.getTopLeft(art).dy;
      final bottom = tester
          .getBottomLeft(
            find.text('Kısa sorularla kelime öğren, kültürü tanı.'),
          )
          .dy;
      final above = top - area.top;
      final below = area.bottom - bottom - 24; // son satır (marka sözü) payı
      // 2026-10-29 son kurul tur 2 (F, Astra + Sol): tam ortalama ilerleme
      // çubuğunun altında büyük boşluk bırakıp dil seçimini aşağı itiyordu.
      // Grup artık üst-orta durur (boşluğun ≈ %30'u üstte); eski "üst/alt
      // fark ≤ 120" kuralı yerine oran ölçülür (bkz. `son_kurul_test`).
      final share = above / (above + below);
      expect(share, inInclusiveRange(0.2, 0.45), reason: 'üst pay $share');
      expect(above, lessThanOrEqualTo(220), reason: 'üstte büyük boş alan yok');
    });
  });

  group('4) Taşma yok', () {
    for (final (size, scale) in [
      (const Size(375, 667), 1.0),
      (const Size(320, 568), 1.0),
      (const Size(320, 568), 2.0),
      (const Size(390, 844), 2.0),
    ]) {
      testWidgets(
        '${size.width.toInt()}x${size.height.toInt()} yazı $scale: 3 adım taşmaz',
        (tester) async {
          phone(tester, size);
          await _pumpOnboarding(tester, textScale: scale);
          expect(tester.takeException(), isNull);
          await _next(tester);
          expect(tester.takeException(), isNull);
          await _next(tester);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
