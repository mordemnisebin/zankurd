import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/avatar_editor_screen.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/screens/paywall_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

/// Kalan yüzeylerin gerçek telefon geometrisinde taşma/kırpma taraması.
///
/// ## Niçin var
///
/// `realistic_device` deseni (402×874, 59/34 çentik dolgusu, gerçek Rubik)
/// yalnız üç testte kullanılıyordu: kabuk güvenli alanı, joker etiketleri ve
/// serbest metin soru tipleri. Geri kalan yüzeyler — oda, turnuva, arkadaşlar,
/// paywall, mağaza, avatar, çark, sıralama — hâlâ 800×600, sıfır güvenli alan
/// ve ölçü fontuyla ölçülüyordu.
///
/// Bu üçlünün her biri gerçek kusur sakladı:
/// çentik dolgusu sıfır olduğu için sekme içeriğinin durum çubuğunun altına
/// girdiği görülmedi; ölçü fontu gerçek metrikleri taşımadığı için Kurmancî
/// joker etiketlerinin kırpıldığı görülmedi. Aynı iki körlük bu yüzeyler için
/// de geçerliydi ve hiçbiri ölçülmemişti (2026-08-17).
///
/// ## Kural
///
/// İki şey birden ölçülür ve ikisi de "görünüş" değil, KULLANILABİLİRLİK
/// ölçüsüdür:
///
/// 1. **Taşma yok.** `RenderFlex overflowed` hata olarak fırlar; `takeException`
///    onu yakalar. Taşan bir satır yalnız çirkin değildir — sarı-siyah bant
///    altındaki içerik tıklanamaz.
/// 2. **Kırpma yok.** `didExceedMaxLines` hiçbir metinde doğru olmamalı.
///    `find.text(...)` kırpılmış metni de bulur, çünkü kırpma çizim aşamasında
///    olur; bu yüzden varlık testleri bunu göremez.
///
/// Tarama **Kurmancî** koşar. Ürünün asıl dili odur (temiz kurulumda uygulama
/// Kurmancî açılır) ve Kurmancî metinler Türkçeden düzenli olarak uzundur —
/// yani kırpma önce burada görünür.
void main() {
  setUpAll(loadAppFonts);

  /// Ekranda kırpılmış metin var mı?
  ///
  /// Yalnız `RenderParagraph` sayılır: `TextPainter` ile çizilen metinler
  /// (çark dilimleri) bu ağaçta görünmez ve zaten simülatörden doğrulanır.
  List<String> truncatedTexts(WidgetTester tester) {
    final offenders = <String>[];
    for (final element in find.byType(Text).evaluate()) {
      final renderObject = element.renderObject;
      if (renderObject is! RenderParagraph) continue;
      if (!renderObject.didExceedMaxLines) continue;
      final data = (element.widget as Text).data;
      if (data != null && data.isNotEmpty) offenders.add(data);
    }
    return offenders;
  }

  Future<void> sweep(
    WidgetTester tester,
    String name,
    Widget Function() build, {
    bool dark = false,
  }) async {
    await tester.pumpWidget(
      testShell(
        child: withDeviceInsets(build()),
        languageProvider: kurmanciLang(),
        themeProvider: dark ? ThemeProvider(initialMode: ThemeMode.dark) : null,
      ),
    );
    // `pumpAndSettle` KULLANILMAZ: bu yüzeylerin bir kısmı sonsuz yükleme
    // animasyonu taşır ve koşucu kilitlenir (ekran turunun aynı kararı).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(
      tester.takeException(),
      isNull,
      reason: '$name gerçek telefon ölçüsünde taşıyor.',
    );

    // Boş ekranda taşma da kırpma da olmaz; yani bu bekçi, yüzey hiç
    // çizilmediyse kendiliğinden geçerdi. Mock depo asenkron yüklediği için
    // bu gerçek bir risk: ekranın DOLU olduğu ayrıca doğrulanır.
    final texts = find.byType(Text).evaluate().length;
    expect(
      texts,
      greaterThanOrEqualTo(3),
      reason:
          '$name yalnız $texts metinle çizildi — yüzey muhtemelen hiç '
          'yüklenmedi ve tarama boşa geçiyor.',
    );

    final truncated = truncatedTexts(tester);
    expect(
      truncated,
      isEmpty,
      reason:
          '$name üzerinde kırpılan metinler var; Kurmancî etiketler '
          'Türkçeden uzundur ve kırpma önce burada görünür:\n'
          '${truncated.join('\n')}',
    );
  }

  final surfaces = <String, Widget Function()>{
    'Sıralama': () => LeaderboardScreen(repository: freshMockRepository()),
    'Arkadaşlar': () => FriendsScreen(repository: freshMockRepository()),
    'Turnuva': () => TournamentScreen(repository: freshMockRepository()),
    'Mağaza': () => ShopScreen(repository: freshMockRepository()),
    'Çark': () => SpinWheelScreen(repository: freshMockRepository()),
    'Avatar düzenleyici': () =>
        AvatarEditorScreen(repository: freshMockRepository()),
    'Paywall': () => PaywallScreen(repository: freshMockRepository()),
  };

  surfaces.forEach((name, build) {
    testWidgets('$name Kurmancî\'de taşmadan ve kırpmadan çiziliyor', (
      tester,
    ) async {
      await sweep(tester, name, build);
    });
  });

  testWidgets('Oda ekranı Kurmancî\'de taşmadan ve kırpmadan çiziliyor', (
    tester,
  ) async {
    final repository = freshMockRepository();
    await sweep(
      tester,
      'Oda',
      () => RoomScreen(
        repository: repository,
        initialRoom: repository.createRoom(),
      ),
    );
  });

  // Karanlık tema ayrı bir çizim yolu değil ama yüzeylerin bir kısmı orada
  // farklı bileşen kullanıyor (ör. rozet/çip zeminleri). En kalabalık iki
  // yüzey karanlıkta da sürülür.
  testWidgets('Mağaza ve turnuva karanlık temada da sığıyor', (tester) async {
    await sweep(
      tester,
      'Mağaza (karanlık)',
      () => ShopScreen(repository: freshMockRepository()),
      dark: true,
    );
    await sweep(
      tester,
      'Turnuva (karanlık)',
      () => TournamentScreen(repository: freshMockRepository()),
      dark: true,
    );
  });
}
