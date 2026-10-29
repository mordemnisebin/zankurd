import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';

/// Gizlilik metni ve "İlerlemem başka cihaza taşınır mı?" cevabı GERÇEK
/// davranışı anlatır (Opus–Astra kapışması U1, 2026-10-29, ENGELLEYİCİ).
///
/// Kusur: metin "öğrenme ilerlemesi yalnız bu cihazda tutulur" diyordu;
/// oysa tamamlanan dersler `user_lesson_progress` tablosuna, kayıtlı
/// hesabın seri/rozet/yanlış geçmişi `save_my_progress` ile sunucuya
/// yazılıyor. Analiz ayarı için gösterilen "Ayarlar > Gizlilik ve veri"
/// yolu da yoktu; ayar "Hesap ve gizlilik" bölümünde. 2026-10-29'dan beri
/// analiz ve hata raporları ayrı anahtar, ikisi de varsayılan kapalı.
/// Sessiz kaldı çünkü hiçbir test metni koda bağlamıyordu: metin elle
/// yazılmış bir iddiaydı.
void main() {
  String tr(String key) => Tr.of(key, AppLanguage.tr);
  String ku(String key) => Tr.of(key, AppLanguage.ku);

  test('ayar yolları gerçek bölüm ve satır adlarından oluşur', () {
    for (final lang in AppLanguage.values) {
      String t(String k) => Tr.of(k, lang);
      final body = t(K.privacyBody);
      expect(
        body,
        contains(
          '${t(K.settings)} > ${t(K.secAccountPrivacy)} > '
          '${t(K.analyticsConsent)}',
        ),
        reason: '$lang: analiz ayarının yolu ekrandaki adlarla aynı olmalı',
      );
      expect(
        body,
        contains(
          '${t(K.settings)} > ${t(K.secAccountPrivacy)} > '
          '${t(K.crashReportsConsent)}',
        ),
        reason:
            '$lang: hata raporu ayarının yolu ekrandaki adlarla aynı olmalı',
      );
      expect(
        body,
        contains(
          '${t(K.settings)} > ${t(K.secDanger)} > ${t(K.deleteAccount)}',
        ),
        reason: '$lang: hesap silme yolu ekrandaki adlarla aynı olmalı',
      );
    }
    expect(tr(K.privacyBody), isNot(contains('Gizlilik ve veri')));
  });

  test('sunucuya giden ilerleme "yalnız cihazda" diye anlatılmaz', () {
    final body = tr(K.privacyBody);
    expect(body, contains('tamamlanan dersler'));
    expect(body, contains('yedeği de sunucuya'));
    expect(body, isNot(contains('öğrenme ilerlemesi yalnız bu cihazda')));
    // 2026-10-29 (Opus+Astra): analiz ve hata raporları ayrı anahtar,
    // ikisi de varsayılan kapalı (AnalyticsConsentProvider.defaultEnabled).
    // Metin "başlangıçta açıktır" ya da kanıtsız "anonim" diyemez.
    expect(body, contains('başlangıçta kapalıdır'));
    expect(body, isNot(contains('başlangıçta açıktır')));
    expect(body, isNot(contains('anonim çökme')));
    expect(ku(K.privacyBody), contains('di destpêkê de girtî ne'));
    expect(ku(K.privacyBody), isNot(contains('di destpêkê de vekirî ye')));

    // Metnin dayandığı kod gerçekleri yerinde mi? Biri değişirse metin de
    // gözden geçirilmeli.
    final repo = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    expect(repo, contains("from('user_lesson_progress')"));
    final consent = File(
      'lib/src/providers/analytics_consent_provider.dart',
    ).readAsStringSync();
    expect(consent, contains('defaultEnabled = false'));
    final sync = File('lib/src/data/progress_sync.dart').readAsStringSync();
    expect(sync, contains('misafir olmayan'));
  });

  test('SSS eşitleme cevabı misafir ile kayıtlı hesabı ayırır', () {
    final a = tr(K.faqSyncA);
    expect(a, contains('tamamlanan derslerin'));
    expect(a, contains('Misafir'));
    expect(a, contains('geri getirilemez'));
  });
}
