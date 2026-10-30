import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('T16 daily SQL uses own real answers with hidden-result protection', () {
    final sql = File(
      'supabase/2026-10-30_t16_weekly_answer_history.sql',
    ).readAsStringSync();
    for (final (table, alias, choice, timestamp) in [
      ('player_answers', 'pa', 'selected_option', 'created_at'),
      ('async_duel_answers', 'da', 'choice', 'answered_at'),
      ('tournament_match_answers', 'ta', 'choice', 'answered_at'),
    ]) {
      expect(sql, contains('from public.$table $alias'));
      expect(sql, contains('$alias.player_id = v_uid'));
      expect(sql, contains("$alias.$choice in ('A', 'B', 'C', 'D')"));
      expect(sql, contains('$alias.$timestamp >= p_day_boundaries[1]'));
      expect(sql, contains('$alias.$timestamp < p_day_boundaries[8]'));
    }
    expect(sql, contains('rq.revealed_at is not null'));
    expect(sql, contains('rq.question_index < r.current_question_index'));
    expect(sql, contains('v_uid uuid := auth.uid()'));
    expect(sql, contains("raise exception 'Not authenticated'"));
    expect(sql, contains('security definer'));
    expect(sql, contains('set search_path = public, pg_temp'));
    expect(sql, contains('cardinality(p_day_boundaries) <> 8'));
    expect(sql, contains('left join own_answers'));
    expect(sql, contains('a.answered_at >= p_day_boundaries[d.day_index]'));
    expect(sql, contains('a.answered_at < p_day_boundaries[d.day_index + 1]'));
    expect(sql, contains('order by day_index'));
    expect(sql, isNot(contains('correct_option')));
    expect(
      RegExp(
        r'create function public\.([a-z_]+)\(',
      ).allMatches(sql).map((match) => match.group(1)),
      ['get_my_online_answer_history'],
    );
    expect(
      RegExp(r'\b(insert into|update|delete from)\b').hasMatch(sql),
      isFalse,
    );
    expect(sql, contains('from public, anon;'));
    expect(sql, contains('to authenticated;'));
    expect(
      File('supabase/applied.md').readAsStringSync(),
      contains('2026-10-30_t16_weekly_answer_history.sql | ⏳'),
    );
  });
}
