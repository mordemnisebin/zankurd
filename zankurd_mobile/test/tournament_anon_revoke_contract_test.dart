import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Turnuva/yarışma tablolarında baseline GRANT ALL TO anon kapatılır.
void main() {
  test('anon turnuva ve yarışma GRANT\'ı geri alınır', () {
    final sql = File(
      'supabase/2026-09-06_tournament_contest_anon_revoke.sql',
    ).readAsStringSync();

    expect(sql, contains('revoke all on table public.tournaments from anon'));
    expect(
      sql,
      contains('revoke all on table public.tournament_matches from anon'),
    );
    expect(sql, contains('revoke all on table public.contests from anon'));
    expect(
      sql,
      contains('revoke all on table public.contest_entries from anon'),
    );
    expect(
      sql,
      isNot(contains('grant all on table public.tournaments to anon')),
    );
  });
}
