/// GPT-6 Pro alan 9 (mağaza/gizlilik/yasal) bulgularının bekçisi.
///
/// ## Kusurlar
///
/// * Hesap silme profil fotoğrafını `delete_my_account` içindeki doğrudan SQL
///   `DELETE FROM storage.objects` ile siliyordu: Supabase'te fiziksel dosyayı
///   silmez (korumalı projede hata verip hesap silmeyi geri alır). Dosya artık
///   RPC'den ÖNCE Storage API'siyle silinir.
/// * Ardışık hesap silmelerinde başkalarının `room_result_snapshots` JSON'unda
///   silinen kişinin kimliği/adı kalıyordu (göç + yerel PGlite kanıtı).
/// * `kProEnabled=false` iken bile RevenueCat yapılandırılıp her kullanıcının
///   kimliği (misafir dahil) oraya gönderiliyordu.
/// * Gizlilik metni Firebase Analytics'in IP'den türettiği yaklaşık konumu
///   anlatmıyor, hazırlık belgesi "konum izni yok → konum verisi yok" diyordu.
/// * `delete-account.html` e-postasız misafir ve Apple gizli adresi için
///   doğrulama yolu vermiyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Hiçbiri hata vermez: fiziksel dosya sessizce kalır, JSON'daki kimlik yalnız
/// bilerek kurulan ardışık silmede görünür, RevenueCat kaydı SDK'nın kendi
/// panelinde birikir, metin eksikliği derleyiciye görünmez. Yaş sorusunun
/// cevapsız kapatılması testi `riza_yas_beyani_test.dart` içindedir.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';

class _LogHttp extends http.BaseClient {
  _LogHttp(this.log);
  final List<String> log;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    log.add(request.url.path);
    final bytes = utf8.encode(jsonEncode({'deleted': true}));
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _Repo extends SupabaseZanKurdRepository {
  _Repo(super.client, this.log);
  final List<String> log;

  @override
  bool get hasAppleIdentity => false;

  @override
  Future<bool> removeAllOwnAvatarObjects() async {
    log.add('avatar-storage-api');
    return true;
  }
}

String _strip(String s) =>
    s.split('\n').where((l) => !l.trimLeft().startsWith('--')).join('\n');

void main() {
  final goc = File('supabase/2026-11-08_hesap_silme_yasal.sql');
  final geri = File('supabase/geri_al/2026-11-08_hesap_silme_yasal_geri.sql');

  test(
    '1. avatar dosyaları RPC\'den ÖNCE Storage API\'siyle silinir',
    () async {
      final log = <String>[];
      final repo = _Repo(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _LogHttp(log),
        ),
        log,
      );
      await repo.deleteMyAccount();
      expect(log, ['avatar-storage-api', '/rest/v1/rpc/delete_my_account']);
      final src = File(
        'lib/src/data/supabase_zankurd_repository.dart',
      ).readAsStringSync();
      expect(src, contains("client.storage.from('avatars').remove("));
      expect(
        src.indexOf('await removeAllOwnAvatarObjects();'),
        lessThan(src.indexOf("await client.rpc('delete_my_account');")),
      );
    },
  );

