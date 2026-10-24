// Tur 11 bekçisi — öğrenme ekranı sadeleşmesi.
//
// KUSUR: "Seviyeni bul" 130 px'lik kartı sıradaki dersle
// yarışıyordu. NİÇİN SESSİZDİ: eski test yalnız kartın var/yok olmasına
// bakıyordu, boyuta değil. Burada şeridin ince (<= 64) olduğu ve kilitli
// satırların sıkı (<= 48) olduğu sabitlenir.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

void main() {
  testWidgets('öğrenmede seviye şeridi ince, kilitli satırlar sıkı', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    PlacementStore.resetInstance();
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => LanguageProvider())],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: LearningScreen(repository: MockZanKurdRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final strip = find.byKey(const ValueKey('learning-placement-prompt'));
    expect(strip, findsOneWidget);
    expect(tester.getSize(strip).height, lessThanOrEqualTo(64));
    final more = find.byKey(const ValueKey('learning-locked-more'));
    expect(more, findsOneWidget);
    expect(tester.getSize(more).height, lessThanOrEqualTo(49));
  });
}
