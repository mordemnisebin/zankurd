import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/feature_flags.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/screens/paywall_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/widgets/zk_back_button.dart';

import 'support/paywall_fixtures.dart';
import 'support/widget_test_helpers.dart';

/// Paywall dürüstlüğü (A10, 2026-10-01 tasarım denetimi).
///
/// ## Kusurlar
///
/// 1. **Uydurma popülerlik iddiası.** Yıllık paketin üstünde "En çok alınan"
///    ("Ya herî zêde tê kirîn") rozeti duruyordu. Satış verisi yok; rozet her
///    kurulumda yıllık pakete yapışıyordu. Aynı iddia mağazada 2026-09-29'da
///    tam bu gerekçeyle (K10) kaldırılmıştı ama paywall'da kalmıştı.
/// 2. **Asimetrik iptal sözü.** "İstediğin zaman iptal" yalnız AYLIK kartta
///    yazıyordu; yıllık kart sessizdi ve okuyan kişi yıllığın iptal
///    edilemediğini sanabilirdi.
/// 3. **Fiyatsız satın alma.** Mağaza bir paketin fiyatını çözemediğinde
///    kart "Fiyat geliyor" yazıyor ama "Satın al" düğmesi ETKİN kalıyordu:
///    kullanıcı ne ödeyeceğini görmeden onaya götürülüyordu (Apple 3.1.2).
/// 4. **Geri yükle yalnız paketle görünürdü.** Paketler yüklenemeyince (ağ
///    hatası) ya da henüz aktif olmayınca "Satın alımları geri yükle" ve
///    hukuk bağlantıları gizleniyordu; başka cihazdan abone olmuş kullanıcı
///    aboneliğini geri getirmenin tek yolunu görmüyor, yeniden satın almaya
///    itiliyordu.
///
/// ## Niçin sessiz kaldı
///
/// Paywall testleri `Offerings({})` ile koşuyordu: paket kartı hiç çizilmedi,
/// yani rozet, iptal sözü ve düğme durumu ölçülmedi. Geri yükle gizleme ise
/// bir testle KORUNUYORDU (`paywall_compliance_test`: restore `findsNothing`)
/// — kusur savunulmuştu. Üstelik fayda metinlerinin kodda karşılığı olup
/// olmadığını ölçen hiçbir şey yoktu; kapalı bir özelliği (turnuva, lig)
/// vaat eden satır sessizce girebilirdi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPaywall(
    WidgetTester tester, {
    bool unknownMonthlyPrice = false,
    String lang = 'tr',
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(
        child: PaywallScreen(repository: MockZanKurdRepository()),
        premiumService: fakePaywallService(
          unknownMonthlyPrice: unknownMonthlyPrice,
        ),
        languageProvider: lang == 'ku' ? kurmanciLang() : turkishLang(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('paketli ekran', () {
    for (final lang in ['tr', 'ku']) {
      final l = lang == 'ku' ? AppLanguage.ku : AppLanguage.tr;

      testWidgets('satış verisi olmadan popülerlik iddiası yok ($lang)', (
        tester,
      ) async {
        await pumpPaywall(tester, lang: lang);
        expect(find.byType(SahneBadge), findsNothing);
        for (final claim in [
          'En çok alınan',
          'Ya herî zêde tê kirîn',
          'Popüler',
          'En iyi değer',
        ]) {
          expect(find.text(claim), findsNothing);
        }
      });

      testWidgets('iptal sözü her pakette aynıdır ($lang)', (tester) async {
        await pumpPaywall(tester, lang: lang);
        expect(
          find.text(Tr.of(K.cancelAnytime, l)),
          findsNWidgets(2),
          reason: 'Aylık ve yıllık kartın ikisi de iptal koşulunu söylemeli.',
        );
      });

      testWidgets(
        'fiyat, dönem, yenileme koşulu, geri yükle ve hukuk bağlantıları '
        'satın alma anında görünür ($lang)',
        (tester) async {
          await pumpPaywall(tester, lang: lang);
          final perMonth = Tr.of(K.perMonthSuffix, l);
          final perYear = Tr.of(K.perYearSuffix, l);
          expect(find.text('₺39,99$perMonth'), findsOneWidget);
          expect(find.text('₺399,99$perYear'), findsOneWidget);
          // Yıllığın aylık karşılığı mağazanın kendi fiyatından hesaplanır.
          expect(find.text('≈ ₺33,33$perMonth'), findsOneWidget);
          expect(find.text(Tr.of(K.paywallRenewalTerms, l)), findsOneWidget);
          expect(find.text(Tr.of(K.restorePurchases, l)), findsOneWidget);
          expect(find.text(Tr.of(K.privacyPolicy, l)), findsOneWidget);
          expect(find.text(Tr.of(K.termsOfUse, l)), findsOneWidget);
        },
      );
    }

    testWidgets('fiyatı çözülmemiş paket satın alınamaz', (tester) async {
      await pumpPaywall(tester, unknownMonthlyPrice: true);
      expect(find.text(Tr.of(K.priceComing, AppLanguage.tr)), findsOneWidget);

      Finder buy(int index) => find.descendant(
        of: find.byType(SahneSurfaceCard).at(index),
        matching: find.byType(FilledButton),
      );
      // Sıra: yıllık (fiyatlı), aylık (fiyatsız).
      expect(tester.widget<FilledButton>(buy(0)).onPressed, isNotNull);
      expect(
        tester.widget<FilledButton>(buy(1)).onPressed,
        isNull,
        reason: 'Fiyatı görünmeyen pakette "Satın al" etkin kalmış.',
      );
    });

    testWidgets('kapatma düğmesi görünür ve en az 48 dp', (tester) async {
      await pumpPaywall(tester);
      final back = find.byType(ZkBackButton);
      expect(back, findsOneWidget);
      final size = tester.getSize(
        find.descendant(of: back, matching: find.byType(SahneIconButton)),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  testWidgets('paket yokken de geri yükle ve hukuk bağlantıları görünür', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(
        child: PaywallScreen(repository: MockZanKurdRepository()),
        // Yapılandırılmamış servis: boş teklif listesi.
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(Tr.of(K.paywallPackagesInactive, AppLanguage.tr)),
      findsOneWidget,
    );
    expect(
      find.text(Tr.of(K.restorePurchases, AppLanguage.tr)),
      findsOneWidget,
    );
    expect(find.text(Tr.of(K.privacyPolicy, AppLanguage.tr)), findsOneWidget);
    // Olmayan bir aboneliğin yenileme koşulu yazılmaz.
    expect(
      find.text(Tr.of(K.paywallRenewalTerms, AppLanguage.tr)),
      findsNothing,
    );
  });

  // Fayda metinlerinin kodda karşılığı olmalı. Bekçi iki yönlüdür: kapalı
  // özelliği anan sözcük yasak, açık iddianın dayanağı kodda aranır.
  group('fayda iddiaları kodda karşılık bulur', () {
    final copyKeys = [
      K.paywallSubtitle,
      K.paywallFeatures,
      K.paywallPerkStreak,
      K.paywallPerkStreakBody,
      K.paywallPerkSupport,
      K.paywallPerkSupportBody,
      K.premiumPerks,
      K.premiumActive,
    ];

    test('kapalı ya da olmayan özellikleri vaat eden söz yok', () {
      // `kTournamentEnabled` ve `kWeeklyLeagueEnabled` kapalıyken Premium
      // bu özellikleri anarsa kullanıcı olmayan bir şey için öder. Bayrak
      // açılırsa bu bekçi bilerek yeniden yazılmalı.
      expect(kTournamentEnabled, isFalse);
      expect(kWeeklyLeagueEnabled, isFalse);
      const banned = [
        'turnuva', 'tournament', 'lig', 'league', // kapalı bayraklar
        'sınırsız', 'bêsînor', 'unlimited', // ölçülmemiş miktar
        'reklam', 'ad-free', // reklamsız söz verilmiyor
        'indirim', 'dakika', 'son fırsat', // sahte aciliyet / indirim
      ];
      for (final key in copyKeys) {
        for (final lang in AppLanguage.values) {
          final text = Tr.of(key, lang).toLowerCase();
          for (final word in banned) {
            // Sözcük başında eşleşir: "lig" "bilgi"nin içinde değil,
            // "lige"nin başında aranır.
            final found = RegExp(
              '(?<![a-zçğıöşüêîû])${RegExp.escape(word)}',
            ).hasMatch(text);
            expect(
              found,
              isFalse,
              reason: '$key ($lang) "$word" diyor; kodda karşılığı yok.',
            );
          }
        }
      }
    });

    test('"otomatik seri koruması" sonuç ekranında gerçekten uygulanır', () {
      final result = File(
        'lib/src/screens/quiz_result_screen.dart',
      ).readAsStringSync();
      // Premium kapısı: taze entitlement bilinen premium ise dondurma
      // ücretsiz uygulanır.
      expect(result, contains('refresh.isPremium'));
      expect(result, contains('streakStore.addFreeze()'));
      expect(result, contains('freezeAndRecordPlay'));
    });
  });
}
