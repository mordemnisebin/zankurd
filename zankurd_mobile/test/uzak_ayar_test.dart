/// Uzak çalışma ayarı (`app_runtime_config`): zorunlu güncelleme sınırı ve
/// riskli özellikler için kapatma anahtarları.
///
/// ## Kusur
///
/// 10 bin+ kullanıcı hazırlığı denetimi (olcek_*, 2026-11): özellik
/// bayrakları DERLEME-ZAMANI sabitiydi ve eski sürümü zorla yükseltmenin
/// yolu yoktu. Canlıda sorun çıkaran bir özelliği kapatmak yeni sürüm +
/// mağaza incelemesi demekti.
///
/// ## Niçin sessiz kalırdı
///
/// Eksik olan bir şey ÇÖKMEZ: bayrak hiç uzaktan okunmuyordu, yani hiçbir
/// test "sunucu kapat derse özellik kapanır" ya da "sunucuya ulaşılamazsa
/// her şey açık kalır" demiyordu. En kolay hata iki yönden biridir:
/// (1) ulaşılamayan sunucuda varsayılanın KAPALI olması (çevrimdışı oyuncu
/// bütün yarışı kaybeder) ya da (2) uzak anahtarın derleme kapısını AŞIP
/// sunucusu hazır olmayan özelliği açması. Bu dosya ikisini ve tablonun
/// yazma yolu açmadığını sabitler.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/feature_flags.dart';
import 'package:zankurd_mobile/src/config/runtime_config.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RuntimeConfigService.debugReset();
  });
  tearDown(RuntimeConfigService.debugReset);

  group('göç dosyası', () {
    final sql = File('supabase/2026-11-04_uzak_ayar.sql').readAsStringSync();

    test('tek satır, RLS açık, anon+authenticated yalnız SELECT', () {
      expect(sql, contains('\nbegin;'));
      expect(sql, contains('\ncommit;'));
      expect(sql, contains('check (id = 1)'));
      expect(
        sql,
        contains(
          'alter table public.app_runtime_config enable row level security',
        ),
      );
      expect(sql, contains('for select to anon, authenticated'));
      expect(
        sql,
        contains(
          'grant select on table public.app_runtime_config to anon, authenticated',
        ),
      );
      // İstemci yazamaz: ne politika ne yetki.
      expect(sql, isNot(contains('for insert')));
      expect(sql, isNot(contains('for update')));
      expect(sql, isNot(contains('for delete')));
      expect(
        RegExp(r'grant\s+(insert|update|delete|all)').hasMatch(sql),
        false,
      );
    });

    test(
      'tohum: güncelleme KAPALI (0) ve yedi özellik anahtarı varsayılan AÇIK',
      () {
        expect(
          sql,
          contains('insert into public.app_runtime_config (id) values (1)'),
        );
        for (final column in const [
          'async_duel_enabled',
          'tournament_enabled',
          'crowd_rooms_enabled',
          'chat_enabled',
          'push_v2_enabled',
          'share_challenge_enabled',
          'streak_rescue_enabled',
        ]) {
          expect(sql, contains('$column boolean not null default true'));
        }
        for (final column in const [
          'min_supported_build_ios',
          'min_supported_build_android',
          'latest_build_ios',
          'latest_build_android',
        ]) {
          expect(sql, contains('$column integer not null default 0'));
        }
        expect(sql, contains('maintenance_message_tr'));
        expect(sql, contains('maintenance_message_ku'));
      },
    );

    test('geri alma dosyası ve applied.md ✅ kaydı var', () {
      final rollback = File(
        'supabase/geri_al/2026-11-04_uzak_ayar_geri.sql',
      ).readAsStringSync();
      expect(
        rollback,
        contains('drop table if exists public.app_runtime_config'),
      );
      final applied = File('supabase/applied.md').readAsStringSync();
      expect(
        RegExp(r'\| 2026-11-04_uzak_ayar\.sql \| ✅').hasMatch(applied),
        isTrue,
      );
    });
  });

  group('RuntimeConfig', () {
    test('varsayılan: her şey açık, güncelleme yok', () {
      const c = RuntimeConfig.defaults;
      expect([
        c.asyncDuel,
        c.tournament,
        c.crowdRooms,
        c.chat,
        c.pushV2,
        c.shareChallenge,
        c.streakRescue,
      ], everyElement(isTrue));
      expect(c.requiresUpdate(1, TargetPlatform.iOS), isFalse);
      expect(c.hasNewerBuild(1, TargetPlatform.android), isFalse);
    });

    test('bozuk ya da eksik satır varsayılana düşer (uygulama kapanmaz)', () {
      final c = RuntimeConfig.fromJson(const {
        'min_supported_build_ios': 'x',
        'latest_build_ios': -4,
        'chat_enabled': 'false', // yanlış tip: KAPATMA saymaz
        'async_duel_enabled': false,
        'maintenance_message_tr': '   ',
      });
      expect(c.minSupportedBuildIos, 0);
      expect(c.latestBuildIos, 0);
      expect(c.chat, isTrue);
      expect(c.asyncDuel, isFalse);
      expect(c.maintenanceMessageTr, isNull);
    });

    test(
      'zorunlu/yumuşak güncelleme platforma göre; build bilinmiyorsa kilit yok',
      () {
        final c = RuntimeConfig.fromJson(const {
          'min_supported_build_ios': 40,
          'min_supported_build_android': 0,
          'latest_build_ios': 44,
          'latest_build_android': 44,
        });
        expect(c.requiresUpdate(39, TargetPlatform.iOS), isTrue);
        expect(c.requiresUpdate(40, TargetPlatform.iOS), isFalse);
        expect(c.requiresUpdate(39, TargetPlatform.android), isFalse);
        expect(c.requiresUpdate(null, TargetPlatform.iOS), isFalse);
        expect(c.requiresUpdate(0, TargetPlatform.iOS), isFalse);
        expect(c.hasNewerBuild(43, TargetPlatform.android), isTrue);
        expect(c.hasNewerBuild(44, TargetPlatform.android), isFalse);
        expect(c.requiresUpdate(1, TargetPlatform.macOS), isFalse);
      },
    );

    test('bakım iletisi arayüz diline göre, diğer dile düşer', () {
      final c = RuntimeConfig.fromJson(const {
        'maintenance_message_tr': 'Bakım',
      });
      expect(c.maintenanceMessage(isKu: true), 'Bakım');
      expect(c.maintenanceMessage(isKu: false), 'Bakım');
    });
  });

  group('RuntimeConfigService', () {
    test('önbellek yoksa varsayılan; ağa gitmez', () async {
      var fetched = false;
      final s = await RuntimeConfigService.load(
        fetcher: () async {
          fetched = true;
          return null;
        },
      );
      expect(s.value.asyncDuel, isTrue);
      expect(fetched, isFalse, reason: 'yükleme açılışı ağda bekletmemeli');
    });

    test(
      'başarılı okuma değeri önbelleğe yazar; sonraki açılış onu okur',
      () async {
        final s = await RuntimeConfigService.load(
          fetcher: () async => {
            'chat_enabled': false,
            'min_supported_build_ios': 50,
          },
        );
        await s.refresh();
        expect(s.value.chat, isFalse);
        expect(RuntimeConfigService.current.chat, isFalse);

        final next = await RuntimeConfigService.load();
        expect(next.value.chat, isFalse);
        expect(next.value.minSupportedBuildIos, 50);
      },
    );

    test('ulaşılamayan sunucu: eski değer kalır, hata dışarı sızmaz', () async {
      SharedPreferences.setMockInitialValues({
        RuntimeConfigService.cacheKey: '{"tournament_enabled":false}',
      });
      final s = await RuntimeConfigService.load(
        fetcher: () async => throw Exception('ağ yok'),
      );
      await s.refresh();
      expect(s.value.tournament, isFalse);
    });

    test('öne dönüşte yalnız 15 dakika geçtiyse yeniden okur', () async {
      var now = DateTime(2026, 11, 4, 12);
      var calls = 0;
      final s = RuntimeConfigService(
        clock: () => now,
        fetcher: () async {
          calls++;
          return {'chat_enabled': true};
        },
      );
      await s.refreshIfStale();
      expect(calls, 1);
      now = now.add(const Duration(minutes: 14));
      await s.refreshIfStale();
      expect(calls, 1, reason: '15 dakikadan önce');
      now = now.add(const Duration(minutes: 2));
      await s.refreshIfStale();
      expect(calls, 2);
    });
  });

  group('FeatureGate: derleme sabiti VE uzak anahtar', () {
    test(
      'uzak kapatınca özellik kapanır, varsayılanda derleme kararı geçer',
      () {
        expect(FeatureGate.asyncDuel, kAsyncDuelEnabled);
        expect(FeatureGate.tournament, kTournamentEnabled);
        expect(FeatureGate.crowdRooms, isTrue);

        RuntimeConfigService(
          initial: const RuntimeConfig(
            asyncDuel: false,
            tournament: false,
            crowdRooms: false,
            chat: false,
            pushV2: false,
            shareChallenge: false,
            streakRescue: false,
          ),
        );
        expect(FeatureGate.asyncDuel, isFalse);
        expect(FeatureGate.tournament, isFalse);
        expect(FeatureGate.crowdRooms, isFalse);
        expect(FeatureGate.chat, isFalse);
        expect(FeatureGate.pushV2, isFalse);
        expect(FeatureGate.shareChallenge, isFalse);
        expect(FeatureGate.streakRescue, isFalse);
      },
    );

    test('uzak anahtar derleme kapısını AŞAMAZ: sabit VE uzak', () {
      final flags = File(
        'lib/src/config/feature_flags.dart',
      ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
      expect(
        flags,
        contains('kAsyncDuelEnabled && RuntimeConfigService.current.asyncDuel'),
      );
      expect(
        flags,
        contains(
          'kTournamentEnabled && RuntimeConfigService.current.tournament',
        ),
      );
    });

    test(
      'feature_flags.dart ve çağrı yerleri kapıyı kullanır (sabit doğrudan değil)',
      () {
        for (final path in const [
          'lib/src/screens/play_hub_screen.dart',
          'lib/src/screens/home_screen.dart',
          'lib/src/screens/room_screen.dart',
          'lib/src/screens/quiz_result_screen.dart',
          // Jeton eşitleme kapıyı PushTokenSync içinde (tüm yollar için) denetler.
          'lib/src/services/push_token_sync.dart',
        ]) {
          final text = File(path).readAsStringSync();
          expect(text, contains('FeatureGate.'), reason: path);
        }
        final hub = File(
          'lib/src/screens/play_hub_screen.dart',
        ).readAsStringSync();
        expect(hub, isNot(contains('kTournamentEnabled')));
        expect(
          File('lib/src/screens/home_screen.dart').readAsStringSync(),
          isNot(contains('!kAsyncDuelEnabled')),
        );
      },
    );
  });
}