  test('2. göç: md5 zinciri, yedek, anonimleştirme, yedek SQL silme', () {
    final raw = goc.readAsStringSync();
    final code = _strip(raw);
    expect(code.trimLeft(), startsWith('begin;'));
    expect(code.trimRight(), endsWith('commit;'));
    expect(raw, isNot(contains('COMMIT')));
    expect(raw, isNot(contains('__TABAN_MD5__')));
    expect(raw, isNot(contains('__NIHAI_MD5__')));
    expect(
      RegExp(r"'[0-9a-f]{32}'").allMatches(code).length,
      2,
      reason: 'taban + nihai md5',
    );
    expect(code, contains("'tur10:public.delete_my_account()'"));
    expect(code, contains('göç zaten uygulanmış görünüyor'));
    expect(code, contains('bilinen canlı taban değil'));
    expect(code, contains('v_adet <> 1'));
    expect(code, contains('p.proacl::text is not distinct from d.acl'));
    // Yardımcı istemciye kapalı, SECURITY DEFINER + sabit search_path.
    expect(
      code,
      contains(
        'revoke all on function public.anonymize_deleted_user_in_snapshots(uuid)',
      ),
    );
    expect(code, contains('security definer'));
    // Eski istemci: delete_my_account imzası değişmez, authenticated kalır.
    expect(code, isNot(contains('drop function')));
    expect(code, contains("has_function_privilege('authenticated'"));
    // Anonimleştirme room_players silinmeden ÖNCE; SQL silme alt işlemde.
    final yeni = code.substring(code.indexOf(r'$y$'));
    expect(
      yeni.indexOf('anonymize_deleted_user_in_snapshots(v_user_id)'),
      lessThan(yeni.indexOf('delete from public.room_players')),
    );
    expect(yeni, contains('exception when others then'));
    // Geri alma + yeni göç applied.md'de bekliyor.
    final back = _strip(geri.readAsStringSync());
    expect(back.trimLeft(), startsWith('begin;'));
    expect(back.trimRight(), endsWith('commit;'));
    expect(back, contains('yedek satırı yok; hiçbir şey geri alınmadı'));
    expect(back, contains('drop function if exists'));
    expect(
      File('supabase/applied.md').readAsStringSync(),
      contains('2026-11-08_hesap_silme_yasal.sql | ✅'),
    );
    // Yerel kanıt betiği (PGlite) var.
    expect(
      File('tool/test_hesap_silme_yasal_local.mjs').readAsStringSync(),
      contains('HESAP SILME YASAL LOCAL: TAMAM'),
    );
  });

  test(
    '3. Pro kapalıyken RevenueCat hiç başlatılmaz, anahtar zorunlu değil',
    () async {
      final premium = await PremiumService.load(proEnabled: false);
      expect(premium.isPremium, isFalse);
      expect(premium.canSell, isFalse);
      final src = File(
        'lib/src/services/premium_service.dart',
      ).readAsStringSync();
      expect(src, contains('if (!proEnabled) {'));
      expect(
        src.indexOf('if (!proEnabled) {'),
        lessThan(src.indexOf('Purchases.configure(')),
      );
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains('kProEnabled &&'));
    },
  );

  test(
    '4. gizlilik: IP\'den yaklaşık konum + RevenueCat + silme, TR ve KU',
    () {
      final html = File('web/privacy.html').readAsStringSync();
      expect(html, contains('Yaklaşık konum (IP adresinden)'));
      expect(html, contains('Cihê nêzîk (ji navnîşana IP)'));
      expect(html, contains('konum iznini ya da GPS'));
      expect(html, contains('RevenueCat\'i başlatmaz'));
      expect(html, contains('RevenueCat nade destpêkirin'));
      // 2.1.2 W7 (alan 7 bulgu 1.5): uygulama RevenueCat'e silme talebi
      // İLETMEZ; metin artık otomatik silme vaat etmez, talep üzerine der.
      expect(html, contains('otomatik silmez'));
      expect(html, contains('iletisim@zankurd.com'));
      expect(html, contains('bi xweber ji RevenueCat jê nake'));
      final doc = File(
        'docs/app_privacy_reconciliation_1.9.2_build15.md',
      ).readAsStringSync();
      expect(
        doc,
        isNot(contains('bulunmadığı için manifestte konum veri sınıfı')),
      );
      expect(doc, contains('Coarse Location'));
      final veri = File('docs/HESAP_SILME_VE_VERI.md').readAsStringSync();
      expect(veri, contains('gizli (secret) API anahtarı'));
      expect(veri, contains('UYGULANMADI'));
    },
  );

  test(
    '5. silme sayfası: misafir ve Apple gizli adres için doğrulama yolu',
    () {
      final html = File('web/delete-account.html').readAsStringSync();
      expect(html, contains('Misafir hesabı (e-postasız)'));
      expect(html, contains('birincil yol uygulama içinden silmedir'));
      expect(html, contains('tek başına silme yetkisi sayılmaz'));
      expect(html, contains('E-postamı Gizle'));
      expect(html, contains('ZK-XXXX'));
      expect(html, contains('Hesabê mêvan (bê e-peyam)'));
      expect(html, contains('rêya sereke jêbirina di nav sepanê de ye'));
      expect(html, contains('Koda lîstikvan bi tena serê xwe'));
      // Eski "yalnız hesaptaki e-postadan" tek yol cümlesi kalmadı.
      expect(
        html,
        isNot(contains('Hesabında kullandığın e-posta adresinden bize')),
      );
    },
  );
}
