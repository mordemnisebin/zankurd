/// Hesap değişiminde analitik/Crashlytics rızası önceki kullanıcıdan kalıyordu
/// (GPT-6 Pro 2.1.2 alan 7, bulgu 1.1).
///
/// ## Kusur
///
/// Rıza anahtarları cihaz geneli; yaş beyanı ise hesaba bağlı. A "13+" deyip
/// analizi açtıktan sonra aynı cihazda B'ye geçilince `AgeGate.bindUser` A'nın
/// beyanını geçersiz kılıyor ama `AnalyticsConsentProvider` bellekte açık
/// kalıyor, çalışan Firebase SDK durmuyor ve diskteki "evet" B "13+" dediği
/// anda B'nin rızası gibi uygulanıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Tek hesaplı testlerde hiç hesap değişmez; arayüz anahtarı bellekten okur ve
/// SDK durumunu hiçbir test sormaz.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/age_gate_store.dart';
import 'package:zankurd_mobile/src/providers/analytics_consent_provider.dart';
import 'package:zankurd_mobile/src/utils/error_reporter.dart';

Future<AnalyticsConsentProvider> _aAcik() async {
  SharedPreferences.setMockInitialValues({
    AgeGate.declarationKey: 'adult',
    AgeGate.ownerKey: 'a',
    'zankurd.analyticsConsent': true,
    'zankurd.crashReportsConsent': true,
  });
  AgeGate.debugSet(null);
  final consent = await AnalyticsConsentProvider.load();
  await AgeGate.bindUser('a');
  expect(consent.enabled, isTrue);
  expect(consent.crashReportsEnabled, isTrue);
  return consent;
}

void main() {
  tearDown(() {
    AnalyticsConsentProvider.isEnabled = false;
    ErrorReporter.crashlyticsEnabled = false;
  });

  test('A -> B: bellek, statik bayraklar ve disk B için sıfırlanır', () async {
    final consent = await _aAcik();
    await AgeGate.bindUser('b');
    expect(consent.enabled, isFalse);
    expect(consent.crashReportsEnabled, isFalse);
    expect(AnalyticsConsentProvider.isEnabled, isFalse);
    expect(ErrorReporter.crashlyticsEnabled, isFalse);
    // Yazım kuyruğunun boşalmasını bekle.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('zankurd.analyticsConsent'), isNot(true));
    expect(prefs.getBool('zankurd.crashReportsConsent'), isNot(true));
    // B şimdi "13+" derse A'nın eski "evet"i uygulanmaz.
    await AgeGate.declare(AgeDeclaration.adult);
    final yeni = await AnalyticsConsentProvider.load();
    expect(yeni.enabled, isFalse);
    expect(yeni.crashReportsEnabled, isFalse);
    consent.dispose();
    yeni.dispose();
  });

  test('yetişkinden çocuğa düzeltme de rızayı kapatır', () async {
    final consent = await _aAcik();
    await AgeGate.declare(AgeDeclaration.minor);
    expect(consent.enabled, isFalse);
    expect(AnalyticsConsentProvider.isEnabled, isFalse);
    consent.dispose();
  });

  test('aynı hesapta yeniden bağlanma rızaya dokunmaz', () async {
    final consent = await _aAcik();
    await AgeGate.bindUser('a');
    expect(consent.enabled, isTrue);
    consent.dispose();
  });
}
