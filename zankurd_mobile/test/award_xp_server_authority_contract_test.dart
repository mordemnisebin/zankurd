import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Oda XP'si istemci deltasından değil sunucu skorundan yazılır.
void main() {
  test('award_room_xp oda üyeliği ve bitiş doğrular', () {
    final sql = File(
      'supabase/2026-09-06_award_xp_server_authority.sql',
    ).readAsStringSync();

    expect(sql, contains('create or replace function public.award_room_xp'));
    expect(sql, contains("status is distinct from 'finished'"));
    expect(sql, contains('xp_awarded'));
    expect(sql, contains('public.award_xp_delta(v_delta)'));
    expect(sql, contains('revoke all on function public.award_room_xp'));
    expect(sql, contains('from public, anon'));
    expect(sql, isNot(RegExp(r'\bstable\b', caseSensitive: false)));
  });
}
