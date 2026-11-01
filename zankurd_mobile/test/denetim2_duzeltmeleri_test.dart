/// İkinci tüm-uygulama denetiminin (SONNET_DENETIM, 2026-11-01) on bulgusunun
/// bekçisi.
///
/// ## Kusurlar
///
/// 1. Günün ilk paylaşım ödülü `awardSpinCoins`i çağırıyordu: çarkın günlük
///    hakkını ya da satın alınmış ekstra çevirmeyi yakıyor, bildirim hep
///    "+25" diyordu. Artık ayrı `claim_share_reward` RPC'si; miktar sunucudan.
/// 2. Paylaşım metni iOS'ta da "Play Store'da" diyordu.
/// 3. `suggested_questions` INSERT'inde hız sınırı yoktu (misafir dahil).
/// 4. `log_analytics_event` saatlik sınırı ZATEN canlıda (2026-10-24 S5, 600);
///    denetim eski tanımı okumuştu. Bekçi sınırın silinmemesini sabitler.
/// 5. Sunucu `spend_coins`ı kalıcı reddedince joker bedava kalıyordu.
/// 6. Görev "alındı" bayrağı XP yazılmadan ÖNCE kalıcıydı.
/// 7. `ResultSharer.share` metin yolu try dışındaydı.
/// 8. Bedava günlük joker cihaz yerel gününe bağlıydı.
/// 9. Hesap silme sonrası `signOut` beklenmedik hata verirse "silinemedi"
///    deniyordu.
/// 10. `visibleFor` her `build`de binlerce soruyu sayıyordu.
///
/// ## Niçin sessizdi
///
/// Hiçbiri çökme üretmez: ödül yalnız "yanlış miktar/yanlış hak", metin
/// yalnız yanlış mağaza adı, sınırlar yalnız yokluk, joker/görev/silme yalnız
/// hata dalında yanlış davranır; mutlu yol testleri hepsini geçiyordu.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/daily_mission_store.dart';
import 'package:zankurd_mobile/src/data/free_wildcard_store.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/contest.dart';
import 'package:zankurd_mobile/src/models/daily_mission.dart';
import 'package:zankurd_mobile/src/utils/result_sharer.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalProgressScope.debugReset();
  });

  group('1 paylaşım ödülü çarktan ayrı', () {
    test('sonuç ekranı awardSpinCoins değil claimShareReward çağırır', () {
      final src = _read('lib/src/screens/quiz_result_screen.dart');
      expect(src, contains('repository.claimShareReward'));
      expect(src, isNot(contains('repository.awardSpinCoins')));
    });

    test('bildirim sunucunun verdiği miktarı yazar', () async {
      final amount = await ResultSharer.settleDailyShareRewardAmount(
        awardCoins: () async => 40,
        now: DateTime(2026, 11, 1),
      );
      expect(amount, 40);
      final again = await ResultSharer.settleDailyShareRewardAmount(
        awardCoins: () async => 40,
        now: DateTime(2026, 11, 1),
      );
      expect(again, 0);
      final tr = Tr.forKu(K.shareRewardEarned, false, {'amount': '40'});
      expect(tr, contains('+40'));
      expect(tr, isNot(contains('{amount}')));
      expect(
        Tr.forKu(K.shareRewardEarned, true, {'amount': '40'}),
        contains('+40'),
      );
    });

    test('RPC yoksa istemci ödül vermez (çark yakılmaz)', () {
      final src = _read('lib/src/data/supabase_zankurd_repository.dart');
      final start = src.indexOf('Future<int> claimShareReward()');
      final body = src.substring(start, src.indexOf('@override', start));
      expect(body, contains("rpc<dynamic>('claim_share_reward')"));
      expect(body, contains('isMissingRpcError(error)) return 0'));
      expect(body, isNot(contains('award_spin_coins')));
    });

    test('göç: tek gün, sabit 25, definer, anon yetkisiz', () {
      final sql = _read('supabase/2026-11-01_paylasim_odulu.sql');
      expect(sql, contains('security definer'));
      expect(sql, contains("set search_path to 'public', 'pg_temp'"));
      expect(sql, contains('primary key (player_id, claim_date)'));
      expect(sql, contains('on conflict (player_id, claim_date) do nothing'));
      expect(sql, contains('c_reward constant integer := 25'));
      expect(sql, contains('from public, anon;'));
      expect(sql, contains('public.app_today()'));
      expect(sql, contains("'share_reward'"));
      expect(RegExp(r'^begin;$', multiLine: true).hasMatch(sql), isTrue);
      expect(RegExp(r'^commit;$', multiLine: true).hasMatch(sql), isTrue);
      expect(
        File(
          'supabase/geri_al/2026-11-01_paylasim_odulu_geri.sql',
        ).existsSync(),
        isTrue,
      );
    });
  });

  group('2 mağaza adı platforma göre', () {
    test('iOS App Store, Android Play Store', () {
      final ios = ResultSharer.shareTextKey(TargetPlatform.iOS);
      final android = ResultSharer.shareTextKey(TargetPlatform.android);
      expect(ios, K.resultShareTextIos);
      expect(android, K.resultShareText);
      for (final ku in [false, true]) {
        final params = {
          'score': '1',
          'correct': '1',
          'total': '1',
          'percent': '100',
        };
        expect(Tr.forKu(ios, ku, params), contains('App Store'));
        expect(Tr.forKu(ios, ku, params), isNot(contains('Play Store')));
        expect(Tr.forKu(android, ku, params), contains('Play Store'));
      }
    });
  });

  group('3-4 sunucu sınırları', () {
    test('öneri sınırı: 24 saatte 10, ZK429, rollback var', () {
      final sql = _read('supabase/2026-11-01_oneri_siniri.sql');
      expect(sql, contains('before insert on public.suggested_questions'));
      expect(sql, contains("interval '24 hours'"));
      expect(sql, contains('v_recent >= 10'));
      expect(
        sql,
        contains("'suggestion_rate_limited' using errcode = 'ZK429'"),
      );
      expect(sql, contains('security definer'));
      expect(sql, contains("set search_path to 'public', 'pg_temp'"));
      expect(RegExp(r'^begin;$', multiLine: true).hasMatch(sql), isTrue);
      expect(RegExp(r'^commit;$', multiLine: true).hasMatch(sql), isTrue);
      expect(
        File('supabase/geri_al/2026-11-01_oneri_siniri_geri.sql').existsSync(),
        isTrue,
      );
    });

    test('istemci sınır hatasını çökme diye raporlamaz', () {
      final src = _read('lib/src/data/supabase_zankurd_repository.dart');
      expect(src, contains("contains('suggestion_rate_limited')"));
    });

    test('analitik saatlik sınır canlı tanımda zaten var (S5)', () {
      final sql = _read('supabase/2026-10-24_sunucu_sertlestirme.sql');
      final start = sql.indexOf('-- S5 ---');
      final body = sql.substring(start, start + 2500);
      expect(body, contains("interval '1 hour'"));
      expect(body, contains('v_recent >= 600'));
    });
  });

  group('5 kalıcı ret joker kilidi', () {
    test('retryable olmayan ret turu kilitler ve uyarı gösterir', () {
      final ui = _read('lib/src/screens/quiz/quiz_screen_ui.dart');
      expect(ui, contains('if (!charged) _lockWildcards();'));
      expect(ui, contains('!_wildcardsLocked &&'));
      expect(ui, contains('K.wildcardNoCoins'));
      expect(
        _read('lib/src/screens/quiz_screen.dart'),
        contains('bool _wildcardsLocked = false;'),
      );
    });
  });

  group('6 görev ödülü XP sonrası kalıcı', () {
    DailyMission mission() => DailyMission(
      type: MissionType.answerCorrect,
      target: 3,
      coinReward: 0,
      progress: 3,
      completed: true,
    );

    test('XP yazılamazsa bayrak yazılmaz, yeniden denenebilir', () async {
      final m = mission();
      final store = await DailyMissionStore.loadForTest([m]);
      final failed = await store.claimRewardAfter(
        m,
        () async => throw StateError('xp yazılamadı'),
      );
      expect(failed, isFalse);
      expect(m.claimed, isFalse);

      final ok = await store.claimRewardAfter(m, () async {});
      expect(ok, isTrue);
      expect(m.claimed, isTrue);
      expect(await store.claimRewardAfter(m, () async {}), isFalse);
    });

    test('ana ekran claimRewardAfter kullanır', () {
      final src = _read('lib/src/screens/home_screen.dart');
      expect(src, contains('claimRewardAfter(mission'));
      expect(src, isNot(contains('missionStore.claimReward(mission)')));
    });
  });

  test('7 metin yolundaki paylaşım çağrısı try içinde', () {
    final src = _read('lib/src/utils/result_sharer.dart');
    expect(src, contains("reason: 'result_share_text'"));
    expect(src.trimRight().contains('return false;'), isTrue);
  });

  group('8 bedava joker günü İstanbul', () {
    test('dayKey contestDayString ile aynı; saat dilimi kaymaz', () {
      // 22:30 UTC = İstanbul'da ertesi gün 01:30.
      final late = DateTime.utc(2026, 10, 24, 22, 30);
      expect(FreeWildcardStore.dayKey(late), contestDayString(late));
      expect(FreeWildcardStore.dayKey(late), '2026-10-25');
    });

    test('aynı İstanbul gününde ikinci hak yok', () async {
      final a = DateTime.utc(2026, 10, 24, 21, 30); // İstanbul 25'i 00:30
      final b = DateTime.utc(2026, 10, 25, 20, 30); // İstanbul 25'i 23:30
      expect(await FreeWildcardStore.consume(now: a), isTrue);
      expect(await FreeWildcardStore.consume(now: b), isFalse);
    });
  });

  test('9 silme sonrası beklenmedik hatada yerel çıkış zorlanır', () {
    final src = _read('lib/src/screens/settings_screen.dart');
    expect(src, contains('serverDeleted = true;'));
    expect(src, contains('await authProvider.forceLocalSignOut();'));
    expect(
      _read('lib/src/providers/auth_provider.dart'),
      contains('SignOutScope.local'),
    );
  });

  test('10 alt kategori listesi build içinde hesaplanmaz', () {
    final src = _read('lib/src/screens/subcategory_screen.dart');
    final build = src.substring(src.indexOf('Widget build('));
    expect(build, isNot(contains('SubcategoryConfig.visibleFor')));
    expect(src, contains('_refreshVisible()'));
  });
}
