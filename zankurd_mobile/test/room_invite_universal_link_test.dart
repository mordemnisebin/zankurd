/// Oda daveti bağlantısı telefonda uygulamayı doğrudan açsın.
///
/// ## Kusur
///
/// `JoinDeepLink.shareUrl` `https://www.zankurd.com/join/<KOD>` üretiyordu
/// ve web sürümü bu yolu açınca doğrudan odaya katılıyordu — ama telefonda
/// uygulama KURULU olsa bile bağlantı hep tarayıcıya düşüyordu. Sebep
/// platform tarafında eksikti, Flutter tarafında değil: iOS bir
/// `apple-app-site-association` dosyası ve `associated-domains`
/// entitlement'ı, Android ise bir `assetlinks.json` ve `autoVerify`'lı
/// `https` intent-filter'ı görmeden bağlantıyı uygulamaya asla yönlendirmez.
/// Hiçbiri var olmadığı için iki platform da göz ardı ederek web'e
/// düşüyordu — ki bu YANLIŞ değil (fallback tasarımın parçası), ama
/// uygulama YÜKLÜYKEN de aynı şey oluyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Web sürümü zaten çalıştığı için davet bağlantısı asla "kırık"
/// görünmüyordu — yalnız beklenenden bir adım daha uzundu (tarayıcı açılıp
/// App Store/Play yönlendirmesi ya da web'de oyun) ve bunu ölçen hiçbir
/// bekçi yoktu. Bu dosya platform dosyalarının VAR OLDUĞUNU ve DOĞRU
/// alanları taşıdığını sabitler; gerçek cihazda "Open" banner'ının
/// çıkıp çıkmadığı yalnız simülatör/cihazdan doğrulanabilir (bkz.
/// `test/app_shell_join_deep_link_test.dart` Flutter tarafındaki sıcak/soğuk
/// açılış tüketimi için).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Testler `flutter test` ile paket köküden (`zankurd_mobile/`) koşar;
/// yollar bu köke görelidir (bkz. `native_qa_gate_contract_test.dart`).
const _appleTeamId = 'M43VHXMRDR';
const _bundleId = 'com.zankurd.app';
const _uploadKeyFingerprint =
    '80:59:2E:73:81:FE:05:2B:0C:E1:49:F2:09:06:0F:32:CC:7B:53:F3:5B:92:E2:FC:39:58:DD:19:32:E8:98:B3';

