/// Günün dersi kartının üst etiketi cümle düzenindedir.
///
/// ## Kusur
///
/// 2026-09-29 doğallık (K8): kartın üst etiketi büyük harf + geniş harf
/// aralığıyla ("BUGÜNÜN GÖREVİ", "İLK DERS") yazılıyordu. Her kart, rozet ve
/// çip etiketinin aynı biçimde bağırması şablon izi bırakıyordu; büyük harf
/// yalnız soru sahnesinin künyesinde ("KONU • SORU n/N") kalır.
///
/// ## Niçin sessiz kalırdı
///
/// Kartın testleri anahtara ve sayıya bakıyordu, etiketin biçimine değil.
///
/// 2026-09-29 doğallık: etiketler dizge defterinde de cümle düzenine geçti
/// (`K.bugununGorevi`, `K.firstSessionBadge`); ekrandaki çevirici
/// (`sentenceCaseLabel`) gereksiz kaldı ve silindi, onun birim testi de.
/// Ekrandaki sonuç aşağıdaki kart testleriyle korunur.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/home/today_task_card.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

Future<void> _pump(
  WidgetTester tester, {
  required bool isKu,
  required bool firstSession,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: TodayTaskCard(
          isKu: isKu,
          loading: false,
          firstSession: firstSession,
          total: firstSession ? 5 : 10,
          onStart: () {},
        ),
      ),
    ),
  );
}

void main() {
  for (final (isKu, firstSession, label) in const [
    (false, true, 'İlk ders'),
    (false, false, 'Bugünün görevi'),
    (true, true, 'Dersa yekem'),
    (true, false, 'Erkê îro'),
  ]) {
    testWidgets('kart etiketi "$label" kalın açıklama, büyük harf değil', (
      tester,
    ) async {
      await _pump(tester, isKu: isKu, firstSession: firstSession);
      final text = tester.widget<Text>(find.text(label));
      expect(text.style?.fontSize, SahneType.captionStrong.fontSize);
      expect(text.style?.fontWeight, SahneType.captionStrong.fontWeight);
      expect(text.style?.letterSpacing, isNot(SahneType.eyebrow.letterSpacing));
      expect(find.text(label.toUpperCase()), findsNothing);
    });
  }
}
