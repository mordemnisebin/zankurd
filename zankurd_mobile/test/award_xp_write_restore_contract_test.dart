import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 2026-07-29 no-op `award_xp_delta` sıralamayı boş bıraktı. Geri yazım
/// göçü delta eklemeli, çağrı/gün tavanı olmalı, STABLE olmamalı.
void main() {
  test('geri yazım göçü XP delta ekler ve tavan uygular', () {
    final sql = File(
      'supabase/2026-09-02_award_xp_delta_write_restore.sql',
    ).readAsStringSync();

    expect(sql, contains('create or replace function public.award_xp_delta'));
    expect(sql, contains('set xp = coalesce(xp, 0) + v_delta'));
    expect(sql, contains('least(v_delta, 2000)'));
    expect(sql, contains('20000'));
    expect(sql, contains('security definer'));
    expect(sql, contains('set search_path = public'));
    expect(sql, isNot(RegExp(r'\bstable\b', caseSensitive: false)));
    expect(sql, contains('revoke all on function public.award_xp_delta'));
    expect(sql, contains('from public, anon'));
  });
}
