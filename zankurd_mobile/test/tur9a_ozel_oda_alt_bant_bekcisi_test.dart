// Tasarım kurulu tur 8 (3 denetçi + Opus): "Özel oda oluştur" sayfasında
// "Ücretsiz (0)" seçiliyken altta "40 jeton eksik" uyarısı ve "Jeton kazan"
// düğmesi duruyor, "Odayı aç" yoktu: seçim ile alt bant çelişiyordu. Ayrıca
// ücret ızgarası ile alt bant arasında ~180 pt ölü boşluk vardı.
//
// Niçin sessiz kaldı: bu iki durum (yetmeyen ücrete dokunuldu) yalnız o
// dokunuştan sonra oluşuyor, eski testler "Jeton kazan düğmesi gelir"i
// DOĞRU davranış diye sabitliyordu; ölü boşluğu ise `SingleChildScrollView`
// her zaman tüm yüksekliği doldurduğundan ölçen test yoktu.
//
// Bekçi: varsayılan (Ücretsiz) durumda eksik metni yok, "Odayı aç" etkin;
// kilitli ücrete dokunulunca not + ikincil "Jeton kazan" belirir ama birincil
// düğme yine "Odayı aç" kalır; yetebilen ücrete dönünce not kaybolur; son ücret
// satırı ile alt ayraç arası dar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';

import 'support/widget_test_helpers.dart';

class _Repo extends MockZanKurdRepository {
  @override
  Future<int> loadCoinBalance() async => 10;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(child: PlayHubScreen(repository: _Repo())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play-hub-create-room')));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('custom-room-settings-row'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  final shortfall = find.byKey(const ValueKey('custom-room-shortfall'));
  final earn = find.byKey(const ValueKey('custom-room-earn-coins'));
  final openRoom = find.byKey(const ValueKey('custom-room-open'));

  testWidgets('Ücretsiz seçiliyken eksik metni yok, Odayı aç etkin', (
    tester,
  ) async {
    await open(tester);
    expect(find.textContaining('jeton eksik'), findsNothing);
    expect(shortfall, findsNothing);
    expect(earn, findsNothing);
    expect(tester.widget<FilledButton>(openRoom).onPressed, isNotNull);
  });

  testWidgets('kilitli ücrete dokunmak not + ikincil bağlantı açar, birincil '
      'düğme değişmez; yetebilen ücret notu kapatır', (tester) async {
    await open(tester);
    final fee50 = find.byKey(const ValueKey('custom-room-fee-50'));
    await tester.ensureVisible(fee50);
    await tester.pumpAndSettle();
    await tester.tap(fee50);
    await tester.pumpAndSettle();
    expect(find.text('40 jeton eksik'), findsOneWidget);
    expect(earn, findsOneWidget);
    expect(tester.widget<FilledButton>(openRoom).onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('custom-room-fee-0')));
    await tester.pumpAndSettle();
    expect(shortfall, findsNothing);
    expect(earn, findsNothing);
  });

  testWidgets('ücret ızgarası ile alt ayraç arasında ölü boşluk yok', (
    tester,
  ) async {
    await open(tester);
    final lastRow = tester.getBottomLeft(
      find.byKey(const ValueKey('custom-room-fee-100')),
    );
    final divider = tester.getTopLeft(
      find.byKey(const ValueKey('custom-room-footer-divider')),
    );
    expect(
      divider.dy - lastRow.dy,
      lessThan(48),
      reason: 'Sayfa içeriğe göre boyutlanır; ~180 pt boşluk kalmamalı.',
    );
  });
}
