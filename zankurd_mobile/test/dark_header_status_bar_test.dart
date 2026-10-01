/// Koyu başlığı durum çubuğunun altına uzanan ekranlar açık saat ve pil
/// ikonu ister (bugün yalnız kategori ekranı; ad ekranı 2026-10-01'de giriş
/// iskeletine geçip şeridi bıraktı).
///
/// ## Kusur
///
/// Uygulama kökü durum çubuğu stilini temadan seçer; açık temada saat ve pil
/// koyudur. Ad ekranının orman şeridi ve kategori ekranının görsel başlığı
/// ise tam durum çubuğunun altına uzanır: koyu yeşil üstünde koyu saat ve
/// pil okunmuyordu (2026-09-27 simülatör turu).
///
/// ## Niçin sessiz kalırdı
///
/// Durum çubuğu Flutter'ın çizdiği bir yüzey değildir; widget testleri ve
/// ekran turu onu hiç göstermez. Yalnız gerçek cihazda görünür. Bu bekçi
/// ekranın istediği stili doğrudan okur.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/profile_name_gate_screen.dart';
import 'package:zankurd_mobile/src/screens/subcategory_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

import 'support/widget_test_helpers.dart';

void main() {
  test('koyu başlık stili açık ikon ister (iOS ve Android)', () {
    // iOS `statusBarBrightness` ile ZEMİNİN, Android
    // `statusBarIconBrightness` ile İKONUN parlaklığını tanımlar.
    expect(AppTheme.overlayOnDarkHeader.statusBarBrightness, Brightness.dark);
    expect(
      AppTheme.overlayOnDarkHeader.statusBarIconBrightness,
      Brightness.light,
    );
  });

  testWidgets('ad ekranı artık koyu şerit uzatmaz, zorla açık ikon istemez', (
    tester,
  ) async {
    // 2026-10-01 giriş iskeleti: ad ekranı da giriş ve kayıt gibi sayfa
    // zemini üstünde başlar (üst çubuk + kahraman kart). Durum çubuğunun
    // altında artık koyu bir şerit YOK; eskiden zorla istenen açık ikon
    // açık temada AÇIK zeminde görünmez olurdu. Bu yüzden ekran stili
    // temaya bırakır (kök, temadan seçer).
    await tester.pumpWidget(
      testShell(
        child: ProfileNameGateScreen(
          repository: MockZanKurdRepository(),
          onCompleted: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final regions = tester.widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.descendant(
        of: find.byType(ProfileNameGateScreen),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      ),
    );
    expect(
      regions.map((r) => r.value),
      isNot(contains(AppTheme.overlayOnDarkHeader)),
    );
  });

  testWidgets('kategori ekranının saydam app bar\'ı açık ikon ister', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: SubcategoryScreen(
          repository: MockZanKurdRepository(),
          category: 'Ziman',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final appBar = tester.widget<AppBar>(find.byType(AppBar).first);
    expect(appBar.systemOverlayStyle, AppTheme.overlayOnDarkHeader);
  });
}
