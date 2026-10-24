// Tasarım kurulu tur 7 (5/5 denetçi): "Özel oda oluştur" sayfasında
//
// * jetonu yetmeyen ücret SEÇİLİ görünüyordu (50 jeton turuncu seçili iken
//   altta "40 jeton eksik"): seçim ile durum çelişiyordu;
// * yetmeyen ücret çipleri yalnız soluklaştırılmıştı (opaklık), kilit yoktu;
// * "N jeton eksik" kırmızıydı: hata değil, çözümü olan bir uyarı;
// * alt solma 24 px idi, son ücret satırını bozuk gösteriyordu.
//
// Niçin sessiz kaldı: testler "dokununca not çıkar" diyordu; seçili
// görünümü, kilidi, notun tonunu ve solma yüksekliğini hiçbiri ölçmüyordu.
import 'support/play_hub_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

class _Repo extends MockZanKurdRepository {
  @override
  Future<int> loadCoinBalance() async => 30;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(child: PlayHubScreen(repository: _Repo())),
    );
    await tester.pumpAndSettle();
    await openRoomSheet(tester);
    await tester.tap(find.byKey(const ValueKey('play-hub-create-room')));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('custom-room-settings-row'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  SahnePickChip chip(WidgetTester tester, int fee) =>
      tester.widget(find.byKey(ValueKey('custom-room-fee-$fee')));

  testWidgets('yetmeyen ücret seçilmez: kilitli çip, seçim yetebilene kalır, '
      'eksik notu kehribar', (tester) async {
    await open(tester);
    final fee50 = find.byKey(const ValueKey('custom-room-fee-50'));
    await tester.ensureVisible(fee50);
    await tester.pumpAndSettle();
    expect(chip(tester, 50).locked, isTrue);
    expect(chip(tester, 25).locked, isFalse);
    expect(
      find.descendant(of: fee50, matching: find.byIcon(AppIcons.lock)),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('custom-room-fee-25')));
    await tester.pumpAndSettle();
    expect(chip(tester, 25).selected, isTrue);

    await tester.tap(fee50);
    await tester.pumpAndSettle();
    expect(chip(tester, 50).selected, isFalse, reason: 'seçilmemeli');
    expect(chip(tester, 25).selected, isTrue, reason: 'seçim yetebilene kalır');
    expect(find.text('50 jeton için 20 jeton eksik'), findsOneWidget);
    final note = tester.widget<SahneShortfallNote>(
      find.byKey(const ValueKey('custom-room-shortfall')),
    );
    expect(note.warn, isTrue);
    expect(note.alert, isFalse, reason: 'kırmızı değil, kehribar');
    expect(SahneTokens.night.shortfallTx, isNot(SahneTokens.night.errTx));
  });

  testWidgets('alt solma 8 px, üstte 8 px bant', (tester) async {
    await open(tester);
    final fade = tester.widget<SahneBottomFade>(
      find.byKey(const ValueKey('custom-room-bottom-fade')),
    );
    expect(fade.height, lessThanOrEqualTo(8));
    expect(fade.topHeight, 8);
  });
}
