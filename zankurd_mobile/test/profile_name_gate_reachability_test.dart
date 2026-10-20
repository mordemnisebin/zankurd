import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/profile_name_gate_screen.dart';

import 'support/widget_test_helpers.dart';

/// Ad kapısındaki iki çıkışın HER ekran boyunda dokunulabilir olduğunun
/// bekçisi.
///
/// ## Kusur
///
/// 2026-08-12 canlı turunda iPhone 17 Pro Max'te (440×956 pt) ad kapısının
/// kartı çiziliyor ama hiçbir dokunuşu almıyordu: ne metin alanı odak
/// alıyor, ne «Dest pê bike», ne de «Paşê bike» çalışıyordu. Aynı ikili,
/// aynı ekran, sıfırlanmış iPhone SE'de (375×667) anında çalışıyordu —
/// yani kusur cihaz boyuna bağlıydı.
///
/// Ağırlığı şurada: bu ekran açılıştan sonraki İLK kapıdır ve geri yolu
/// yoktur. Dokunuş almadığında yeni oyuncu uygulamaya hiç giremez.
///
/// Sessizdi çünkü tek testi (`profile_name_gate_validation_test`) varsayılan
/// 800×600 test yüzeyinde koşuyor ve `tester.tap(find.text(...))` widget'ı
/// AĞAÇTAN buluyor — gerçek isabet testinden (hit-test) geçmiyor. Ekranda
/// duran ama dokunulamayan bir düğme o testte kusursuz görünür.
///
/// Burada tam tersi yapılır: dokunuş ekran KOORDİNATINDAN gönderilir ve
/// birkaç gerçek cihaz boyunda tekrarlanır.
void main() {
  const sizes = <String, Size>{
    'iPhone SE (375×667)': Size(375, 667),
    'iPhone 13/14 (390×844)': Size(390, 844),
    'iPhone 16 Pro (402×874)': Size(402, 874),
    'iPhone 17 Pro Max (440×956)': Size(440, 956),
    'iPad portre (768×1024)': Size(768, 1024),
  };

  for (final entry in sizes.entries) {
    testWidgets('${entry.key}: «şimdilik geç» dokunuşu ulaşıyor', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value * tester.view.devicePixelRatio;
      tester.view.devicePixelRatio = tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);

      var completed = false;
      await tester.pumpWidget(
        testShell(
          child: ProfileNameGateScreen(
            repository: MockZanKurdRepository(),
            onCompleted: () => completed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Merkez KOORDİNATINDAN dokun: `tester.tap(Finder)` widget'ı ağaçtan
      // bulur ve isabet testini atlar; oysa kusur tam orada yaşıyordu.
      final skip = find.text('Şimdilik geç');
      expect(skip, findsOneWidget, reason: 'çıkış bağlantısı çizilmemiş');
      await tester.tapAt(tester.getCenter(skip));
      await tester.pumpAndSettle();

      expect(
        completed,
        isTrue,
        reason:
            '${entry.key}: «şimdilik geç» çiziliyor ama dokunuş ona '
            'ulaşmıyor. Bu ekranın geri yolu yok — ulaşmayan bir çıkış, '
            'kapalı bir uygulama demektir.',
      );
    });

    testWidgets('${entry.key}: ad alanı odak alıyor', (tester) async {
      tester.view.physicalSize = entry.value * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        testShell(
          child: ProfileNameGateScreen(
            repository: MockZanKurdRepository(),
            onCompleted: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final field = find.byKey(const ValueKey('player-name-field'));
      expect(field, findsOneWidget);
      await tester.tapAt(tester.getCenter(field));
      await tester.pumpAndSettle();

      final focus = FocusScope.of(tester.element(field));
      expect(
        focus.hasFocus,
        isTrue,
        reason:
            '${entry.key}: ad alanına dokunuş odak vermiyor; oyuncu adını '
            'yazamaz.',
      );
    });
  }
}
