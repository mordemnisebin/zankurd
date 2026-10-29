import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/okunur_boyut.dart';
import 'support/realistic_device.dart';

/// Gerekli bilgi taşıyan rozetler okunur boyutun altına KÜÇÜLTÜLMEZ
/// (Opus–Astra kapışması U13, 2026-10-29).
///
/// Kusur: mod kartlarının durum rozeti ("Sonuç hazır", "Sıra sende")
/// FittedBox ile sığdırılıyordu; ana sayfadaki yarım kartta ≈5 pt
/// çiziliyordu (tur karesi 247_home_duel_ready) — gözle okunmuyordu ama
/// stil `captionStrong` (14) olduğu için hiçbir bekçi görmedi. Bekçi stile
/// değil ÇİZİLEN boya bakar ve gerçek yazı tipiyle ölçer.
void main() {
  setUpAll(loadAppFonts);

  for (final width in [375.0, 402.0]) {
    for (final scale in [1.0, 1.3]) {
      for (final badge in ['Sonuç hazır', 'Sıra sende', 'Encam amade ye']) {
        testWidgets('mod kartı rozeti "$badge" ${width}pt x$scale okunur', (
          tester,
        ) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 874);
          addTearDown(tester.view.reset);
          for (final lobby in [true, false]) {
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SahneModeGrid(
                      children: [
                        SahneModeTile(
                          lobby: lobby,
                          icon: AppIcons.graduationCap,
                          role: SahneRole.learn,
                          title: 'Kurmancî öğren',
                          subtitle: 'Ders, hikâye, sözlük',
                          onTap: () {},
                        ),
                        SahneModeTile(
                          lobby: lobby,
                          icon: AppIcons.gamepad,
                          title: 'Yarış',
                          subtitle: 'Düello, oda, turnuva',
                          badge: badge,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 600));
            expect(tester.takeException(), isNull);
            final text = find.text(badge);
            expect(text, findsOneWidget);
            expect(
              renderedFontSize(tester, text),
              greaterThanOrEqualTo(kOkunurAltSinir * scale - 0.01),
              reason: 'lobby=$lobby rozet küçültülmüş',
            );
            final paragraph = tester.renderObject<RenderParagraph>(text);
            expect(
              paragraph.didExceedMaxLines,
              isFalse,
              reason: 'lobby=$lobby rozet kesilmiş',
            );
          }
        });
      }
    }
  }
}
