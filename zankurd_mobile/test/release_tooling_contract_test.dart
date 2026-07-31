import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter web viewport is owned by the engine', () {
    final index = File('web/index.html').readAsStringSync();
    expect(index, isNot(contains('name="viewport"')));
  });

  test('Google Play için bağımsız hesap silme sayfası mevcut', () {
    final page = File('web/delete-account.html');
    expect(page.existsSync(), isTrue);
    final html = page.readAsStringSync();
    expect(html, contains('ZanKurd'));
    expect(html, contains('Hesap silme talebi gönder'));
    expect(html, contains('mailto:'));

    final privacy = File('web/privacy.html').readAsStringSync();
    expect(privacy, contains('delete-account.html'));
  });

  // Bekçinin kapsamı bir zamanlar yalnız beş yerel betikti. Depo kökündeki
  // GitHub iş akışları listede olmadığı için `deploy-web-hostinger.yml`
  // yıllarca düz FTP ile parola gönderdiği hâlde bu testten geçiyordu
  // (2026-07-31 denetimi). Bir bekçinin kapsamı kusurun yaşadığı yeri
  // içermiyorsa o bekçi değildir; iş akışları artık taranıyor.
  test('deployment tooling never uses plaintext FTP or password arguments', () {
    expect(File('tools/.env').existsSync(), isFalse);
    final paths = [
      'deploy_ftp.sh',
      'tools/deploy_hostinger_ftp.py',
      'tools/repair_hostinger_ftp.py',
      'deploy_sftp.sh',
      '.env.deploy.example',
      ...Directory('../.github/workflows')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.yml'))
          .map((file) => file.path),
    ];
    final forbidden = [
      'ftp://',
      'ftplib',
      'FTP_PASS',
      'FTP_PASSWORD',
      '--user',
      '--password',
      'sshpass',
      'curl -u',
      'lftp',
    ];

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      for (final token in forbidden) {
        expect(source, isNot(contains(token)), reason: '$path contains $token');
      }
    }
    expect(File('deploy_sftp.sh').existsSync(), isTrue);
  });

  test('SFTP aktarımı hedefi ve SSH kimliğini sıkı doğrular', () {
    final source = File('deploy_sftp.sh').readAsStringSync();
    expect(source, contains('BatchMode=yes'));
    expect(source, contains('IdentitiesOnly=yes'));
    expect(source, contains('StrictHostKeyChecking=yes'));
    expect(source, contains('UserKnownHostsFile='));
    expect(source, contains('SFTP_EXPECTED_REALPATH'));
    expect(source, contains('pwd -P'));
    expect(source, contains('--delay-updates'));
    expect(source, contains('SFTP_BACKUP_PATH'));
    expect(source, isNot(contains('--protect-args')));
    expect(source, isNot(contains('--delete')));
    for (final output in [
      'index.html',
      'main.dart.js',
      'flutter_bootstrap.js',
      '.htaccess',
      'privacy.html',
      'terms.html',
      'delete-account.html',
    ]) {
      expect(source, contains(output));
    }
  });

  test('tek komutlu web yayını doğrulama sırasını korur', () {
    final file = File('release_web.sh');
    expect(file.existsSync(), isTrue);
    final source = file.readAsStringSync();
    final analyze = source.indexOf('dart analyze');
    final tests = source.indexOf('flutter test');
    final build = source.indexOf('flutter build web --release');
    final deploy = source.indexOf('deploy_sftp.sh');
    expect(analyze, greaterThanOrEqualTo(0));
    expect(tests, greaterThan(analyze));
    expect(build, greaterThan(tests));
    expect(deploy, greaterThan(build));
    expect(source, contains('--dart-define-from-file'));
    // 0c8ea27 bu bayrağı README'ye, kontrol listesine ve CI'ya yazdı ama
    // kontrol listesinin 1. maddesinin çalıştırmanı söylediği bu betiğe
    // yazmadı; düzeltilen kusur bir sonraki yayında geri gelecekti.
    expect(
      source,
      contains('--no-web-resources-cdn'),
      reason: 'Bayrak olmadan CanvasKit 7,2 MB olarak gstatic.com dan iner.',
    );
    expect(
      source,
      contains('useLocalCanvasKit'),
      reason: 'Bayrak sessizce düşerse dağıtım durmalı.',
    );
    expect(source, contains('privacy.html'));
    expect(source, contains('terms.html'));
    expect(source, contains('delete-account.html'));
    expect(source, contains('cmp -s'));
    expect(
      source,
      contains(r'cmp -s "$SCRIPT_DIR/web/$path" "$output"'),
      reason: 'Canlı yasal dosyalar kaynakla birebir karşılaştırılmalı.',
    );
  });

  test('canlı web yayını güvenlik ve kod önbelleği başlıklarını doğrular', () {
    final source = File('release_web.sh').readAsStringSync();
    final deploy = source.lastIndexOf(r'"$SCRIPT_DIR/deploy_sftp.sh"');
    final csp = source.indexOf(
      'verify_header "" "Content-Security-Policy" "default-src \'self\'"',
    );
    final nosniff = source.indexOf(
      'verify_header "" "X-Content-Type-Options" "nosniff"',
    );
    final noCache = source.indexOf(
      'verify_header "main.dart.js" "Cache-Control" "no-cache"',
    );
    final revalidate = source.indexOf(
      'verify_header "main.dart.js" "Cache-Control" "must-revalidate"',
    );

    expect(deploy, greaterThanOrEqualTo(0));
    expect(csp, greaterThan(deploy));
    expect(nosniff, greaterThan(deploy));
    expect(noCache, greaterThan(deploy));
    expect(revalidate, greaterThan(deploy));
  });

  test('ödül yetkisi doğrulaması claim sonucunu davranışsal ölçer', () {
    final source = File(
      'supabase/2026-07-29_client_reward_authority_verify.sql',
    ).readAsStringSync();

    expect(source, contains('claim_probe as'));
    expect(source, contains('not claimed'));
    expect(source, contains('rank_reward = 0'));
    expect(source, contains('badge_awarded is null'));
    expect(
      source,
      isNot(contains("claim_def ilike '%return query select false%'")),
    );
  });

  test('web entrypoints revalidate and security headers are enabled', () {
    final headers = File('web/.htaccess').readAsStringSync();
    final index = File('web/index.html').readAsStringSync();
    expect(headers, contains('Content-Security-Policy'));
    expect(headers, contains('X-Content-Type-Options'));
    expect(headers, contains('flutter_bootstrap\\.js'));
    expect(headers, contains('main\\.dart\\.js'));
    expect(headers, contains('no-cache'));
    // `no-store` + `no-cache` birlikte yazıldığında `no-store` kazanır ve
    // tarayıcı main.dart.js'i diske hiç koymaz: her açılışta 12,9 MB
    // sıfırdan iner. Amaç (bayat bundle ile açılmama) `no-cache` ile zaten
    // sağlanıyor (2026-07-31 denetimi).
    //
    // Ham metin yerine YÖNERGE taranıyor: dosyanın kendi açıklama yorumu
    // niçin `no-store` kullanılmadığını anlatmak için o kelimeyi içeriyor
    // ve düz `contains` denetimi buna takılıyordu.
    final cacheDirectives = RegExp(
      r'^\s*Header\s+set\s+Cache-Control\s+"([^"]*)"',
      multiLine: true,
    ).allMatches(headers).map((match) => match.group(1)!).toList();
    expect(cacheDirectives, isNotEmpty);
    for (final directive in cacheDirectives) {
      expect(
        directive,
        isNot(contains('no-store')),
        reason: 'no-store her sayfa açılışında tüm bundle ı yeniden indirtir.',
      );
    }
    expect(
      headers,
      contains('AddOutputFilterByType DEFLATE'),
      reason: 'Sıkıştırma açık değilse main.dart.js dört katı boyutta iner.',
    );
    expect(
      headers,
      contains(r'<FilesMatch "\.(png|jpg|jpeg|webp|woff|woff2|ttf|svg)$">'),
      reason: 'Yalnızca görsel ve fontlar uzun süreli cache kullanmalı.',
    );
    expect(
      headers,
      contains(r'<FilesMatch "\.(js|mjs|wasm|css|json)$">'),
      reason: 'Kod ve veri dosyaları her yayında yeniden doğrulanmalı.',
    );
    expect(headers, contains('public, max-age=0, must-revalidate'));
    expect(index, contains('src="flutter_bootstrap.js"'));
    expect(index, isNot(contains('flutter_bootstrap.js?v=')));
  });

  // Yayın belgesi bir zamanlar ilk adım olarak "SQL Editor'ü aç, dosyayı
  // yapıştır, Run" diyordu; oysa `applied.md` o göçü çoktan uygulanmış ve
  // canlı sorguyla doğrulanmış olarak kaydediyordu. Sahibi yayına, bitmiş
  // bir işi tekrar yaparak başlıyordu ve gerçek ilk adım (site güncelleme)
  // bir sıra aşağıda kalıyordu. İki belge birbirinden habersiz güncellendiği
  // için kusur sessiz kaldı; bu bekçi ikisini birbirine bağlar.
  test('yayın belgesi uygulanmış bir göçü yeniden çalıştırtmaz', () {
    final applied = File('supabase/applied.md').readAsStringSync();
    final steps = File('docs/YAYIN_ADIMLARI.md').readAsStringSync();

    // `applied.md` satırı: | dosya.sql | ✅ | tarih / not |
    // "✅?" (canlıda çalışıyor ama dosya bazında doğrulanmadı) bilerek
    // dışarıda kalır: onu yeniden çalıştırmak istemek meşrudur.
    final appliedMigrations = RegExp(
      r'^\|\s*([\w./-]+\.sql)\s*\|\s*✅\s*\|',
      multiLine: true,
    ).allMatches(applied).map((match) => match.group(1)!).toSet();

    expect(
      appliedMigrations,
      contains('2026-07-28_player_tag.sql'),
      reason: 'Uygulanma kaydının satır biçimi değiştiyse bekçi kör kalır.',
    );

    // Bir *dosyayı* elle çalıştırma emrinin izleri. Salt okunur bir `select`
    // için "**New query**" demek meşrudur; yasak olan, göç dosyasını editöre
    // yapıştırıp Run'a bastırmaktır.
    const runInstructions = ['**Run**', 'editöre yapıştır'];

    for (final migration in appliedMigrations) {
      final mention = steps.indexOf(migration);
      if (mention < 0) continue;

      final sectionStart = steps.lastIndexOf('\n## ', mention);
      final nextSection = steps.indexOf('\n## ', mention);
      final section = steps.substring(
        sectionStart < 0 ? 0 : sectionStart,
        nextSection < 0 ? steps.length : nextSection,
      );

      for (final instruction in runInstructions) {
        expect(
          section,
          isNot(contains(instruction)),
          reason:
              '$migration canlıda uygulanmış; yayın belgesi onu yeniden '
              'çalıştırmayı iş adımı olarak sunuyor ("$instruction").',
        );
      }
    }
  });

  // GitHub Actions yalnızca deponun kökündeki `.github/workflows` dizinini
  // okur. İş akışı 2026-07-31'e kadar `zankurd_mobile/.github/workflows/`
  // altındaydı, yani analyze, testler ve APK derlemesi hiçbir push'ta
  // koşmuyordu — README ise "CI sonucunu doğrulayın" diyordu. Kusur
  // sessizdi çünkü yeşil bir CI yoktu; hiç CI yoktu.
  test('CI iş akışı deponun kökünde ve alt dizine iniyor', () {
    final root = File('../.github/workflows/flutter_ci.yml');
    expect(
      root.existsSync(),
      isTrue,
      reason: 'flutter_ci.yml depo kökünde değilse GitHub Actions onu görmez.',
    );
    expect(
      Directory('.github/workflows').existsSync(),
      isFalse,
      reason: 'Alt dizindeki iş akışı hiçbir zaman tetiklenmez; kök tek yerdir.',
    );

    final source = root.readAsStringSync();
    expect(
      source,
      contains('working-directory: zankurd_mobile'),
      reason: 'Kökte pubspec yok; adımlar uygulama dizinine inmeli.',
    );
    for (final step in [
      'dart analyze',
      'flutter test --coverage',
      'question_quality_audit.dart gate',
    ]) {
      expect(source, contains(step), reason: 'CI $step adımını kaybetmiş.');
    }
    // upload-artifact yolları working-directory'den etkilenmez.
    expect(source, contains('path: zankurd_mobile/coverage/lcov.info'));
    expect(
      source,
      contains('path: zankurd_mobile/build/app/outputs/flutter-apk'),
    );
  });

  test('mobile release commands always load explicit public configuration', () {
    final example = File('.env.mobile.release.example.json');
    final steps = File('docs/YAYIN_ADIMLARI.md').readAsStringSync();
    expect(example.existsSync(), isTrue);
    expect(example.readAsStringSync(), contains('REVENUECAT_API_KEY_ANDROID'));
    expect(example.readAsStringSync(), contains('REVENUECAT_API_KEY_IOS'));
    expect(steps, contains('--dart-define-from-file=.env.mobile.release.json'));
  });
}
