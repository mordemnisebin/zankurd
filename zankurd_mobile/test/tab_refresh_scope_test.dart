import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/utils/app_route.dart';

import 'support/widget_test_helpers.dart';

/// Sekme tazelemesinin YALNIZ sayfa geçişlerinde çalıştığının bekçisi.
///
/// ## Kusur
///
/// Tur bitince ana ekranın eski sayıları göstermesi, tazelemeyi kabuğun
/// `didPopNext`ine bağlayarak çözülmüştü. Çözüm doğru yeri buldu ama fazla
/// geniş bir kapıya bağlandı: `appRouteObserver` bir
/// `RouteObserver<ModalRoute>` ve `DialogRoute` ile `ModalBottomSheetRoute`
/// da `PopupRoute extends ModalRoute`. Yani her diyalog kapanışı da
/// tazeleme sayılıyordu.
///
/// Bedeli görünürdü: profil sekmesinde "Çıkış yap" diyaloğunu İPTAL etmek
/// ekranı iskelete döndürüyor, ad/istatistik/etiket/avatar yeniden
/// çekiliyordu — hiçbir şeyi değiştirmemiş bir iptalden sonra. Ana ekranda
/// zincir dondurma sayfasını kapatmak yedi yükleme tetikliyordu, biri ağ
/// üzerinden bakiye.
///
/// Sessizdi çünkü tazelemenin kendisi doğru çalışıyordu; fazladan çalışması
/// hiçbir testte ölçülmüyordu.
///
/// Tazeleme artık ayrı bir `RouteAware` üzerinden ve yalnız
/// `appPageRouteObserver`e bağlı. Ayrı nesne şart: kabuk iki gözlemciye
/// birden abone olsaydı sayfadan her dönüşte `didPopNext` iki kez çalışırdı.
void main() {
  Future<_StatsSpy> pumpShell(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _StatsSpy();
    await tester.pumpWidget(testShell(child: AppShell(repository: repository)));
    // `pumpAndSettle` burada zaman aşımına uğrar: kabuk sürekli dönen bir
    // yükleyici barındırıyor. Mevcut kabuk testleri de sayılı `pump` kullanır.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    return repository;
  }

  testWidgets('diyalog kapanışı sekmeyi tazelemiyor', (tester) async {
    final repo = await pumpShell(tester);
    final context = tester.element(find.byType(AppShell));
    final before = repo.statsCalls;

    // BEKLENMEZ: `showDialog`'un future'ı diyalog kapanana kadar dönmez;
    // beklemek testi kilitler.
    showDialog<void>(
      context: context,
      builder: (context) => const AlertDialog(content: Text('sınama')),
    ).ignore();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    Navigator.of(context, rootNavigator: true).pop();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(
      repo.statsCalls,
      before,
      reason:
          'Kapatılan bir diyalog sekmeyi tazeledi. İptal edilen bir eylemden '
          'sonra ekranın iskelete dönüp yeniden ağ isteği yapması, hiçbir '
          'şeyi onarmayan görünür bir gerilemedir.',
    );
  });

  testWidgets('sayfadan dönüş sekmeyi bir kez tazeliyor', (tester) async {
    // Korumanın öteki yarısı: daraltma, asıl düzeltmeyi kırmamalı ve
    // tazelemeyi ikiye de katlamamalı.
    final repo = await pumpShell(tester);
    final context = tester.element(find.byType(AppShell));
    final before = repo.statsCalls;

    Navigator.of(context)
        .push(
          AppRoute<void>(
            page: const Scaffold(body: Center(child: Text('sayfa'))),
          ),
        )
        .ignore();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    Navigator.of(context).pop();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(
      repo.statsCalls - before,
      lessThanOrEqualTo(1),
      reason:
          'Sayfadan dönüş tazelemeyi ikiye katladı; kabuk büyük olasılıkla '
          'iki gözlemciye birden abone.',
    );
  });
}

/// Kabuğun görünen sekmesinin tazelendiğini ölçen en ucuz gösterge.
class _StatsSpy extends MockZanKurdRepository {
  int statsCalls = 0;

  @override
  String? get currentUserId => 'shell-user';

  @override
  Future<int> loadCoinBalance() async {
    statsCalls++;
    return 0;
  }
}
