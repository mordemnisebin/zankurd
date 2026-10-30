import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/2026-10-30_t11_profile_answer_stats.sql',
  ).readAsStringSync();

  test('T11: bütün çevrimiçi modların yalnız kendi gerçek cevabı sayılır', () {
    for (final (table, alias, choice) in [
      ('player_answers', 'pa', 'selected_option'),
      ('async_duel_answers', 'da', 'choice'),
      ('tournament_match_answers', 'ta', 'choice'),
    ]) {
      expect(sql, contains('from public.$table $alias'));
      expect(sql, contains('$alias.player_id = v_uid'));
      expect(sql, contains("$alias.$choice in ('A', 'B', 'C', 'D')"));
    }
    expect(RegExp(r'\bunion all\b').allMatches(sql), hasLength(2));
    expect(sql, contains("'correct', count(*) filter (where is_correct)"));
    expect(sql, contains("'wrong', count(*) filter (where not is_correct)"));
  });

  test('T11: gizli oda sonucu ve başka oyuncu verisi açılmaz', () {
    expect(sql, contains('rq.room_id = pa.room_id'));
    expect(sql, contains('rq.question_id = pa.question_id'));
    expect(sql, contains('rq.revealed_at is not null'));
    expect(sql, contains('rq.question_index < r.current_question_index'));
    expect(sql, contains('v_uid uuid := auth.uid()'));
    expect(sql, contains('if v_uid is null then'));
    expect(sql, contains("raise exception 'Not authenticated'"));
    expect(sql, contains('security definer'));
    expect(sql, contains('set search_path = public, pg_temp'));
    expect(sql, isNot(contains('correct_option')));
    expect(
      sql,
      contains(
        'revoke all on function public.get_my_online_answer_stats() '
        'from public, anon;',
      ),
    );
    expect(
      sql,
      contains(
        'grant execute on function public.get_my_online_answer_stats() '
        'to authenticated;',
      ),
    );
  });

  test('T11: yalnız yeni RPC; mevcut canlı gövde ve kayıtlar değişmez', () {
    final functions = RegExp(
      r'create or replace function public\.([a-z_]+)\(',
    ).allMatches(sql).map((match) => match.group(1));
    expect(functions, ['get_my_online_answer_stats']);
    expect(
      RegExp(r'\b(insert into|update|delete from)\b').hasMatch(sql),
      isFalse,
    );
    expect(sql.trim(), endsWith('commit;'));
    expect(
      File('supabase/applied.md').readAsStringSync(),
      contains('2026-10-30_t11_profile_answer_stats.sql | ⏳'),
    );
  });
}
