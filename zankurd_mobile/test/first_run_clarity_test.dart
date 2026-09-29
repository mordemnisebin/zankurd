// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
/// İlk kez giren oyuncu ilk birkaç dakikada kaybolmasın: simülatörde canlı
/// gezintinin bulduğu beş belirsizlik noktası.
///
/// ## Kusur
///
/// Canlı gezinti beş ayrı noktada ilk kez giren oyuncuyu durdurdu — hiçbiri
/// çökme değildi, hepsi yalnız BELİRSİZDİ:
///
/// 1. Tanıtımdaki dil "hapı" yalnız O ANKİ dili yazıyordu ("KU" ya da "TR");
///    karşı dile NASIL geçileceği hiçbir yerde görünmüyordu.
/// 2. Yaş kutusu işaretsizken "Başla"ya basınca çıkan SnackBar ne
///    yapılacağını söylemiyordu VE tam "Başla" düğmesinin üstüne oturuyordu.
/// 3. Ad ekranı, tanıtım turunun VE giriş ekranının zaten anlattığı
///    "ZanKurd'a hoş geldin" karşılamasını ve aynı üç özelliği ÜÇÜNCÜ kez
///    tekrarlıyordu; asıl soru ("Oyundaki adın ne olsun?") bu gürültünün
///    altında kalıyordu.
/// 4. İlk ders bitince günlük görev kartı hâlâ "Günün dersi" diyordu;
///    oyuncu az önce bir ders bitirmişken aynı adı yeniden görünce
///    "bitirdim, neden yine ders?" diye duruyordu.
/// 5. Tanıtımın 1. sayfasında logo, 2. sayfasında düz "ZanKurd" yazısı
///    vardı — aynı sabit yükseklikli başlık kutusunda çok daha küçük
///    içerik durunca üstte boşluk açılıyor, başlık sayfa geçişinde
///    zıplıyormuş gibi görünüyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Var olan testlerin hepsi FONKSİYONEL doğruluğu ölçüyordu: düğme doğru
/// callback'i çağırıyor mu, anahtar doğru widget'ı buluyor mu, ekran
/// taşıyor mu. Beşi de bu ölçüde zaten "doğru" geçiyordu — kutu
/// işaretlenince onboarding gerçekten tamamlanıyor, kart gerçekten doğru
/// sayıyı gösteriyordu. Hiçbir test "yeni gelen biri bu ekranı görünce ne
/// YAPACAĞINI anlıyor mu" sorusunu sormuyordu; bu yalnız simülatörde
/// uçtan uca, sanki ilk kez giriyormuş gibi gezinince ortaya çıktı.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/home/today_task_card.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_name_gate_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/app_logo.dart';

import 'support/widget_test_helpers.dart';

