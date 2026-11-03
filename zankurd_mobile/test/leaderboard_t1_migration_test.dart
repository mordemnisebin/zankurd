// T1 sıralama bekçisi.
//
// Arkadaşlar RPC'si invoker olarak profilleri okuyamadığından sıfır puan
// gösteriyordu; yalnız eski XP testi bu RLS sessizliğini yakalayamazdı.
// Genel sıralama iki ayrı fonksiyonda günlük 5000'de kesiliyordu; mevcut
// bekçi eski göçün metnini doğruladığı için sınırın sonradan kaldırıldığını
// da görmüyordu. Bu test son göçü, izinlerini ve geri alma yolunu korur.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/2026-11-03_siralama_t1.sql',
  ).readAsStringSync();
  final rollback = File(
    'supabase/geri_al/2026-11-03_siralama_t1_geri.sql',
  ).readAsStringSync();

  String functionBody(String source, String name) {
    final match = RegExp(
      'create or replace function public\\.$name\\(',
      caseSensitive: false,
    ).firstMatch(source);
    if (match == null) throw StateError('$name tanımı bulunamadı');
    final open =
        source.indexOf(r'$function$', match.start) + r'$function$'.length;
    final close = source.indexOf(r'$function$', open);
    return source.substring(match.start, close + r'$function$'.length);
  }

  test('göç atomik, tekrar çalıştırılabilir ve canlıya uygulanmadı', () {
    expect(migration, contains('\nbegin;\n'));
    expect(migration.trimRight(), endsWith('commit;'));
    expect(migration, contains('create or replace function'));
    expect(migration, isNot(contains('drop function')));
    expect(migration, isNot(contains('drop table')));
    expect(
      File('supabase/applied.md').readAsStringSync(),
      contains('| 2026-11-03_siralama_t1.sql | ✅ |'),
    );
  });

  test('genel sıra ve oyuncu sırası aynı İstanbul günü puanını kullanır', () {
    for (final name in ['get_leaderboard', 'get_my_leaderboard_rank']) {
      final body = functionBody(migration, name);
      expect(body, contains('coalesce(sum(rp.score), 0)::bigint as day_score'));
      expect(body, isNot(contains('least(coalesce(sum(rp.score)')));
      expect(
        body,
        contains("(r.finished_at at time zone 'Europe/Istanbul')::date"),
      );
      expect(
        body,
        contains("coalesce(r.ended_reason, 'completed') = 'completed'"),
      );
      expect(body, contains('b.blocker_id = auth.uid()'));
      expect(body, contains('player_id asc'));
    }
  });

  test(
    'arkadaş RPC yalnız arkadaşları ve çağıranı, güvenli biçimde döndürür',
    () {
      final body = functionBody(migration, 'get_friends_leaderboard');
      expect(body, contains('security definer'));
      expect(body, contains("set search_path to 'public'"));
      expect(body, contains('from public.friends f'));
      expect(body, contains('f.user_id = auth.uid()'));
      expect(body, contains('select auth.uid()'));
      expect(body, contains('union'));
      expect(body, contains('join visible_players vp'));
      expect(body, contains('from public.blocked_users b'));
      expect(body, contains('experience bigint'));
      expect(body, contains('is_self boolean'));
      expect(body, contains('p_days <= 0'));
      expect(body, contains('public.room_players rp'));
      expect(body, isNot(contains('least(coalesce(sum(rp.score)')));
      expect(
        migration,
        contains(
          'revoke all on function public.get_friends_leaderboard(integer) '
          'from public, anon;',
        ),
      );
      expect(
        migration,
        contains(
          'grant execute on function public.get_friends_leaderboard(integer) '
          'to authenticated;',
        ),
      );
    },
  );

  test('geri alma RPC’yi kaldırır ve iki tavanı da geri getirir', () {
    expect(rollback, contains('\nbegin;\n'));
    expect(rollback.trimRight(), endsWith('commit;'));
    expect(
      rollback,
      contains(
        'drop function if exists public.get_friends_leaderboard(integer)',
      ),
    );
    for (final name in ['get_leaderboard', 'get_my_leaderboard_rank']) {
      expect(
        functionBody(rollback, name),
        contains('least(coalesce(sum(rp.score), 0), 5000)'),
      );
    }
  });
}
