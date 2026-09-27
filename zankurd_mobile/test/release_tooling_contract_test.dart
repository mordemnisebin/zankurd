import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `deploy_sftp.sh`in aktarımdan önce varlığını şart koştuğu derleme
/// çıktıları.
///
/// `.well-known` ikilisi 2026-09-27'de eklendi. Davet bağlantısının
/// (zankurd.com/join/KOD) yüklü uygulamayı açması bu iki dosyaya bağlı: iOS
/// `apple-app-site-association`, Android `assetlinks.json`. Derleme onları
/// düşürse ya da aktarım kaçırsa site yine açılır, hiçbir kontrol kızarmaz;
/// bağlantı yalnız tarayıcıda kalır ve kusur ancak telefonda fark edilir.
const _requiredWebOutputs = [
  'index.html',
  'main.dart.js',
  'flutter_bootstrap.js',
  '.htaccess',
  'privacy.html',
  'terms.html',
  'delete-account.html',
  '.well-known/apple-app-site-association',
  '.well-known/assetlinks.json',
];

void main() {
  test('Flutter web viewport is owned by the engine', () {
    final index = File('web/index.html').readAsStringSync();
    expect(index, isNot(contains('name="viewport"')));
  });

  test('Playwright web denetimi platforma özel Chrome yoluna bağlı değil', () {
    final source = File('tools/audit_web_app.mjs').readAsStringSync();
    expect(source, contains("channel: 'chrome'"));
    expect(
      source,
      contains(
        "createRequire(new URL('./playwright/package.json', import.meta.url))",
      ),
    );
    expect(source, isNot(contains('C:/Program Files/Google/Chrome')));
    expect(source, isNot(contains('executablePath:')));
  });

  test(
    'Playwright smoke güncel tek sayfalık onboarding sözleşmesini izler',
    () {
      final source = File('tools/playwright/smoke.mjs').readAsStringSync();
      expect(source, contains("Ez ji 13 salî mezintir im"));
      expect(source, contains('await ageGate.click();'));
      expect(source, contains("await ageGate.waitFor({ state: 'visible'"));
      expect(source, contains("aria-checked"));
      expect(source, isNot(contains('ageGate.check()')));
      expect(source, contains("clickText('Bidomîne')"));
      expect(source, contains("clickText('Dest pê bike')"));
      expect(source, contains("DESTPÊKA BIÇÛK"));
      expect(source, contains("Hemû mijar"));
      expect(source, contains('ZANKURD_EXPECT_SOCIAL'));
      expect(source, contains('expectSocialBackend'));
      expect(source, contains("Pêşkêşkar negihîştbar e"));
      expect(
        source,
        contains("getByRole('button', { name: /Pêşbirka bilez/ })"),
      );
      expect(source, contains('await quickDuel.isEnabled()'));
      expect(source, isNot(contains("Rojbaş, Rojda!")));
      expect(source, isNot(contains("Pêşbirkê bike û bi ser keve")));
    },
  );

  test('learning-focus tarayıcı turu güncel yaş ve misafir kapısını izler', () {
    final source = File(
      'tools/playwright/learning-focus.mjs',
    ).readAsStringSync();
    expect(source, contains("Ez ji 13 salî mezintir im"));
    expect(source, contains("Wek mêvan bidomîne"));
    expect(source, contains("click('Bidomîne')"));
    expect(source, contains("Hînbûn temam bû"));
    expect(source, contains('ZANKURD_AUDIT_DIR'));
    expect(source, contains('ZANKURD_AUDIT_MODE'));
    expect(source, isNot(contains("mode:'local debug, offline repository'")));
  });

  test(
    'Play Store iç test belgesi gerçek artifact ve migration kapısını kullanır',
    () {
      final doc = File('docs/play_store_internal_test.md').readAsStringSync();

      expect(doc, contains('build/app/outputs/bundle/release/app-release.aab'));
      expect(doc, contains('docs/YAYIN_ADIMLARI.md'));
      expect(doc, contains('supabase migration list --linked'));
      expect(doc, contains('20260819000000_gamification_and_custom_rooms.sql'));
      expect(
        doc,
        isNot(contains('release_packages/zankurd-playstore-release.aab')),
      );
      expect(doc, isNot(contains('supabase/daily_spin_rpc.sql')));
      expect(doc, isNot(contains('supabase/quiz_reward_rpc.sql')));
      expect(doc, isNot(contains('supabase/coin_policies.sql')));
    },
  );

  test(
    'CI mobil derlemeleri release derleyicisini ve staging kapısını kullanır',
    () {
      final workflow = File(
        '../.github/workflows/flutter_ci.yml',
      ).readAsStringSync();

      expect(workflow, contains('flutter build appbundle --release'));
      expect(workflow, contains('flutter build ios --release --no-codesign'));
      expect(workflow, contains('--dart-define=APP_ENV=staging'));
      expect(workflow, contains('REVENUECAT_API_KEY_ANDROID=test_'));
      expect(workflow, contains('REVENUECAT_API_KEY_IOS=test_'));
      expect(workflow, isNot(contains('flutter build apk --debug')));
      expect(workflow, isNot(contains('flutter build ios --debug')));
      expect(workflow, isNot(contains('device-nightly-note:')));
    },
  );

  test('yayın rehberi dört cihaz testini kanıt dosyasıyla kapatır', () {
    final steps = File('docs/YAYIN_ADIMLARI.md').readAsStringSync();

    for (final testName in [
      'local_backend_1v1_test.dart',
      'revenuecat_roundtrip_test.dart',
      'notification_real_schedule_test.dart',
      'os_level_resilience_test.dart',
    ]) {
      expect(
        steps,
        contains(testName),
        reason: '$testName yayın kapısında yok',
      );
    }
    expect(
      steps,
      contains('dart run tool/validate_device_release_evidence.dart'),
    );
    expect(steps, contains('.release-device-evidence.json'));
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
    expect(source, contains(r'BACKUP_RUN="$REMOTE_BACKUP_REALPATH/'));
    expect(source, isNot(contains('--protect-args')));
    expect(source, isNot(contains('--delete')));
    final requiredLine = source
        .split('\n')
        .firstWhere((line) => line.startsWith('for output in '));
    for (final output in _requiredWebOutputs) {
      expect(requiredLine, contains(output));
    }
  });

  test('uygulama bağlantısı dosyaları web kaynağında duruyor', () {
    for (final output in _requiredWebOutputs.where(
      (output) => output.startsWith('.well-known/'),
    )) {
      expect(File('web/$output').existsSync(), isTrue, reason: output);
    }
  });

  test('SFTP dry-run yazılamayan yedek kökünde aktarımı durdurur', () async {
    final temp = Directory.systemTemp.createTempSync(
      'zankurd-deploy-preflight-',
    );
    try {
      final script = File('${temp.path}/deploy_sftp.sh');
      File('deploy_sftp.sh').copySync(script.path);
      final bin = Directory('${temp.path}/bin')..createSync();
      final localBuild = Directory('${temp.path}/build/web')
        ..createSync(recursive: true);
      for (final output in _requiredWebOutputs) {
        File('${localBuild.path}/$output')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(output);
      }

      final identity = File('${temp.path}/identity')..writeAsStringSync('key');
      final knownHosts = File('${temp.path}/known_hosts')
        ..writeAsStringSync('host key');
      File('${temp.path}/.env.deploy').writeAsStringSync('''
SFTP_HOST="example.com"
SFTP_USER="deploy"
SFTP_PORT="22"
SFTP_PATH="/remote/web"
SFTP_EXPECTED_REALPATH="/remote/web"
SFTP_BACKUP_PATH="/remote/backups"
SFTP_IDENTITY_FILE="${identity.path}"
SFTP_KNOWN_HOSTS_FILE="${knownHosts.path}"
LIVE_SITE_URL="https://example.com"
LOCAL_DIR="${localBuild.path}"
''');

      final fakeSsh = File('${bin.path}/ssh')
        ..writeAsStringSync(r'''#!/bin/bash
set -euo pipefail
last="${@: -1}"
if [[ "$last" == *"test -d '/remote/backups'"* ]]; then
  printf '%s\n' backup-check >> "$FAKE_COMMAND_LOG"
  if [[ "$last" != *"test -x '/remote/backups'"* ]]; then
    exit 43
  fi
  [[ "$FAKE_BACKUP_WRITABLE" == "1" ]]
elif [[ "$last" == *"cd '/remote/backups' && pwd -P"* ]]; then
  printf '%s\n' "$FAKE_BACKUP_REALPATH"
elif [[ "$last" == *"cd '/remote/web' && pwd -P"* ]]; then
  printf '%s\n' /remote/web
fi
''');
      final fakeRsync = File('${bin.path}/rsync')
        ..writeAsStringSync(r'''#!/bin/bash
set -euo pipefail
printf '%s\n' rsync >> "$FAKE_COMMAND_LOG"
''');
      final chmod = Process.runSync('chmod', [
        '+x',
        script.path,
        fakeSsh.path,
        fakeRsync.path,
      ]);
      expect(chmod.exitCode, 0);

      final commandLog = File('${temp.path}/commands.log');
      final environment = {
        ...Platform.environment,
        'PATH': '${bin.path}:${Platform.environment['PATH'] ?? ''}',
        'FAKE_COMMAND_LOG': commandLog.path,
        'FAKE_BACKUP_WRITABLE': '0',
        'FAKE_BACKUP_REALPATH': '/remote/backups',
      };
      final blocked = await Process.run(script.path, [
        '--dry-run',
      ], environment: environment);

      expect(blocked.exitCode, isNot(0));
      expect(commandLog.readAsStringSync(), contains('backup-check'));
      expect(commandLog.readAsStringSync(), isNot(contains('rsync')));

      commandLog.writeAsStringSync('');
      final allowed = await Process.run(
        script.path,
        ['--dry-run'],
        environment: {...environment, 'FAKE_BACKUP_WRITABLE': '1'},
      );
      expect(allowed.exitCode, 0, reason: '${allowed.stderr}');
      expect(commandLog.readAsStringSync(), contains('rsync'));

      commandLog.writeAsStringSync('');
      final canonicalCollision = await Process.run(
        script.path,
        ['--dry-run'],
        environment: {
          ...environment,
          'FAKE_BACKUP_WRITABLE': '1',
          'FAKE_BACKUP_REALPATH': '/remote/web/backups',
        },
      );
      expect(canonicalCollision.exitCode, isNot(0));
      expect(commandLog.readAsStringSync(), isNot(contains('rsync')));
    } finally {
      temp.deleteSync(recursive: true);
    }
  });

  test('tek komutlu web yayını doğrulama sırasını korur', () {
    final file = File('release_web.sh');
    expect(file.existsSync(), isTrue);
    final source = file.readAsStringSync();
    final analyze = source.indexOf('dart analyze');
    final tests = source.indexOf('flutter test');
    final configValidation = source.indexOf('validate_release_config.dart');
    final build = source.indexOf('flutter build web --release');
    final deploy = source.indexOf('deploy_sftp.sh');
    expect(analyze, greaterThanOrEqualTo(0));
    expect(tests, greaterThan(analyze));
    expect(configValidation, greaterThan(tests));
    expect(build, greaterThan(configValidation));
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

  test(
    'yayın belgesi migration-history ayrışmasını db push öncesi durdurur',
    () {
      final steps = File('docs/YAYIN_ADIMLARI.md').readAsStringSync();
      final cutoverStart = steps.indexOf('## 3. Koordineli üretim kesimi');
      expect(cutoverStart, isNonNegative);
      final nextSection = steps.indexOf('\n## 4.', cutoverStart);
      expect(nextSection, greaterThan(cutoverStart));
      final cutover = steps.substring(cutoverStart, nextSection);

      expect(cutover, contains('supabase migration list --linked'));
      expect(
        cutover,
        contains('20260819000000_gamification_and_custom_rooms.sql'),
      );
      expect(cutover, contains('supabase migration repair'));
      expect(cutover, contains('supabase db push'));
      expect(
        cutover,
        isNot(contains('bir kez uygula')),
        reason:
            'Uygulanmış eski SQL dosyaları history gap yüzünden yeniden '
            'çalıştırılmamalı; önce migration history bilinçli onarılmalı.',
      );
    },
  );

  test(
    'release notes onarılmış 19 Ağustos migration history durumunu açık bırakmaz',
    () {
      final notes = File('docs/release_notes_internal.md').readAsStringSync();
      final sectionStart = notes.indexOf('## 1.9.2+20');
      expect(sectionStart, isNonNegative);
      final olderRelease = notes.indexOf('\n## ', sectionStart + 4);
      final current = notes.substring(
        sectionStart,
        olderRelease < 0 ? notes.length : olderRelease,
      );

      expect(
        current,
        contains('20260819000000_gamification_and_custom_rooms.sql'),
      );
      expect(
        current,
        contains('supabase migration repair --status applied 20260819000000'),
        reason:
            'Applied ledger ile aynı repair gerçeği release notes içinde görünmeli.',
      );
      expect(
        current,
        isNot(
          contains(
            'Production migration-history farkının hesap sahibi onayıyla giderilmesi.',
          ),
        ),
        reason:
            'Tamamlanmış migration-history onarımı kalan manuel kapı sayılamaz.',
      );
    },
  );

  test('1v1 üretim göçü hazırlanmış istemci ve legacy kapısıyla kesilir', () {
    final steps = File('docs/YAYIN_ADIMLARI.md').readAsStringSync();
    final normalized = steps.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    final stagingSmoke = steps.indexOf('Staging/preview iki istemci turu');
    final webArtifact = steps.indexOf(
      'flutter build web --release --no-web-resources-cdn',
    );
    final androidArtifact = steps.indexOf('flutter build appbundle --release');
    final iosArtifact = steps.indexOf('flutter build ipa --release');
    final legacyGate = steps.indexOf('Bu göç yeni `ready` protokolü');
    final cutoverStart = steps.indexOf('## 3. Koordineli üretim kesimi');
    final productionMigration = steps.indexOf(
      'supabase migration list --linked',
      cutoverStart,
    );
    final dryRuns = RegExp(
      r'^\./deploy_sftp\.sh --dry-run$',
      multiLine: true,
    ).allMatches(steps).toList();
    final productionDeploy =
        RegExp(
          r'^\./deploy_sftp\.sh$',
          multiLine: true,
        ).firstMatch(steps)?.start ??
        -1;
    final preMigrationDryRun = dryRuns.isEmpty ? -1 : dryRuns.first.start;
    final cutoverDryRun = dryRuns.length < 2 ? -1 : dryRuns.last.start;
    final productionSmoke = steps.indexOf('**Üretim iki istemci smoke**');
    final appliedRecord = steps.indexOf(
      '`supabase/applied.md` dosyasına tarih/kanıt notuyla `✅`',
    );

    for (final checkpoint in {
      'staging doğrulaması': stagingSmoke,
      'web artefaktı': webArtifact,
      'Android artefaktı': androidArtifact,
      'iOS artefaktı': iosArtifact,
      'legacy istemci kapısı': legacyGate,
      'göç öncesi dağıtım ön kontrolü': preMigrationDryRun,
      'üretim göçü': productionMigration,
      'kesim dağıtım ön kontrolü': cutoverDryRun,
      'hazır web dağıtımı': productionDeploy,
      'üretim iki istemci turu': productionSmoke,
      'applied.md kaydı': appliedRecord,
    }.entries) {
      expect(
        checkpoint.value,
        isNonNegative,
        reason: 'Yayın rehberinde ${checkpoint.key} eksik.',
      );
    }

    expect(webArtifact, greaterThan(stagingSmoke));
    expect(androidArtifact, greaterThan(stagingSmoke));
    expect(iosArtifact, greaterThan(stagingSmoke));
    expect(preMigrationDryRun, greaterThan(webArtifact));
    expect(preMigrationDryRun, greaterThan(androidArtifact));
    expect(preMigrationDryRun, greaterThan(iosArtifact));
    expect(productionMigration, greaterThan(preMigrationDryRun));
    expect(productionMigration, greaterThan(webArtifact));
    expect(productionMigration, greaterThan(androidArtifact));
    expect(productionMigration, greaterThan(iosArtifact));
    expect(productionMigration, greaterThan(legacyGate));
    expect(cutoverDryRun, greaterThan(productionMigration));
    expect(productionDeploy, greaterThan(cutoverDryRun));
    expect(productionSmoke, greaterThan(productionDeploy));
    expect(appliedRecord, greaterThan(productionSmoke));

    expect(normalized, contains('migration\'ı uygulama'));
    expect(normalized, contains('bakım modu'));
    expect(normalized, contains('minimum sürüm'));
    expect(normalized, contains('zorunlu güncelleme'));
    expect(normalized, contains('ilk yayın'));
    expect(normalized, contains('public legacy istemci yok'));
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
      reason:
          'Alt dizindeki iş akışı hiçbir zaman tetiklenmez; kök tek yerdir.',
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
      contains(
        'path: zankurd_mobile/build/app/outputs/bundle/release/app-release.aab',
      ),
    );
    expect(
      source,
      contains('flutter build ios --release --no-codesign'),
      reason: 'iOS derlemesi yoksa Apple yüzeyi yalnız yerelde kırılır.',
    );
    expect(
      source,
      contains(
        'flutter build web --release --no-web-resources-cdn '
        '--dart-define=USE_BUNDLED_SUPABASE_DEFAULTS=true',
      ),
      reason:
          'Release web derlemesi CI dışında kalırsa web-only derleme ve '
          'release yapılandırma kusurları push sırasında görülmez.',
    );
  });

  test('Supabase yayın rehberi uygulanmış göçü yeniden uygulatmaz', () {
    final steps = File('docs/YAYIN_ADIMLARI.md').readAsStringSync();

    expect(steps, contains('20260802000000_multiplayer_session_hardening.sql'));
    expect(steps, contains('20260819000000_gamification_and_custom_rooms.sql'));
    expect(steps, contains('supabase migration list --linked'));
    expect(
      steps,
      contains(
        "to_regprocedure('public.create_online_room(text,integer,integer,integer)')",
      ),
    );
    expect(
      steps,
      isNot(
        contains("to_regprocedure('public.create_online_room(text,integer)')"),
      ),
    );
    expect(
      steps,
      isNot(
        contains(
          '`supabase/2026-08-02_multiplayer_session_hardening.sql` gerekir',
        ),
      ),
    );
  });

  test('iOS inceleme notu güncel giriş seçeneklerini anlatır', () {
    final steps = File('docs/YAYIN_ADIMLARI.md').readAsStringSync();
    final normalized = steps.toLowerCase();

    expect(normalized, contains('apple'));
    expect(normalized, contains('google'));
    expect(normalized, contains('e-posta/şifre'));
    expect(normalized, contains('misafir'));
    expect(
      normalized,
      isNot(contains('sosyal giriş seçenekleri bu sürümde bilerek sunulmaz')),
    );
  });

  test('bir sonraki mağaza sürümü yayımlanmış kimliği tekrar kullanmaz', () {
    final steps = File('docs/YAYIN_ADIMLARI.md').readAsStringSync();
    final normalized = steps.toLowerCase();

    expect(normalized, contains('marketing version'));
    expect(normalized, contains('en yüksek `versioncode`'));
    expect(normalized, contains('app store connect'));
    expect(normalized, contains('zaten yayındaysa'));
    expect(normalized, contains('build numarası'));
  });

  test('mobile release commands always load explicit public configuration', () {
    final example = File('.env.mobile.release.example.json');
    final steps = File('docs/YAYIN_ADIMLARI.md').readAsStringSync();
    expect(example.existsSync(), isTrue);
    expect(example.readAsStringSync(), contains('REVENUECAT_API_KEY_ANDROID'));
    expect(example.readAsStringSync(), contains('REVENUECAT_API_KEY_IOS'));
    expect(steps, contains('--dart-define-from-file=.env.mobile.release.json'));
  });

  test(
    'release guides only reference current configuration and runnable paths',
    () {
      final steps = File('docs/YAYIN_ADIMLARI.md').readAsStringSync();
      expect(steps, contains('staging/preview'));
      expect(steps.toLowerCase(), contains('iki ayrı istemci'));
      expect(
        RegExp(r'`version: \d+\.\d+\.\d+\+\d+`').hasMatch(steps),
        isFalse,
        reason:
            'Yayın rehberi mevcut sürüm numarasını kopyalarsa ilk version bump '
            'sonrasında sessizce bayatlar; yalnız version şablonunu anlatmalı.',
      );
      expect(steps, contains('`version: x.y.z+N`'));

      final releaseGuideBuildCommands = RegExp(
        r'^flutter build [^\r\n]+',
        multiLine: true,
      ).allMatches(steps).map((match) => match.group(0)!).toList();
      expect(
        releaseGuideBuildCommands,
        unorderedEquals([
          'flutter build web --release --no-web-resources-cdn '
              '--dart-define-from-file=.env.web.release.json',
          'flutter build appbundle --release '
              '--dart-define-from-file=.env.mobile.release.json',
          'flutter build ipa --release --export-method=app-store '
              '--dart-define-from-file=.env.mobile.release.json',
        ]),
      );

      final runCommands = RegExp(
        r'^flutter run [^\r\n]+',
        multiLine: true,
      ).allMatches(steps).map((match) => match.group(0)!).toList();
      expect(
        runCommands,
        unorderedEquals([
          'flutter run --release -d <birinci-cihaz-id> '
              '--dart-define=APP_ENV=staging '
              '--dart-define-from-file=.env.mobile.staging.json',
          'flutter run --release -d <ikinci-cihaz-id> '
              '--dart-define=APP_ENV=staging '
              '--dart-define-from-file=.env.mobile.staging.json',
          'flutter run --release -d <iphone-smoke-cihaz-id> '
              '--dart-define-from-file=.env.mobile.release.json',
        ]),
        reason:
            'Staging iki açık cihaz kimliğiyle, son tur ise fiziksel iPhone '
            'kimliğiyle ve doğru env dosyasıyla çalıştırılmalı.',
      );
      expect(steps, contains('bundletool validate --bundle='));
      expect(steps, contains('--device-id=<android-smoke-cihaz-id>'));
      expect(steps, contains('bundletool install-apks'));
      expect(
        steps.toLowerCase(),
        contains('app store ipa doğrudan cihaza kurulmaz'),
      );

      final configValidationCommands = RegExp(
        r'^dart run tool/validate_release_config\.dart [^\r\n]+',
        multiLine: true,
      ).allMatches(steps).map((match) => match.group(0)!).toSet();
      expect(
        configValidationCommands,
        containsAll([
          'dart run tool/validate_release_config.dart '
              '--file=.env.mobile.staging.json --target=mobile '
              '--environment=staging',
          'dart run tool/validate_release_config.dart '
              '--file=.env.web.release.json --target=web '
              '--environment=production',
          'dart run tool/validate_release_config.dart '
              '--file=.env.mobile.release.json --target=mobile '
              '--environment=production',
        ]),
      );

      final multiPlatform = File(
        'docs/multi_platform_release.md',
      ).readAsStringSync();
      expect(
        multiPlatform,
        isNot(contains('NEXT_PUBLIC_SUPABASE_URL=https://')),
      );
      expect(
        multiPlatform,
        isNot(contains('NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=')),
      );

      final platformBuildCommands = RegExp(
        r'^flutter build [^\r\n]+',
        multiLine: true,
      ).allMatches(multiPlatform).map((match) => match.group(0)!).toList();
      expect(
        platformBuildCommands,
        unorderedEquals([
          'flutter build apk --debug '
              '--dart-define-from-file=.env.mobile.release.json',
          'flutter build web --release --no-web-resources-cdn '
              '--dart-define-from-file=.env.web.release.json',
          'flutter build windows --release '
              '--dart-define-from-file=.env.web.release.json',
          'flutter build ipa --release --export-method=app-store '
              '--dart-define-from-file=.env.mobile.release.json',
          'flutter build macos --release '
              '--dart-define-from-file=.env.mobile.release.json',
          'flutter build linux --release '
              '--dart-define-from-file=.env.web.release.json',
        ]),
        reason: 'Her platform komutu kendi açık yapılandırmasını yüklemeli.',
      );

      final integration = File(
        'integration_test/app_flows_test.dart',
      ).readAsStringSync();
      expect(
        integration,
        contains(
          'flutter test integration_test/app_flows_test.dart -d <device>',
        ),
      );
      expect(integration, isNot(contains('test_driver/integration_test.dart')));

      final screenshotGuide = File(
        'tool/screenshots/README.md',
      ).readAsStringSync();
      final scriptPaths = RegExp(
        r'flutter test (tool/screenshots/[^\s`]+\.dart)',
      ).allMatches(screenshotGuide).map((match) => match.group(1)!).toList();
      expect(scriptPaths, isNotEmpty);
      for (final path in scriptPaths) {
        expect(File(path).existsSync(), isTrue, reason: '$path mevcut değil.');
      }
    },
  );

  test('Android imza belgeleri var olan upload anahtarını korur', () {
    final releaseSteps = File('docs/YAYIN_ADIMLARI.md').readAsStringSync();
    final signingGuide = File(
      'docs/android_signing_setup.md',
    ).readAsStringSync();
    final readme = File('README.md').readAsStringSync();
    const certificateSha256 =
        '80:59:2E:73:81:FE:05:2B:0C:E1:49:F2:09:06:0F:32:'
        'CC:7B:53:F3:5B:92:E2:FC:39:58:DD:19:32:E8:98:B3';

    for (final entry in {
      'docs/YAYIN_ADIMLARI.md': releaseSteps,
      'docs/android_signing_setup.md': signingGuide,
      'README.md': readme,
    }.entries) {
      expect(
        entry.value,
        contains('/Users/kocer/.zankurd/signing/zankurd-upload.jks'),
        reason: '${entry.key} doğrulanmış anahtar yolunu göstermeli.',
      );
      expect(
        entry.value,
        contains('zankurd-upload'),
        reason: '${entry.key} doğrulanmış alias değerini göstermeli.',
      );
      expect(
        entry.value,
        isNot(contains('~/zankurd-upload.jks')),
        reason: '${entry.key} eski anahtar yolunu önermemeli.',
      );
      expect(
        entry.value,
        isNot(contains('keytool -genkeypair')),
        reason: '${entry.key} yeni ve uyumsuz bir upload anahtarı üretmemeli.',
      );
      expect(
        entry.value,
        contains(certificateSha256),
        reason: '${entry.key} doğrulanmış upload sertifikasını sabitlemeli.',
      );
    }

    expect(
      releaseSteps,
      isNot(contains('Supabase güvenlik göçleri ve Hostinger SSH')),
      reason:
          'Bekleyen 1v1 göçü varken üst özet bütün göçleri hazır saymamalı.',
    );
    expect(releaseSteps, contains('jarsigner -verify -verbose -certs'));
    expect(
      releaseSteps,
      contains(
        'if [ ! -f .env.mobile.staging.json ]; then\n'
        '  cp .env.mobile.release.example.json .env.mobile.staging.json\n'
        'fi',
      ),
    );
    expect(
      releaseSteps,
      contains(
        'if [ ! -f .env.mobile.release.json ]; then\n'
        '  cp .env.mobile.release.example.json .env.mobile.release.json\n'
        'fi',
      ),
    );
    expect(
      readme,
      contains(
        "if (-not (Test-Path '.env.mobile.release.json')) {\n"
        "  Copy-Item '.env.mobile.release.example.json' "
        "'.env.mobile.release.json'\n"
        '}',
      ),
    );
    expect(readme, isNot(contains('cp -n')));
    expect(releaseSteps, isNot(contains('grep -Eq')));
    expect(
      releaseSteps,
      contains('dart run tool/validate_release_config.dart'),
      reason: 'Env değerleri yazdırılmadan yapısal ve rol bazlı doğrulanmalı.',
    );
    expect(
      releaseSteps,
      isNot(contains('exit 1')),
      reason: 'Yayın rehberi etkileşimli terminali kapatmamalı.',
    );
  });
}
