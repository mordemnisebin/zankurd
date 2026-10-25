import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/widgets/sync_failed_notice.dart';

import 'support/widget_test_helpers.dart';

/// 2026-10-25 (Opus 5.5 karar 4 → (b)): başarısız senkron ödülü varken ana
/// ekranda uyarı görünür; yokken yer kaplamaz. Otomatik yeniden deneme yok,
/// dokununca elle dener — bu yüzden uyarı kullanıcıya görünür olmalı.
void main() {
  Widget host() => testShell(
    languageProvider: turkishLang(),
    child: const Scaffold(body: Center(child: SyncFailedNotice())),
  );

  tearDown(() => SyncManager.failedCountNotifier.value = 0);

  testWidgets('başarısız ödül yoksa hiçbir şey çizmez', (tester) async {
    SyncManager.failedCountNotifier.value = 0;
    await tester.pumpWidget(host());
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('başarısız ödül varsa sayılı uyarı çıkar', (tester) async {
    SyncManager.failedCountNotifier.value = 2;
    await tester.pumpWidget(host());
    expect(find.byType(InkWell), findsOneWidget);
    expect(
      find.textContaining('2'),
      findsOneWidget,
      reason: 'sayı metinde görünmeli',
    );
  });
}
