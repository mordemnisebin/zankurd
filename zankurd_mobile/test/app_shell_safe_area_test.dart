import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

/// Sekme içeriği hiçbir zaman durum çubuğunun altına girmez.
///
/// ## Kusur
///
/// `AppShell` sekmeleri `SafeArea` olmadan çiziyordu. Ekranlar kendi üst
/// dolgularını verdiği için AÇILIŞ karesi doğru görünüyordu; kusur ancak
/// kaydırınca ortaya çıkıyordu: kartlar durum çubuğunun ve Dynamic Island'ın
/// altından geçiyor, ana ekranda "Ders yolu" başlığı saatin arkasında
/// kayboluyordu (2026-08-16 simülatör taraması, iPhone 17).
///
/// ## Niçin sessiz kaldı
///
/// Widget testleri varsayılan olarak 0 güvenli alan dolgusuyla koşar —
/// `MediaQuery.padding` sıfırdır, yani durum çubuğu diye bir şey yoktur ve
/// altına girecek içerik de olmaz. Ekran turu da sıfır dolguyla basıyor.
/// Kusur yalnız gerçek bir çentik/adacık varken görünüyordu; bu yüzden bekçi
/// dolguyu kendi enjekte eder.
void main() {
  testWidgets('sekme içeriği üst güvenli alanın altında başlar', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: withDeviceInsets(
          AppShell(
            repository: freshMockRepository(),
            // Gerçek monitör koşucuda çözülmeyen bir future bırakır.
            connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final safeArea = find.descendant(
      of: find.byType(AppShell),
      matching: find.byWidgetPredicate(
        (widget) => widget is SafeArea && widget.top,
      ),
    );

    expect(
      safeArea,
      findsWidgets,
      reason:
          'Sekme içeriği üst güvenli alanı tüketen bir SafeArea içinde '
          'olmalı; yoksa kaydırılan kartlar durum çubuğunun altına girer.',
    );

    // Gövdenin çizim alanı durum çubuğunun altından başlamalı.
    final rect = tester.getRect(safeArea.first);
    expect(
      rect.top,
      greaterThanOrEqualTo(0.0),
      reason: 'SafeArea ekranın dışına taşmamalı',
    );
    expect(tester.takeException(), isNull);
  });
}
