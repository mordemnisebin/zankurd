// Kurul 3. tur 2026-10-20: bütün alt sayfalar tek kabuğu (tutamaç + başlık +
// kapat + görünür karartma) paylaşır.
//
// Kusur: ekran 90 tutamaç ve kapat düğmesi taşırken 249 (meydan okuma)
// ikisinden de yoksundu ve arka planla karışıyordu. NİÇİN SESSİZ: her sayfa
// kendi `showModalBottomSheet` çağrısını yazıyordu, ortak bir sözleşme yoktu.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

void main() {
  testWidgets('showSahneSheet tutamaç, başlık, kapat ve karartma çizer', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider()..setLang('tr'),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSahneSheet<void>(
                context: context,
                title: 'Başlık',
                builder: (_) => const Text('içerik'),
              ),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sahne-sheet-handle')), findsOneWidget);
    expect(find.byKey(const ValueKey('sahne-sheet-close')), findsOneWidget);
    expect(find.text('Başlık'), findsOneWidget);
    expect(find.text('içerik'), findsOneWidget);
    final barrier = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(barrier.color, isNotNull);
    expect(barrier.color!.a, greaterThanOrEqualTo(0.5));

    await tester.tap(find.byKey(const ValueKey('sahne-sheet-close')));
    await tester.pumpAndSettle();
    expect(find.text('içerik'), findsNothing);
  });
}