void main() {
  group('iOS associated domains', () {
    for (final path in [
      'ios/Runner/Runner.entitlements',
      'ios/Runner/Runner-Release.entitlements',
    ]) {
      test('$path applinks:www.zankurd.com ve applinks:zankurd.com taşır', () {
        final content = File(path).readAsStringSync();
        expect(
          content,
          contains('<key>com.apple.developer.associated-domains</key>'),
        );
        expect(content, contains('<string>applinks:www.zankurd.com</string>'));
        expect(content, contains('<string>applinks:zankurd.com</string>'));
      });
    }
  });

  group('apple-app-site-association', () {
    final file = File('web/.well-known/apple-app-site-association');

    test('uzantısız dosya olarak var ve geçerli JSON', () {
      expect(file.existsSync(), isTrue);
      // AASA yorum TAŞIYAMAZ (geçerli JSON şartı) — Play App Signing
      // notu burada değil, assetlinks testinin belgesinde yaşar.
      expect(() => jsonDecode(file.readAsStringSync()), returnsNormally);
    });

    test('doğru appID ve /join/* bileşenini tanımlar', () {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final details =
          (json['applinks'] as Map<String, dynamic>)['details'] as List;
      final detail = details.single as Map<String, dynamic>;

      expect(detail['appIDs'], contains('$_appleTeamId.$_bundleId'));
      final components = detail['components'] as List;
      final joinComponent = components.cast<Map<String, dynamic>>().where(
        (c) => c['/'] == '/join/*',
      );
      expect(
        joinComponent,
        isNotEmpty,
        reason: 'Oda daveti yolu (/join/<KOD>) eşleşmeli.',
      );
    });
  });

  group('assetlinks.json', () {
    final file = File('web/.well-known/assetlinks.json');

    test('var ve geçerli JSON', () {
      expect(file.existsSync(), isTrue);
      expect(() => jsonDecode(file.readAsStringSync()), returnsNormally);
    });

    test('doğru paket ve upload anahtarı parmak izini taşır', () {
      final json = jsonDecode(file.readAsStringSync()) as List;
      final statement = json.single as Map<String, dynamic>;

      expect(
        statement['relation'],
        contains('delegate_permission/common.handle_all_urls'),
      );
      final target = statement['target'] as Map<String, dynamic>;
      expect(target['package_name'], _bundleId);
      expect(
        target['sha256_cert_fingerprints'],
        contains(_uploadKeyFingerprint),
        reason:
            'README.md içinde doğrulanmış upload anahtarı parmak izi '
            '(80:59:...:98:B3).',
      );
    });

    // JSON yorum taşıyamadığı için Play App Signing notu BURADA yaşar:
    // uygulama Google Play'e ilk kez çıktığında Play, APK'yi KENDİ
    // anahtarıyla yeniden imzalar (Play App Signing) — o zaman gerçek
    // dağıtılan APK'nin imza parmak izi burada listelenenden (upload
    // anahtarı) FARKLI olur. Play Console > Release > Setup > App
    // integrity'deki "App signing key certificate" SHA-256'sı bu diziye
    // upload anahtarının YANINA eklenmeli (onun yerine değil — Play
    // Console'a doğrudan yüklenen debug/internal test APK'leri hâlâ
    // upload anahtarıyla imzalanır). Bu README'de "henüz Play'de değil"
    // diye not edilen boşluk; kapatılmadan otomatik doğrulama üretim
    // Play APK'sinde başarısız kalır (App Links "Yalnız bu uygulamayla
    // aç" diyaloğunu göstermeyip her zaman tarayıcıya düşer).
    test('Play App Signing parmak izi henüz eklenmedi (bilinçli boşluk)', () {
      final json = jsonDecode(file.readAsStringSync()) as List;
      final target =
          (json.single as Map<String, dynamic>)['target']
              as Map<String, dynamic>;
      final fingerprints = target['sha256_cert_fingerprints'] as List;
      expect(
        fingerprints,
        hasLength(1),
        reason:
            'Uygulama Play\'e çıkınca Play App Signing parmak izi buraya '
            'İKİNCİ satır olarak eklenmeli; bu test o an bilinçli olarak '
            'kızaracak ve güncelleme unutulmayacak.',
      );
    });
  });

  group('AndroidManifest App Links intent-filter', () {
    test('autoVerify https intent-filter iki host ve /join/ pathPrefix taşır, '
        'login-callback filtresi bozulmadı', () {
      final content = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(
        content,
        contains(
          '<data android:scheme="com.zankurd.app" '
          'android:host="login-callback"/>',
        ),
        reason: 'Mevcut OAuth geri çağrı filtresi dokunulmadan kalmalı.',
      );

      expect(content, contains('<intent-filter android:autoVerify="true">'));
      expect(
        content,
        contains(
          'android:scheme="https"\n'
          '                    android:host="www.zankurd.com"\n'
          '                    android:pathPrefix="/join/"',
        ),
      );
      expect(
        content,
        contains(
          'android:scheme="https"\n'
          '                    android:host="zankurd.com"\n'
          '                    android:pathPrefix="/join/"',
        ),
      );
    });
  });

  group('.htaccess', () {
    test('apple-app-site-association için application/json kuralı içerir', () {
      final content = File('web/.htaccess').readAsStringSync();

      expect(content, contains('<FilesMatch "^apple-app-site-association\$">'));
      // Kural gövdesi de doğru içerik türünü ayarlamalı — yalnız dosya
      // adının geçmesi yetmez, `Header set Content-Type` satırı aynı
      // bloğun İÇİNDE olmalı.
      final blockStart = content.indexOf(
        '<FilesMatch "^apple-app-site-association\$">',
      );
      final blockEnd = content.indexOf('</FilesMatch>', blockStart);
      final block = content.substring(blockStart, blockEnd);
      expect(block, contains('Header set Content-Type "application/json"'));
    });

    test('SPA fallback yalnız var olmayan dosya/dizinlerde çalışır', () {
      // `.well-known/*` GERÇEK dosyalar olarak deploy edilir (bkz.
      // `deploy_sftp.sh` — `build/web`i olduğu gibi rsync'ler); bu kural
      // zaten var olan bir dosyayı index.html'e YUTMAZ çünkü `!-f` koşulu
      // dosya diskte bulununca false olur. Regresyon: biri "basitleştirir"
      // diye `RewriteCond` satırlarını kaldırırsa .well-known istekleri
      // sessizce index.html'e düşer ve AASA/assetlinks JSON yerine HTML
      // döner — Apple/Google doğrulayıcıları bunu JSON PARSE HATASI
      // sayıp App Links'i sessizce reddeder.
      final content = File('web/.htaccess').readAsStringSync();
      expect(content, contains('RewriteCond %{REQUEST_FILENAME} !-f'));
      expect(content, contains('RewriteCond %{REQUEST_FILENAME} !-d'));
      expect(content, contains('RewriteRule ^ index.html [L]'));
    });
  });

  // Ana ajan incelemesi (2026-09-27): ilk taslak .htaccess'e HTML tarzı
  // yorum yazmıştı. Apache yapılandırmasında yorum yalnız '#' ile yazılır;
  // HTML yorumu "Invalid command" ile bütün siteyi 500'e düşürür —
  // mağazaların istediği gizlilik ve hesap silme sayfaları dahil. Kuralın
  // VARLIĞINI denetleyen testler bunu göremezdi.
  test('.htaccess HTML yorumu taşımaz (Apache yalnız # tanır)', () {
    final htaccess = File('web/.htaccess').readAsStringSync();
    expect(
      htaccess,
      isNot(
        contains(
          '<'
          '!--',
        ),
      ),
    );
    expect(
      htaccess,
      isNot(
        contains(
          '--'
          '>',
        ),
      ),
    );
  });
}
