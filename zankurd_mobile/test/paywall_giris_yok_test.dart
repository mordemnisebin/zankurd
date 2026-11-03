/// Satın alma (Pro) etkin değilken paywall'a giden giriş YOKTUR
/// (2026-10-28 kurul K12).
///
/// ## Kusur
///
/// Paketler yüklenmemişken (Pro kapalı, satıcı hesabı yok, mağaza ürünü boş)
/// paywall'a götüren bir giriş görünürse kullanıcı "Premium paketler henüz
/// aktif değil" ve çıkmaz bir "Tekrar dene" ile karşılaşır; Android'de
/// 2026-10-23'te yaşandı. Girişler artık `kProEnabled` + `canSell` kapısının
/// arkasındadır; boş durumda "Tekrar dene" yerine "Geri" vardır (bkz.
/// `paywall_compliance_test.dart`).
///
/// ## Niçin sessiz kalırdı
///
/// Ana sayfa girişi `home_premium_entry_test.dart`'ta sınanıyordu; Ayarlar
/// girişi ve YENİ eklenecek girişler hiçbir yerde sınanmıyordu. Bu dosya
/// iki şeyi bağlar: (1) Ayarlar'da, satılabilir paket yokken Premium satırı
/// çizilmez; (2) kodda `PaywallScreen(` kuran her dosya `canSell` kapısını da
/// içerir (yeni giriş kapısız eklenirse test kırılır).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

void main() {
  restoreKapisiTesti();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => PremiumService.debugCanSell = null);

  testWidgets('paket yokken Ayarlar\'da Premium satırı çizilmez', (
    tester,
  ) async {
    PremiumService.debugCanSell = false;
    await tester.binding.setSurfaceSize(const Size(390, 6000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(child: SettingsScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Premium'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is SahneListRow && w.title.contains('Pro'),
      ),
      findsNothing,
    );
  });

  test('PaywallScreen kuran her giriş canSell kapısının arkasında', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('paywall_screen.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('PaywallScreen(') && !source.contains('canSell')) {
        offenders.add(entity.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Paywall girişi satılabilir paket kapısı (PremiumService.canSell) '
          'olmadan eklenmiş: $offenders',
    );
  });
}

/// Paket yokken paywall girişi gizlenir ama geri yükleme kapanmaz: başka
/// cihazdan abone olmuş kullanıcı aboneliğini geri getirecek yolu
/// kaybederse yeniden satın almaya itilir.
void restoreKapisiTesti() {
  test('paket yokken yalnız geri yükleme satırı açık kalır', () {
    bool f({
      bool pro = true,
      bool conf = true,
      bool prem = false,
      bool sell = false,
    }) => settingsRestoreOnly(
      proEnabled: pro,
      configured: conf,
      isPremium: prem,
      canSell: sell,
    );
    expect(f(), isTrue);
    expect(f(sell: true), isFalse); // paket var: tam Premium satırı
    expect(f(prem: true), isFalse); // abone: durum satırı
    expect(f(pro: false), isFalse);
    expect(f(conf: false), isFalse);
  });
}