/// Tek başına `OnboardingScreen`i (yalnız dil sağlayıcısıyla) çizer —
/// `onboarding_hierarchy_test.dart` ile aynı hafif kurulum.
Future<void> _pumpOnboarding(
  WidgetTester tester, {
  String lang = 'tr',
  VoidCallback? onComplete,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => LanguageProvider()..setLang(lang),
      child: MaterialApp(
        home: OnboardingScreen(onComplete: onComplete ?? () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('1) Tanıtımda iki parçalı KU|TR seçici', () {
    testWidgets('her iki dil de aynı anda görünür — yalnız o anki dil değil', (
      tester,
    ) async {
      await _pumpOnboarding(tester, lang: 'ku');

      expect(
        find.byKey(const ValueKey('onboarding-language-ku')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-language-tr')),
        findsOneWidget,
      );
      // Eski tek hap yalnız TEK etiket gösterirdi (o anki dil); şimdi
      // ikisi de aynı anda ekranda — karşı dile nasıl geçileceği görünür.
      expect(find.text('KU'), findsOneWidget);
      expect(find.text('TR'), findsOneWidget);
    });

    testWidgets('TR çipine dokununca tanıtım gerçekten Türkçeye geçer', (
      tester,
    ) async {
      await _pumpOnboarding(tester, lang: 'ku');
      expect(find.text('Bidomîne'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('onboarding-language-tr')));
      await tester.pumpAndSettle();

      expect(find.text('Sonraki'), findsOneWidget);
      expect(find.text('Bidomîne'), findsNothing);
    });

    test('giriş ekranındaki seçiciyle aynı bileşeni paylaşır', () {
      // Regresyon: iki ekran aynı kararı iki ayrı kopyada uygulamasın diye
      // `LanguageToggle` `lib/src/widgets/` altına çıkarıldı.
      final source = File(
        'lib/src/screens/onboarding_screen.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('class _OnboardingLanguageToggle')));
      expect(source, contains("import '../widgets/language_toggle.dart';"));
    });
  });

  group('2) Yaş uyarısı satır içi ve yönlendirici', () {
    testWidgets(
      'kutu işaretsizken "Başla" SnackBar değil satır içi ipucu gösterir',
      (tester) async {
        var completed = false;
        await _pumpOnboarding(tester, onComplete: () => completed = true);
        await tester.tap(find.text('Sonraki'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('onboarding-age-gate-hint')),
          findsNothing,
          reason: 'henüz hiçbir deneme yokken ipucu erken görünmemeli',
        );

        await tester.tap(find.text('Başla'));
        await tester.pumpAndSettle();

        // Ne YAPILACAĞI artık söyleniyor...
        expect(
          find.text(
            'Devam etmek için "13 yaşından büyüğüm" kutusunu işaretle.',
          ),
          findsOneWidget,
        );
        // ...bir SnackBar'da DEĞİL (SnackBar "Başla"nın üstüne oturuyordu).
        expect(find.byType(SnackBar), findsNothing);
        expect(completed, isFalse);
      },
    );

    testWidgets('kutu işaretlenince ipucu hemen kaybolur ve akış tamamlanır', (
      tester,
    ) async {
      var completed = false;
      await _pumpOnboarding(tester, onComplete: () => completed = true);
      await tester.tap(find.text('Sonraki'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Başla'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('onboarding-age-gate-hint')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('onboarding-age-gate')));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('onboarding-age-gate-hint')),
        findsNothing,
        reason: 'kutu işaretlenince uyarı oyalamaya devam etmemeli',
      );

      await tester.tap(find.text('Başla'));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
    });
  });

  group('3) Ad ekranında karşılama tekrarı yok', () {
    testWidgets(
      'büyük "Hoş Geldin" bloğu ve üç özellik maddesi bir daha görünmez',
      (tester) async {
        await tester.pumpWidget(
          testShell(
            child: ProfileNameGateScreen(
              repository: MockZanKurdRepository(),
              onCompleted: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tanıtım turu ve giriş ekranı bunları ZATEN söylemişti.
        expect(find.text("ZanKurd'a Hoş Geldin!"), findsNothing);
        expect(
          find.text('Öğren, ilerle ve arkadaşlarınla eğlen.'),
          findsNothing,
        );
        expect(find.text('Oyunları tamamla, ödül kazan'), findsNothing);
        expect(find.text('Arkadaşlarınla yarış'), findsNothing);

        // Asıl iş — tek soru — yerinde duruyor.
        expect(find.text('Oyundaki adın ne olsun?'), findsOneWidget);
        expect(find.byKey(const ValueKey('player-name-field')), findsOneWidget);
        expect(find.text('Şimdilik geç'), findsOneWidget);

        // Hero tamamen kaldırılmadı — küçük marka şeridi (logo) kaldı.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('profile-name-gate-hero-surface')),
            matching: find.byType(AppLogo),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('3b) Ad kartı marka şeridinin hemen altında başlar', () {
    testWidgets('uzun ekranda kart ortada yüzmez', (tester) async {
      // Hero yalnız logo şeridine inince kalan alanda ORTALANAN kart
      // ekranın ortasına düştü: üstünde ve altında ~400px boşluk kaldı,
      // ekran yarım yüklenmiş gibi göründü (2026-09-27 tur görüntüsü).
      await tester.binding.setSurfaceSize(const Size(390, 1300));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testShell(
          child: ProfileNameGateScreen(
            repository: MockZanKurdRepository(),
            onCompleted: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final heroBottom = tester
          .getBottomLeft(find.byKey(const ValueKey('profile-name-gate-hero')))
          .dy;
      final cardTop = tester
          .getTopLeft(find.byKey(const ValueKey('profile-name-gate-card')))
          .dy;
      expect(
        cardTop - heroBottom,
        lessThanOrEqualTo(AppSpacing.xl + 1),
        reason: 'Kart şeridin altında sayfa boşluğu kadar aralıkla başlamalı.',
      );
    });
  });

  group('4) Günlük hedef kalan DOĞRU CEVABI sayar', () {
    Widget wrap(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );

    testWidgets('ilk oturum kartına ("Küçük başlangıç") dokunulmadı', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const TodayTaskCard(
            isKu: false,
            loading: false,
            onStart: _noop,
            done: 2,
            total: 5,
            firstSession: true,
          ),
        ),
      );

      expect(find.text('Günün dersi'), findsOneWidget);
      expect(find.text('Günlük hedef'), findsNothing);
    });

    testWidgets('tamamlanmış hedef durumuna dokunulmadı (done >= total)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const TodayTaskCard(
            isKu: false,
            loading: false,
            onStart: _noop,
            done: 10,
            total: 10,
          ),
        ),
      );

      expect(find.text('Günün dersi'), findsOneWidget);
      expect(find.text('Günlük hedef'), findsNothing);
    });

    testWidgets(
      'ilk oturum DIŞINDA ve hedef tamamlanmadan ÖNCE başlık günlük hedefe '
      'döner, alt satır kalan DOĞRU CEVABI söyler (soru sayısını değil)',
      (tester) async {
        // done = bugün verilen DOĞRU cevap, total = günlük "answerCorrect"
        // hedefi (bkz. HomeScreen._todayAnswered/_todayTarget). 4/10 burada
        // "4 doğru cevap, hedef 10" demektir — 4 SORU cevaplandı demek
        // değildir.
        await tester.pumpWidget(
          wrap(
            const TodayTaskCard(
              isKu: false,
              loading: false,
              onStart: _noop,
              done: 4,
              total: 10,
            ),
          ),
        );

        expect(find.text('Günlük hedef'), findsOneWidget);
        expect(find.text('Günün dersi'), findsNothing);
        // Kalan = 10-4 = 6; süre de KALANDAN hesaplanır:
        // ((6*25)/60).ceil() = 3 dakika. Toplamdan (10 → 5 dakika)
        // hesaplansaydı yarısı biten hedef için süre hiç kısalmazdı.
        expect(
          find.text('6 doğru cevap daha · yaklaşık 3 dakika'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'günün ilk açılışı (0 doğru) "Günün dersi" kalır — "10 doğru cevap '
      'daha" demez',
      (tester) async {
        // Henüz hiçbir şey yapılmamışken "daha" kelimesi boşa düşer; oyuncu
        // önce dersi görmeli. Hedef dili ilerleme başlayınca devreye girer.
        await tester.pumpWidget(
          wrap(
            const TodayTaskCard(
              isKu: false,
              loading: false,
              onStart: _noop,
              done: 0,
              total: 10,
            ),
          ),
        );

        expect(find.text('Günün dersi'), findsOneWidget);
        expect(find.text('Günlük hedef'), findsNothing);
        expect(find.text('10 soru · yaklaşık 5 dakika'), findsOneWidget);
      },
    );

    testWidgets('Kurmancî: alt satır da kalan DOĞRU CEVABI söyler', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const TodayTaskCard(
            isKu: true,
            loading: false,
            onStart: _noop,
            done: 4,
            total: 10,
          ),
        ),
      );

      expect(find.text('Armanca rojane'), findsOneWidget);
      expect(
        find.text('6 bersivên rast ên din · nêzîkî 3 deqe'),
        findsOneWidget,
      );
    });
  });

  group('5) Tanıtım başlığı sayfalar arası zıplamaz', () {
    testWidgets(
      '1. ve 2. sayfada üst alan aynı logoyu kullanır, düz metne düşmez',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pumpOnboarding(tester);

        expect(find.byType(AppLogo), findsOneWidget);
        final widthPage0 = tester.widget<AppLogo>(find.byType(AppLogo)).width;
        final headerHeightPage0 = tester
            .getSize(find.byKey(const ValueKey('onboarding-header')))
            .height;

        await tester.tap(find.text('Sonraki'));
        await tester.pumpAndSettle();

        // Eskiden burada logo kaybolup düz "ZanKurd" yazısına düşüyordu;
        // aynı sabit yükseklikli kutuda çok daha küçük içerik durunca
        // üstte boşluk açılıyor, başlık zıplıyormuş gibi görünüyordu.
        expect(
          find.byType(AppLogo),
          findsOneWidget,
          reason: '2. sayfada da logo görünmeli, düz metne düşmemeli',
        );
        final widthPage1 = tester.widget<AppLogo>(find.byType(AppLogo)).width;
        final headerHeightPage1 = tester
            .getSize(find.byKey(const ValueKey('onboarding-header')))
            .height;

        expect(widthPage1, widthPage0);
        expect(headerHeightPage1, headerHeightPage0);
      },
    );
  });
}

void _noop() {}
