import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/profile_name_gate_screen.dart';

import 'support/widget_test_helpers.dart';

/// 2026-07-22 canlı UX denetimi (P1-C): boş adla "Oyuna Başla"ya basınca
/// çıkan "Ad en az 2 karakter olmalı" uyarısı, geçerli bir ad yazıldıktan
/// sonra da ekranda kalıyordu — TextFormField varsayılan olarak yalnız
/// Form.validate() ile güncelleniyor.
void main() {
  testWidgets('geçerli ad yazılınca hata durumu temizlenir', (tester) async {
    await tester.pumpWidget(
      testShell(
        child: ProfileNameGateScreen(
          repository: MockZanKurdRepository(),
          onCompleted: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('player-name-field'));
    expect(field, findsOneWidget);

    // Boş adla gönder → hata görünür.
    await tester.tap(find.text('Oyuna başla'));
    await tester.pumpAndSettle();
    expect(find.text('Ad en az 2 karakter olmalı'), findsOneWidget);

    // Geçerli ad yaz → hata kendiliğinden kaybolmalı.
    await tester.enterText(field, 'Rojhat');
    await tester.pumpAndSettle();
    expect(
      find.text('Ad en az 2 karakter olmalı'),
      findsNothing,
      reason: 'girdi geçerli hale gelince hata temizlenmeli',
    );
  });

  // 2026-07-23 M23: hero bölümü önceden ekran yüksekliğinin sabit bir
  // yüzdesini (flex 42-45) alıyordu — uzun ekranda alt kısmı tamamen boş
  // kalıyordu. Artık içerik kadar yer kaplıyor; bu yüzden hero yüksekliği
  // ekran yüksekliğinden bağımsız (sabit) olmalı.
  testWidgets(
    'hero bölümü ekran yüksekliğine göre esnemez (içerik kadar yer kaplar)',
    (tester) async {
      Future<double> heroHeightAt(Size size) async {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          testShell(
            child: ProfileNameGateScreen(
              repository: MockZanKurdRepository(),
              onCompleted: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester
            .getSize(find.byKey(const ValueKey('profile-name-gate-hero')))
            .height;
      }

      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 900 ve 1300: ikisi de "compact" eşiğinin (860) üstünde, yani aynı
      // içerik (3 değer satırı) render edilir — tek fark ekran yüksekliği.
      // Flex kaldırılmadan önce bu 400px'lik fark hero'ya da yansırdı.
      final shortHeroHeight = await heroHeightAt(const Size(390, 900));
      final tallHeroHeight = await heroHeightAt(const Size(390, 1300));

      expect(
        (tallHeroHeight - shortHeroHeight).abs(),
        lessThan(5),
        reason:
            'Hero, ekran yüksekliğinin %42-45\'i gibi sabit bir oran '
            'almamalı — flex kaldırıldığından her iki ekranda da aynı '
            '(içerik kadar) yükseklikte olmalı.',
      );
    },
  );

  testWidgets('kaydetme başarısız olursa oyuncu niçin geçemediğini görür', (
    tester,
  ) async {
    // 2026-07-31, sahibin iPhone ekran görüntüleri: adını yazıyor,
    // "Dest pê bike"ye basıyor ve **hiçbir şey olmuyor**.
    //
    // Sebep iki katmanlıydı. Ad kaydetmek ağ üzerinden `profiles` tablosuna
    // yazmayı gerektiriyor; o yazım başarısız olunca hata bir SnackBar ile
    // bildiriliyordu. Ama tema `SnackBarBehavior.floating` kullanır — kutu
    // ekranın en altına konur ve **açık klavye tam orayı örter**. Mesaj
    // klavyenin arkasında doğup üç saniye sonra ölüyordu.
    //
    // Sonuç, ekranın en can sıkıcı hâliydi: ad vermek, ad vermemekten zor.
    // "Paşê bike" hiç ağ çağrısı yapmadan geçerken, ad giren oyuncu
    // açıklamasız bir duvara çarpıyordu.
    //
    // Kusur sessizdi çünkü buradaki mevcut durumlar yalnız **doğrulama**
    // hatasını (boş ad) sınıyor; kaydetmenin kendisi hiç başarısız
    // olmuyordu.
    await tester.pumpWidget(
      testShell(
        child: ProfileNameGateScreen(
          repository: _KaydetmeyenDepo(),
          onCompleted: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('player-name-field')),
      'Çekdar',
    );
    await tester.tap(find.text('Oyuna başla'));
    await tester.pumpAndSettle();

    // Hata formun içinde, kalıcı olarak duruyor — klavyenin arkasında değil.
    expect(find.byKey(const ValueKey('name-gate-save-error')), findsOneWidget);
    expect(find.textContaining('Ad kaydedilemedi'), findsOneWidget);

    // Ve çıkış yolu hâlâ görünür: oyuncu tıkanmış durumda bırakılmaz.
    expect(find.text('Şimdilik geç'), findsOneWidget);
  });

  testWidgets(
    'kapı önce boş ve kullanılabilir görünür, sonra geçerli sunucu adıyla dolar',
    (tester) async {
      final repository = _GecikenProfilAdiDeposu();
      await tester.pumpWidget(
        testShell(
          child: ProfileNameGateScreen(
            repository: repository,
            onCompleted: () {},
          ),
        ),
      );
      await tester.pump();

      final field = find.byKey(const ValueKey('player-name-field'));
      expect(field, findsOneWidget);
      expect(tester.widget<TextFormField>(field).controller!.text, isEmpty);
      expect(tester.widget<TextFormField>(field).enabled, isTrue);

      repository.profileName.complete('Rojhat');
      await tester.pump();

      expect(tester.widget<TextFormField>(field).controller!.text, 'Rojhat');
    },
  );

  testWidgets('kullanıcının yazdığı ad geciken sunucu adıyla ezilmez', (
    tester,
  ) async {
    final repository = _GecikenProfilAdiDeposu();
    await tester.pumpWidget(
      testShell(
        child: ProfileNameGateScreen(
          repository: repository,
          onCompleted: () {},
        ),
      ),
    );
    await tester.pump();

    final field = find.byKey(const ValueKey('player-name-field'));
    await tester.enterText(field, 'Dilan');
    repository.profileName.complete('Rojhat');
    await tester.pump();

    expect(tester.widget<TextFormField>(field).controller!.text, 'Dilan');
  });
}

/// Ad yazımı her seferinde başarısız olan depo — canlıdaki ağ/RLS hatasının
/// testteki karşılığı.
class _KaydetmeyenDepo extends MockZanKurdRepository {
  @override
  Future<void> updateProfileName(String name) async {
    throw StateError('profil adı yazılamadı');
  }
}

class _GecikenProfilAdiDeposu extends MockZanKurdRepository {
  final profileName = Completer<String>();

  @override
  Future<String> getProfileName() => profileName.future;
}
