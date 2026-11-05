import 'support/play_hub_nav.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/main.dart';

import 'support/widget_test_helpers.dart';

/// Oda koduyla katılma: "Kod zorunlu" hatası kod yazılınca silinir.
///
/// ## Kusur
///
/// 2026-11-05 simülatör turu (13_C_kod_girildi): boş alanla Katıl'a basınca
/// çıkan "Kod pêwîst e" uyarısı, oyuncu kodu yazıp alan dolduktan sonra da
/// alanın altında duruyordu; doğru kod girilmiş ekran hâlâ "hatalı" görünüyordu.
///
/// ## Niçin sessiz kalırdı
///
/// `Form` yalnız Katıl'a basınca doğrular; yazarken doğrulayan yoktu.
/// Hata metni bir çökme değil, bayat bir etiketti; var olan testler yalnız
/// ilk hatanın GÖRÜNDÜĞÜNÜ sınıyordu, kaybolduğunu değil.
void main() {
  testWidgets('kod yazılınca "Kod zorunlu" kaybolur', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: freshMockRepository(),
        authProvider: FakeAuthProvider(),
        languageProvider: turkishLang(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-play')));
    await tester.pumpAndSettle();
    await openRoomSheet(tester);
    await tester.tap(find.byKey(const ValueKey('play-hub-join-room')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('play-hub-join-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Kod zorunlu'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('play-hub-join-room-code-field')),
      '482913',
    );
    await tester.pumpAndSettle();
    expect(find.text('Kod zorunlu'), findsNothing);
  });
}
