import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

/// Metin alanlarında otomatik düzeltme kapalı (2026-10-27).
///
/// ## Kusur
///
/// Çok simülatörlü uçtan uca testte ad ekranına "Berfin" yazıldı, oyuncunun
/// adı "Bergen" kaydedildi: iOS'un Türkçe/İngilizce klavyesi alan odağını
/// kaybedince Kürtçe adı bilinen bir sözcüğe çevirdi. Ad, sohbet, soru
/// önerisi ve kodlar çoğunlukla Kurmancîdir; klavye sözlükleri tanımaz.
///
/// ## Niçin sessiz kalırdı
///
/// Widget testlerinde klavye yoktur; düzeltme yalnız gerçek cihazda olur.
/// Bekçi bu yüzden davranışı değil, platforma giden ayarı denetler.
void main() {
  testWidgets('SahneField varsayılanı: otomatik düzeltme kapalı', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: SahneField(controller: controller, hintText: 'Örn: Zelal'),
        ),
      ),
    );
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.autocorrect, isFalse);
    // Öneri çubuğu açık kalır: kendiliğinden değiştirmez.
    expect(editable.enableSuggestions, isTrue);
  });
}
